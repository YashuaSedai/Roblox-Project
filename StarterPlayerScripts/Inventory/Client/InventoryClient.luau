-- SERVICES
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local TS = game:GetService("TweenService")

-- MODULES
local Janitor = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Signal = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Signal"))
local Types = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Types"))

-- PLAYER VARIABLES
local player = Players.LocalPlayer
local playerGui = player.PlayerGui

-- GUI VARIABLES
local gui = playerGui:WaitForChild("Inventory")
local hotbarF = gui:WaitForChild("Hotbar")
local invF = gui:WaitForChild("Inventory"); invF.Visible = false -- F stands for Frane
local invB = gui:WaitForChild("Open") -- B stands for button
local errorT = gui:WaitForChild("Error"); errorT.Visible = false -- T stands for Text

local infoF = invF:WaitForChild("ItemInfo"); infoF.Visible = false
local itemNameT = infoF:WaitForChild("ItemName")
local itemDescT = infoF:WaitForChild("ItemDesc")
local equipB = infoF:WaitForChild("Equip")
local dropB = infoF:WaitForChild("Drop")
local instructT = infoF:WaitForChild("Instructions"); instructT.Visible = false

local itemsSF = invF:WaitForChild("ItemScroll") -- SF stands for Scrolling Frame
local itemSample = itemsSF:WaitForChild("Sample"); itemSample.Visible = false

local armorF = invF:WaitForChild("Armor")
local armorInnerF = armorF:WaitForChild("Inner")

local hotbarSlots = {
	hotbarF.Slot1,
	hotbarF.Slot2,
	hotbarF.Slot3,
	hotbarF.Slot4,
	hotbarF.Slot5,
	hotbarF.Slot6,
	hotbarF.Slot7,
	hotbarF.Slot8,
	hotbarF.Slot9,
	hotbarF.Slot0,
}
local keysToSlots = {
	[Enum.KeyCode.One] = hotbarF.Slot1;
	[Enum.KeyCode.Two] = hotbarF.Slot2;
	[Enum.KeyCode.Three] = hotbarF.Slot3;
	[Enum.KeyCode.Four] = hotbarF.Slot4;
	[Enum.KeyCode.Five] = hotbarF.Slot5;
	[Enum.KeyCode.Six] = hotbarF.Slot6;
	[Enum.KeyCode.Seven] = hotbarF.Slot7;
	[Enum.KeyCode.Eight] = hotbarF.Slot8;
	[Enum.KeyCode.Nine] = hotbarF.Slot9;
	[Enum.KeyCode.Zero] = hotbarF.Slot0;
}
local armorSlots = {
	Helm = armorInnerF.Helm;
	Plate = armorInnerF.Plate;
	Boots = armorInnerF.Boots;
}

-- MODULE
local InventoryClient = {}
InventoryClient.OpenPosition = invF.Position
InventoryClient.ClosePosition = invF.Position + UDim2.fromScale(0, 1)
InventoryClient.OpenCloseDb = false -- Db stands for Debounce
InventoryClient.IsOpen = false

InventoryClient.ErrorDb = false
InventoryClient.ErrorPosition = errorT.Position
InventoryClient.ErrorTime = 2

InventoryClient.InvData = nil
InventoryClient.SelectedStackId = nil
InventoryClient.UpdatingDb = false

InventoryClient.EquipInstructText = instructT.Text
InventoryClient.HeldSlotNum = nil

-- START
function InventoryClient.Start()
	
	-- Disabling default backpack
	SG:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	
	-- Updating Inventory
	InventoryClient.UpdateInventoryData()
	InventoryClient.UpdateDisplay()
	InventoryClient.UpdateHeldItem()
	
	-- Connecting Signals
	Signal.ListenRemote("InventoryClient:Update", function(newInvData: Types.Inventory)
		InventoryClient.InvData = newInvData
		InventoryClient.UpdateDisplay()
		InventoryClient.UpdateHeldItem()
	end)
	Signal.ListenRemote("InventoryClient:ErrorMessage", InventoryClient.ErrorMessage)
	
	-- Open/Close
	UIS.InputBegan:Connect(InventoryClient.OnInputBegan)
	invB.MouseButton1Click:Connect(function()
		InventoryClient.SetWindowOpen(not InventoryClient.IsOpen)
	end)
	
	-- Connecting Buttons
	equipB.MouseButton1Click:Connect(InventoryClient.OnEquipButton)
	dropB.MouseButton1Click:Connect(InventoryClient.OnDropButton)
	
	-- Connecting Slot Buttons
	for i, slotF: TextButton in hotbarSlots do
		slotF.MouseButton1Down:Connect(function()
			InventoryClient.ToggleHold(i)
		end)
	end
	
end

-- INPUT BEGAN
function InventoryClient.OnInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end
	if player.Character:GetAttribute("IsWeaving") == true then return end
	-- Open/Close
	if input.KeyCode == Enum.KeyCode.Backquote then
		InventoryClient.SetWindowOpen(not InventoryClient.IsOpen)
	end
	
	-- Equipping Slots
	for key: Enum.KeyCode, slotF: TextButton in keysToSlots do
		if input.KeyCode == key then
			InventoryClient.ToggleHold(table.find(hotbarSlots, slotF))
			break
		end
	end
	
end

-- OPENING AND CLOSING
function InventoryClient.SetWindowOpen(toSet: boolean)
	if InventoryClient.OpenCloseDb then return end
	InventoryClient.OpenCloseDb = true
	
	-- Checking toSet
	if toSet == true then
		invF.Position = InventoryClient.ClosePosition
		invF.Visible = true
		invF:TweenPosition(InventoryClient.OpenPosition, Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.5)
		task.wait(0.5)
		InventoryClient.IsOpen = true
	else
		invF:TweenPosition(InventoryClient.ClosePosition, Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.5)
		task.wait(0.5)
		invF.Visible = false
		InventoryClient.IsOpen = false
	end
	
	InventoryClient.OpenCloseDb = false
end

-- Equip Button
function InventoryClient.OnEquipButton()
	
	-- Finding Stack Data
	local stackData = InventoryClient.FindStackDataFromId(InventoryClient.SelectedStackId)
	
	-- Checking Button Mode
	if equipB.Text == "Equip" and stackData ~= nil then
	
	-- Instructions
	local tempJanitor = Janitor.new()
	instructT.Visible = true; tempJanitor:GiveChore(function() instructT.Visible = false end)
	equipB.Text = "<--->"; tempJanitor:GiveChore(function() equipB.Text = "Equip" end)
	
	-- Checking Item Type
	if stackData.ItemType == "Armor" then
		tempJanitor:Clean()
		
		-- Equipping to armor slot
		local success = Signal.InvokeServer("InventoryServer:EquipArmor", stackData.StackId)
		if not success then
			InventoryClient.ErrorMessage("Something went wrong while equipping armor!")
			return
		end
	else
		
		-- Variables
		local chosenSlot: TextButton = nil
		local slotNum: number = nil
		
		-- Keyboard Inputs
		tempJanitor:GiveChore(UIS.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
			if gameProcessedEvent then return end
			if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
			
			-- Selecting Slot
			for key: Enum.KeyCode, slotF: TextButton in keysToSlots do
				if input.KeyCode == key then
					chosenSlot = slotF
					tempJanitor:Clean()
					return
				end	
			end
			
			-- Canceling
			instructT.Text = "Error: Not a valid Key"; tempJanitor:GiveChore(function() instructT.Text = InventoryClient.EquipInstructText end)
			task.wait(2)
			tempJanitor:Clean()
			
		end))
		
		-- Button Presses
		for i, slotF: TextButton in hotbarSlots do
			tempJanitor:GiveChore(slotF.MouseButton1Click:Connect(function()
				chosenSlot = slotF
				slotNum = i
				tempJanitor:Clean()
			end))
		end
		
		-- Waiting For Selection
		while chosenSlot == nil do task.wait() end
		
		if slotNum == nil then
			slotNum = table.find(hotbarSlots, chosenSlot)
		end
		
		-- Equipping
		Signal.FireServer("InventoryServer:EquipToHotbar", slotNum, stackData.StackId)
		
	end
	
	elseif equipB.Text == "Unequip" and stackData ~= nil then
		if stackData.ItemType == "Armor" then
			Signal.FireServer("InventoryServer:UnequipArmor", InventoryClient.SelectedStackId)
		else
			Signal.FireServer("InventoryServer:UnequipFromHotbar", InventoryClient.SelectedStackId)
		end
	end
	
end

-- Drop Button
function InventoryClient.OnDropButton()
	if InventoryClient.SelectedStackId == nil then warn ("Nothing is Selected") return end
	
	-- Dropping Item
	local success: boolean = Signal.InvokeServer("InventoryServer:DropItem", InventoryClient.SelectedStackId)
	if success == nil then
		InventoryClient.ErrorMessage("Something went wrong; Unable to drop item")
	elseif success == false then
		InventoryClient.ErrorMessage("You cannot drop that item!")
	end
	
end

-- SETTING EQUIP/UNEQUIP BUTTON
function InventoryClient.SetEquipButton(toSet: boolean)
	if toSet == true then
		equipB.Text = "Equip"
		equipB.BackgroundColor3 = equipB:GetAttribute("EquipColor")
	else
		equipB.Text = "Unequip"
		equipB.BackgroundColor3 = equipB:GetAttribute("UnequipColor")
	end
end

-- TOGGLING HELD ITEM
function InventoryClient.ToggleHold(slotNum: number)
	if slotNum == nil then return end
	if InventoryClient.HeldSlotNum == slotNum then
		Signal.FireServer("InventoryServer:UnholdItems")
	else
		Signal.FireServer("InventoryServer:HoldItem", slotNum)
	end
end

-- UPDATE HELD ITEM
function InventoryClient.UpdateHeldItem()
	
	-- Character Variables
	local char: Model = player.Character; if not char then return end
	local tool: Tool = char:FindFirstChildOfClass("Tool")
	
	-- If There's A Tool
	if tool then
	
		-- Finding Slot
		local slotNum: number = nil
		for i = 1, 10 do
			local stackId: number? = InventoryClient.InvData.Hotbar["Slot" .. i]
			local stackData: Types.StackData? = InventoryClient.FindStackDataFromId(stackId)
			if stackData ~= nil and table.find(stackData.Items, tool) then
				slotNum = i
				break
			end
		end
		
		-- Updating
		if slotNum ~= nil then
			InventoryClient.HeldSlotNum = slotNum
			local slotF: TextButton = hotbarSlots[slotNum]
			for i, otherSlotF: TextButton in hotbarSlots do
				if otherSlotF == slotF then
					otherSlotF.BackgroundColor3 = otherSlotF:GetAttribute("SelectedColor")
				else
					otherSlotF.BackgroundColor3 = otherSlotF:GetAttribute("NormalColor")
				end
			end
		else
			InventoryClient.HeldSlotNum = nil
			--Signal.FireServer("InventoryServer:UnholdItems")
		end

	else
		
		-- Setting All Slots Back To Normal
		for i, slotF:TextButton in hotbarSlots do
			slotF.BackgroundColor3 = slotF:GetAttribute("NormalColor")
		end
		InventoryClient.HeldSlotNum = nil
		
	end
	
end

-- CHECKING IF AN ITEM IS CURRENTLY EQUIPPED
function InventoryClient.CheckItemEquipped(stackData: Types.StackData):boolean
	if stackData.ItemType == "Armor" then
		for armorType: string, stackId: number in InventoryClient.InvData.Armor do
			if stackId == stackData.StackId then
				return true
			end
		end
		return false
	else
		for slotKey: string, stackId: number in InventoryClient.InvData.Hotbar do
			if stackId == stackData.StackId then
				return true
			end
		end
		return false
	end
end

-- UPDATING INVENTORY DATA
function InventoryClient.UpdateInventoryData()
	InventoryClient.InvData = Signal.InvokeServer("InventoryServer:GetInventoryData")
end

-- UPDATING DISPLAY
function InventoryClient.UpdateDisplay()
	while InventoryClient.UpdatingDb do task.wait() end
	InventoryClient.UpdatingDb = true
	
	-- Clearing Items
	for i, itemF: Frame in itemsSF:GetChildren() do
		if itemF.ClassName == "TextButton" and itemF ~= itemSample then
			itemF:Destroy()
		end
	end
	
	-- Creating Item Frames
	local  inv: Types.Inventory = InventoryClient.InvData
	for i, stackData: Types.StackData in inv.Inventory do
		
		-- Cloning
		local itemF = itemSample:Clone()
		itemF.Name = "Stack-" .. stackData.StackId
		itemF.ImageLabel.Image = stackData.Image
		itemF.ItemCount.Text = #stackData.Items .. "x"
		itemF.Equipped.Visible = InventoryClient.CheckItemEquipped(stackData)
		itemF.Parent = itemSample.Parent
		itemF.Visible = true
		
		if #stackData.Items == 1 then
			itemF.ItemCount.Visible = false
		end
		
		-- Selecting Item
		itemF.MouseButton1Click:Connect(function()
			if InventoryClient.SelectedStackId == stackData.StackId then
				InventoryClient.SelectItem()
			else
				InventoryClient.SelectItem(stackData)
			end
		end)
		
	end
	
	-- Updating Hotbar
	for slotNum = 1, 10 do
		
		-- Getting Slot Information
		local slotF: TextButton = hotbarSlots[slotNum]
		local stackId: number? = InventoryClient.InvData.Hotbar["Slot" .. slotNum]
		
		-- Updating Display of Hotbar Slot
		if stackId == nil then
			slotF.ItemCount.Visible = false
			slotF.ImageLabel.Image = ""
		else
			
			-- Finding Stack Data
			local foundStack: Types.StackData = InventoryClient.FindStackDataFromId(stackId)
			
			-- Updating Information
			if foundStack ~= nil then
				slotF.ItemCount.Text = #foundStack.Items .. "x"
				slotF.ImageLabel.Image = foundStack.Image
				if #foundStack.Items == 1 then
					slotF.ItemCount.Visible = false
				else
					slotF.ItemCount.Visible = true
				end
			else
				slotF.ItemCount.Visible = false
				slotF.ImageLabel.Image = ""
			end
				
		end
		
	end
	
	-- Updating armor
	for i, armorType: string in {"Helm", "Plate", "Boots"} do
		
		-- Finding slot data
		local slotF: TextButton = armorSlots[armorType]
		local stackId: number? = InventoryClient.InvData.Armor[armorType]
		local stackData: Types.StackData? = InventoryClient.FindStackDataFromId(stackId)
		
		-- Updating display
		if stackData == nil then
			slotF.ImageLabel.Image = ""
		else
			slotF.ImageLabel.Image = stackData.Image
		end
	end
	
	-- Reselecting Item
	local selectedStack: Types.StackData? = InventoryClient.FindStackDataFromId(InventoryClient.SelectedStackId)
	InventoryClient.SelectItem(selectedStack)
	InventoryClient.UpdatingDb = false
end

-- SELECTING ITEMS
function InventoryClient.SelectItem(stackData: Types.StackData)
	
	-- Setting Selected Item
	InventoryClient.SelectedStackId = if stackData ~= nil then stackData.StackId else nil
	
	-- Finding Item Frame
	local itemF: TextButton = if stackData ~= nil then itemsSF:FindFirstChild("Stack-" .. stackData.StackId) else nil
	
	-- Setting Frame Colors
	for i, otherItemF: TextButton in itemsSF:GetChildren() do
		if otherItemF.ClassName == "TextButton" and otherItemF ~= itemSample then
			if otherItemF == itemF then
				otherItemF.BackgroundColor3 = otherItemF:GetAttribute("SelectedColor")
			else
				otherItemF.BackgroundColor3 = otherItemF:GetAttribute("NormalColor")
			end
		end
	end
	
	-- Updating Information
	if stackData ~= nil then
		
		-- Setting stack information
		infoF.Visible = true
		itemNameT.Text = stackData.Name
		itemDescT.Text = stackData.Description
	
	-- Setting Equip Button
	local isEquipped = InventoryClient.CheckItemEquipped(stackData)
	InventoryClient.SetEquipButton(not isEquipped)
	
	else
		infoF.Visible = false
		InventoryClient.SetEquipButton(true)
	end
	
end

-- ERROR MESSAGE
function InventoryClient.ErrorMessage(message: string)
	if InventoryClient.ErrorDb then return end
	local errorJanitor = Janitor.new()
	InventoryClient.ErrorDb = true; errorJanitor:GiveChore(function() InventoryClient.ErrorDb = false end)
	
	-- Setting Up Message
	errorT.Text = message
	errorT.Position = InventoryClient.ErrorPosition + UDim2.fromScale(0, -0.5)
	errorT.Visible = true; errorJanitor:GiveChore(function() errorT.Visible = false end)
	
	-- Tweening Out
	local tweenOut = TS:Create(errorT, TweenInfo.new(InventoryClient.ErrorTime / 4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = InventoryClient.ErrorPosition;
		}); errorJanitor:GiveChore(tweenOut)
	tweenOut:Play()
	tweenOut.Completed:Wait()
	
	-- Waiting Error Time
	task.wait(InventoryClient.ErrorTime / 2)
	
	-- Tweening To Be Invisible
	local tweenAway = TS:Create(errorT, TweenInfo.new(InventoryClient.ErrorTime / 4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		TextTransparency = 1;
		TextStrokeTransparency = 1;
	}); errorJanitor:GiveChore(tweenAway)
	errorJanitor:GiveChore(function()
		errorT.TextTransparency = 0
		errorT.TextStrokeTransparency = 0
	end)
	tweenAway:Play()
	tweenAway.Completed:Wait()
	
	-- Cleaning Up
	errorJanitor:Clean()
	
end

-- FINDING STACK DATA FROM ID
function InventoryClient.FindStackDataFromId(stackId: NumberValue): Types.StackData?
	if stackId == nil then return end
	for i, stackData: Types.StackData in InventoryClient.InvData.Inventory do
		if stackData.StackId == stackId then
			return stackData
		end
	end
end

-- RETURNING
return InventoryClient