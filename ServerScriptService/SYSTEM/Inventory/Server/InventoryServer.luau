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
local HOTBAR_SLOTS = 10
local DROP_COOLDOWN = 0.3   -- seconds between drops for one player (a client can fire DropItem as fast as it likes)
local MAX_ATTEMPTS = 5      -- tries per DataStore call
local LOCK_TIMEOUT = 180    -- seconds before another server's session lock is assumed dead
local LOCK_WAITS = 6        -- how many times to wait for the old server to let go...
local LOCK_WAIT_SECONDS = 3 -- ...and how long between waits
local lastDrop = {}         -- [player] = os.clock() of their last drop
local AUTOSAVE_TIME = 60 * 3
local SAVE_KEY = "%i-V.01"
local ARMOR_TAG = "%i %s EquippedArmor"

-- DATASTORE HELPERS ----------------------------------------------------------------------------------------------
-- calls fn until it works, waiting 1, 2, 4, 8, 8 seconds between tries. Returns ok, result
local function withRetry(fn)
	local lastErr
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		if tostring(result):find("StudioAccessToApisNotAllowed") then break end
		if attempt < MAX_ATTEMPTS then task.wait(math.min(2 ^ (attempt - 1), 8)) end
	end
	return false, lastErr
end

-- READS the saved inventory and takes the SESSION LOCK in one atomic request, so two servers can never both own a player.
-- The lock lives inside the saved JSON ("Lock"), so old saves (which have none) still load. Returns the saved table ({} if
-- there is none yet), or nil + a reason.
local function claimInventory(userId: number)
	local key = SAVE_KEY:format(userId)
	for _ = 1, LOCK_WAITS do
		local lockedByOther, corrupt, claimed = false, false, nil
		local ok, err = withRetry(function()
			IDS:UpdateAsync(key, function(old)
				lockedByOther, corrupt, claimed = false, false, nil
				local data = {}
				if type(old) == "string" then
					local okDecode, decoded = pcall(function() return HS:JSONDecode(old) end)
					if not (okDecode and type(decoded) == "table") then
						corrupt = true
						return nil -- never overwrite something we can't read
					end
					data = decoded
				end
				local lock = data.Lock
				if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_TIMEOUT then
					lockedByOther = true
					return nil -- cancel: another server has this player right now
				end
				data.Lock = { JobId = game.JobId, Time = os.time() }
				claimed = data
				return HS:JSONEncode(data)
			end)
		end)
		if not ok then return nil, err end
		if corrupt then return nil, "the saved inventory could not be read" end
		if not lockedByOther then return claimed or {} end
		task.wait(LOCK_WAIT_SECONDS)
	end
	return nil, "this player is still active on another server"
end

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
		local pending = 0
		for _, player: Player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				InventoryServer.SaveData(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
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

	InventoryServer.SaveData(player, true)
	lastDrop[player] = nil
	if InventoryServer.Janitors[player] then
		InventoryServer.Janitors[player]:Destroy()
	end

end

-- Heartbeat Loop
function InventoryServer.OnPostSimulation(dt: number)
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
					if prevValue ~= nil then
						part.CanTouch = prevValue
						InventoryServer.ToolCanTouch[part] = nil
					end

					-- Resetting CanCollide
					local prevCollide = InventoryServer.ToolCanCollide[part]
					if prevCollide ~= nil then
						part.CanCollide = prevCollide
						InventoryServer.ToolCanCollide[part] = nil
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
						InventoryServer.ToolCanCollide[part] = part.CanCollide
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
	for i, stackData: Types.StackData in inv.Inventory do
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
				for slotNum: number = 1, HOTBAR_SLOTS do
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
	-- the client sends these: only a whole slot number 1..HOTBAR_SLOTS may become a "Slot<n>" key (anything else would be saved)
	if type(equipTo) ~= "number" or equipTo % 1 ~= 0 or equipTo < 1 or equipTo > HOTBAR_SLOTS then return end
	if type(stackId) ~= "number" then return end

	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	if not inv then return end

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
	if not inv then return end

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
	if not inv then return end
	local stackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then return end
	if stackData.ItemType ~= "Armor" then return end
	if not stackData.Items[1] then return end

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
	if not inv then return end
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
	if not inv then return end
	local totalHealthBuff: number = 0

	for armorType: string, stackId: number in inv.Armor do
		if stackId == nil then continue end
		local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
		if not stackData or not stackData.Items[1] then continue end

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
	local inv = InventoryServer.AllInventories[player]
	if not inv then return end
	for i, stackData: Types.StackData in inv.Inventory do
		if stackData.StackId == stackId then
			return stackData
		end
	end
end

-- DROPPING ITEMS
function InventoryServer.DropItem(player: Player, stackId: number): boolean?
	if InventoryServer.Respawning[player] then return end
	if os.clock() - (lastDrop[player] or 0) < DROP_COOLDOWN then return end -- rate limit
	lastDrop[player] = os.clock()

	-- Finding Stack Data
	local stackData: Types.StackData = InventoryServer.FindStackDataFromId(player, stackId)
	if not stackData then return end
	if not stackData.IsDroppable then return false end

	-- Character Variables
	local char:Mouse = player.Character; if not char then return end
	local root: BasePart = char:FindFirstChild("HumanoidRootPart"); if not root then return end

	-- Dropping First Item In List
	local toolToDrop = stackData.Items[1]
	if not toolToDrop then return end
	toolToDrop:PivotTo(root.CFrame * CFrame.new(0, 0, -3))
	toolToDrop.Parent = workspace
	return true

end

-- HOLDING ITEM
function InventoryServer.HoldItem(player: Player, slotNum: number)
	if InventoryServer.Respawning[player] then return end
	if type(slotNum) ~= "number" then return end

	-- Finding Stack
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	if not inv then return end
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
		if not tool or not player.Character then return end
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
	if InventoryServer.AllInventories[player] then
		Signal.FireClient(player, "InventoryClient:Update", InventoryServer.AllInventories[player])
	end

end

-- SAVING DATA   (releaseLock = true when the player is leaving or the server is closing)
-- UpdateAsync instead of SetAsync: a server that no longer holds the player's session lock can't overwrite the data.
function InventoryServer.SaveData(player: Player, releaseLock: boolean?)
	if InventoryServer.HasLoaded[player] ~= true then return end
	local inv: Types.Inventory = InventoryServer.AllInventories[player]
	if not inv then return end

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

	local lostLock = false
	local ok, err = withRetry(function()
		IDS:UpdateAsync(SAVE_KEY:format(player.UserId), function(old)
			lostLock = false
			if type(old) == "string" then
				local okDecode, existing = pcall(function() return HS:JSONDecode(old) end)
				if okDecode and type(existing) == "table" and existing.Lock and existing.Lock.JobId ~= game.JobId then
					lostLock = true
					return nil -- another server owns this player now: never overwrite their data
				end
			end
			modifiedInv.Lock = if releaseLock then nil else { JobId = game.JobId, Time = os.time() }
			return HS:JSONEncode(modifiedInv)
		end)
	end)

	if not ok then
		warn(`[Inventory] Unable to save the data of {player.Name} ({player.UserId}): {err}`)
	elseif lostLock then
		warn(`[Inventory] {player.Name} is locked by another server, nothing saved`)
	end
end

-- LOADING DATA
function InventoryServer.LoadData(player: Player)
	local savedData, err = claimInventory(player.UserId)
	if not savedData then
		-- HasLoaded stays unset, so this session's (empty) inventory is never saved over the real one
		warn(`[Inventory] The data of {player.Name} did not load: {err}`)
		Signal.FireClient(player, "InventoryClient:ErrorMessage", "Your inventory could not be loaded. It won't be saved this session, rejoin to try again.")
		return
	end

	local function markLoaded()
		InventoryServer.HasLoaded[player] = true
		local janitor = InventoryServer.Janitors[player]
		if janitor then
			janitor:GiveChore(function()
				InventoryServer.HasLoaded[player] = nil
			end)
		end
	end

	if savedData.Inventory == nil then -- nothing saved yet (a new player: only the lock exists)
		markLoaded()
		return
	end

	-- Loading Inventory
	local inv: Types.Inventory = {
		Inventory = {};
		Hotbar = savedData.Hotbar or {};
		Armor = savedData.Armor or {};
		NextStackId = savedData.NextStackId or 0;
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
	markLoaded()

	-- Adding armor models
	for armorType, stackId in inv.Armor do
		InventoryServer.EquipArmor(player, stackId)
	end

	-- Updating Client UI
	Signal.FireClient(player, "InventoryClient:Update", InventoryServer.AllInventories[player])
end

-- RETURNING
return InventoryServer