-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- GENERIC
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local WeaveList = PlayerGui:WaitForChild("WeaveList")
local Main = WeaveList:WaitForChild("Main")
local Sub = Main:WaitForChild("Sub")
local ArrowL = Sub:WaitForChild("Book"):WaitForChild("ArrowL")
local ArrowR = Sub:WaitForChild("Book"):WaitForChild("ArrowR")

local MainPos = Main.Position
local StartPosition = UDim2.new(-0.5, MainPos.X.Offset, MainPos.Y.Scale, MainPos.Y.Offset)

-- TABLE
local TableOfPages = {}

-- VARIABLES
local CurrentPage = 1
local TweenDuration = 1 -- Duration of the tween animation
local IsTweening = false -- Prevent multiple tweens from overlapping
local OnScreen = false

-- INITIALIZATION
for _, page in pairs(Sub:GetChildren()) do
	if page:IsA("Folder") and page.Name:match("^Page%d+$") then
		-- ^ indicates the start of the string, % identifies as an escape symbol, d refers to digit, + indicates that there are more than 1 digit, $ marks the end of the string
		-- for the above reason, the folder's name must start with "Page" and end with a number (for example, Page1, Page2, Page3, etc.)
		
		local Container: Frame = page and page:FindFirstChild("Container")
		
		table.insert(TableOfPages, Container)
	end
end

-- Sort pages numerically based on their names
table.sort(TableOfPages, function(a, b)
	return tonumber(a.Name:match("%d+")) < tonumber(b.Name:match("%d+"))
end)

Main.Visible = true
Main.Position = StartPosition
	
	
-- FUNCTIONS
local function UpdatePages()
	-- Hide all pages
	for _, page in pairs(TableOfPages) do
		page.Visible = false
	end

	-- Show the current page
	local currentFolder = TableOfPages[CurrentPage]
	if currentFolder then
		currentFolder.Visible = true
	end

	-- Toggle arrow visibility
	ArrowL.Visible = CurrentPage > 1
	ArrowR.Visible = CurrentPage < #TableOfPages
end

UpdatePages()

local function TweenIn()
	if IsTweening then return end -- Prevent overlapping tweens
	IsTweening = true

	local goalPosition = UDim2.new(0.5, 0, 0.5, 0)
	local tween = TweenService:Create(Main, TweenInfo.new(TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = goalPosition})

	tween:Play()
	tween.Completed:Connect(function()
		OnScreen = true
		IsTweening = false
	end)
end

local function TweenOut()
	if IsTweening then return end -- Prevent overlapping tweens
	IsTweening = true

	local goalPosition = StartPosition
	local tween = TweenService:Create(Main, TweenInfo.new(TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = goalPosition})

	tween:Play()
	tween.Completed:Connect(function()
		OnScreen = false
		IsTweening = false
	end)
end

-- MAIN
ArrowL.MouseButton1Down:Connect(function()
	if CurrentPage > 1 then
		CurrentPage -= 1
		UpdatePages()
	end
end)

ArrowR.MouseButton1Down:Connect(function()
	if CurrentPage < #TableOfPages then
		CurrentPage += 1
		UpdatePages()
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe then
		if input.KeyCode == Enum.KeyCode.Tab then
			if not OnScreen then
				TweenIn()
			else
				TweenOut()
			end
		end
	end
end)