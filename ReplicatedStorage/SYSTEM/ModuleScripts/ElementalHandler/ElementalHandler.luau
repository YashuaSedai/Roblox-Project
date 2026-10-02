--=========================================== MAIN REQUIREMENTS ===========================================
-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- MODULES
local Utilities = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
--=========================================== CORE REQUIREMENTS =========================================== 
-- DIRECTORIES
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")

-- EVENT
local Assign = ElementalMixing:WaitForChild("Assign")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")

-- SOUNDS FOLDER
local SoundsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Elements"):WaitForChild("Sounds")

--=========================================== VARIABLES =========================================== 
-- CONSTANTS
local ELEMENTAL_DEBOUNCE_CD = 0.2
local IS_WEAVING_DEBOUNCE_CD = 0.2
--=========================================== MODULE ===========================================
local ElementalHandler = {}

ElementalHandler.ElementalDebounce = {}
ElementalHandler.IsWeavingDebounce = {}

ElementalHandler.ElementalKeyMap = {
	[Enum.KeyCode.One] = "Fire",
	[Enum.KeyCode.Two] = "Water",
	[Enum.KeyCode.Three] = "Earth",
	[Enum.KeyCode.Four] = "Air",
	[Enum.KeyCode.Five] = "Spirit"
}

-- EMPTY SLOT FINDER
function ElementalHandler.SlotFinder(char: Model, totalSlots: number)
	-- Iterate through all the slots (e.g., Slot1 to Slot5)
	for i = 1, totalSlots do
		local slotName = "Slot" .. i
		local slotValue = char:GetAttribute(slotName)

		-- Check if the slot has the default value
		if slotValue == "Default" then
			return slotName, i -- Return the first empty slot found
		end
	end
	return nil, nil -- If no empty slot is found, return nil
end

-- LAST SLOT DELETER
function ElementalHandler.LastSlotDeleter(char: Model, totalSlots: number)
	for i = totalSlots, 1, -1 do
		local slotName = "Slot"..i
		local slotValue = char:GetAttribute(slotName)

		-- Check if the slot is not "Default"
		if slotValue ~= "Default" then
			Assign:FireServer(slotName, "Default")
			return slotName
		end
	end	
end

-- ALL SLOTS DELETER (Server should use this)
function ElementalHandler.AllSlotsDeleter(player: Player, totalSlots:number)
	local char = player and player.Character
	if char == nil then warn (`Character not found for {player.Name}`) return end
	for i = totalSlots, 1, -1 do
		local slotName = "Slot"..i
		if char:GetAttribute(slotName) then
			Assign:FireServer(slotName, "Default")
		end
	end
end

-- SOUND PLAYER
function ElementalHandler.PlaySound(player: Player, slotValue: string, slotName: string)
	if slotValue == nil then warn("Sound cannot be played. SlotValue:", slotValue, ", SlotName:", slotName) return end
	if player == nil then wait("Player Not Found") return end
	
	local char: Model = player.Character 
	
	if not char then warn("Character Not Found", player.Name) return end

	local humanoidRP: BasePart = char:WaitForChild("HumanoidRootPart")
	-- Referencing the Folder based on the SlotName i.e Fire, Water, Earth, Air, Spirit, or Default
	local SfxFolder = SoundsFolder:FindFirstChild(slotValue)
	if SfxFolder then
		-- Getting the Sfx in them
		local SoundEffects = SfxFolder:GetChildren()

		if #SoundEffects > 0 then
			-- For elements
			if SfxFolder.Name ~= "Default" then
				-- Play a random sound for non-default elements
				local randomIndex = math.random(1, #SoundEffects)
				local randomSound = SoundEffects[randomIndex]
				if randomSound:IsA("Sound") then
					local selectedSfx = randomSound:Clone()
					selectedSfx.Parent = humanoidRP
					selectedSfx:Play()
					
					local tempJanitor = Janitor.new()

					tempJanitor:GiveChore(selectedSfx.Ended:Connect(function()
						selectedSfx:Destroy()
						tempJanitor:Clean()
					end))	
				end
			-- For Default
			else
				local SoundEffect = SfxFolder:FindFirstChild(slotName)
				if SoundEffect and SoundEffect:IsA("Sound") then
					local selectedSfx = SoundEffect:Clone()
					selectedSfx.Parent = humanoidRP
					selectedSfx:Play()
					
					local tempJanitor = Janitor.new()
					
					tempJanitor:GiveChore(selectedSfx.Ended:Connect(function()
						selectedSfx:Destroy()
						tempJanitor:Clean()
					end))
				end
			end

		end

	end
end

-- WAITER FOR DEBOUNCES/COOLDOWNS
function ElementalHandler.Cooldown(variable: boolean, timer: number)
	task.wait(timer)
	variable = not variable
	
	return variable	
end

-- TOGGLE FOR SLOTS UI VISIBILITY
function ElementalHandler.SlotsVisibilityToggle(player: Player, bool: boolean)
	if not player then warn("Specify target player for slots visibility function") return end

	local char = player and player.Character
	local head = char:WaitForChild("Head")
	local targetGui = head:WaitForChild("SlotsUI"):WaitForChild("BillboardGui")

	for _, frame in targetGui:GetDescendants() do
		if frame.Name == "Frame" then
			frame.Visible = bool
		end

		if frame.Name == "Frame2" then
			frame.Visible = not bool
		end
	end
end

-- ISWEAVING ATTRIBUTE HANDLER (useful for switching the inventory's visibility and slots color)
function ElementalHandler.IsWeaving(player: Player, gpe: boolean)
	if player == nil then return end
	if gpe then return end

	-- Checks if the a the debounce exists for the player
	if ElementalHandler.IsWeavingDebounce[player.UserId] == nil then
		ElementalHandler.IsWeavingDebounce[player.UserId] = false
	end

	local char = player and player.Character

	if ElementalHandler.IsWeavingDebounce[player.UserId] == true then GuiRelatedThings.ErrorMessage(player, "Your weaving is on cooldown") return end
	
	-- Setting Debounce to True
	ElementalHandler.IsWeavingDebounce[player.UserId] = true

	-- Setup the Attribute for the Character
	if not char:GetAttribute("IsWeaving") or char:GetAttribute("IsWeaving") == false then
		char:SetAttribute("IsWeaving", true)

		-- Toggle Visibility of the Slots
		ElementalHandler.SlotsVisibilityToggle(player, char:GetAttribute("IsWeaving"))

		-- TweenOut Hotbar
		GuiRelatedThings.HotbarTweenPosition(player, not char:GetAttribute("IsWeaving"))

		-- Setting Debounce to False
		ElementalHandler.IsWeavingDebounce[player.UserId] =  ElementalHandler.Cooldown(ElementalHandler.IsWeavingDebounce[player.UserId], IS_WEAVING_DEBOUNCE_CD)
		
	elseif char:GetAttribute("IsWeaving") == true then
		char:SetAttribute("IsWeaving", false)
		
		-- Toggle Visibility of the Slots
		ElementalHandler.SlotsVisibilityToggle(player, char:GetAttribute("IsWeaving"))

		-- TweenIn Hotbar
		GuiRelatedThings.HotbarTweenPosition(player, not char:GetAttribute("IsWeaving"))

		-- Setting Debounce to False
		ElementalHandler.IsWeavingDebounce[player.UserId] =  ElementalHandler.Cooldown(ElementalHandler.IsWeavingDebounce[player.UserId], IS_WEAVING_DEBOUNCE_CD)

	end
end

-- MAIN HANDLER
function ElementalHandler.MainHandler(player: Player, input: InputObject, gpe: boolean, animationTable)
	if player == nil then return end
	if gpe then return end
	
	if not animationTable then warn("Animations Table does not exist") return end
	
	-- Checks if the a the debounce exists for the player
	if ElementalHandler.ElementalDebounce[player.UserId] == nil then
		ElementalHandler.ElementalDebounce[player.UserId] = false
	end
	
	local char = player and player.Character
	
	if char:GetAttribute("IsWeaving") == false or char:GetAttribute("IsWeaving") == nil then return end
	
	local element = ElementalHandler.ElementalKeyMap[input.KeyCode]
	if element then
		local emptySlot, slotNo = ElementalHandler.SlotFinder(char, 5)
		if emptySlot then
			Assign:FireServer(emptySlot, element)
			DrawEvent:FireServer(element, emptySlot, slotNo)
		end
		
		if emptySlot == "Slot1" then
			animationTable.Default.Track:Play()
		end
		
		if not slotNo then
			ElementalHandler.Cooldown(ElementalHandler.ElementalDebounce, ELEMENTAL_DEBOUNCE_CD)
			return
		end
		
		local selectedAnim = (slotNo % 2 == 0) and "Draw1" or "Draw2"
		local selectedTrack: AnimationTrack= animationTable[selectedAnim] and animationTable[selectedAnim].Track
		if selectedTrack then
			selectedTrack:Play()
		end
		
		ElementalHandler.PlaySound(player, element, slotNo)
	end
end

-- DELETER HANDLER
function ElementalHandler.DeleterHandler(player: Player, input: InputObject, gpe: boolean, animationTable)
	if player == nil then return end
	if gpe then return end
	
	if not animationTable then warn("Animations Table does not exist") return end
	
	local char: Model = player and player.Character
	
	local SlotName = ElementalHandler.LastSlotDeleter(char, 5)
	if SlotName then
		ElementalHandler.PlaySound(player, "Default", SlotName)
		DrawEvent:FireServer("Default", SlotName, nil)
		
		if SlotName == "Slot1" then
			animationTable.Default.Track:Stop()
		end
	end
	
	ElementalHandler.Cooldown(ElementalHandler.ElementalDebounce, ELEMENTAL_DEBOUNCE_CD)
end

return ElementalHandler
