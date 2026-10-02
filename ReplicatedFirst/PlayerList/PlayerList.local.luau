-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- GENERIC
local Player = Players.LocalPlayer
local PlayerGui = Player.PlayerGui
local PlayerList = PlayerGui:WaitForChild("PlayerList")
local Main = PlayerList:WaitForChild("Main")
local ScrollList = Main:WaitForChild("Sub"):WaitForChild("ScrollList")
local Template = script:WaitForChild("Template")
local Open = Main:WaitForChild("Open")
local Close = Main:WaitForChild("Close")


-- VARIABLES
local TweenDuration = 1 -- Duration of the tween animation
local IsTweening = false -- Prevent multiple tweens from overlapping
local OnScreen = false
local MainPos = Main.Position
local StartPosition = UDim2.new(1, MainPos.X.Offset, MainPos.Y.Scale, MainPos.Y.Offset)

-- INITIALIZATION
Main.Visible = true
Main.Position = StartPosition

-- FUNCTIONS

function AddPlayer(Player)
	local leaderstats = Player:WaitForChild("leaderstats")
	local level = leaderstats:WaitForChild("Level")
	
	local playerTemplate = Template:Clone()
	playerTemplate.Name = Player.UserId
	playerTemplate.User1.Text = Player.Name .. " LVL " .. level.Value
	playerTemplate.Parent = ScrollList
	
	level.Changed:Connect(function()
		playerTemplate.User1.Text = Player.Name.. " LVL" .. level.Value
	end)

	-- Fetch the thumbnail
	local userId = Player.UserId
	local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
	local content, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)

	playerTemplate.ImageLabel.Image = content
end

function RemovePlayer(Player)
	local playerTemplate = ScrollList:FindFirstChild(Player.UserId)
	if playerTemplate then
		playerTemplate:Destroy()
	end
end

local function TweenIn()
	if IsTweening then return end -- Prevent overlapping tweens
	IsTweening = true

	local goalPosition = UDim2.new(0.5, 0, 0.5, 0)
	local tween = TweenService:Create(Main, TweenInfo.new(TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = goalPosition})

	tween:Play()
	task.wait(TweenDuration)
	OnScreen = true
	IsTweening = false

end

local function TweenOut()
	if IsTweening then return end -- Prevent overlapping tweens
	IsTweening = true

	local goalPosition = StartPosition
	local tween = TweenService:Create(Main, TweenInfo.new(TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = goalPosition})

	tween:Play()
	task.wait(TweenDuration)
	OnScreen = false
	IsTweening = false

end

Players.PlayerAdded:Connect(AddPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)


for _, Player in pairs(Players:GetPlayers()) do
	AddPlayer(Player)
end


UserInputService.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.Tab then
		if gpe then return end
		if IsTweening then return end
		if not OnScreen then
			Open:Play()
			TweenIn()
		else
			Close:Play()
			TweenOut()
		end
	end
end)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false)