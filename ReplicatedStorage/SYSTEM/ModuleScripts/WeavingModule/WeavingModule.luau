-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- MODULES
local ElementalHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("ElementalHandler"))
local DrawHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))

-- REMOTES
local ToggleDebounce = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Debounces"):WaitForChild("ToggleDebounce")
local RemoveEvent = ReplicatedStorage:WaitForChild("ElementalMixing"):WaitForChild("Drawing"):WaitForChild("Remove")
local SourceDeduct = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Stats"):WaitForChild("SourceDeduct")

local WeavingModule = {}

WeavingModule.ElementList = {
	Slot1 = {},
	Slot2 = {},
	Slot3 = {},
	Slot4 = {},
	Slot5 = {}
}

-- INITIATOR FOR WEAVING
function WeavingModule.Start(player: Player, animationTable)
	if player == nil then warn("No Player detected") return end
	if animationTable == nil then warn("Animations Table is missing") end
	
	local char: Model? = player and player.Character
	if not char then warn("No Character detected") return end
	if char:GetAttribute("Slot1") == "Default" then GuiRelatedThings.ErrorMessage(player, "You haven't drawn any elements") return end

	if DebounceHandler.DebounceCheck(player, char, "WeavingDB") then GuiRelatedThings.ErrorMessage(player, "You cannot cast another weave yet") return nil end
	
	ToggleDebounce:FireServer(char, "WeavingDB", 3)
	
	local TotalSlots: number = 0
	local Prefix = "Slot"
	
	for i = 1, 5 do
		local attrName = Prefix .. i
		local Element = char:GetAttribute(attrName)

		TotalSlots = TotalSlots + 1
		
		if Element then
			-- Insert Element into corresponding slot
			table.insert(WeavingModule.ElementList[attrName], Element)
			DrawHandler.RemoveElementalFx(player.Name, player.UserId, attrName)
		else
			table.insert(WeavingModule.ElementList[attrName], "Default")
		end
	end
	
	local WeaveName = WeavingModule.WeavingPrepare(WeavingModule.ElementList)
	
	if WeaveName == nil then
		warn("No Weave Found for", WeaveName)
		WeavingModule.WeavingReset(player, TotalSlots, animationTable)
		return nil
	end

	WeavingModule.WeavingReset(player, TotalSlots, animationTable)
	
	return WeaveName
end

-- CLEARS THE WEAVE
function WeavingModule.WeavingReset(player: Player, TotalSlots: number, animationTable)
	-- Stop the Weaving animation
	animationTable.Default.Track:Stop()
	
	RemoveEvent:FireServer(player)
	
	-- Clear all the Slots from the Attributes
	ElementalHandler.AllSlotsDeleter(player, TotalSlots)

	WeavingModule.ElementList = {
		Slot1 = {},
		Slot2 = {},
		Slot3 = {},
		Slot4 = {},
		Slot5 = {}
	}
end

function WeavingModule.WeavingPrepare(ElementList)
	
	-- Local variables for the slots
	local Slot1, Slot2, Slot3, Slot4, Slot5

	-- Loop through ElementList and assign to corresponding variables
	for slot, elements in pairs(ElementList) do
		if slot == "Slot1" then
			-- Ensure only the first element of the table is assigned
			Slot1 = elements[1] or "Default"
		elseif slot == "Slot2" then
			Slot2 = elements[1] or "Default"
		elseif slot == "Slot3" then
			Slot3 = elements[1] or "Default"
		elseif slot == "Slot4" then
			Slot4 = elements[1] or "Default"
		elseif slot == "Slot5" then
			Slot5 = elements[1] or "Default"
		end
	end

	local WeaveName = WeavingModule.WeaveIdentifer(Slot1, Slot2, Slot3, Slot4, Slot5)
	
	return WeaveName
	-- Now you have Slot1 to Slot5 assigned, you can fire them to the server
end

-- FUNCTION TO GET THE KEY OF THE WEAVE
function WeavingModule.WeaveIdentifer(Slot1, Slot2, Slot3, Slot4, Slot5)
	-- Mapping elements to corresponding numbers
	local elementMap = {
		Default = "0",
		Fire = "1",
		Water = "2",
		Earth = "3",
		Air = "4",
		Spirit = "5"
	}
	-- Build the WeaveName by concatenating corresponding numbers
	local WeaveKey = ""
	WeaveKey = WeaveKey .. (elementMap[Slot1] or "0")
	WeaveKey = WeaveKey .. (elementMap[Slot2] or "0")
	WeaveKey = WeaveKey .. (elementMap[Slot3] or "0")
	WeaveKey = WeaveKey .. (elementMap[Slot4] or "0")
	WeaveKey = WeaveKey .. (elementMap[Slot5] or "0")
	
	local WeaveName = WeavingModule.SearchDictionary(WeaveKey)

	return WeaveName
end

-- SEARCH DICTIONARY FOR WEAVENAME
function WeavingModule.SearchDictionary(WeaveKey)
	-- Iterate over the dictionary to find the matching WeaveKey
	for weaveName, weaveData in pairs(Dictionary) do
		if weaveData.WeaveKey == WeaveKey then
			return weaveName  -- Return the name of the weave
		end
	end

	-- If the WeaveKey isn't found, return nil or a default message
	return nil
end

-- INITIATOR FOR INVERSING A WEAVE
function WeavingModule.StartInversing(player: Player, animationTable)
	if player == nil then warn("No Player detected") return end
	if animationTable == nil then warn("Animations Table is missing") end

	local char: Model? = player and player.Character
	if not char then warn("No Character detected") return end
	if char:GetAttribute("Slot1") == "Default" then GuiRelatedThings.ErrorMessage(player, "You haven't drawn any elements") return end

	local TotalSlots: number = 0
	local Prefix = "Slot"

	for i = 1, 5 do
		local attrName = Prefix .. i
		local Element = char:GetAttribute(attrName)

		TotalSlots = TotalSlots + 1

		if Element then
			-- Insert Element into corresponding slot
			table.insert(WeavingModule.ElementList[attrName], Element)
			DrawHandler.RemoveElementalFx(player.Name, player.UserId, attrName)
		else
			table.insert(WeavingModule.ElementList[attrName], "Default")
		end
	end

	local InverseName = WeavingModule.PrepareInversing(WeavingModule.ElementList)

	if InverseName == nil then
		warn("No Inverse Weave Found for", InverseName)
		WeavingModule.WeavingReset(player, TotalSlots, animationTable)
		return nil
	end

	WeavingModule.WeavingReset(player, TotalSlots, animationTable)

	return InverseName

end

function WeavingModule.PrepareInversing(ElementList)

	-- Local variables for the slots
	local Slot1, Slot2, Slot3, Slot4, Slot5

	-- Loop through ElementList and assign to corresponding variables
	for slot, elements in pairs(ElementList) do
		if slot == "Slot1" then
			-- Ensure only the first element of the table is assigned
			Slot1 = elements[1] or "Default"
		elseif slot == "Slot2" then
			Slot2 = elements[1] or "Default"
		elseif slot == "Slot3" then
			Slot3 = elements[1] or "Default"
		elseif slot == "Slot4" then
			Slot4 = elements[1] or "Default"
		elseif slot == "Slot5" then
			Slot5 = elements[1] or "Default"
		end
	end

	local InverseName = WeavingModule.InverseWeaveIdentifier(Slot1, Slot2, Slot3, Slot4, Slot5)

	return InverseName
	-- Now you have Slot1 to Slot5 assigned, you can fire them to the server
end

-- FUNCTION TO GET THE INVERSE KEY OF THE WEAVE
function WeavingModule.InverseWeaveIdentifier(Slot1, Slot2, Slot3, Slot4, Slot5)
	-- Mapping elements to corresponding numbers
	local elementMap = {
		Default = "0",
		Fire = "1",
		Water = "2",
		Earth = "3",
		Air = "4",
		Spirit = "5"
	}
	-- Build the WeaveName by concatenating corresponding numbers
	local InverseKey = ""
	InverseKey = InverseKey .. (elementMap[Slot1] or "0")
	InverseKey = InverseKey .. (elementMap[Slot2] or "0")
	InverseKey = InverseKey .. (elementMap[Slot3] or "0")
	InverseKey = InverseKey .. (elementMap[Slot4] or "0")
	InverseKey = InverseKey .. (elementMap[Slot5] or "0")

	local InverseName = WeavingModule.SearchDictionaryForInverse(InverseKey)

	return InverseName
end

-- SEARCH DICTIONARY FOR INVERSE WEAVE NAME
function WeavingModule.SearchDictionaryForInverse(InverseKey)
	-- Iterate over the dictionary to find the matching WeaveKey
	for InverseName, weaveData in pairs(Dictionary) do
		if weaveData.InverseKey == InverseKey then
			return InverseName  -- Return the name of the weave
		end
	end

	-- If the WeaveKey isn't found, return nil or a default message
	return nil
end

-- START COUNTING CHARGE
--function WeavingModule.Charge(char: Model, maxCharge: number, level: number)
--	local hum = char and char:FindFirstChild("Humanoid")
--	local Charge = 0
	
--	while char and char:GetAttribute("Charging") do
--		if Charge < maxCharge then
--			Charge = Charge + 1
--			hum:SetAttribute("Charge", Charge)
--			task.wait(1 - ((level * 0.01)) * 0.5)
--		else
--			break
--		end
--	end
--end

function WeavingModule.ChargeInterval(level: number)
	return math.max(0.1, 1 - (level * 0.005)) -- same formula as before, but can't hit 0
end

function WeavingModule.Charge(char: Model, maxCharge: number, level: number)
	local hum = char and char:FindFirstChild("Humanoid")
	local Charge = 0

	while char and hum and char:GetAttribute("Charging") do
		if Charge < maxCharge then
			Charge += 1
			hum:SetAttribute("Charge", Charge)
			task.wait(WeavingModule.ChargeInterval(level))
		else
			break
		end
	end
end

-- INITIATE SOURCE DEDUCTION
function WeavingModule.InitiateSourceDeduction(hum: Humanoid, amount: number, Charging: boolean, Interval: number?, max: number?, serverPaid: boolean?)
	if not hum then warn("SourceDeduct failed, no humanoid found") return false end
	if not amount then warn("SourceDeduct did not receive an amount") end

	local Source: NumberValue = hum:FindFirstChild("Source")
	if not Source then return false end

	local SourceDepleted = Instance.new("BindableEvent") -- Create an event to signal depletion

	-- If source deduction is a type of charging then continuously deduct source
	if Charging then
		local LastTick = 0 -- Stores the last deduction time

		local Connection
		Connection = RunService.Heartbeat:Connect(function()
			if hum and Source and Source.Value > amount then
				local CurrentTime = tick()
				if CurrentTime - LastTick >= Interval then 
					LastTick = CurrentTime
					--SourceDeduct:FireServer(hum, amount)

					local Charge = hum:GetAttribute("Charge")

					if Charge and max ~= 0 and Charge >= max then
						Connection:Disconnect()
					end
				end

			elseif hum and Source and Source.Value < amount then
				Connection:Disconnect()
				SourceDepleted:Fire() -- Fire the event when source runs out
			end
		end)

		return Connection, SourceDepleted.Event -- Return both connection and event
	end

	-- If source deduction is not a type of charging then only deduct source once
	if Source.Value < amount then
		return false -- return false if the caster's source is less than the amount
	else
		if not serverPaid then
			SourceDeduct:FireServer(hum, amount)
		end
		return true
	end
end

-- DEDUCT SOURCE
--function WeavingModule.DeductSource(player: Player, hum: Humanoid, amount: number)
--	local Source: NumberValue= hum:FindFirstChild("Source")
--	if Source.Value > amount then
--		Source.Value = Source.Value - amount
--	end
--end

function WeavingModule.DeductSource(player: Player, hum: Humanoid, amount: number)
	local Source = hum and hum:FindFirstChild("Source")
	if not Source then return false end
	if Source.Value < amount then return false end
	Source.Value -= amount
	return true
end

-- CAST RANGE CHECKER
function WeavingModule.CheckRange(CastRange, MousePosition, PartPosition)
	-- Calculate the distance between the MousePosition and the PartPosition
	local distance = (MousePosition - PartPosition).Magnitude
	
	-- Return true if the distance is within the CastRange, otherwise false
	return distance <= CastRange
end

-- INVERSE KEY DECODER
function WeavingModule.DecodeInverseKey(InverseKey)
	local elementMap = {
		["0"] = "Default",
		["1"] = "Fire",
		["2"] = "Water",
		["3"] = "Earth",
		["4"] = "Air",
		["5"] = "Spirit"
	}
	
	local elementTable = {}

	for i = 1, #InverseKey do
		local digit = InverseKey:sub(i, i)
		local element = elementMap[digit] -- Get element name from mapping

		if element and element ~= "Default" then -- Ignore default
			table.insert(elementTable, element)
		end
	end

	-- Ensure we always return 5 values (some may be nil)
	return elementTable[1], elementTable[2], elementTable[3], elementTable[4], elementTable[5]
end

return WeavingModule
