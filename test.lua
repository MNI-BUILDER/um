-- Roblox Client-Side UI Layout Manager (FULL FIXED VERSION)
-- Auto-arranges UIs + Auto-scrolls any ScrollingFrame found

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIG
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.5
local UI_SCALE = 0.70
local SCROLL_PAUSE_TIME = 1.0

wait(1)

local foundUIs = {}

-- FIND UI GUIs
for _, uiName in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(uiName)
	if ui then
		table.insert(foundUIs, ui)
		ui.Enabled = true

		if ui:IsA("ScreenGui") then
			ui.ResetOnSpawn = false
			ui.IgnoreGuiInset = false
		end
	end
end

if #foundUIs == 0 then
	warn("NO UIs FOUND!")
	return
end

-- CORNER POSITIONS
local cornerPositions = {
	{anchor = Vector2.new(0, 0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)}, 	
	{anchor = Vector2.new(1, 0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)}, 	
	{anchor = Vector2.new(0, 1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)}, 	
	{anchor = Vector2.new(1, 1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)}, 	
}

-- LAYOUT MANAGER
local function arrangeUIs()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local uiWidth = viewportSize.X * 0.35
	local uiHeight = viewportSize.Y * 0.45

	for index, ui in ipairs(foundUIs) do
		local corner = cornerPositions[((index - 1) % #cornerPositions) + 1]

		for _, child in ipairs(ui:GetChildren()) do
			if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("ScrollingFrame") then
				child.Visible = true
				child.AnchorPoint = corner.anchor
				child.Size = UDim2.new(0, uiWidth, 0, uiHeight)
				child.Position = corner.position

				local scale = child:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", child)
				scale.Scale = UI_SCALE
			end
		end
	end
end

arrangeUIs()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)

---------------------------------------------------------
-- AUTO SCROLLING SYSTEM
---------------------------------------------------------

local scrollFrames = {}
local scrollDirection = 1
local scrollProgress = 0
local isPaused = false
local pauseTimer = 0

-- FIXED maxScroll detector (supports scale + offset)
local function getMaxScroll(f)
	local canvasHeight = f.CanvasSize.Y.Offset
	if f.CanvasSize.Y.Scale > 0 then
		canvasHeight += f.CanvasSize.Y.Scale * f.AbsoluteSize.Y
	end
	return math.max(0, canvasHeight - f.AbsoluteSize.Y)
end

-- SCAN FOR SCROLLING FRAMES
local function findScrollFrames()
	scrollFrames = {}

	for _, ui in ipairs(foundUIs) do
		for _, d in ipairs(ui:GetDescendants()) do
			if d:IsA("ScrollingFrame") then
				d.ScrollingEnabled = true
				d.ScrollBarThickness = 8
				table.insert(scrollFrames, d)
			end
		end
	end
end

findScrollFrames()

-- RESCAN every 5 sec
task.spawn(function()
	while task.wait(5) do
		findScrollFrames()
	end
end)

-- SMOOTH AUTO-SCROLL LOOP
RunService.Heartbeat:Connect(function(dt)
	if #scrollFrames == 0 then return end

	if isPaused then
		pauseTimer += dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			isPaused = false
			pauseTimer = 0
			scrollDirection *= -1 -- reverse
		end
		return
	end

	-- increase progress
	scrollProgress += dt * scrollDirection * SCROLL_SPEED

	-- top/bottom limits
	if scrollProgress >= 10 then
		scrollProgress = 10
		isPaused = true
	elseif scrollProgress <= 0 then
		scrollProgress = 0
		isPaused = true
	end

	-- APPLY SCROLLING TO ALL FRAMES
	for _, frame in ipairs(scrollFrames) do
		if frame and frame.Parent then
			local maxScroll = getMaxScroll(frame)
			if maxScroll > 0 then
				local targetY = (scrollProgress / 10) * maxScroll
				frame.CanvasPosition = Vector2.new(0, math.floor(targetY))
			end
		end
	end
end)

print("[UI Layout Manager] Loaded and Scrolling!")
