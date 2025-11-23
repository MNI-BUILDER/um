-- Roblox Client-Side UI Layout Manager
-- Arranges multiple UIs in corners and adds auto-scrolling

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
-- Reduced scroll speed for smoother, slower scrolling
local SCROLL_SPEED = 0.2
-- Increased UI scale from 50% to 85% to make UIs bigger
local UI_SCALE = 0.70

-- Wait for all UIs to load
wait(1)

local foundUIs = {}

-- Find and force show all UIs
for _, uiName in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(uiName)
	if ui then
		table.insert(foundUIs, ui)
		-- Force enable the ScreenGui
		ui.Enabled = true
		if ui:IsA("ScreenGui") then
			ui.ResetOnSpawn = false
			ui.IgnoreGuiInset = false
		end
		print("[v0] Found and enabled UI:", uiName)
	else
		warn("[v0] Could not find UI:", uiName)
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
		
		-- Force show ALL children frames
		for _, child in ipairs(ui:GetChildren()) do
			if child:IsA("Frame") or child:IsA("ImageLabel") or child:IsA("ScrollingFrame") then
				child.Visible = true
				child.AnchorPoint = corner.anchor
				child.Size = UDim2.new(0, uiWidth, 0, uiHeight)
				child.Position = corner.position
				
				-- Apply UIScale
				local uiScale = child:FindFirstChildOfClass("UIScale")
				if not uiScale then
					uiScale = Instance.new("UIScale")
					uiScale.Parent = child
				end
				uiScale.Scale = UI_SCALE
				
				print("[v0] Arranged:", ui.Name, "->", child.Name, "in corner", cornerIndex)
			end
		end
	end
end

-- Initial arrangement
arrangeUIs()

-- Re-arrange on screen resize
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)

-- Enhanced scrolling system that continuously checks for new ScrollingFrames
local allScrollFrames = {}
-- Using single global scroll progress for all frames
local globalScrollProgress = 0
local globalScrollDirection = 1

local function findAndSetupScrollFrames()
	allScrollFrames = {}
	
	-- Scan ALL descendants in PlayerGui
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("ScrollingFrame") then
			-- Check if this ScrollingFrame belongs to one of our managed UIs
			local isOurUI = false
			for _, ui in ipairs(foundUIs) do
				if descendant:IsDescendantOf(ui) then
					isOurUI = true
					break
				end
			end
			
			if isOurUI then
				-- Check if frame is actually scrollable
				local canvasSize = descendant.CanvasSize.Y.Offset
				local frameSize = descendant.AbsoluteSize.Y
				local maxScroll = canvasSize - frameSize
				
				if maxScroll > 10 then
					table.insert(allScrollFrames, descendant)
					print("[v0] Found scrollable frame in:", descendant.Parent.Name, "- Max scroll:", maxScroll)
				end
			end
		end
	end
	
	print("[v0] Total ScrollingFrames detected:", #allScrollFrames)
end

-- Initial scan for ScrollingFrames
findAndSetupScrollFrames()

-- Re-scan for new ScrollingFrames every 5 seconds (in case UIs load dynamically)
spawn(function()
	while wait(5) do
		findAndSetupScrollFrames()
	end
end)

-- Synchronized auto-scroll - all frames scroll together with same progress
RunService.RenderStepped:Connect(function(deltaTime)
	if #allScrollFrames == 0 then return end
	
	-- Update global scroll progress
	globalScrollProgress = globalScrollProgress + (SCROLL_SPEED * globalScrollDirection * 60 * deltaTime)
	
	-- Reverse direction at boundaries (0 to 100%)
	if globalScrollProgress >= 100 then
		globalScrollDirection = -1
		globalScrollProgress = 100
	elseif globalScrollProgress <= 0 then
		globalScrollDirection = 1
		globalScrollProgress = 0
	end
	
	-- Apply the same scroll percentage to all frames
	for _, scrollFrame in ipairs(allScrollFrames) do
		if scrollFrame and scrollFrame.Parent and scrollFrame.Visible then
			local canvasSize = scrollFrame.CanvasSize.Y.Offset
			local frameSize = scrollFrame.AbsoluteSize.Y
			local maxScroll = math.max(0, canvasSize - frameSize)
			
			-- Calculate position based on global progress (0-100%)
			local targetPosition = (globalScrollProgress / 100) * maxScroll
			scrollFrame.CanvasPosition = Vector2.new(0, targetPosition)
		end
	end
end)

print("[v0] UI Layout Manager initialized with", #foundUIs, "UIs and", #allScrollFrames, "scrolling frames!")
