-- SERVICES
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- MODULES
local ExpHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))
local EnemyDictionary = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("EnemyDictionary"))
local DamageTracker = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("DamageTracker"))
local PlayerHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("PlayerHandler"))
local NpcHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("NpcHandler"))

-- CHILD LISTENER
workspace.ChildAdded:Connect(function(obj)

	-- Determines if the child added to workspace contains a humanoid
	if obj and obj:FindFirstChild("Humanoid") then

		-- Properly store the components in understandable variables
		local char: Model? = obj
		local hum: Humanoid? = char and char:FindFirstChild("Humanoid")

		-- Try retrieving the player
		local possiblePlayer = Players:GetPlayerFromCharacter(char)
		if not possiblePlayer then warn("New instance is not a player, ", char.Name) end

		local diedConnection -- Just a simple storage for rbxconnection
		local damageConnection

		-- Try retrieving the NPC attribute from the humanoid
		if char and hum and hum:GetAttribute("NPC") then -- If added child is indeed an NPC

			-- Check if the NPC is in the EnemyDictionary
			local npcName = char.Name
			if not EnemyDictionary.Information[npcName] then
				return -- If the NPC isn't part of the dictionary, stop further processing
			end
			
			-- Check if the NPC is in the EnemyDictionary
			local npcName = char.Name
			if not EnemyDictionary.Information[npcName] then
				return -- If the NPC isn't part of the dictionary, stop further processing
			end

			DamageTracker.CreateTracker(char)
			local NpcHealthConnection = NpcHandler.HealthTracker(hum, char)
			NpcHandler.DeathTracker(hum, char, NpcHealthConnection)

		elseif possiblePlayer then -- If the added child is a player

			local plr = possiblePlayer -- Store the player in a different variable for clearer reading
			local uid = plr.UserId

			DamageTracker.CreateTracker(uid)
			local PlayerHealthConnection = PlayerHandler.HealthTracker(hum, uid)
			PlayerHandler.DeathTracker(hum, char, plr, uid, PlayerHealthConnection)
		end

	end

end)

for _, obj in workspace:GetChildren() do
	-- Determines if the child added to workspace contains a humanoid
	if obj and obj:FindFirstChild("Humanoid") then

		-- Properly store the components in understandable variables
		local char: Model? = obj
		local hum: Humanoid? = char and char:FindFirstChild("Humanoid")

		-- Try retrieving the player
		local possiblePlayer = Players:GetPlayerFromCharacter(char)
		if not possiblePlayer then warn("New instance is not a player, ", char.Name) end

		local diedConnection -- Just a simple storage for rbxconnection
		local damageConnection

		-- Try retrieving the NPC attribute from the humanoid
		if char and hum and hum:GetAttribute("NPC") then -- If added child is indeed an NPC

			-- Check if the NPC is in the EnemyDictionary
			local npcName = char.Name
			if not EnemyDictionary.Information[npcName] then
				return -- If the NPC isn't part of the dictionary, stop further processing
			end

			-- Check if the NPC is in the EnemyDictionary
			local npcName = char.Name
			if not EnemyDictionary.Information[npcName] then
				return -- If the NPC isn't part of the dictionary, stop further processing
			end

			DamageTracker.CreateTracker(char)
			local NpcHealthConnection = NpcHandler.HealthTracker(hum, char)
			NpcHandler.DeathTracker(hum, char, NpcHealthConnection)

		elseif possiblePlayer then -- If the added child is a player

			local plr = possiblePlayer -- Store the player in a different variable for clearer reading
			local uid = plr.UserId
			
			DamageTracker.CreateTracker(uid)
			local PlayerHealthConnection = PlayerHandler.HealthTracker(hum, uid)
			PlayerHandler.DeathTracker(hum, char, plr, uid, PlayerHealthConnection)
		end

	end
end