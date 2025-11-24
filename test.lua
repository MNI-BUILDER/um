-- FULLY DEFENSIVE UI LAYOUT + AUTO-SCROLL (SeasonPass Store fix included)
-- Put this in StarterPlayerScripts (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.22      -- lower = slower (tweak)
local UI_SCALE = 0.75
local SCROLL_PAUSE_TIME = 1.2
local RESCAN_INTERVAL = 1      -- seconds
local DEBUG = false            -- set true to see prints

local function dbg(...)
	if DEBUG then print("[AutoScroll]", ...) end
end

-- ---------- find & arrange UIs ----------
local foundUIs = {}

local function tryAddUI(ui)
	for _, name in ipairs(UI_NAMES) do
		if ui.Name == name then
			if not table.find(foundUIs, ui) then
				table.insert(foundUIs, ui)
				ui.Enabled = true
				if ui:IsA("ScreenGui") then
					ui.ResetOnSpawn = false
					ui.IgnoreGuiInset = false
				end
				dbg("Added UI:", ui.Name)
			end
		end
	end
end

for _, name in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(name)
	if ui then tryAddUI(ui) end
end
playerGui.ChildAdded:Connect(tryAddUI)

local cornerPositions = {
	{anchor = Vector2.new(0,0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)},
	{anchor = Vector2.new(1,0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)},
	{anchor = Vector2.new(0,1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)},
	{anchor = Vector2.new(1,1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)},
}

local function arrangeUIs()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local view = cam.ViewportSize
	local uiW = math.floor(view.X * 0.35)
	local uiH = math.floor(view.Y * 0.45)
	for idx, ui in ipairs(foundUIs) do
		local corner = cornerPositions[((idx-1) % #cornerPositions) + 1]
		for _, child in ipairs(ui:GetChildren()) do
			if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("ScrollingFrame") then
				child.Visible = true
				child.AnchorPoint = corner.anchor
				child.Position = corner.position
				child.Size = UDim2.new(0, uiW, 0, uiH)
				local sc = child:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", child)
				sc.Scale = UI_SCALE
			end
		end
	end
end

arrangeUIs()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs) end

-- ---------- scrolling frames management ----------
local managed = {} -- { { frame = ScrollingFrame, layout = layoutObj, currentY = number } }

local function findLayout(sf)
	return sf:FindFirstChildOfClass("UIListLayout")
		or sf:FindFirstChildOfClass("UIGridLayout")
		or sf:FindFirstChildOfClass("UIPageLayout")
end

local function addManaged(sf)
	for _, e in ipairs(managed) do if e.frame == sf then return end end
	local layout = findLayout(sf)
	local entry = { frame = sf, layout = layout, currentY = (sf.CanvasPosition and sf.CanvasPosition.Y) or 0 }
	table.insert(managed, entry)
	sf.ScrollingEnabled = true
	sf.ScrollBarThickness = 8
	dbg("Managed added:", sf:GetFullName())

	-- if layout exists, keep CanvasSize updated
	if layout then
		local function updateCanvasFromLayout()
			-- grid: set both X and Y (defensive)
			if layout:IsA("UIGridLayout") then
				local acs = layout.AbsoluteContentSize
				if acs and (acs.X > 0 or acs.Y > 0) then
					sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
				end
			else
				local acs = layout.AbsoluteContentSize
				if acs and acs.Y > 0 then
					sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
				end
			end
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasFromLayout)
		task.defer(updateCanvasFromLayout)
	end

	-- if layout not present, also listen for children changes and update CanvasSize fallback
	sf.DescendantAdded:Connect(function()
		task.defer(function() -- give time for layout to update if any
			-- attempt to attach layout if it appears later
			if not entry.layout then
				entry.layout = findLayout(sf)
				if entry.layout then
					dbg("Layout found later for:", sf:GetFullName())
					-- hook new layout
					entry.layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
						if entry.layout:IsA("UIGridLayout") then
							sf.CanvasSize = UDim2.new(0, entry.layout.AbsoluteContentSize.X, 0, entry.layout.AbsoluteContentSize.Y)
						else
							sf.CanvasSize = UDim2.new(0, 0, 0, entry.layout.AbsoluteContentSize.Y)
						end
					end)
					task.defer(function()
						if entry.layout:IsA("UIGridLayout") then
							sf.CanvasSize = UDim2.new(0, entry.layout.AbsoluteContentSize.X, 0, entry.layout.AbsoluteContentSize.Y)
						else
							sf.CanvasSize = UDim2.new(0, 0, 0, entry.layout.AbsoluteContentSize.Y)
						end
					end)
				end
			end
		end)
	end)
end

local function computeContentHeight(entry)
	local f = entry.frame
	if not f then return 0 end

	-- prefer AbsoluteCanvasSize if available and > 0
	if f.AbsoluteCanvasSize and f.AbsoluteCanvasSize.Y and f.AbsoluteCanvasSize.Y > 0 then
		return f.AbsoluteCanvasSize.Y
	end

	-- prefer layout absolutecontentsize
	if entry.layout and entry.layout.AbsoluteContentSize and entry.layout.AbsoluteContentSize.Y > 0 then
		return entry.layout.AbsoluteContentSize.Y
	end

	-- fallback: sum children heights (account for Layouts margins partly)
	local total = 0
	for _, child in ipairs(f:GetChildren()) do
		if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("TextLabel") or child:IsA("ImageButton") then
			if child.AbsoluteSize and child.AbsoluteSize.Y then
				total = total + child.AbsoluteSize.Y
			end
		end
	end
	return total
end

local function getMaxScroll(entry)
	local f = entry.frame
	if not f or not f.Parent then return 0 end
	if f.AbsoluteWindowSize and f.AbsoluteWindowSize.Y and f.AbsoluteWindowSize.Y > 0 and f.AbsoluteCanvasSize and f.AbsoluteCanvasSize.Y then
		return math.max(0, f.AbsoluteCanvasSize.Y - f.AbsoluteWindowSize.Y)
	end

	if f.AbsoluteSize and f.AbsoluteSize.Y and f.AbsoluteSize.Y > 0 then
		local content = computeContentHeight(entry)
		return math.max(0, content - f.AbsoluteSize.Y)
	end

	return 0
end

-- aggressive rescan that also tries to find the SeasonPass Store path
local function rescanAll()
	-- scan known UIs
	for _, ui in ipairs(foundUIs) do
		for _, desc in ipairs(ui:GetDescendants()) do
			if desc:IsA("ScrollingFrame") then
				addManaged(desc)
			end
		end
		-- If SeasonPassUI specifically present, search for "Store" path
		if ui.Name == "SeasonPassUI" then
			local frame = ui:FindFirstChild("SeasonPassFrame", true) -- not real API; fallback below
			-- Roblox doesn't have FindFirstChild with deep search built-in, so do manual:
			-- manual deep find for "Store" container (defensive)
			for _, d in ipairs(ui:GetDescendants()) do
				if d.Name == "Store" and d:IsA("ScrollingFrame") then
					addManaged(d)
					dbg("SeasonPass Store found by name 'Store'")
				elseif d.Name == "Store" then
					-- store might be a frame that contains a ScrollingFrame inside
					for _, inner in ipairs(d:GetDescendants()) do
						if inner:IsA("ScrollingFrame") then
							addManaged(inner)
							dbg("SeasonPass Store -> found inner ScrollingFrame")
						end
					end
				end
			end
		end
	end
end

-- initial scan + periodic rescan (handles late-spawned UI)
rescanAll()
task.spawn(function()
	while true do
		rescanAll()
		task.wait(RESCAN_INTERVAL)
	end
end)

-- ---------- smooth auto-scroll loop ----------
local scrollDir = 1
local progress = 0
local paused = false
local pauseTimer = 0

local function progressToTargetY(p, entry)
	local max = getMaxScroll(entry)
	if max <= 0 then return 0 end
	p = math.clamp(p, 0, 1)
	return p * max
end

RunService.RenderStepped:Connect(function(dt)
	if #managed == 0 then return end

	-- pause handling
	if paused then
		pauseTimer = pauseTimer + dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			paused = false
			pauseTimer = 0
			scrollDir = -scrollDir
			dbg("resume, dir:", scrollDir)
		else
			return
		end
	end

	-- advance progress (normalized)
	local normalizedSpeed = SCROLL_SPEED -- already small
	progress = progress + (dt * scrollDir * normalizedSpeed)

	if progress >= 1 then
		progress = 1
		paused = true
	elseif progress <= 0 then
		progress = 0
		paused = true
	end

	for _, entry in ipairs(managed) do
		local f = entry.frame
		if not f or not f.Parent then goto continue end
		-- only apply if absolute sizes ready
		if f.AbsoluteSize and f.AbsoluteSize.Y > 0 then
			local maxScroll = getMaxScroll(entry)
			if maxScroll > 0 then
				local targetY = progressToTargetY(progress, entry)
				-- lerp current position for smoothness
				entry.currentY = entry.currentY or (f.CanvasPosition and f.CanvasPosition.Y) or 0
				local lerpAlpha = math.clamp(15 * dt, 0, 1) -- higher = snappier
				entry.currentY = entry.currentY + (targetY - entry.currentY) * lerpAlpha
				-- write integer-safe
				local writeY = math.floor(entry.currentY + 0.5)
				if f.CanvasPosition == nil then
					f.CanvasPosition = Vector2.new(0, writeY)
				else
					f.CanvasPosition = Vector2.new(0, writeY)
				end
			end
		else
			-- wait until absolute size ready (most likely first frames render)
			dbg("Skipping frame (no AbsoluteSize yet):", f:GetFullName())
		end
		::continue::
	end
end)

dbg("Defensive auto-scroll loaded. Managed count will grow after scanning.")
