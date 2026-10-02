--=========================================== MAIN REQUIREMENTS ===========================================
-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
--=========================================== CORE REQUIREMENTS =========================================== 
-- DIRECTORIES
local StarterGui = game:GetService("StarterGui")

-- HOTBAR
local Hotbar = StarterGui:WaitForChild("Inventory"):WaitForChild("Hotbar")
local Design = StarterGui:WaitForChild("Inventory"):WaitForChild("Design")
local Healthbar = StarterGui:WaitForChild("DisplayBar"):WaitForChild("Frame"):WaitForChild("Health")
local Sourcebar = StarterGui:WaitForChild("DisplayBar"):WaitForChild("Frame"):WaitForChild("Source")
local WeaveDebounce = StarterGui:WaitForChild("WeaveDebounces"):WaitForChild("Main")

-- MODULES
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
--=========================================== VARIABLES =========================================== 
-- CONSTANTS
local Y_POS = 0.14
local HOTBAR_OG_POS = Hotbar.Position
local HOTBAR_GOAL_POS = UDim2.new(Hotbar.Position.X.Scale, 0, Hotbar.Position.Y.Scale + Y_POS, 0)
local DESIGN_OG_POS = Design.Position
local DESIGN_GOAL_POS = UDim2.new(DESIGN_OG_POS.X.Scale, 0, DESIGN_OG_POS.Y.Scale + Y_POS, 0)
local HEALTH_OG_POS = Healthbar.Position
local HEALTH_GOAL_POS = UDim2.new(HEALTH_OG_POS.X.Scale, 0, HEALTH_OG_POS.Y.Scale + Y_POS, 0)
local SOURCE_OG_POS = Sourcebar.Position
local SOURCE_GOAL_POS = UDim2.new(SOURCE_OG_POS.X.Scale, 0, SOURCE_OG_POS.Y.Scale + Y_POS, 0)
local WEAVEDEBOUNCE_OG_POS = WeaveDebounce.Position
local WEAVEDEBOUNCE_GOAL_POS = UDim2.new(WEAVEDEBOUNCE_OG_POS.X.Scale, 0, WEAVEDEBOUNCE_OG_POS.Y.Scale + Y_POS, 0)

local GuiRelatedThings = {}
GuiRelatedThings.WeaveDebounces = StarterGui:WaitForChild("WeaveDebounces")
GuiRelatedThings.DebounceIconTemplate = GuiRelatedThings.WeaveDebounces:WaitForChild("Main"):WaitForChild("Template")
GuiRelatedThings.PlaySoundRemote = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("PlaySound")

-- TWEEN THINGS IN
function GuiRelatedThings.TweenIn (Main: Frame, OriginalPosition: UDim2)
	if Main == nil or OriginalPosition == nil then warn("No Main nor Position received. Main: ", Main.Name, "Position: ", OriginalPosition) return end

	task.spawn(function()
		Main:TweenPosition(OriginalPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
	end)
end

-- TWEEN THINGS OUT
function GuiRelatedThings.TweenOut (Main: Frame, GoalPosition: UDim2)
	if Main == nil or GoalPosition == nil then warn("No Main nor Position received. Main: ", Main.Name, "Position: ", GoalPosition) return end

	task.spawn(function()
		Main:TweenPosition(GoalPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2)
	end)
end

-- TWEENS EVERYTHING ON THE LOWER SCREEN (Hotbar, Design, and Healthbar/Sourcebar)
function GuiRelatedThings.HotbarTweenPosition (player: Player, bool: boolean)
	if player == nil or bool == nil then warn("Hotbar couldn't be tweened") return end

	-- Retrieve player gui first, everything that we identify as a hotbar (we might want to remake this into attribute-based or tag-based grouping instead of manually doing it like this UnU)
	local PlayerGui = player:WaitForChild("PlayerGui")
	local Hotbar = PlayerGui:WaitForChild("Inventory"):WaitForChild("Hotbar")
	local Design = PlayerGui:WaitForChild("Inventory"):WaitForChild("Design")
	local Healthbar = PlayerGui:WaitForChild("DisplayBar"):WaitForChild("Frame"):WaitForChild("Health")
	local Sourcebar = PlayerGui:WaitForChild("DisplayBar"):WaitForChild("Frame"):WaitForChild("Source")
	local WeaveDebounce = PlayerGui:WaitForChild("WeaveDebounces"):WaitForChild("Main")

	-- Bool refers to if player is weaving: Refer to ElementalSetting script and ElementalHandler
	if bool == true then
		GuiRelatedThings.TweenIn(Hotbar, HOTBAR_OG_POS)
		GuiRelatedThings.TweenIn(Design, DESIGN_OG_POS)
		GuiRelatedThings.TweenIn(Healthbar, HEALTH_OG_POS)
		GuiRelatedThings.TweenIn(Sourcebar, SOURCE_OG_POS)
		GuiRelatedThings.TweenIn(WeaveDebounce, WEAVEDEBOUNCE_OG_POS)
	elseif bool == false then
		GuiRelatedThings.TweenOut(Hotbar, HOTBAR_GOAL_POS)
		GuiRelatedThings.TweenIn(Design, DESIGN_GOAL_POS)
		GuiRelatedThings.TweenIn(Healthbar, HEALTH_GOAL_POS)
		GuiRelatedThings.TweenIn(Sourcebar, SOURCE_GOAL_POS)
		GuiRelatedThings.TweenIn(WeaveDebounce, WEAVEDEBOUNCE_GOAL_POS)
	end
end

-- ERROR MESSAGE
function GuiRelatedThings.ErrorMessage(player, message: string)
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		local ErrorMsg = playerGui:WaitForChild("Menu"):WaitForChild("Error")
		GuiRelatedThings.ErrorDb = false
		GuiRelatedThings.ErrorPosition = ErrorMsg.Position
		GuiRelatedThings.ErrorTime = 2

		if GuiRelatedThings.ErrorDb then return end
		local errorJanitor = Janitor.new()
		GuiRelatedThings.ErrorDb = true; errorJanitor:GiveChore(function() GuiRelatedThings.ErrorDb = false end)

		-- Setting Up Message
		ErrorMsg.Text = message
		ErrorMsg.Position = GuiRelatedThings.ErrorPosition + UDim2.fromScale(0, -0.5)
		ErrorMsg.Visible = true; errorJanitor:GiveChore(function() ErrorMsg.Visible = false end)

		-- 
		local tweenOut = TweenService:Create(ErrorMsg, TweenInfo.new(GuiRelatedThings.ErrorTime / 4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = GuiRelatedThings.ErrorPosition;
		}); errorJanitor:GiveChore(tweenOut)
		tweenOut:Play()
		tweenOut.Completed:Wait()

		-- Waiting Error Time
		task.wait(GuiRelatedThings.ErrorTime / 2)

		-- Tweening To Be Invisible
		local tweenAway = TweenService:Create(ErrorMsg, TweenInfo.new(GuiRelatedThings.ErrorTime / 4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			TextTransparency = 1;
			TextStrokeTransparency = 1;
		}); errorJanitor:GiveChore(tweenAway)
		errorJanitor:GiveChore(function()
			ErrorMsg.TextTransparency = 0
			ErrorMsg.TextStrokeTransparency = 0
		end)
		tweenAway:Play()
		tweenAway.Completed:Wait()

		-- Cleaning Up
		errorJanitor:Clean()
	end)
end

-- DEBOUNCE ICON
function GuiRelatedThings.DebounceIcon(player: Player, weaveName: string)
	local duration = Dictionary[weaveName].DebounceDuration
	local newIcon = GuiRelatedThings.DebounceIconTemplate:Clone()
	newIcon.Parent = player:WaitForChild("PlayerGui"):WaitForChild("WeaveDebounces"):WaitForChild("Main")
	newIcon.Visible = true
	newIcon.ImageLabel.Image = Dictionary[weaveName].Image

	local DurationLabel = newIcon.Duration
	local Cover = newIcon.ImageLabel.Cover -- UI element to fade

	-- Tween Transparency from current value to 1
	task.spawn(function()
		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local transparencyTween = TweenService:Create(Cover, tweenInfo, { BackgroundTransparency = 1 })
		transparencyTween:Play()
	end)
	
	task.spawn(function()
		-- Countdown
		for i = duration, 0, -0.1 do
			DurationLabel.Text = string.format("%.1f", i) -- Formats to 1 decimal place
			task.wait(0.1)
		end

		-- Cleanup
		newIcon:Destroy()
	end)
end

-- PLAYS A SOUND FOR A PLAYER
function GuiRelatedThings.PlaySoundFor(targetPlayer: Player, soundName)
	GuiRelatedThings.PlaySoundRemote:FireClient(targetPlayer, soundName)
end


return GuiRelatedThings
