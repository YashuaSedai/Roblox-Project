-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- MODULE
local GuiRelatedThings = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))

local ExpHandler = {}
ExpHandler.BaseExp = 100

-- EXP AWARDER
function ExpHandler.AwardExp(player: Player, value: number, hasTripleExp)
	
	local leaderstats = player:FindFirstChild("leaderstats") -- First we'll have to find the leaderstats folder
	if leaderstats then -- We check if it exists
		
		local exp = leaderstats:FindFirstChild("Exp")
		local level = leaderstats:FindFirstChild("Level")
		
		if exp and level then
			
			-- Check if the player has the triple Exp gamepass
			if hasTripleExp then
				ExpHandler.BaseExp = ExpHandler.BaseExp * 3
			end
			
			local expToAward = ExpHandler.BaseExp + value -- calculate exp to award
			
			local requiredExp = level.Value * ExpHandler.BaseExp -- calculate the required Exp before leveling up
			-- Add the Exp
			exp.Value = exp.Value + expToAward
			ExpHandler.CheckExp(player)
			
		end
	end
	
end

-- EXP CHECKER
function ExpHandler.CheckExp(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local exp = leaderstats:FindFirstChild("Exp")
		local level = leaderstats:FindFirstChild("Level")
		local requiredExp = level.Value * ExpHandler.BaseExp -- calculate the required Exp before leveling up

		-- Loop in case there are excess exp
		while exp.Value >= requiredExp do
			requiredExp = level.Value * ExpHandler.BaseExp -- recalculate the required Exp again
			local excessExp = exp.Value - requiredExp
			if excessExp >= 0 then
				exp.Value = excessExp -- Subtract excess exp
				level.Value = level.Value + 1 -- Increase the level by 1
				GuiRelatedThings.PlaySoundFor(player, "Level Up")
			else
				break -- Stop if the exp would go negative
			end
		end
	end
end

-- TWEEN

return ExpHandler
