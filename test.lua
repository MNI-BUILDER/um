-- Roblox Client-Side UI Layout Manager
-- Arranges multiple UIs in corners and adds auto-scrolling

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local UI_NAMES = {
	"Gear_Shop",
	"Seed_Shop", 
	"SeasonPassUI",
	"PetShop_UI"
}

local UI_PADDING = 20
-- Increased scroll speed to make scrolling more visible
local SCROLL_SPEED = 0.5 -- Faster scrolling so you can see it working
local UI_SCALE = 0.70
local SCROLL_PAUSE_TIME = 1.5 -- Pause at top and bottom

-- Wait for all UIs to load
wait(1)

local foundUIs = {}

-- Find and force show all UIs
for _, uiName in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(uiName)
	if ui then
		table.insert(foundUIs, ui)
		ui.Enabled = true
		if ui:IsA("ScreenGui") then
			ui.ResetOnSpawn = false
			ui.IgnoreGuiInset = false
		end
		print("[v0] Found UI:", uiName)
	end
end

if #foundUIs == 0 then
	warn("[v0] No UIs found!")
	return
end

-- Corner positions array
local cornerPositions = {
	{anchor = Vector2.new(0, 0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)}, -- Top-left
	{anchor = Vector2.new(1, 0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)}, -- Top-right
	{anchor = Vector2.new(0, 1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)}, -- Bottom-left
	{anchor = Vector2.new(1, 1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)}, -- Bottom-right
}

local function arrangeUIs()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local uiWidth = viewportSize.X * 0.35
	local uiHeight = viewportSize.Y * 0.45
	
	for index, ui in ipairs(foundUIs) do
		local cornerIndex = ((index - 1) % #cornerPositions) + 1
		local corner = cornerPositions[cornerIndex]
		
		for _, child in ipairs(ui:GetChildren()) do
			if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("ScrollingFrame") then
				child.Visible = true
				child.AnchorPoint = corner.anchor
				child.Size = UDim2.new(0, uiWidth, 0, uiHeight)
				child.Position = corner.position
				
				local uiScale = child:FindFirstChildOfClass("UIScale")
				if not uiScale then
					uiScale = Instance.new("UIScale")
					uiScale.Parent = child
				end
				uiScale.Scale = UI_SCALE
				
				print("[v0] Arranged:", ui.Name, "in corner", cornerIndex)
			end
		end
	end
end

arrangeUIs()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)

-- Simplified and fixed scrolling system
local scrollFrames = {}
local scrollDirection = 1
local scrollProgress = 0
local isPaused = false
local pauseTimer = 0

-- Find ALL ScrollingFrames in the managed UIs
local function findScrollFrames()
	scrollFrames = {}
	
	for _, ui in ipairs(foundUIs) do
		for _, descendant in ipairs(ui:GetDescendants()) do
			if descendant:IsA("ScrollingFrame") then
				-- Keep scrolling enabled so user can also manually scroll
				descendant.ScrollingEnabled = true
				descendant.ScrollBarThickness = 10
				
				table.insert(scrollFrames, descendant)
				print("[v0] Found ScrollingFrame in:", ui.Name, "- Canvas:", descendant.CanvasSize.Y.Offset, "Frame:", descendant.AbsoluteSize.Y)
			end
		end
	end
	
	print("[v0] Total scrolling frames found:", #scrollFrames)
end

findScrollFrames()

-- Rescan every 5 seconds for new frames
spawn(function()
	while wait(5) do
		local oldCount = #scrollFrames
		findScrollFrames()
		if #scrollFrames ~= oldCount then
			print("[v0] Scroll frame count changed from", oldCount, "to", #scrollFrames)
		end
	end
end)

-- Improved auto-scroll with smooth looping and pauses at top/bottom
RunService.Heartbeat:Connect(function(dt)
	if #scrollFrames == 0 then 
		print("[v0] DEBUG: No scroll frames to scroll!")
		return 
	end
	
	-- Handle pause at top/bottom
	if isPaused then
		pauseTimer = pauseTimer + dt
		if pauseTimer >= SCROLL_PAUSE_TIME then
			isPaused = false
			pauseTimer = 0
			scrollDirection = scrollDirection * -1 -- Reverse direction
			print("[v0] DEBUG: Direction changed to", scrollDirection > 0 and "DOWN" or "UP")
		end
		return
	end
	
	-- Update scroll progress
	scrollProgress = scrollProgress + (dt * scrollDirection * SCROLL_SPEED)
	
	-- Check if we hit the boundaries
	if scrollProgress >= 10 then -- Scroll down completely
		scrollProgress = 10
		isPaused = true
		print("[v0] DEBUG: Reached BOTTOM, pausing...")
	elseif scrollProgress <= 0 then -- Scroll up completely
		scrollProgress = 0
		isPaused = true
		print("[v0] DEBUG: Reached TOP, pausing...")
	end
	
	-- Apply scroll to ALL frames at the same time
	for _, frame in ipairs(scrollFrames) do
		if frame and frame.Parent then
			local maxScroll = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteSize.Y)
			if maxScroll > 0 then
				-- Convert 0-10 range to 0-maxScroll range
				local targetY = (scrollProgress / 10) * maxScroll
				frame.CanvasPosition = Vector2.new(frame.CanvasPosition.X, targetY)
				print("[v0] DEBUG: Scrolling", frame.Parent.Name, "- Progress:", math.floor(scrollProgress), "TargetY:", math.floor(targetY), "MaxScroll:", math.floor(maxScroll))
			else
				print("[v0] DEBUG:", frame.Parent.Name, "has NO scrollable content! MaxScroll:", maxScroll)
			end
		end
	end
end)

print("[v0] UI Layout Manager initialized! Auto-scrolling", #scrollFrames, "frames with smooth looping")
