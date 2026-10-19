-- ServerScriptService > SYSTEM > AttributesHandler > BurnoutSetup   (Script, NEW)
--
-- BURNING OUT. The server owns all of it; the UI only displays it.
--   * Burn           (NumberValue on the Humanoid)   the meter. It fills when the weaver spends Source.
--   * BurnThreshold  (NumberValue on the Humanoid)   the meter's maximum. Reaching it = burning out.
--   * BurningOut     (attribute on the character)    true while the penalty is active (for warning effects).
--
-- Burn also fills when Source REGENERATES above 50% of MaxSource (SourceSetup does that, using the "PerRegen"
-- attribute below).
--
-- The filling from casting is done by WeavingModule.DeductSource (it adds  Source spent x the "PerSource" attribute  to Burn),
-- so every weave fills the meter, including channeled weaves that pay every 0.1s, with no change to the weaves.
-- Only Weavers get a meter (the same rule as Source).

-- SERVICES
local Players = game:GetService("Players")

-- TUNING (placeholder numbers: change freely)
local BASE_THRESHOLD = 100            -- threshold at level 0
local THRESHOLD_PER_LEVEL = 4         -- same growth as MaxSource (100 + level * 4)
local BURN_PER_SOURCE = 0.2           -- Burn gained for every 1 Source spent
local BURN_PER_REGEN = 0.2            -- Burn gained for every 1 Source regenerated ABOVE 50% of MaxSource (read by SourceSetup)
local DECAY_DELAY = 2                 -- seconds without casting before the meter starts to fall
local DECAY_PER_SECOND = 5            -- Burn lost per second while resting
local RECOVER_AT = 0.90               -- burning out stops once Burn falls below this fraction of the threshold
local DAMAGE_PERCENT_PER_SECOND = 6	   -- % of max health lost per second while burning out (was 5; Roblox's own regen heals ~1%/s)
local CAN_KILL = true                -- false: burnout never takes you below 1 HP. true: it can kill.

local TICK = 0.1                      -- how often the meter updates
local DAMAGE_TICK = 0.1               -- how often burnout damage is applied

-- the penalty: health goes down, and nobody gets credit for it (no attacker). It still goes through DamageService like every
-- other source, with BypassForceField so a ForceField doesn't block it.
local DamageService = require(game:GetService("ServerScriptService"):WaitForChild("SYSTEM"):WaitForChild("DamageService"))

local function applyBurnDamage(hum: Humanoid, amount: number)
	if not CAN_KILL then
		amount = math.min(amount, math.max(hum.Health - 1, 0)) -- stop at 1 HP
	end
	DamageService.Damage(hum, amount, nil, { Source = "Burnout", BypassForceField = true })
end

-- creates the meter for one character and returns a function that removes it again
local function startMeter(char: Model, hum: Humanoid, level: NumberValue)
	local burn = Instance.new("NumberValue")
	burn.Name = "Burn"
	burn.Value = 0
	burn:SetAttribute("PerSource", BURN_PER_SOURCE) -- read by WeavingModule.DeductSource
	burn:SetAttribute("PerRegen", BURN_PER_REGEN)   -- read by SourceSetup (regenerating above 50% fills Burn)
	burn.Parent = hum

	local threshold = Instance.new("NumberValue")
	threshold.Name = "BurnThreshold"
	threshold.Value = BASE_THRESHOLD + level.Value * THRESHOLD_PER_LEVEL
	threshold.Parent = hum

	char:SetAttribute("BurningOut", false)

	local owner = Players:GetPlayerFromCharacter(char)
	local running = true
	local burning = false
	local lastGain = 0   -- os.clock() of the last time the meter went UP (= the last cast)
	local lastValue = 0

	local connections = {}
	table.insert(connections, level.Changed:Connect(function()
		threshold.Value = BASE_THRESHOLD + level.Value * THRESHOLD_PER_LEVEL
	end))
	table.insert(connections, burn.Changed:Connect(function(value)
		if value > lastValue then
			lastGain = os.clock() -- casting restarts the rest timer
		end
		lastValue = value
	end))

	task.spawn(function()
		local damageTimer = 0

		while running and hum.Parent and hum.Health > 0 do
			task.wait(TICK)

			-- a STILLED weaver doesn't burn: the meter is held empty. (The Burn value stays, so the Burn bar stays bound.)
			if owner and owner:GetAttribute("Stilled") == true then
				burn.Value = 0
				lastValue = 0
				if burning then
					burning = false
					damageTimer = 0
					char:SetAttribute("BurningOut", false)
				end
				continue
			end

			-- the meter never goes past full
			if burn.Value > threshold.Value then
				burn.Value = threshold.Value
			end

			-- resting: the meter falls
			if os.clock() - lastGain >= DECAY_DELAY and burn.Value > 0 then
				burn.Value = math.max(0, burn.Value - DECAY_PER_SECOND * TICK)
			end

			-- burning out starts at full and stops once it has fallen back to RECOVER_AT (so it doesn't flicker on and off)
			if not burning and threshold.Value > 0 and burn.Value >= threshold.Value then
				burning = true
				char:SetAttribute("BurningOut", true)
			elseif burning and burn.Value < threshold.Value * RECOVER_AT then
				burning = false
				damageTimer = 0
				char:SetAttribute("BurningOut", false)
			end

			-- the penalty
			if burning then
				damageTimer += TICK
				if damageTimer >= DAMAGE_TICK then
					damageTimer = 0
					applyBurnDamage(hum, hum.MaxHealth * (DAMAGE_PERCENT_PER_SECOND / 100) * DAMAGE_TICK)
				end
			end
		end
	end)

	return function()
		running = false
		for _, connection in connections do
			connection:Disconnect()
		end
		burn:Destroy()
		threshold:Destroy()
		if char.Parent then
			char:SetAttribute("BurningOut", nil)
		end
	end
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid")
	local level = player:WaitForChild("leaderstats"):WaitForChild("Level")

	local stopMeter = nil

	-- only Weavers get a meter; a role change (Weaver <-> Warder) adds or removes it
	local function refresh()
		local isWeaver = player:GetAttribute("Role") == "Weaver"
		if isWeaver and not stopMeter then
			stopMeter = startMeter(char, hum, level)
		elseif not isWeaver and stopMeter then
			stopMeter()
			stopMeter = nil
		end
	end

	local roleConnection = player:GetAttributeChangedSignal("Role"):Connect(refresh)
	player.CharacterRemoving:Once(function() -- respawn or leaving: clean up so nothing piles up across lives
		roleConnection:Disconnect()
		if stopMeter then
			stopMeter()
			stopMeter = nil
		end
	end)

	refresh()
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	onPlayer(player)
end
