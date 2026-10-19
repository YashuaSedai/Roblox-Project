-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utilities = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))
local ShieldBalance = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ShieldBalance"))
local LinkData = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("LinkData"))

-- SOURCE REGENERATION ------------------------------------------------------------------------------------
-- Two sources of regeneration, applied every TICK (scaled by the REAL time since the last tick, so the rates are per second):
--   1. PASSIVE: a slow trickle that is always on, but it only refills Source up to PASSIVE_CAP (a fraction of MaxSource).
--      Passive regen never pushes Source past that line.
--   2. SLOTS:   every element sitting in a slot adds  SLOT_REGEN * (Level / 100 + 1)  Source per second (see ShieldBalance). This one is
--      NOT capped by PASSIVE_CAP, it can fill Source all the way to MaxSource.
-- LINKS (see LinkData / LinkService): a link LEADER (the end of a chain with at least one linker) regenerates
--   x (1 + 0.5 per linker), has NO passive cap (passive regen fills the whole bar) and has NO natural drain above the cap.
--   Anyone in a link (leader or linker) doesn't gain Burn from regenerating.
-- Regeneration that lands ABOVE BURN_REGEN_ABOVE (a fraction of MaxSource) also fills the Burn meter
-- (by that amount x the Burn's "PerRegen" attribute, which BurnOutSetup sets).
local TICK = 0.1                  -- how often Source updates (seconds)
local PASSIVE_REGEN = 1           -- Source per SECOND from passive regen
local PASSIVE_CAP = 0.20          -- passive regen stops at this fraction of MaxSource
-- SLOT_REGEN / SLOT_LEVEL_DIVISOR now live in ShieldBalance (shared with the Shielding drain, so the 5-level rule can't break)
local BURN_REGEN_ABOVE = 0.5     -- regenerating above this fraction of MaxSource fills Burn
local DRAIN_ABOVE_CAP = 1  -- Source lost per SECOND while above the passive cap line

local SLOT_COUNT = ShieldBalance.MAX_SLOTS

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
					local lastTickAt = os.clock()
					while regenId == myId and hum.Parent and hum:FindFirstChild("Source") and hum:FindFirstChild("MaxSource") do
						-- real elapsed time. Measured BEFORE the GlobalCD check so a pause never "catches up" afterwards.
						local now = os.clock()
						local dt = now - lastTickAt
						lastTickAt = now

						local max = maxSource.Value
						local current = source.Value
						if current > max then
							current = max
							source.Value = max
						end

						-- GlobalCD still pauses everything, as before
						-- A STILLED weaver has no Power: Source is held at 0 and nothing regenerates.
						-- (The Source / MaxSource values are NOT destroyed, so the Source bar stays bound to them.)
						if player:GetAttribute("Stilled") == true then
							if source.Value ~= 0 then source.Value = 0 end
						elseif not char:GetAttribute("GlobalCD") then
							-- while shielded: no passive trickle and no drain from here (the Shielding script already drains its target),
							-- but elements the player has channeled into their slots keep regenerating Source
							local shielded = char:GetAttribute("Shielded") or char:GetAttribute("ShieldApplication")
							local floor = PASSIVE_CAP * max

							-- LINKS: the leader regenerates faster and the passive cap / natural drain are gone
							local isLinkLeader = char:GetAttribute("LinkLeader") == true
							local linkRegen = isLinkLeader and LinkData.RegenMultiplier(char:GetAttribute("Link") or 0) or 1
							local passiveCeiling = isLinkLeader and max or floor

							-- 1. gain: passive (only up to the floor, not while shielded) + slots (always, not capped by the floor)
							local passive = shielded and 0 or math.clamp(passiveCeiling - current, 0, PASSIVE_REGEN * linkRegen * dt)
							local filledSlots = countFilledSlots(char)
							local slotRegen = ShieldBalance.slotRegenPerSecond(filledSlots, level.Value)
							local gain = passive + slotRegen * linkRegen * dt

							-- 2. drain: only the part above the floor, never down through it, and not while shielded
							local drain = (not shielded and not isLinkLeader and current > floor) and DRAIN_ABOVE_CAP * dt or 0

							local newValue = math.clamp(current + gain - drain, 0, max)
							if drain > 0 then
								newValue = math.max(newValue, floor)
							end

							if newValue ~= current then
								source.Value = newValue
							end

							-- 3. BURN: counts the regeneration above the burn line (the gain, not the net).
							-- While elements are still in the slots, regeneration keeps counting even when Source is already FULL
							-- (the part that would overflow the bar still fills Burn). With empty slots, only Source that really fits counts.
							local burn = hum:FindFirstChild("Burn")
							local perRegen = burn and burn:GetAttribute("PerRegen")
							if perRegen and gain > 0 and char:GetAttribute("Linked") ~= true then
								local reached = filledSlots > 0 and (current + gain) or math.min(current + gain, max)
								local aboveLine = reached - math.max(current, BURN_REGEN_ABOVE * max)
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

		-- When Stilled wears off, Source comes back full
		player:GetAttributeChangedSignal("Stilled"):Connect(function()
			if not hum.Parent then return end -- an old life's listener
			if player:GetAttribute("Stilled") ~= true and source and source.Parent and maxSource and maxSource.Parent then
				source.Value = maxSource.Value
			end
		end)

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
