-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- MODULE
local GuiRelatedThings = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))

local ExpHandler = {}
ExpHandler.BaseExp = 100 -- exp needed per level (level * BaseExp)

-- EXP AWARDER
-- Adds EXACTLY `value` (x3 with the triple exp pass). Kill exp is worked out by DamageService, from the damage dealt.
-- (It used to add a flat BaseExp on top of every award and, with the triple pass, multiplied BaseExp itself by 3 on every
-- award, which also tripled the exp needed to level. Both are gone.)
function ExpHandler.AwardExp(player: Player, value: number, hasTripleExp)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local exp = leaderstats:FindFirstChild("Exp")
	local level = leaderstats:FindFirstChild("Level")
	if not exp or not level then return end

	local amount = value * (hasTripleExp and 3 or 1)
	if amount <= 0 then return end

	exp.Value = exp.Value + amount
	ExpHandler.CheckExp(player)
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

return ExpHandler
