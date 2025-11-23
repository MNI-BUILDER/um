-- FINAL DEFENSIVE AUTO-SCROLL + SEASONPASS SIZE FIX
-- Put in StarterPlayerScripts (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.3      -- lower = slower
local UI_SCALE = 0.76
local SCROLL_PAUSE_TIME = 1.0
local RESCAN_INTERVAL = 1
local DEBUG = true            -- set true to show detailed debug & errors

-- Make SeasonPass bigger by this multiplier (1.0 = same size)
local SEASON_UI_SIZE_MULTIPLIER = 1.18

local function dbg(...)
	if DEBUG then
		print("[AutoScroll DEBUG]", ...)
	end
end

local function safePcall(fn, ctx)
	local ok, err = pcall(fn)
	if not ok then
		warn(("AutoScroll ERROR (%s): %s"):format(ctx or "unknown", tostring(err)))
		if DEBUG then
			print(debug.traceback())
		end
	end
	return ok, err
end

-- ---------- find & arrange UIs ----------
local foundUIs = {}

local function tryAddUI(ui)
	safePcall(function()
		for _, name in ipairs(UI_NAMES) do
			if ui and ui.Name == name then
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
	end, "tryAddUI")
end

-- initial find
safePcall(function()
	for _, name in ipairs(UI_NAMES) do
		local ui = playerGui:FindFirstChild(name)
		if ui then tryAddUI(ui) end
	end
end, "initial UI find")

playerGui.ChildAdded:Connect(function(child)
	safePcall(function() tryAddUI(child) end, "ChildAdded tryAddUI")
end)

local cornerPositions = {
	{anchor = Vector2.new(0,0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)},
	{anchor = Vector2.new(1,0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)},
	{anchor = Vector2.new(0,1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)},
	{anchor = Vector2.new(1,1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)},
}

local function arrangeUIs()
	safePcall(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local view = cam.ViewportSize
		local baseW = math.floor(view.X * 0.35)
		local baseH = math.floor(view.Y * 0.45)

		for idx, ui in ipairs(foundUIs) do
			local corner = cornerPositions[((idx-1) % #cornerPositions) + 1]
			-- season multiplier
			local multiplier = (ui.Name == "SeasonPassUI") and SEASON_UI_SIZE_MULTIPLIER or 1.0
			local uiW = math.floor(baseW * multiplier)
			local uiH = math.floor(baseH * multiplier)

			for _, child in ipairs(ui:GetChildren()) do
				if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("ScrollingFrame") then
					-- wrap property changes in pcall to prevent runtime errors killing the loop
					safePcall(function()
						child.Visible = true
						child.AnchorPoint = corner.anchor
						child.Position = corner.position
						child.Size = UDim2.new(0, uiW, 0, uiH)

						local sc = child:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", child)
						sc.Scale = UI_SCALE
					end, "arrange child "..tostring(child:GetFullName()))
				end
			end
		end
	end, "arrangeUIs")
end

-- initial arrange
arrangeUIs()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		safePcall(arrangeUIs, "ViewportSize changed arrangeUIs")
	end)
end

-- ---------- scrolling frames management ----------
local managed = {} -- entries: { frame = ScrollingFrame, layout = layoutObj, currentY = number }

local function findLayout(sf)
	return sf:FindFirstChildOfClass("UIListLayout")
		or sf:FindFirstChildOfClass("UIGridLayout")
		or sf:FindFirstChildOfClass("UIPageLayout")
end

local function addManaged(sf)
	safePcall(function()
		for _, e in ipairs(managed) do if e.frame == sf then return end end
		local layout = findLayout(sf)
		local entry = { frame = sf, layout = layout, currentY = (sf.CanvasPosition and sf.CanvasPosition.Y) or 0 }
		table.insert(managed, entry)

		-- ensure user can still scroll manually
		sf.ScrollingEnabled = true
		sf.ScrollBarThickness = 8

		dbg("Managed added:", sf:GetFullName())

		-- If layout exists, update CanvasSize from AbsoluteContentSize
		if layout then
			local function updateCanvas()
				safePcall(function()
					local acs = layout.AbsoluteContentSize
					if acs and (acs.Y > 0 or acs.X > 0) then
						if layout:IsA("UIGridLayout") then
							sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
						else
							sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
						end
					end
				end, "updateCanvas for "..sf:GetFullName())
			end
			layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
			task.defer(updateCanvas)
		end

		-- fallback: if children added later, try to attach layout and update CanvasSize
		sf.DescendantAdded:Connect(function()
			task.defer(function()
				if not entry.layout then
					entry.layout = findLayout(sf)
					if entry.layout then
						dbg("Layout found later for:", sf:GetFullName())
						entry.layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
							safePcall(function()
								local acs = entry.layout.AbsoluteContentSize
								if entry.layout:IsA("UIGridLayout") then
									sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
								else
									sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
								end
							end, "DescendantAdded layout update for "..sf:GetFullName())
						end)
						task.defer(function()
							safePcall(function()
								local acs = entry.layout.AbsoluteContentSize
								if entry.layout:IsA("UIGridLayout") then
									sf.CanvasSize = UDim2.new(0, acs.X, 0, acs.Y)
								else
									sf.CanvasSize = UDim2.new(0, 0, 0, acs.Y)
								end
							end, "deferred layout set for "..sf:GetFullName())
						end)
					end
				end
			end)
		end)
	end, "addManaged")
end

-- ---------- content / max scroll helpers ----------
local function computeContentHeight(entry)
	local f = entry.frame
	if not f then return 0 end

	-- 1: Prefer AbsoluteCanvasSize
	if f.AbsoluteCanvasSize and f.AbsoluteCanvasSize.Y and f.AbsoluteCanvasSize.Y > 0 then
		return f.AbsoluteCanvasSize.Y
	end

	-- 2: layout AbsoluteContentSize
	if entry.layout and entry.layout.AbsoluteContentSize and entry.layout.AbsoluteContentSize.Y > 0 then
		return entry.layout.AbsoluteContentSize.Y
	end

	-- 3: sum children as fallback
	local total = 0
	for _, child in ipairs(f:GetChildren()) do
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

	-- prefer AbsoluteCanvasSize/Window if present
	if f.AbsoluteCanvasSize and f.AbsoluteWindowSize and f.AbsoluteCanvasSize.Y and f.AbsoluteWindowSize.Y and f.AbsoluteWindowSize.Y > 0 then
		return math.max(0, f.AbsoluteCanvasSize.Y - f.AbsoluteWindowSize.Y)
	end

	local content = computeContentHeight(entry)
	if f.AbsoluteSize and f.AbsoluteSize.Y and f.AbsoluteSize.Y > 0 then
		return math.max(0, content - f.AbsoluteSize.Y)
	end

	return 0
end

-- ---------- aggressive rescan (guarantee SeasonPass Store attach) ----------
local function rescanAll()
	safePcall(function()
		for _, ui in ipairs(foundUIs) do
			for _, desc in ipairs(ui:GetDescendants()) do
				if desc:IsA("ScrollingFrame") then
					addManaged(desc)
				end
			end

			-- special: deep find "Store" nodes under SeasonPassUI
			if ui.Name == "SeasonPassUI" then
				for _, d in ipairs(ui:GetDescendants()) do
					if d.Name == "Store" then
						if d:IsA("ScrollingFrame") then
							addManaged(d)
							dbg("Attached Store as ScrollingFrame:", d:GetFullName())
						else
							for _, inner in ipairs(d:GetDescendants()) do
								if inner:IsA("ScrollingFrame") then
									addManaged(inner)
									dbg("Attached inner ScrollingFrame inside Store:", inner:GetFullName())
								end
							end
						end
					end
				end
			end
		end
	end, "rescanAll")
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
	-- if nothing managed yet, skip
	if #managed == 0 then return end

	-- paused handling
	if paused then
		pauseTimer = pauseTimer + dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			paused = false
			pauseTimer = 0
			direction = -direction
			dbg("Resuming scroll; direction:", direction)
		else
			return
		end
	end

	-- advance progress
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

		-- ensure ready
		if f.AbsoluteSize and f.AbsoluteSize.Y > 0 then
			local maxScroll = getMaxScroll(entry)
			if maxScroll > 0 then
				local target = progressToY(progress, entry)
				entry.currentY = entry.currentY or (f.CanvasPosition and f.CanvasPosition.Y) or 0
				local alpha = math.clamp(10 * dt, 0, 1)
				entry.currentY = entry.currentY + (target - entry.currentY) * alpha
				local writeY = math.floor(entry.currentY + 0.5)
				local ok, err = pcall(function()
					f.CanvasPosition = Vector2.new(0, writeY)
				end)
				if not ok then
					dbg("Failed to set CanvasPosition for", f:GetFullName(), ":", err)
				end
			end
		else
			dbg("Waiting for AbsoluteSize for", f:GetFullName())
		end

		::cont::
	end
end)

dbg("Auto-scroll loaded. Set DEBUG = true for verbose output.")
