-- ServerScriptService > SYSTEM > WeatherLightning   (Script)
--
-- Makes lightning strike by itself while the weather is a stormy one (see STRIKE_WEATHERS below).
-- It reads the Lighting attribute "Weather" (the same one AtmosphereController paints from), so it strikes whenever the
-- sky LOOKS stormy: natural weather, a spell's WeatherService.SetWeather("Storm", 30), or even the attribute set by hand.
-- The first strike comes MinDelay..MaxDelay seconds after the storm starts, and it needs at least one living player.
--
-- The visuals are played by WeatherLightningEffect (a LocalScript in ReplicatedFirst), using the same
-- LightningStrike VFX as the weave. This script decides WHERE it strikes and who gets hurt.

-- SERVICES
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- MODULES
local DamageService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("DamageService"))
local RagdollService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("RagdollService"))

-- SETTINGS ------------------------------------------------------------------------------------------
-- Which weathers have lightning, and how. Add Rain = { ... } if you want rare strikes in the rain too.
local STRIKE_WEATHERS = {
	Storm = {
		MinDelay = 4,            -- shortest wait (seconds) between strikes
		MaxDelay = 12,           -- longest wait between strikes
		Damage = 30,             -- damage to anything inside the strike area (set 0 for visuals only)
		Area = 15,               -- radius of the damage, same as the Lightning Strike weave
		RagdollDuration = 1.5,   -- seconds ragdolled when hit (nil = no ragdoll)
		DoubleStrikeChance = 0.2, -- chance of a second strike right after the first
	},
}

local NEAR_PLAYER_CHANCE = 0.7  -- chance a strike lands near a player (so people actually see it) instead of anywhere
local NEAR_MIN, NEAR_MAX = 25, 90   -- how far from the player a "near" strike lands (min is above Area, so it's a near miss)
local WIDE_RADIUS = 250         -- how far from a player a "random" strike can land
local DIRECT_HIT_CHANCE = 0.05  -- chance a strike lands right on a player. Set to 0 if you never want that.
local DAMAGE_DELAY = 0.25       -- wind-up before damage, same as the weave
local DEBUG = true              -- prints to the Output window when a storm starts and each time a strike lands (turn off when it works)
-------------------------------------------------------------------------------------------------------

-- the remote the clients listen to (created here so nothing has to be added by hand in Studio)
local remote = ReplicatedStorage:FindFirstChild("WeatherLightningEvent")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "WeatherLightningEvent"
	remote.Parent = ReplicatedStorage
end

local running = false

local function getWeather(): string
	return Lighting:GetAttribute("Weather") or "Clear"
end

local function log(...)
	if DEBUG then print("[WeatherLightning]", ...) end
end

local function getCharacters()
	local list = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			table.insert(list, { char = char, root = root })
		end
	end
	return list
end

local function pickStrikePoint(candidates)
	local target = candidates[math.random(1, #candidates)]
	local center = target.root.Position
	local x, z

	local roll = math.random()
	if roll < DIRECT_HIT_CHANCE then
		x, z = center.X, center.Z
	else
		local distance
		if roll < DIRECT_HIT_CHANCE + NEAR_PLAYER_CHANCE then
			distance = NEAR_MIN + math.random() * (NEAR_MAX - NEAR_MIN)
		else
			distance = NEAR_MIN + math.random() * (WIDE_RADIUS - NEAR_MIN)
		end
		local angle = math.random() * math.pi * 2
		x = center.X + math.cos(angle) * distance
		z = center.Z + math.sin(angle) * distance
	end

	-- find the ground (ignoring characters)
	local ignore = {}
	for _, c in candidates do
		table.insert(ignore, c.char)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(Vector3.new(x, center.Y + 150, z), Vector3.new(0, -400, 0), params)
	if not result then return nil end

	return result.Position + Vector3.new(0, 1, 0)
end

local function strike(config)
	local candidates = getCharacters()
	if #candidates == 0 then log("no living players, skipped a strike") return end

	local position = pickStrikePoint(candidates)
	if not position then log("no ground found under the strike point, skipped") return end
	log("strike at", position)

	-- clients only get the visuals
	remote:FireAllClients(position)

	-- the server picks who gets hit, after the wind-up
	if not config.Damage or config.Damage <= 0 then return end
	task.delay(DAMAGE_DELAY, function()
		for _, model in workspace:GetChildren() do
			local hum = model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
			local root = hum and model:FindFirstChild("HumanoidRootPart")
			if root and hum.Health > 0 and (root.Position - position).Magnitude <= config.Area then
				DamageService.Damage(hum, config.Damage, nil, { Source = "WeatherLightning" })
				if config.RagdollDuration then
					RagdollService.Ragdoll(model, config.RagdollDuration)
				end
			end
		end
	end)
end

local function loop()
	running = true
	log("storm started, strikes begin")
	while STRIKE_WEATHERS[getWeather()] do
		local config = STRIKE_WEATHERS[getWeather()]
		task.wait(config.MinDelay + math.random() * (config.MaxDelay - config.MinDelay))

		-- the weather may have changed while waiting
		config = STRIKE_WEATHERS[getWeather()]
		if not config then break end

		strike(config)

		if math.random() < (config.DoubleStrikeChance or 0) then
			task.wait(0.2 + math.random() * 0.5)
			if STRIKE_WEATHERS[getWeather()] then
				strike(config)
			end
		end
	end
	running = false
	log("storm over, strikes stopped")
end

local function evaluate()
	if not running and STRIKE_WEATHERS[getWeather()] then
		task.spawn(loop)
	end
end

Lighting:GetAttributeChangedSignal("Weather"):Connect(evaluate)
evaluate() -- in case it's already stormy when this script starts
