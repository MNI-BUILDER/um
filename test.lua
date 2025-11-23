-- Roblox Client-Side UI Layout Manager
-- Arranges multiple UIs in corners and adds one-way auto-scrolling

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration
local UI_NAMES = { "Gear_Shop", "Seed_Shop", "SeasonPassUI", "PetShop_UI" }
local UI_PADDING = 20
local SCROLL_SPEED = 0.2 -- Slower scrolling for smoother effect
local UI_SCALE = 0.73

wait(1) -- Wait for all UIs to load

local foundUIs = {}

-- Find and show all UIs
for _, uiName in ipairs(UI_NAMES) do
	local ui = playerGui:FindFirstChild(uiName)
	if ui then
		table.insert(foundUIs, ui)
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

local cornerPositions = {
	{anchor = Vector2.new(0, 0), position = UDim2.new(0, UI_PADDING, 0, UI_PADDING)},       -- Top-left
	{anchor = Vector2.new(1, 0), position = UDim2.new(1, -UI_PADDING, 0, UI_PADDING)},      -- Top-right
	{anchor = Vector2.new(0, 1), position = UDim2.new(0, UI_PADDING, 1, -UI_PADDING)},      -- Bottom-left
	{anchor = Vector2.new(1, 1), position = UDim2.new(1, -UI_PADDING, 1, -UI_PADDING)},     -- Bottom-right
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
				print("[v0] Arranged:", ui.Name, "->", child.Name, "in corner", cornerIndex)
			end
		end
	end
end

arrangeUIs()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrangeUIs)

-- Scroll management
local allScrollFrames = {}
local globalScrollProgress = 0 -- 0 to 100 percent

local function findAndSetupScrollFrames()
	allScrollFrames = {}
	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("ScrollingFrame") then
			for _, ui in ipairs(foundUIs) do
				if descendant:IsDescendantOf(ui) then
					local canvasSize = descendant.CanvasSize.Y.Offset
					local frameSize = descendant.AbsoluteSize.Y
					local maxScroll = canvasSize - frameSize
					if maxScroll > 10 then -- Minimally scrollable
						table.insert(allScrollFrames, descendant)
						print("[v0] Found scrollable frame in:", descendant.Parent.Name, "- Max scroll:", maxScroll)
					end
					break
				end
			end
		end
	end
	print("[v0] Total ScrollingFrames detected:", #allScrollFrames)
end

findAndSetupScrollFrames()
spawn(function()
	while wait(5) do
		findAndSetupScrollFrames()
	end
end)

-- One-way scroll (no looping)
RunService.RenderStepped:Connect(function(deltaTime)
	if #allScrollFrames == 0 then return end
	-- Advance until 100%, then stop
	if globalScrollProgress < 100 then
		globalScrollProgress = math.min(globalScrollProgress + (SCROLL_SPEED * 60 * deltaTime), 100)
		for _, scrollFrame in ipairs(allScrollFrames) do
			if scrollFrame and scrollFrame.Parent then
				local canvasSize = scrollFrame.CanvasSize.Y.Offset
				local frameSize = scrollFrame.AbsoluteSize.Y
				local maxScroll = math.max(0, canvasSize - frameSize)
				local targetPosition = (globalScrollProgress / 100) * maxScroll
				scrollFrame.CanvasPosition = Vector2.new(0, targetPosition)
			end
		end
	end
end)

print("[v0] UI Layout Manager initialized with", #foundUIs, "UIs and", #allScrollFrames, "scrolling frames!")
