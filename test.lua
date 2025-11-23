-- FINAL FIX: Aggressive + Defensive Auto-Scroll (uses AbsoluteCanvasSize first)
-- Paste into StarterPlayerScripts (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.3     
local UI_SCALE = 0.76
local SCROLL_PAUSE_TIME = 1.0
local RESCAN_INTERVAL = 1      -- seconds
local DEBUG = false            -- set true to see console debug

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

-- ---------- managed frames ----------
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

	-- Keep CanvasSize updated from layout if layout exists
	if layout then
		local function updateCanvas()
			local acs = layout.AbsoluteContentSize
			if acs and (acs.Y > 0 or acs.X > 0) then
				if layout:IsA("UIGridLayout") then
					sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
				else
					sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
				end
			end
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
		task.defer(updateCanvas)
	end

	-- Fallback: if children change, try to recalc canvas / detect layout later
	sf.DescendantAdded:Connect(function()
		task.defer(function()
			if not entry.layout then
				entry.layout = findLayout(sf)
				if entry.layout then
					dbg("Found layout later for:", sf:GetFullName())
					entry.layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
						local acs = entry.layout.AbsoluteContentSize
						if entry.layout:IsA("UIGridLayout") then
							sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
						else
							sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
						end
					end)
					task.defer(function()
						local acs = entry.layout.AbsoluteContentSize
						if entry.layout:IsA("UIGridLayout") then
							sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
						else
							sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
						end
					end)
				end
			end
		end)
	end)
end

-- ---------- content / max scroll helpers ----------
local function computeContentHeight(entry)
	local f = entry.frame
	if not f then return 0 end

	-- 1) Prefer AbsoluteCanvasSize (very reliable)
	if f.AbsoluteCanvasSize and f.AbsoluteCanvasSize.Y and f.AbsoluteCanvasSize.Y > 0 then
		return f.AbsoluteCanvasSize.Y
	end

	-- 2) Prefer layout AbsoluteContentSize
	if entry.layout and entry.layout.AbsoluteContentSize and entry.layout.AbsoluteContentSize.Y > 0 then
		return entry.layout.AbsoluteContentSize.Y
	end

	-- 3) Sum children heights as last resort
	local total = 0
	for _, child in ipairs(f:GetChildren()) do
		-- count common UI elements; ignore layout objects themselves
		if child:IsA("GuiObject") and not child:IsA("UILayout") then
			if child.AbsoluteSize and child.AbsoluteSize.Y then
				total = total + math.max(0, child.AbsoluteSize.Y)
			end
		end
	end
	return total
end

local function getMaxScroll(entry)
	local f = entry.frame
	if not f or not f.Parent then return 0 end

	-- Prefer AbsoluteCanvasSize & AbsoluteWindowSize if available
	if f.AbsoluteCanvasSize and f.AbsoluteWindowSize and f.AbsoluteCanvasSize.Y and f.AbsoluteWindowSize.Y then
		if f.AbsoluteWindowSize.Y > 0 then
			return math.max(0, f.AbsoluteCanvasSize.Y - f.AbsoluteWindowSize.Y)
		end
	end

	-- Fallback to contentHeight - frame size (AbsoluteSize)
	local content = computeContentHeight(entry)
	if f.AbsoluteSize and f.AbsoluteSize.Y and f.AbsoluteSize.Y > 0 then
		return math.max(0, content - f.AbsoluteSize.Y)
	end

	return 0
end

-- aggressive rescan that guarantees SeasonPass Store is found
local function rescanAll()
	for _, ui in ipairs(foundUIs) do
		for _, desc in ipairs(ui:GetDescendants()) do
			if desc:IsA("ScrollingFrame") then
				addManaged(desc)
			end
		end

		-- Extra: try to find 'Store' nodes under SeasonPassUI and attach inner ScrollingFrame
		if ui.Name == "SeasonPassUI" then
			for _, d in ipairs(ui:GetDescendants()) do
				if d.Name == "Store" then
					-- If the Store itself is the ScrollingFrame
					if d:IsA("ScrollingFrame") then
						addManaged(d)
						dbg("Attached Store ScrollingFrame directly")
					else
						-- Look inside Store for a ScrollingFrame
						for _, inner in ipairs(d:GetDescendants()) do
							if inner:IsA("ScrollingFrame") then
								addManaged(inner)
								dbg("Attached inner ScrollingFrame inside Store")
							end
						end
					end
				end
			end
		end
	end
end

-- initial scan + periodic rescan
rescanAll()
task.spawn(function()
	while true do
		rescanAll()
		task.wait(RESCAN_INTERVAL)
	end
end)

-- ---------- smooth auto-scroll loop ----------
local direction = 1
local progress = 0
local paused = false
local pauseTimer = 0

local function progressToY(p, entry)
	local max = getMaxScroll(entry)
	if max <= 0 then return 0 end
	p = math.clamp(p, 0, 1)
	return p * max
end

RunService.RenderStepped:Connect(function(dt)
	if #managed == 0 then return end

	if paused then
		pauseTimer = pauseTimer + dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			paused = false
			pauseTimer = 0
			direction = -direction
			dbg("Resume direction:", direction)
		else
			return
		end
	end

	-- advance normalized progress
	progress = progress + (dt * direction * SCROLL_SPEED)

	if progress >= 1 then
		progress = 1
		paused = true
	elseif progress <= 0 then
		progress = 0
		paused = true
	end

	for _, entry in ipairs(managed) do
		local f = entry.frame
		if not f or not f.Parent then goto cont end

		-- ensure frame has size
		if f.AbsoluteSize and f.AbsoluteSize.Y > 0 then
			local maxScroll = getMaxScroll(entry)
			if maxScroll > 0 then
				local targetY = progressToY(progress, entry)
				entry.currentY = entry.currentY or (f.CanvasPosition and f.CanvasPosition.Y) or 0
				-- smooth lerp
				local alpha = math.clamp(10 * dt, 0, 1)
				entry.currentY = entry.currentY + (targetY - entry.currentY) * alpha
				local writeY = math.floor(entry.currentY + 0.5)
				-- Set CanvasPosition defensively
				local ok, err = pcall(function()
					f.CanvasPosition = Vector2.new(0, writeY)
				end)
				if not ok then
					dbg("CanvasPosition write failed for", f:GetFullName(), err)
				end
			end
		else
			dbg("Waiting for AbsoluteSize:", f:GetFullName())
		end

		::cont::
	end
end)

dbg("Auto-scroll loaded. Managed frames will populate after scanning.")
