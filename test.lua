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
local SCROLL_SPEED = 0.8
local UI_SCALE = 0.75

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
local scrollTime = 0

-- Find ALL ScrollingFrames in the managed UIs
local function findScrollFrames()
	scrollFrames = {}
	
	for _, ui in ipairs(foundUIs) do
		for _, descendant in ipairs(ui:GetDescendants()) do
			if descendant:IsA("ScrollingFrame") then
				-- Enable scrolling and make scrollbar visible
				descendant.ScrollingEnabled = true
				descendant.ScrollBarThickness = 8
				
				table.insert(scrollFrames, descendant)
				print("[v0] Found ScrollingFrame in:", ui.Name, "- Canvas:", descendant.CanvasSize.Y.Offset, "Frame:", descendant.AbsoluteSize.Y)
			end
		end
	end
	
	print("[v0] Total scrolling frames found:", #scrollFrames)
end

findScrollFrames()

-- Rescan every 3 seconds for new frames
spawn(function()
	while wait(3) do
		findScrollFrames()
	end
end)

-- Auto-scroll all frames together smoothly
RunService.Heartbeat:Connect(function(dt)
	if #scrollFrames == 0 then return end
	
	scrollTime = scrollTime + (dt * scrollDirection * SCROLL_SPEED)
	
	-- Ping-pong between 0 and 1 for smooth up/down motion
	if scrollTime >= 1 then
		scrollTime = 1
		scrollDirection = -1
	elseif scrollTime <= 0 then
		scrollTime = 0
		scrollDirection = 1
	end
	
	-- Apply scroll to ALL frames at the same time
	for _, frame in ipairs(scrollFrames) do
		if frame and frame.Parent then
			local maxScroll = math.max(0, frame.CanvasSize.Y.Offset - frame.AbsoluteSize.Y)
			local targetY = scrollTime * maxScroll
			frame.CanvasPosition = Vector2.new(0, targetY)
		end
	end
end)

print("[v0] UI Layout Manager initialized! Scrolling", #scrollFrames, "frames")
