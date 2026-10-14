-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
local RemoveEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Remove")
local SourceDeduct = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Stats"):WaitForChild("SourceDeduct")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))

local ELEMENTS = { Fire = true, Water = true, Earth = true, Air = true, Spirit = true, Default = true }
local SLOTS = { Slot1 = true, Slot2 = true, Slot3 = true, Slot4 = true, Slot5 = true }
local lastDraw = {}

DrawEvent.OnServerEvent:Connect(function(plr, element, slot, slotNo)
	if typeof(element) ~= "string" or not ELEMENTS[element] then return end
	if typeof(slot) ~= "string" or not SLOTS[slot] then return end
	if slotNo ~= nil and (typeof(slotNo) ~= "number" or slotNo % 1 ~= 0 or slotNo < 1 or slotNo > 5) then return end

	local now = os.clock()
	if now - (lastDraw[plr] or 0) < 0.05 then return end -- at most about 20 a second
	lastDraw[plr] = now

	DrawEvent:FireAllClients(plr.Character, plr.Name, element, slot, slotNo)
end)

-- WHEN FX NEEDS CLEANING UP
RemoveEvent.OnServerEvent:Connect(function(plr: Player)
	RemoveEvent:FireAllClients(plr.Name)
end)

local MAX_COST = 50

SourceDeduct.OnServerEvent:Connect(function(player: Player, hum, amount)
	local char = player.Character
	local ownHum = char and char:FindFirstChildOfClass("Humanoid")
	if not ownHum or hum ~= ownHum then return end -- only your own Source
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0 or amount > MAX_COST then return end
	WeavingModule.DeductSource(player, ownHum, amount)
end)

Players.PlayerRemoving:Connect(function(Player)
	local Name = Player.Name
	RemoveEvent:FireAllClients(Name)
	
end)

Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(function(char)
		if char then
			local tempJanitor = Janitor.new()
			local Humanoid = char and char:WaitForChild("Humanoid")
			local Name = Player.Name
			
				tempJanitor:GiveChore(Humanoid.Died:Connect(function()
				RemoveEvent:FireAllClients(Name)
				tempJanitor:Clean()
				end))
			
		end
	end)
end)
