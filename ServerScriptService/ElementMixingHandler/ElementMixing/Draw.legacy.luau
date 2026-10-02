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

DrawEvent.OnServerEvent:Connect(function(plr: Player, element: string?, slot: string?, slotNo: number?)
	local char = plr.Character
	local name = plr.Name
	
	DrawEvent:FireAllClients(char, name, element, slot, slotNo)
end)

-- WHEN FX NEEDS CLEANING UP
RemoveEvent.OnServerEvent:Connect(function(plr: Player)
	RemoveEvent:FireAllClients(plr.Name)
end)

-- DEDUCT SOURCE
--SourceDeduct.OnServerEvent:Connect(function(player: Player, hum: Humanoid, amount: number)
--	WeavingModule.DeductSource(player, hum, amount)
--end)

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
