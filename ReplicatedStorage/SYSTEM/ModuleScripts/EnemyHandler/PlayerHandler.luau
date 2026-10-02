-- SERVICE
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- MODULES
local ExpHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))
local MarksHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("MarksHandler"):WaitForChild("MarksHandler"))
local EnemyDictionary = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("EnemyDictionary"))
local DamageTracker = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EnemyHandler"):WaitForChild("DamageTracker"))

local PlayerHandler = {}


-- TRACKS PLAYER HEALTH
function PlayerHandler.HealthTracker(hum: Humanoid, uid)
	-- Listens for when the enemy's health is changed
	local storedHealth = hum.Health
	local healthConnection
	healthConnection = hum.HealthChanged:Connect(function(newHealth)
		if newHealth < storedHealth then -- If this is true, damage was taken

			-- Search for the Last Attacker and Last Damage attributes
			local AttackerId = hum:GetAttribute("LastAttacker")
			local AttackerDamage = hum:GetAttribute("LastDamage")
			if AttackerId and typeof(AttackerId) == "number" then
				local AttackerPlayer = Players:GetPlayerByUserId(AttackerId)

				if AttackerPlayer then
					-- Ensure we don't log more damage than the player's remaining health
					local damageToLog = math.min(AttackerDamage or 0, storedHealth - newHealth)

					-- Create a tracker for this Enemy if it doesn't exist yet
					local tracker = DamageTracker.CreateTracker(uid)

					-- Ensure the player entry exists in the tracker, if not, initialize to 0
					tracker[AttackerPlayer.UserId] = tracker[AttackerPlayer.UserId] or 0

					-- Add the capped damage to the player's total in the dictionary
					tracker[AttackerPlayer.UserId] = tracker[AttackerPlayer.UserId] + damageToLog
				end
			end

			storedHealth = newHealth

		else
			storedHealth = newHealth
		end
	end)
	return healthConnection
end

function PlayerHandler.DeathTracker(hum: Humanoid, char: Model, enemyplr: Player, uid, PlayerHealthConnection: RBXScriptConnection)
	-- Listens for when the enemy player dies
	local DeathConnection 
	DeathConnection = hum.Died:Connect(function()

		local EnemyName = char.Name
		local EnemyMaxHealth = char.Health
		local EnemyBaseExp = EnemyDictionary.Information.PlayerBaseInfo.exp 
		local EnemyBaseMarks = EnemyDictionary.Information.PlayerBaseInfo.marks
		local EnemyLevel = enemyplr:WaitForChild("leaderstats"):WaitForChild("Level").Value
		local ExpCalculation = EnemyBaseExp + (EnemyLevel * 3)

		-- Calculate total damage from all players
		local totalDamage = 0
		for playerId, damage in pairs(DamageTracker[uid]) do
			totalDamage = totalDamage + damage
		end

		-- Ensure the total damage does not exceed the NPC's max health
		totalDamage = math.min(totalDamage, hum.MaxHealth)

		if totalDamage > 0 then
			-- Now loop again and calculate the contribution of each player
			for playerId, damage in pairs(DamageTracker[uid]) do
				local player = Players:GetPlayerByUserId(playerId)
				if player then
					-- Calculate the player's contribution to the total damage percentage
					local damagePercentage = damage / totalDamage

					-- Calculate the exp to award the player
					local expToAward = ExpCalculation * damagePercentage
					local marksToAward = EnemyBaseMarks * damagePercentage

					-- Triple EXP handling
					local hasTripleExp = player:GetAttribute("TripleExp") or false -- Check once and store result
					local hasDoubleMarks = player:GetAttribute("DoubleMarks") or false

					-- Award the player the exp
					ExpHandler.AwardExp(player, expToAward, hasTripleExp)
					MarksHandler.GiveMarks(player, marksToAward, hasDoubleMarks)
				end
			end
		end
	
		-- Clear the table for this specific player (plr)
		DamageTracker[uid] = nil
		PlayerHealthConnection:Disconnect()
		DeathConnection:Disconnect()
	end)
end

return PlayerHandler
