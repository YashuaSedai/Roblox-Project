-- ShieldBalance (ModuleScript)
-- ONE place for the numbers behind the Shielding vs. Source-regen balance, so SourceSetup and ShieldingScript can't drift apart.
--
-- THE RULE: a target holding ALL slots out-regenerates a shielder only if targetLevel >= shielderLevel + LEVELS_AHEAD_TO_BEAT.
-- Holding fewer slots needs far more levels (see minLevelToBeat).

local ShieldBalance = {}

ShieldBalance.SLOT_REGEN = 1.75            -- Source per second, per filled slot, at level 0
ShieldBalance.SLOT_LEVEL_DIVISOR = 15    -- slot regen is multiplied by (1 + Level / SLOT_LEVEL_DIVISOR)
ShieldBalance.MAX_SLOTS = 5               -- must match the number of slots on the character (Slot1..Slot5)
ShieldBalance.LEVELS_AHEAD_TO_BEAT = 5    -- levels a full-slot target needs over the shielder

-- Source per second a target regenerates from its filled slots
function ShieldBalance.slotRegenPerSecond(slots: number, level: number): number
	return slots * ShieldBalance.SLOT_REGEN * (1 + level / ShieldBalance.SLOT_LEVEL_DIVISOR)
end

-- Source per second ONE shielder drains from the target.
-- The "- 0.5" makes exactly LEVELS_AHEAD_TO_BEAT levels a win and one level less a loss (without it, 5 ahead is a dead-even tie).
function ShieldBalance.drainPerSecond(shielderLevel: number): number
	return ShieldBalance.SLOT_REGEN * ShieldBalance.MAX_SLOTS
		* (1 + (shielderLevel + ShieldBalance.LEVELS_AHEAD_TO_BEAT - 0.5) / ShieldBalance.SLOT_LEVEL_DIVISOR)
end

-- The lowest whole level at which a target with `slots` filled slots out-regenerates ONE shielder.
function ShieldBalance.minLevelToBeat(shielderLevel: number, slots: number): number
	local d = ShieldBalance.SLOT_LEVEL_DIVISOR
	local needed = (ShieldBalance.MAX_SLOTS / slots) * (shielderLevel + d + ShieldBalance.LEVELS_AHEAD_TO_BEAT - 0.5) - d
	return math.floor(needed) + 1
end

return ShieldBalance
