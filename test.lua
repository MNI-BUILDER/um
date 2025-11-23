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
local SCROLL_SPEED = 0.5
local UI_SCALE = 0.5 -- Scale down to 50% of original size

-- Wait for all UIs to load
wait(1)

local foundUIs = {}

-- Find all UIs
for _, uiName in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(uiName)
	if ui then
		table.insert(foundUIs, ui)
		print("[v0] Found UI:", uiName)
	else
		warn("[v0] Could not find UI:", uiName)
	end
end

if #foundUIs == 0 then
	warn("[v0] No UIs found!")
	return
end

-- Corner positions array: top-left, top-right, bottom-left, bottom-right, then repeat
local cornerPositions = {
	{anchor = Vector2.new(0, 0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)}, -- Top-left
	{anchor = Vector2.new(1, 0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)}, -- Top-right
	{anchor = Vector2.new(0, 1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)}, -- Bottom-left
	{anchor = Vector2.new(1, 1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)}, -- Bottom-right
}

local function arrangeUIs()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	-- Calculate UI size as percentage of screen
	local uiWidth = viewportSize.X * 0.35 -- 35% of screen width
	local uiHeight = viewportSize.Y * 0.45 -- 45% of screen height
	
	for index, ui in ipairs(foundUIs) do
		-- Get corner position (cycle through corners)
		local cornerIndex = ((index - 1) % #cornerPositions) + 1
		local corner = cornerPositions[cornerIndex]
		
		-- Make sure the UI is visible and enabled
		ui.Enabled = true
		if ui:IsA("ScreenGui") then
			ui.ResetOnSpawn = false
		end
		
		-- Find the main frame to resize
		local mainFrame = ui:FindFirstChildWhichIsA("Frame") or ui:FindFirstChildWhichIsA("ImageLabel") or ui:FindFirstChildWhichIsA("ScrollingFrame")
		
		if mainFrame then
			-- Make sure the frame is visible
			mainFrame.Visible = true
			
			-- Store original size if not already stored
			if not mainFrame:GetAttribute("OriginalSizeX") then
				mainFrame:SetAttribute("OriginalSizeX", mainFrame.Size.X.Offset)
				mainFrame:SetAttribute("OriginalSizeY", mainFrame.Size.Y.Offset)
			end
			
			-- Set anchor point for corner positioning
			mainFrame.AnchorPoint = corner.anchor
			
			-- Resize and position in corner
			mainFrame.Size = UDim2.new(0, uiWidth, 0, uiHeight)
			mainFrame.Position = corner.position
			
			-- Apply UIScale to children to prevent breaking
			local uiScale = mainFrame:FindFirstChildOfClass("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Parent = mainFrame
			end
			uiScale.Scale = UI_SCALE
			
			print("[v0] Arranged:", ui.Name, "in corner", cornerIndex, "- Visible:", mainFrame.Visible, "Size:", mainFrame.Size)
		else
			-- If no main frame found, try to make the UI itself visible
			warn("[v0] No main frame found in:", ui.Name, "- Attempting to show UI directly")
			for _, child in ipairs(ui:GetChildren()) do
				if child:IsA("GuiObject") then
					child.Visible = true
					print("[v0] Made visible:", child.Name, "in", ui.Name)
				end
			end
		end
	end
end

-- Initial arrangement
arrangeUIs()

-- Re-arrange on screen resize
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)

-- Auto-scroll function
local scrollDirections = {}

local function findAllScrollingFrames(parent)
	local scrollFrames = {}
	for _, child in ipairs(parent:GetDescendants()) do
		if child:IsA("ScrollingFrame") then
			table.insert(scrollFrames, child)
			scrollDirections[child] = 1 -- 1 = down, -1 = up
			print("[v0] Found ScrollingFrame in:", parent.Name)
		end
	end
	return scrollFrames
end

-- Find all scrolling frames in all UIs
local allScrollFrames = {}
for _, ui in ipairs(foundUIs) do
	local frames = findAllScrollingFrames(ui)
	for _, frame in ipairs(frames) do
		table.insert(allScrollFrames, frame)
	end
end

-- Auto-scroll logic
RunService.RenderStepped:Connect(function(deltaTime)
	for _, scrollFrame in ipairs(allScrollFrames) do
		if scrollFrame and scrollFrame.Parent then
			local canvasSize = scrollFrame.CanvasSize.Y.Offset
			local frameSize = scrollFrame.AbsoluteSize.Y
			local maxScroll = math.max(0, canvasSize - frameSize)
			
			if maxScroll > 0 then
				local direction = scrollDirections[scrollFrame]
				local newPosition = scrollFrame.CanvasPosition.Y + (SCROLL_SPEED * direction)
				
				-- Reverse direction at boundaries
				if newPosition >= maxScroll then
					scrollDirections[scrollFrame] = -1
					newPosition = maxScroll
				elseif newPosition <= 0 then
					scrollDirections[scrollFrame] = 1
					newPosition = 0
				end
				
				scrollFrame.CanvasPosition = Vector2.new(0, newPosition)
			end
		end
	end
end)

print("[v0] UI Layout Manager initialized with", #foundUIs, "UIs and", #allScrollFrames, "scrolling frames!")
