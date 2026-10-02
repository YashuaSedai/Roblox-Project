-- SERVICE
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- MODULES
local ExpHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))
local MarksHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("MarksHandler"):WaitForChild("MarksHandler"))
local EnemyDictionary = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("EnemyDictionary"))
local DamageTracker = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("DamageTracker"))

local NpcHandler = {}

-- TRACKS NPC HEALTH
function NpcHandler.HealthTracker(hum: Humanoid, char: Model)
	-- Listens for when the enemy's health is changed
	local storedHealth = hum.Health
	local healthConnection
	healthConnection = hum.HealthChanged:Connect(function(newHealth)
		if newHealth < storedHealth then -- If this is true, damage was taken

			-- Search for the Last Attacker and Last Damage attributes
			local AttackerId = hum:GetAttribute("LastAttacker")
			local AttackerDamage = hum:GetAttribute("LastDamage")
			local AttackerPlayer = Players:GetPlayerByUserId(AttackerId)

			if AttackerPlayer then
				-- Ensure we don't log more damage than the NPC's remaining health
				local damageToLog = math.min(AttackerDamage, storedHealth - newHealth)

				-- Create a tracker for this NPC if it doesn't exist yet
				local tracker = DamageTracker.CreateTracker(char)

				-- Ensure the player entry exists in the tracker, if not, initialize to 0
				if not tracker[AttackerPlayer.UserId] then
					tracker[AttackerPlayer.UserId] = 0
				end

				-- Add the capped damage to the player's total in the dictionary
				tracker[AttackerPlayer.UserId] = tracker[AttackerPlayer.UserId] + damageToLog
			end

			storedHealth = newHealth

		else
			storedHealth = newHealth
		end
	end)
	return healthConnection
end

-- TRACKS NPC DEATH
function NpcHandler.DeathTracker(hum: Humanoid, char: Model, NpcHealthConnection: RBXScriptConnection?)
	-- Listens for when the NPC dies
	local DeathConnection
	DeathConnection = hum.Died:Connect(function()
		local NpcName = char.Name
		local NpcMaxHealth = EnemyDictionary.Stats[NpcName].health

		-- Calculate total damage from all players
		local totalDamage = 0
		for playerId, damage in pairs(DamageTracker[char]) do
			totalDamage = totalDamage + damage
		end

		-- Ensure the total damage does not exceed the NPC's max health
		totalDamage = math.min(totalDamage, NpcMaxHealth)

		if totalDamage > 0 then
			-- Now loop again and calculate the contribution of each player
			for playerId, damage in pairs(DamageTracker[char]) do
				local player = Players:GetPlayerByUserId(playerId)
				if player then
					-- Calculate the player's contribution to the total damage percentage
					local damagePercentage = damage / totalDamage

					-- Calculate the exp to award the player
					local expToAward = EnemyDictionary.Information[NpcName].exp * damagePercentage
					local marksToAward = EnemyDictionary.Information[NpcName].marks * damagePercentage

					-- Triple EXP handling
					local hasTripleExp = player:GetAttribute("TripleExp") or false -- Check once and store result
					local hasDoubleMarks = player:GetAttribute("DoubleMarks") or false

					-- Award the player the exp
					ExpHandler.AwardExp(player, expToAward, hasTripleExp)
					MarksHandler.GiveMarks(player, marksToAward, hasDoubleMarks)
				end
			end
		end
		
		-- Clear the table for this specific NPC (char)
		DamageTracker[char] = nil
		NpcHealthConnection:Disconnect()
		DeathConnection:Disconnect()
	end)
end

return NpcHandler
