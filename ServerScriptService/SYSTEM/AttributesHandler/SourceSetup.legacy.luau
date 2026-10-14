-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utilities = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))

-- SOURCE REGENERATION ------------------------------------------------------------------------------------
-- Two sources of regeneration, both applied every TICK:
--   1. PASSIVE: a slow trickle that is always on, but it only refills Source up to PASSIVE_CAP (a fraction of MaxSource).
--      Passive regen never pushes Source past that line.
--   2. SLOTS:   every element sitting in a slot adds  SLOT_REGEN * (Level / 100 + 1)  Source per second. This one is
--      NOT capped by PASSIVE_CAP, it can fill Source all the way to MaxSource.
-- Regeneration that lands ABOVE BURN_REGEN_ABOVE (a fraction of MaxSource) also fills the Burn meter
-- (by that amount x the Burn's "PerRegen" attribute, which BurnOutSetup sets).
local TICK = 0.1                  -- how often Source updates (seconds)
local PASSIVE_REGEN = 1           -- Source per SECOND from passive regen
local PASSIVE_CAP = 0.20          -- passive regen stops at this fraction of MaxSource
local SLOT_REGEN = 1.5            -- Source per second, per filled slot, at level 0
local SLOT_LEVEL_DIVISOR = 100    -- slot regen is multiplied by (Level / SLOT_LEVEL_DIVISOR + 1)
local BURN_REGEN_ABOVE = 0.50     -- regenerating above this fraction of MaxSource fills Burn
local DRAIN_ABOVE_CAP = 1  -- Source lost per SECOND while above the passive cap line

local SLOT_COUNT = 5

-- how many slots hold an element (the server knows: ElementAssignment sets Slot1..Slot5 on the character,
-- and an empty slot is "Default")
local function countFilledSlots(char: Model): number
	local count = 0
	for i = 1, SLOT_COUNT do
		local element = char:GetAttribute("Slot" .. i)
		if element ~= nil and element ~= "Default" then
			count += 1
		end
	end
	return count
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hum: Humanoid = char:WaitForChild("Humanoid")

		-- Create attributes if not already set
		if not player:GetAttribute("Role") then
			player:SetAttribute("Role", "Default")
		end

		local leaderstats = player:WaitForChild("leaderstats")
		local level = leaderstats:WaitForChild("Level")
		local multiplier = 4

		-- Create MaxSource and Source values
		local maxSource = hum:FindFirstChild("MaxSource") or Instance.new("NumberValue")
		maxSource.Name = "MaxSource"
		maxSource.Parent = hum
		maxSource.Value = 100 + (level.Value * multiplier)

		local source = hum:FindFirstChild("Source") or Instance.new("NumberValue")
		source.Name = "Source"
		source.Parent = hum
		source.Value = maxSource.Value

		-- (the regeneration rates are the constants at the top of this script)
		local regenId = 0 -- so a role change can never leave two regeneration loops running

		-- Function to clean up source-related logic
		local function CleanupSource()
			regenId += 1 -- stops the regeneration loop
			if hum:FindFirstChild("MaxSource") then
				hum.MaxSource:Destroy()
			end
			if hum:FindFirstChild("Source") then
				hum.Source:Destroy()
			end
		end

		-- Function to set up source-related logic
		local function SetupSource()
			if not hum:FindFirstChild("MaxSource") then
				local newMaxSource = Instance.new("NumberValue")
				newMaxSource.Name = "MaxSource"
				newMaxSource.Parent = hum
				newMaxSource.Value = 100
			end
			if not hum:FindFirstChild("Source") then
				local newSource = Instance.new("NumberValue")
				newSource.Name = "Source"
				newSource.Parent = hum
				newSource.Value = hum.MaxSource.Value
			end

			-- Regenerate source logic
			if source and maxSource then
				regenId += 1
				local myId = regenId
				task.spawn(function()
					while regenId == myId and hum.Parent and hum:FindFirstChild("Source") and hum:FindFirstChild("MaxSource") do
						local max = maxSource.Value
						local current = source.Value
						if current > max then
							current = max
							source.Value = max
						end

						-- GlobalCD still pauses everything, as before
						if not char:GetAttribute("GlobalCD") then
							-- while shielded: no passive trickle and no drain from here (the Shielding script already drains its target),
							-- but elements the player has channeled into their slots keep regenerating Source
							local shielded = char:GetAttribute("Shielded") or char:GetAttribute("ShieldApplication")
							local floor = PASSIVE_CAP * max

							-- 1. gain: passive (only up to the floor, not while shielded) + slots (always, not capped by the floor)
							local passive = shielded and 0 or math.clamp(floor - current, 0, PASSIVE_REGEN * TICK)
							local slotRegen = countFilledSlots(char) * SLOT_REGEN * (level.Value / SLOT_LEVEL_DIVISOR + 1)
							local gain = passive + slotRegen * TICK

							-- 2. drain: only the part above the floor, never down through it, and not while shielded
							local drain = (not shielded and current > floor) and DRAIN_ABOVE_CAP * TICK or 0

							local newValue = math.clamp(current + gain - drain, 0, max)
							if drain > 0 then
								newValue = math.max(newValue, floor)
							end

							if newValue ~= current then
								source.Value = newValue
							end

							-- 3. BURN: counts the regeneration above the burn line (the gain, not the net)
							local burn = hum:FindFirstChild("Burn")
							local perRegen = burn and burn:GetAttribute("PerRegen")
							if perRegen and gain > 0 then
								local aboveLine = math.min(current + gain, max) - math.max(current, BURN_REGEN_ABOVE * max)
								if aboveLine > 0 then
									burn.Value += aboveLine * perRegen
								end
							end
						end

						task.wait(TICK)
					end
				end)
			end
		end

		-- Listen for changes to the "Role" attribute
		player:GetAttributeChangedSignal("Role"):Connect(function()
			local role = player:GetAttribute("Role")
			if role == "Weaver" then
				SetupSource()
			elseif role == "Warder" then
				CleanupSource()
			end
		end)

		-- Initial role setup
		if player:GetAttribute("Role") == "Weaver" then
			SetupSource()
		elseif player:GetAttribute("Role") == "Warder" then
			CleanupSource()
		end
	end)
end)
