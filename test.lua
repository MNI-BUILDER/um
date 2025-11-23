-- Roblox Client-Side UI Layout Manager
-- Arranges multiple UIs in a grid and adds auto-scrolling

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

local GRID_COLUMNS = 2
local UI_PADDING = 15
local SCROLL_SPEED = 0.5
local UI_SCALE = 0.45 -- Scale down to 45% of original size

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

-- Calculate layout
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UILayoutManager"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local function arrangeUIs()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local usableWidth = viewportSize.X - (UI_PADDING * (GRID_COLUMNS + 1))
	local uiWidth = (usableWidth / GRID_COLUMNS) 
	local uiHeight = uiWidth * 0.8 -- Maintain aspect ratio
	
	for index, ui in ipairs(foundUIs) do
		-- Calculate grid position
		local column = (index - 1) % GRID_COLUMNS
		local row = math.floor((index - 1) / GRID_COLUMNS)
		
		local xPos = UI_PADDING + (column * (uiWidth + UI_PADDING))
		local yPos = UI_PADDING + (row * (uiHeight + UI_PADDING))
		
		-- Find the main frame to resize
		local mainFrame = ui:FindFirstChildWhichIsA("Frame") or ui:FindFirstChildWhichIsA("ImageLabel") or ui:FindFirstChildWhichIsA("ScrollingFrame")
		
		if mainFrame then
			-- Store original size if not already stored
			if not mainFrame:GetAttribute("OriginalSizeX") then
				mainFrame:SetAttribute("OriginalSizeX", mainFrame.Size.X.Offset)
				mainFrame:SetAttribute("OriginalSizeY", mainFrame.Size.Y.Offset)
			end
			
			-- Resize with scale to maintain proportions
			mainFrame.Size = UDim2.new(0, uiWidth, 0, uiHeight)
			mainFrame.Position = UDim2.new(0, xPos, 0, yPos)
			
			-- Apply UIScale to children to prevent breaking
			local uiScale = mainFrame:FindFirstChildOfClass("UIScale")
			if not uiScale then
				uiScale = Instance.new("UIScale")
				uiScale.Parent = mainFrame
			end
			uiScale.Scale = UI_SCALE
			
			print("[v0] Arranged:", ui.Name, "at position", xPos, yPos)
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
