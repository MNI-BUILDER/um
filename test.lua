-- Robust Roblox Client-Side UI Layout Manager (Improved, Defensive)
-- Paste into StarterPlayerScripts (Client). Auto-arranges UIs and reliably auto-scrolls ScrollingFrames.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.6     -- tweak this for faster/slower scrolling
local UI_SCALE = 0.75
local SCROLL_PAUSE_TIME = 1.2

-- small helper
local function debug(...)
	-- comment out the next line to silence debug prints
	-- print("[UI AutoScroll]", ...)
end

-- --------------- FIND & ARRANGE UIs ----------------
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
				debug("Added UI:", ui.Name)
			end
		end
	end
end

-- initial gather
for _, name in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(name)
	if ui then
		tryAddUI(ui)
	end
end

-- react to later additions
playerGui.ChildAdded:Connect(function(child)
	tryAddUI(child)
end)

-- corner positions
local cornerPositions = {
	{anchor = Vector2.new(0, 0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)}, -- TL
	{anchor = Vector2.new(1, 0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)}, -- TR
	{anchor = Vector2.new(0, 1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)}, -- BL
	{anchor = Vector2.new(1, 1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)}, -- BR
}

local function arrangeUIs()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local viewport = cam.ViewportSize
	local uiWidth = math.floor(viewport.X * 0.35)
	local uiHeight = math.floor(viewport.Y * 0.45)

	for idx, ui in ipairs(foundUIs) do
		local corner = cornerPositions[((idx - 1) % #cornerPositions) + 1]
		for _, child in ipairs(ui:GetChildren()) do
			if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("ScrollingFrame") then
				child.Visible = true
				child.AnchorPoint = corner.anchor
				child.Position = corner.position
				child.Size = UDim2.new(0, uiWidth, 0, uiHeight)
				local sc = child:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", child)
				sc.Scale = UI_SCALE
			end
		end
	end
end

-- call on start and when viewport changes
arrangeUIs()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)
end

-- --------------- SCROLL FRAME MANAGEMENT ----------------
local managedFrames = {} -- list of {frame = ScrollingFrame, listLayout = UIListLayout or nil}

local function addManagedFrame(sf)
	for _, entry in ipairs(managedFrames) do
		if entry.frame == sf then return end
	end
	local layout = sf:FindFirstChildOfClass("UIListLayout")
	table.insert(managedFrames, { frame = sf, listLayout = layout })
	-- make sure scrolling is enabled for user and bar visible
	sf.ScrollingEnabled = true
	sf.ScrollBarThickness = 8
	debug("Managed ScrollingFrame added:", sf:GetFullName())
end

local function findScrollFrames()
	-- gather from currently foundUIs
	for _, ui in ipairs(foundUIs) do
		for _, desc in ipairs(ui:GetDescendants()) do
			if desc:IsA("ScrollingFrame") then
				addManagedFrame(desc)
			end
		end
		-- also watch for future scroll frames inside this UI
		ui.DescendantAdded:Connect(function(d)
			if d:IsA("ScrollingFrame") then
				addManagedFrame(d)
			end
		end)
	end
end

-- initial scan + set up listeners for later UIs
findScrollFrames()
playerGui.ChildAdded:Connect(function(child)
	-- small delay to allow children to populate
	task.defer(function()
		for _, desc in ipairs(child:GetDescendants()) do
			if desc:IsA("ScrollingFrame") then
				addManagedFrame(desc)
			end
		end
		child.DescendantAdded:Connect(function(d)
			if d:IsA("ScrollingFrame") then
				addManagedFrame(d)
			end
		end)
	end)
end)

-- --------------- UTILS TO CALCULATE MAX SCROLL ----------------
local function getContentHeight(entry)
	-- entry: {frame = ScrollingFrame, listLayout = UIListLayout or nil}
	local f = entry.frame
	if not f then return 0 end

	-- If UIListLayout exists and has AbsoluteContentSize, prefer that (most reliable)
	if entry.listLayout and entry.listLayout.Parent then
		-- AbsoluteContentSize may be 0 until layout populates; that's ok
		local acs = entry.listLayout.AbsoluteContentSize
		if acs and acs.Y then
			return acs.Y
		end
	end

	-- Otherwise fall back to CanvasSize (supports scale and offset)
	local canvasY = f.CanvasSize.Y.Offset or 0
	local scale = f.CanvasSize.Y.Scale or 0
	if scale ~= 0 then
		-- scale is relative to the frame's AbsoluteSize.Y
		canvasY = canvasY + (scale * f.AbsoluteSize.Y)
	end
	-- canvasY == total content height inside the scrolling frame
	return canvasY
end

local function getMaxScroll(entry)
	local f = entry.frame
	if not f then return 0 end
	-- if AbsoluteSize is not ready yet, return 0
	if f.AbsoluteSize.Y <= 0 then
		return 0
	end
	local contentHeight = getContentHeight(entry)
	-- max scrollable distance =
	-- max(0, contentHeight - viewportHeightOfFrame)
	local max = math.max(0, contentHeight - f.AbsoluteSize.Y)
	return max
end

-- --------------- AUTO-SCROLL STATE ----------------
local scrollDirection = 1    -- 1 = down, -1 = up
local scrollProgress = 0     -- 0..1 normalized (we will use 0..1 to be more natural)
local isPaused = false
local pauseTimer = 0

-- convert internal 0..1 progress to target position for a frame
local function progressToY(progress, entry)
	local maxScroll = getMaxScroll(entry)
	if maxScroll <= 0 then
		return 0
	end
	-- clamp progress 0..1
	if progress < 0 then progress = 0 end
	if progress > 1 then progress = 1 end
	return math.floor(progress * maxScroll + 0.5)
end

-- --------------- MAIN RENDER LOOP ----------------
-- Use RenderStepped so UI sizes are stable and synced with UI rendering
RunService.RenderStepped:Connect(function(dt)
	-- nothing to do if no managed frames
	if #managedFrames == 0 then return end

	-- handle pause
	if isPaused then
		pauseTimer = pauseTimer + dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			isPaused = false
			pauseTimer = 0
			scrollDirection = -scrollDirection
			debug("Resuming, direction:", scrollDirection)
		else
			return
		end
	end

	-- advance progress (use normalized 0..1)
	local speedNorm = SCROLL_SPEED * 0.25 -- scale SCROLL_SPEED to reasonable normalized units
	scrollProgress = scrollProgress + (dt * scrollDirection * speedNorm)

	-- clamp and pause at ends
	if scrollProgress >= 1 then
		scrollProgress = 1
		isPaused = true
		debug("Reached bottom - pausing")
	elseif scrollProgress <= 0 then
		scrollProgress = 0
		isPaused = true
		debug("Reached top - pausing")
	end

	-- apply to every managed frame (frames with zero maxScroll are skipped)
	for _, entry in ipairs(managedFrames) do
		local f = entry.frame
		if f and f.Parent then
			-- ensure AbsoluteSize is ready
			if f.AbsoluteSize.Y > 0 then
				local maxScroll = getMaxScroll(entry)
				if maxScroll > 0 then
					local targetY = progressToY(scrollProgress, entry)
					-- keep X at 0 to avoid accidental X movement
					local currentX = f.CanvasPosition.X or 0
					-- set integer positions for stability
					f.CanvasPosition = Vector2.new(0, targetY)
				end
			end
		end
	end
end)

-- --------------- OPTIONAL: keep UIListLayout links up-to-date --------------
-- If a ScrollingFrame later gets a UIListLayout attached, update our registry
task.spawn(function()
	while true do
		for _, entry in ipairs(managedFrames) do
			if entry.frame and (not entry.listLayout or not entry.listLayout.Parent) then
				-- try find layout
				local l = entry.frame:FindFirstChildOfClass("UIListLayout")
				if l then
					entry.listLayout = l
					-- react to content size changes if present to avoid desyncs
					l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
						-- no-op: having this ensures AbsoluteContentSize updates and our getMaxScroll will pick it up
					end)
				end
			end
		end
		task.wait(2)
	end
end)

debug("Auto-scroll manager loaded. Managed frames:", #managedFrames)
