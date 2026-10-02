--=========================================== MAIN REQUIREMENTS ===========================================
-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- INITIALIZATION
local Player = Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Mouse = Player:GetMouse()
local PlayerGui = Player:WaitForChild("PlayerGui")

-- MODULES
local PlayerScripts = Player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()
local Utilities = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))
local ElementalMixing = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalMixing"):WaitForChild("ElementalMixing"))
--=========================================== MAIN REQUIREMENTS ===========================================

--=========================================== CORE REQUIREMENTS =========================================== 
-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local Assign = ElementalMixing:WaitForChild("Assign")
local SoundsFolder = HumanoidRootPart:WaitForChild("Sounds")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
--=========================================== CORE REQUIREMENTS =========================================== 

--=========================================== ANIMATIONS =========================================== 
local Animations = {
	Default = {Id = "114541864387191", Track = nil},
	Draw1 = {Id = "135564656898884", Track = nil},
	Draw2 = {Id = "107214777356354", Track = nil},
}

-- Function to load animations
local function loadAnimation(humanoid, animName)
	local animData = Animations[animName]
	if animData and not animData.Track then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://" .. animData.Id
		animData.Track = humanoid:LoadAnimation(animation)
	end
	return animData and animData.Track
end

-- Preload all animations
for name, _ in pairs(Animations) do
	loadAnimation(Humanoid, name)
end

Animations["Default"].Track.Looped = true
--=========================================== ANIMATIONS =========================================== 

--=========================================== VARIABLES =========================================== 
local Debounce = false
local DebounceCD = 0.2
local AltDebounce = false
local AltDebounceCD = 1

local TweenDuration = 0.5 -- Duration of the tween animation
local IsTweening = false -- Prevent multiple tweens from overlapping
local OnScreen = false
local Hotbar = PlayerGui:WaitForChild("Inventory"):WaitForChild("Hotbar")
local HotbarPos = Hotbar.Position
local StartPosition = HotbarPos
local goalPosition = UDim2.new(0.5, 0, 1.2, 0)

Character:SetAttribute("IsWeaving", false)
--local SlotsUI = Character:WaitForChild("SlotsUI")
--=========================================== VARIABLES =========================================== 

local function findEmptySlot(char)
	-- Iterate through all the slots (Slot1 to Slot5)
	for i = 1, 5 do
		local slotName = "Slot"..i
		local slotValue = char:GetAttribute(slotName)

		-- Check if the slot has the default value
		if slotValue == "Default" then
			return slotName, i -- Return the first empty slot found
		end
	end
	return nil, nil -- If no empty slot is found, return nil
end

local function deleteLastSlot(char)
	for i = 5, 1, -1 do
		local slotName = "Slot"..i
		local slotValue = char:GetAttribute(slotName)

		-- Check if the slot is not "Default"
		if slotValue ~= "Default" then
			Assign:FireServer(slotName, "Default")
			return slotName
		end
	end	
end

local function playSound(elementalfolder, SlotName)
	local SoundsFolder = HumanoidRootPart:FindFirstChild("Sounds") -- Ensure SoundsFolder is defined
	if SoundsFolder then
		local ElementalFolder = SoundsFolder:FindFirstChild(elementalfolder)
		if ElementalFolder then
			local Sounds = ElementalFolder:GetChildren() -- Get all sounds in the elemental folder
			if #Sounds > 0 then
				if elementalfolder ~= "Default" then
					-- Play a random sound for non-default elements
					local randomIndex = math.random(1, #Sounds)
					local randomSound = Sounds[randomIndex]
					if randomSound:IsA("Sound") then
						randomSound:Play()
					end
				else
					-- For Default, find a sound matching the SlotName
					local Sound = ElementalFolder:FindFirstChild(SlotName)
					if Sound and Sound:IsA("Sound") then
						Sound:Play()
					end
				end
			else
				warn("No sounds found in the folder for element:", elementalfolder)
			end
		else
			warn("Elemental folder not found for:", elementalfolder)
		end
	else
		warn("Sounds folder not found in HumanoidRootPart.")
	end
end

local function Cooldown()
	task.wait(DebounceCD)
	Debounce = false
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	
	if input.KeyCode == Enum.KeyCode.LeftAlt then
		if AltDebounce then return end
		AltDebounce = true
		
		if not Character:GetAttribute("IsWeaving") or Character:GetAttribute("IsWeaving") == false then
			Character:SetAttribute("IsWeaving", true)
			
			local Gui = Character:WaitForChild("Head"):WaitForChild("SlotsUI"):WaitForChild("BillboardGui")
			
			for _, frame in Gui:GetDescendants() do
				if frame.Name == "Frame" then
					frame.Visible = true
				end
				
				if frame.Name == "Frame2" then
					frame.Visible = false
				end
			end
			
			Hotbar:TweenPosition(goalPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, TweenDuration)
			
			task.wait(AltDebounceCD)
			AltDebounce = false
			
		else
			Character:SetAttribute("IsWeaving", false)
			
			local Gui = Character:WaitForChild("Head"):WaitForChild("SlotsUI"):WaitForChild("BillboardGui")

			for _, frame in Gui:GetDescendants() do
				if frame.Name == "Frame" then
					frame.Visible = false
				end

				if frame.Name == "Frame2" then
					frame.Visible = true
				end
			end
			
			Hotbar:TweenPosition(StartPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quad, TweenDuration)
			
			task.wait(AltDebounceCD)
			AltDebounce = false
		end
	end
end)


local elementKeyMap = {
	[Enum.KeyCode.One] = "Fire",
	[Enum.KeyCode.Two] = "Water",
	[Enum.KeyCode.Three] = "Earth",
	[Enum.KeyCode.Four] = "Air",
	[Enum.KeyCode.Five] = "Spirit"
}

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or Debounce then return end

	if Character:GetAttribute("IsWeaving") == false or Character:GetAttribute("IsWeaving") == nil then return end
	Debounce = true

	local element = elementKeyMap[input.KeyCode]
	if element then
		local emptyslot, slotNo = findEmptySlot(Character)
		if emptyslot then
			Assign:FireServer(emptyslot, element)
			DrawEvent:FireServer(element, emptyslot, slotNo)
		end

		if emptyslot == "Slot1" then
			Animations["Default"].Track:Play()
		end

		if not slotNo then
			Cooldown()
			return
		end

		local selectedAnim = (slotNo % 2 == 0) and "Draw1" or "Draw2"
		local selectedTrack = Animations[selectedAnim] and Animations[selectedAnim].Track
		if selectedTrack then
			selectedTrack:Play()
		end

		playSound(element)
	elseif input.KeyCode == Enum.KeyCode.Q then
		local SlotName = deleteLastSlot(Character)
		if SlotName then
			playSound("Default", SlotName)
			DrawEvent:FireServer("Default", SlotName, nil)

			if SlotName == "Slot1" then
				Animations["Default"].Track:Stop()
			end
		end
	end

	Cooldown()
end)
