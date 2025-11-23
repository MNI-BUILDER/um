
-- LocalScript - Place this in StarterPlayer > StarterPlayerScripts or StarterGui

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI names to manage
local uiNames = {
    "Gear_Shop",
    "Seed_Shop", 
    "SeasonPassUI",
    "PetShop_UI"
}

-- Configuration
local GRID_COLUMNS = 2 -- Number of UIs per row
local UI_PADDING = 10 -- Spacing between UIs
local SCREEN_MARGIN = 20 -- Margin from screen edges
local SCROLL_SPEED = 0.3 -- Lower = slower scrolling

-- Function to find UI and make it visible
local function findAndShowUI(uiName)
    local ui = playerGui:FindFirstChild(uiName)
    if ui then
        ui.Enabled = true
        return ui
    end
    return nil
end

-- Function to find ScrollingFrame within a UI
local function findScrollingFrame(gui)
    for _, descendant in pairs(gui:GetDescendants()) do
        if descendant:IsA("ScrollingFrame") then
            return descendant
        end
    end
    return nil
end

-- Function to add automatic scrolling to a ScrollingFrame
local function addAutoScroll(scrollingFrame)
    local scrollingUp = true
    local scrollSpeed = SCROLL_SPEED
    
    local connection
    connection = RunService.RenderStepped:Connect(function(deltaTime)
        if not scrollingFrame or not scrollingFrame.Parent then
            connection:Disconnect()
            return
        end
        
        local canvasSize = scrollingFrame.AbsoluteCanvasSize.Y
        local windowSize = scrollingFrame.AbsoluteWindowSize.Y
        local maxScroll = math.max(0, canvasSize - windowSize)
        
        if maxScroll > 0 then
            local currentPosition = scrollingFrame.CanvasPosition.Y
            
            -- Scroll up
            if scrollingUp then
                currentPosition = currentPosition - scrollSpeed
                if currentPosition <= 0 then
                    currentPosition = 0
                    scrollingUp = false
                    wait(0.5) -- Pause at top
                end
            -- Scroll down
            else
                currentPosition = currentPosition + scrollSpeed
                if currentPosition >= maxScroll then
                    currentPosition = maxScroll
                    scrollingUp = true
                    wait(0.5) -- Pause at bottom
                end
            end
            
            scrollingFrame.CanvasPosition = Vector2.new(0, currentPosition)
        end
    end)
end

-- Function to arrange UIs in a grid layout
local function arrangeUIsInGrid(uis)
    local screenSize = workspace.CurrentCamera.ViewportSize
    
    -- Calculate UI size
    local totalColumns = math.min(GRID_COLUMNS, #uis)
    local rows = math.ceil(#uis / totalColumns)
    
    local availableWidth = screenSize.X - (SCREEN_MARGIN * 2) - (UI_PADDING * (totalColumns - 1))
    local availableHeight = screenSize.Y - (SCREEN_MARGIN * 2) - (UI_PADDING * (rows - 1))
    
    local uiWidth = availableWidth / totalColumns
    local uiHeight = availableHeight / rows
    
    -- Position each UI
    for index, ui in ipairs(uis) do
        local frame = ui:FindFirstChildOfClass("Frame") or ui:FindFirstChildOfClass("ScreenGui")
        
        if frame and frame:IsA("Frame") then
            local row = math.floor((index - 1) / totalColumns)
            local col = (index - 1) % totalColumns
            
            local xPos = SCREEN_MARGIN + (col * (uiWidth + UI_PADDING))
            local yPos = SCREEN_MARGIN + (row * (uiHeight + UI_PADDING))
            
            -- Resize and reposition the frame
            frame.Size = UDim2.new(0, uiWidth, 0, uiHeight)
            frame.Position = UDim2.new(0, xPos, 0, yPos)
            frame.AnchorPoint = Vector2.new(0, 0)
            
            -- Find and add auto-scroll to ScrollingFrames
            local scrollingFrame = findScrollingFrame(frame)
            if scrollingFrame then
                addAutoScroll(scrollingFrame)
            end
        end
    end
end

-- Main execution
wait(1) -- Wait for UIs to load

local foundUIs = {}

-- Find all UIs
for _, uiName in ipairs(uiNames) do
    local ui = findAndShowUI(uiName)
    if ui then
        table.insert(foundUIs, ui)
        print("✓ Found and enabled:", uiName)
    else
        warn("✗ Could not find UI:", uiName)
    end
end

-- Arrange them if we found any
if #foundUIs > 0 then
    arrangeUIsInGrid(foundUIs)
    print("🎨 Arranged", #foundUIs, "UIs in grid layout with auto-scrolling!")
else
    warn("❌ No UIs found to arrange!")
end

-- Re-arrange on screen resize
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if #foundUIs > 0 then
        arrangeUIsInGrid(foundUIs)
    end
end)
