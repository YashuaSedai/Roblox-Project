-- SERVICES
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local RunService = game:GetService("RunService")
local DSS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

-- MODULES
local Types = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Types"))
local Janitor = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Signal = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Signal"))

-- DATA STORES
local IDS = DSS:GetDataStore("InventoryDataStore")

-- MODULE
local InventoryServer = {}
InventoryServer.AllInventories = {}
InventoryServer.Janitors = {}
InventoryServer.HasLoaded = {}
InventoryServer.Respawning = {}
InventoryServer.ToolCanTouch = {}
InventoryServer.ToolCanCollide = {}

InventoryServer.MaxStackData = {
	Armor = 1;
	Weapon = 1;
	Special = 1;
	Consumable = 5;
	Resource = 10;
}

InventoryServer.MaxStacks = 20

-- VARIABLES 
local AUTOSAVE_TIME = 60 * 3
local SAVE_KEY = "%i-V.01"
local ARMOR_TAG = "%i %s EquippedArmor"

-- START
function InventoryServer.Start()
	
	for i, player: Player in Players:GetPlayers() do
		task.spawn(InventoryServer.OnPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(InventoryServer.OnPlayerAdded)
	
	Players.PlayerRemoving:Connect(InventoryServer.OnPlayerRemoving)
	
	Signal.ListenRemote("InventoryServer:GetInventoryData", InventoryServer.GetInventoryData)
	Signal.ListenRemote("InventoryServer:EquipToHotbar", InventoryServer.EquipToHotbar)
	Signal.ListenRemote("InventoryServer:UnequipFromHotbar", InventoryServer.UnequipFromHotbar)
	Signal.ListenRemote("InventoryServer:HoldItem", InventoryServer.HoldItem)
	Signal.ListenRemote("InventoryServer:UnholdItems", InventoryServer.UnholdItems)
	Signal.ListenRemote("InventoryServer:DropItem", InventoryServer.DropItem)
	Signal.ListenRemote("InventoryServer:EquipArmor", InventoryServer.EquipArmor)
	Signal.ListenRemote("InventoryServer:UnequipArmor", InventoryServer.UnequipArmor)
	
	
	game:BindToClose(function()
		for i, player : Player in Players:GetPlayers() do
			InventoryServer.SaveData(player	)
		end
	end)
	
	task.spawn(function()
		while true do
			task.wait()
			for i, player: Player in Players:GetPlayers() do
				task.wait(AUTOSAVE_TIME / #Players:GetPlayers())
				InventoryServer.SaveData(player)
			end
		end
	end)
	
	-- Connecting Post Simulation
	RunService.PostSimulation:Connect(InventoryServer.OnPostSimulation)
	
end

function InventoryServer.OnPlayerAdded(player : Player)
	
	for i, tool in StarterPack:GetChildren() do
		while not player.Backpack:FindFirstChild(tool.Name) do
			task.wait()
		end
	end
	
	local janitor = Janitor.new()
	InventoryServer.Janitors[player] = janitor
	janitor:GiveChore(function()
		InventoryServer.Janitors[player] = nil
		InventoryServer.Respawning[player] = nil
	end)
	
	local inv: Types.Inventory = {
		Inventory = {};
		Hotbar = {};
		Armor = {};
		NextStackId = 0;
	}
	InventoryServer.AllInventories[player] = inv
	janitor:GiveChore(function() InventoryServer.AllInventories[player] = nil end)
	
	if not player.Character then player.CharacterAdded:Wait() end
	InventoryServer.LoadData(player)
	
	local function charAdded(char: Model)
	
		for i, tool in player.Backpack:GetChildren() do
			InventoryServer.RegisterItem(player, tool)
		end
		
		char.ChildAdded:Connect(function(child: Instance)
			InventoryServer.RegisterItem(player, child)
		end)
		char.ChildRemoved:Connect(function(child: Instance)
			InventoryServer.UnregisterItem(player, child)
		end)
	
		player.Backpack.ChildAdded:Connect(function(child, instance)
			InventoryServer.RegisterItem(player, child)
		end)
		player.Backpack.ChildRemoved:Connect(function(child, instance)
			InventoryServer.UnregisterItem(player, child)
		end)
		
		-- On Char death
		local hum: Humanoid = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			
			-- Unholding Items And Starting Respawn
			InventoryServer.Respawning[player] = true
			InventoryServer.UnholdItems(player)
			
			-- Reparenting All Items
			local allItems: {Tool} = player.Backpack:GetChildren()
			for i, item: Tool in allItems do
				item.Parent = script
			end
			
			-- Character Respawning
			player.CharacterAdded:Wait()
			local backpack = player:WaitForChild("Backpack")
			
			-- Adding Items Back
			for i, item: Tool in allItems do
				item.Parent = backpack
			end
			
			InventoryServer.Respawning[player] = false
			
		end)
		
	end
	
	task.spawn(charAdded, player.Character)
	janitor:GiveChore(player.CharacterAdded:Connect(charAdded))
	
end

function InventoryServer.OnPlayerRemoving(player : Player)
	
	InventoryServer.SaveData(player)
	InventoryServer.Janitors[player]:Destroy()
	
end

-- Heartbeat Loop
function InventoryServer.OnPostSimulation(dt: Number)
	InventoryServer.UpdateDroppedItems()
end

-- Checking if inventory is Full
function InventoryServer.CheckInventoryFull(player: Player, item: Tool)
	local inv = InventoryServer.AllInventories[player]
	if #inv.Inventory >= InventoryServer.MaxStacks then
		for i, stackData: Types.StackData in inv.Inventory do
			if stackData.Name == item.Name and #stackData.Items < InventoryServer.MaxStackData[stackData.ItemType] then
				return false
			end
		end
		return true
	end
	return false
end

-- Updating Dropped Items
function InventoryServer.UpdateDroppedItems()
	
	-- Looping All Items
	for i, tool: Tool in CS:GetTagged("ItemTool") do
		if not tool:IsDescendantOf(workspace) then continue end
		
		-- Variables
		local handle = tool:FindFirstChild("Handle")
		if not handle then
			warn(`There was no handle found for tool {tool.Name}`)
			continue
		end
		local hum: Humanoid = tool.Parent:FindFirstChild("Humanoid")
		local prompt = handle:FindFirstChild("DroppedItemsPrompt")
		
		-- Checking if Humanoid
		if hum then
			
			-- Re-enabling CanTouch & CanCollide
			for i, part: BasePart in tool:GetDescendants() do
				if part:IsA("BasePart") then
					
					-- Resetting CanTouch
					local prevValue = InventoryServer.ToolCanTouch[part]
					if prevValue then
						part.CanTouch = prevValue
						InventoryServer.ToolCanTouch[part] = nil
					end
					
					-- Resetting CanCollide
					local prevValue = InventoryServer.ToolCanTouch[part]
					if prevValue then
						part.CanCollide = prevValue
						InventoryServer.ToolCanTouch[part] = nil
					end
				end
			end
			
			-- Clearing Prompt
			if prompt then
				prompt:Destroy()
			end
			
		else
			
			if not prompt then
				
				-- Disabling CanTouch & CanCollide
				for i, part: BasePart in tool:GetDescendants() do
					if part:IsA("BasePart") then
						InventoryServer.ToolCanTouch[part] = part.CanTouch
						part.CanTouch = false
						InventoryServer.ToolCanTouch[part] = part.CanCollide
						part.CanCollide = true
					end
				end
				
				-- Adding Proximity Prompt
				prompt = script.DroppedItemsPrompt:Clone()
				prompt.ObjectText = tool.Name
				prompt.Parent = handle
				
				-- Connecting Triggered Event
				prompt.Triggered:Connect(function(player: Player)
					
					-- Check max items
					if InventoryServer.CheckInventoryFull(player, tool) then
						warn(`{player.Name}'s inventory is full!`)
						Signal.FireClient(player, "InventoryClient:ErrorMessage", "Your Inventory is full!")
						return
					end
					
					-- Inserting Item Into Player's Backpack
					local backpack: Backpack = player:FindFirstChild("Backpack"); if not backpack then return end
					tool.Parent = backpack
					
				end)
				
			end
			
		end
		
	end
	
end

-- REGISTERING ITEMS
function InventoryServer.RegisterItem(player: Player, tool: Tool)
	if tool.ClassName ~= "Tool" then return end
	if InventoryServer.Respawning[player] then return end
	
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	
	for i, stackData: Types.StackData in inv.Inventory do
		if table.find(stackData.Items, tool) then
			return
		end
	end
	
	local foundStack: Types.StackData = nil
	for i, stackData: types.StackData in inv.Inventory do
		if stackData.Name == tool.Name and #stackData.Items < InventoryServer.MaxStackData[stackData.ItemType] then
			table.insert(stackData.Items, tool)
			foundStack = stackData
			break
		end
	end
	
	if not foundStack then
		if #inv.Inventory < InventoryServer.MaxStacks then
			
			local stack: Types.StackData = {
				Name = tool.Name;
				Description = tool.ToolTip;
				Image = tool.TextureId;
				ItemType = tool:GetAttribute("ItemType");
				IsDroppable = tool:GetAttribute("IsDroppable");
				Items = {tool};
				StackId = inv.NextStackId;
			}
			inv.NextStackId += 1
			table.insert(inv.Inventory, stack)
			
			if stack.ItemType == "Armor" then
				local armorType = stack.Items[1]:GetAttribute("ArmorType")
				if inv.Armor[armorType] == nil then
					InventoryServer.EquipArmor(player, stack.StackId)
				end
			else
				for slotNum: number = 1, 10 do
					if inv.Hotbar["Slot" .. slotNum] == nil then
						InventoryServer.EquipToHotbar(player, slotNum, stack.StackId)
						break
					end
				end
			end
			
		else
			warn("Items were added to inventory, even though it's full! They won't be displayed to the GUI")
		end
	end
	
	-- UPDATING CLIENT
	Signal.FireClient(player, "InventoryClient:Update", inv)
	
end

-- UNREGISTERING ITEMS
function InventoryServer.UnregisterItem(player: Player, tool: Tool)
	if tool.ClassName ~= "Tool" then return end
	if tool.Parent == player.Backpack or (player.Character == nil and tool.Parent == player.Character) then return end
	
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	
	for i, stackData: Types.StackData in inv.Inventory do
		local found: number = table.find(stackData.Items, tool)
		if found then
			
			table.remove(stackData.Items, found)
			
			if #stackData.Items == 0 then
				local stackFound: number = table.find(inv.Inventory, stackData)
				if stackFound then
					table.remove(inv.Inventory, stackFound)
					InventoryServer.UnequipFromHotbar(player, stackData.StackId)
					InventoryServer.UnequipArmor(player, stackData.StackId)
				end
			end
			
		end
	end
	
	-- UPDATING CLIENT
	Signal.FireClient(player, "InventoryClient:Update", inv)
	
end

function InventoryServer.EquipToHotbar(player: Player, equipTo: number, stackId: number)
	if InventoryServer.Respawning[player] then return end
	
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	
	InventoryServer.UnequipFromHotbar(player, stackId)
	
	local isValid: boolean = false
	for i, stackData: Types.StackData in inv.Inventory do
		if stackData.StackId == stackId and stackData.ItemType ~= "Armor" then
			isValid = true
		end
	end
	if isValid == false then return end
	
	inv.Hotbar["Slot" .. equipTo] = stackId
	
	-- UPDATING CLIENT
	Signal.FireClient(player, "InventoryClient:Update", inv)
	
end

function InventoryServer.UnequipFromHotbar(player: Player, stackId: number)
	if InventoryServer.Respawning[player] then return end
	
	-- Getting Inventory
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	
	for slotKey: string, equippedId: number in inv.Hotbar do
		if equippedId == stackId then
			inv.Hotbar[slotKey] = nil
		end
	end
	
	-- UPDATING CLIENT
	Signal.FireClient(player, "InventoryClient:Update", inv)
	
end

-- EQUIPPING ARMOR
function InventoryServer.EquipArmor(player: Player, stackId: number): boolean?
	if InventoryServer.Respawning[player] then return end
	
	-- Finding stack
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local stackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then return end
	if stackData.ItemType ~= "Armor" then return end
	
	-- Character variables
	local char = player.Character; if not char then return end
	
	-- Equipping to armor data
	local armorType = stackData.Items[1]:GetAttribute("ArmorType"); if not armorType then return end
	inv.Armor[armorType] = stackId
	
	-- Clearing armor
	InventoryServer.ClearArmor(player, armorType)
	
	-- Equipping armor model
	local tag = ARMOR_TAG:format(player.UserId, armorType)
	local armorModel: Model = SS.ArmorModels:FindFirstChild(stackData.Name)
	
	if armorModel then
		
		-- Cloning
		local clone = armorModel:Clone(); clone:AddTag(tag)
		clone.Parent = char
		
		-- Welding
		for i, partModel: Model in clone:GetChildren() do
			local bodyPart: BasePart = char:FindFirstChild(partModel.Name)
			if bodyPart then
				local weld = Instance.new("Weld")
				weld.Parent = bodyPart
				weld.Part0 = bodyPart
				weld.Part1 = partModel.PrimaryPart -- or .ArmorCenter
			else
				warn(`The armor model {clone.Name} has body part model {partModel.Name}, but no body part was found by that name.`)
				
			end
		end
		
	end
	
	-- Updating
	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.UpdateArmorStats(player)
	return true -- sucessful equip
	
end

-- UNEQUIPPING ARMOR
function InventoryServer.UnequipArmor(player: Player, stackId: number)
	if InventoryServer.Respawning[player] then return end

	-- Unequipping
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	for armorType, otherStackId in inv.Armor do
		if stackId == otherStackId then
			inv.Armor[armorType] = nil
			InventoryServer.ClearArmor(player, armorType)
		end
	end
	
	-- Updating
	Signal.FireClient(player, "InventoryClient:Update", inv)
	InventoryServer.UpdateArmorStats(player)
end

-- UPDATING ARMOR STATS
function InventoryServer.UpdateArmorStats(player: Player)
	
	-- Looping through armor and summing buffs
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local totalHealthBuff: number = 0
	
	for armorType: string, stackId: number in inv.Armor do
		if stackId == nil then continue end
		local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
		if not stackData then continue end
		
		-- Checking / adding buff
		local healthBuff = stackData.Items[1]:GetAttribute("HealthBuff")
		if healthBuff ~= nil then
			totalHealthBuff += healthBuff
		end
	end

	-- Character Variables
	local char = player.Character; if not char then return end
	local hum = char:FindFirstChild("Humanoid"); if not hum then return end
	
	-- Adding buffs
	local currentHealthPerc = hum.Health / hum.MaxHealth
	hum.MaxHealth = 100 + totalHealthBuff
	hum.Health = hum.MaxHealth * currentHealthPerc
	print(totalHealthBuff)
	print("It worked?")
end

-- CLEARING ARMOR MODELS
function InventoryServer.ClearArmor(player: Player, armorType: "Helm" | "Plate" | "Boots")
	local tag = ARMOR_TAG:format(player.UserId,armorType)
	for i, obj in CS:GetTagged(tag) do
		obj:Destroy()
	end
end

-- GETTING INVENTORY DATA
function InventoryServer.GetInventoryData(player: Player)
	
	while not InventoryServer.AllInventories[player] do task.wait() end
	
	return InventoryServer.AllInventories[player]
	
end

-- FINDING STACK DATA FROM ID
function InventoryServer.FindStackDataFromId(player: Player, stackId: number)
	if stackId == nil then return end
	for i, stackData: Types.StackData in InventoryServer.AllInventories[player].Inventory do
		if stackData.StackId == stackId then
			return stackData
		end
	end
end

-- DROPPING ITEMS
function InventoryServer.DropItem(player: Player, stackId: number): boolean?
	if InventoryServer.Respawning[player] then return end
	
	-- Finding Stack Data
	local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then return end
	if not stackData.IsDroppable then return false end
	
	-- Character Variables
	local char:Mouse = player.Character; if not char then return end
	local root: BasePart = char:FindFirstChild("HumanoidRootPart"); if not root then return end
	
	-- Dropping First Item In List
	local toolToDrop = stackData.Items[1]
	toolToDrop:PivotTo(root.CFrame * CFrame.new(0, 0, -3))
	toolToDrop.Parent = workspace
	return true
	
end

-- HOLDING ITEM
function InventoryServer.HoldItem(player: Player, slotNum: number)
	if InventoryServer.Respawning[player] then return end
	
	-- Finding Stack
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local stackData: Types.StackData? = nil
	for slotKey: string, stackId: number in inv.Hotbar do
		if slotKey == "Slot" .. slotNum then
			stackData = InventoryServer.FindStackDataFromId(player, stackId)
			break
		end
	end
	
	-- Equipping
	InventoryServer.UnholdItems(player)
	if stackData ~= nil then
		
		-- Equipping First Tool In Stack
		local tool: Tool = stackData.Items[1]
		if not player.Character then return end
		tool.Parent = player.Character
		
		-- Updating Client
		Signal.FireClient(player, "InventoryClient:Update", inv)
		
	end
	
end

-- UNHOLDING ITEMS
function InventoryServer.UnholdItems(player: Players)
	if InventoryServer.Respawning[player] then return end
	
	-- Unequipping
	local char: Mouse = player.Character; if not char then return end
	local hum: Humanoid = char:FindFirstChild("Humanoid"); if not hum then return end
	hum:UnequipTools()
	
	-- Updating Client
	Signal.FireClient(player, "InventoryClient:Update", InventoryServer.AllInventories[player])
	
end

-- SAVING DATA
function InventoryServer.SaveData(player: Player)
	if InventoryServer.HasLoaded[player] ~= true then return end
	print ("[INVENTORY] Saving the data of " .. player.Name .. " - " .. player.UserId)
	
	-- Creating Save String
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	local modifiedInv = {
		Inventory = {};
		Hotbar = inv.Hotbar;
		Armor = inv.Armor;
		NextStackId = inv.NextStackId;
	}
	
	for i, stackData in inv.Inventory do
		table.insert(modifiedInv.Inventory, {
			Name = stackData.Name;
			Count = #stackData.Items;
			StackId = stackData.StackId;
		})
	end
	
	
	local saveString = HS:JSONEncode(modifiedInv)
	
	-- Saving
	local success, result = false, nil
	local timeoutTime =  5
	local startTime = os.clock()
	while not success do
		-- Timeout Checking
		if os.clock() - startTime > timeoutTime then
			print("[Inventory] Unable to save the data of " .. player.Name .. " - " .. player.UserId)
			return
		end
		-- Attempting Saving
		success, result = pcall(function()
			IDS:SetAsync(SAVE_KEY:format(player.UserId), saveString)
		end)
		if not success then
			task.wait(1)
		end
		
	end
	print ("[INVENTORY] Finished saving the data of " .. player.Name .. " - " .. player.UserId)
	
end

-- LOADING DATA
function InventoryServer.LoadData(player: Player)
	print ("[INVENTORY] Loading the data of " .. player.Name .. " - " .. player.UserId)
	
	-- Getting Current Data
	local saveString = IDS:GetAsync(SAVE_KEY:format(player.UserId))
	if saveString == nil then
		print ("[INVENTORY] No data found for player " .. player.Name .. " - " .. player.UserId)
		InventoryServer.HasLoaded[player] = true
		return
	end
	local savedData = HS:JSONDecode(saveString)
	
	-- Loading Inventory
	local inv: Types.Inventory = {
		Inventory = {};
		Hotbar = savedData.Hotbar;
		Armor = savedData.Armor;
		NextStackId = savedData.NextStackId;
	}
	local char: Model = player.Character or player.CharacterAdded:Wait()
	local backpack: Backpack = player:WaitForChild("Backpack")
	
	for i, savedStack in savedData.Inventory do
		
		-- Finding Sample Item
		local sample: Tool = SS.AllItems:FindFirstChild(savedStack.Name)
		if not sample then
			warn("No item sample was found in ServerStorage.Allitems for " .. savedStack.Name)
			continue
		end
		
		-- Creating Stack
		local stack: Types.StackData = {
			Name = savedStack.Name;
			Description = sample.ToolTip;
			Image = sample.TextureId;
			ItemType = sample:GetAttribute("ItemType");
			IsDroppable = sample:GetAttribute("IsDroppable");
			Items = {};
			StackId = savedStack.StackId;
		}
		
		-- Cloning Items
		for i = 1, savedStack.Count do
			local clone = sample:Clone()
			clone.Parent = backpack
			table.insert(stack.Items, clone)
		end
		
		-- Inserting Stack
		table.insert(inv.Inventory, stack)
		
	end
	InventoryServer.AllInventories[player] = inv
	InventoryServer.HasLoaded[player] = true
	InventoryServer.Janitors[player]:GiveChore(function()
		InventoryServer.HasLoaded[player] = nil
	end)
	
	-- Adding armor models
	for armorType, stackId in inv.Armor do
		InventoryServer.EquipArmor(player, stackId)
	end
	
	-- Updating Client UI
	Signal.FireClient(player, "InventoryClient:Update", InventoryServer.AllInventories[player])
	
	print ("[INVENTORY] Finished loading the data of " .. player.Name .. " - " .. player.UserId)
end

-- RETURNING
return InventoryServer