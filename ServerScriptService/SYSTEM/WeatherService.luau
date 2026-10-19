-- ServerScriptService > SYSTEM > WeatherService   (ModuleScript)
--
-- The server's weather. It only decides WHICH weather is active (and changes it over time); how a weather LOOKS is in
-- LightingConfig, painted by AtmosphereController on every client. The active weather is stored on Lighting as the
-- attribute "Weather", so any client script (rain particles, thunder sounds...) can listen to it:
--   Lighting:GetAttributeChangedSignal("Weather"):Connect(function() ... Lighting:GetAttribute("Weather") ... end)
--
-- FOR SPELLS
--   local WeatherService = require(game.ServerScriptService.SYSTEM.WeatherService)
--   WeatherService.GetWeather()                 -- "Clear" | "Rain" | ...
--   WeatherService.SetWeather("Storm", 30)      -- a Storm for 30 seconds, then the natural weather comes back
--   WeatherService.SetWeather("Fog")            -- until ClearOverride() or another SetWeather
--   WeatherService.ClearOverride()              -- back to the natural weather now
--   WeatherService.WeatherChanged:Connect(function(new, old) ... end)
--
-- Two layers, like the speed modifiers in TimeService: the NATURAL weather keeps changing underneath (if AutoChange is on),
-- and a spell's weather is an OVERRIDE shown on top of it. When the override ends you see wherever the natural weather is.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightingConfig = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("LightingConfig"))

local WeatherService = {}

local natural = LightingConfig.WeatherSettings.StartWeather or "Clear"
local override = nil      -- { name, token } while a spell's weather is active
local current = nil       -- what is shown right now
local started = false
local overrideToken = 0
local autoChange = LightingConfig.WeatherSettings.AutoChange

local weatherChanged = Instance.new("BindableEvent")
WeatherService.WeatherChanged = weatherChanged.Event -- (newWeather, oldWeather)

local function refresh()
	local name = override and override.name or natural
	if name == current then return end
	local old = current
	current = name
	Lighting:SetAttribute("Weather", name)
	weatherChanged:Fire(name, old)
end

function WeatherService.GetWeather(): string
	return current or natural
end

-- the weather underneath any override
function WeatherService.GetNaturalWeather(): string
	return natural
end

function WeatherService.IsOverridden(): boolean
	return override ~= nil
end

-- forces a weather. duration nil = until ClearOverride() / another SetWeather. Returns true if the name exists.
function WeatherService.SetWeather(name: string, duration: number?): boolean
	if not LightingConfig.Weather[name] then
		warn(`[WeatherService] "{name}" is not in LightingConfig.Weather`)
		return false
	end

	overrideToken += 1
	local token = overrideToken
	override = { name = name, token = token }
	refresh()

	if duration and duration > 0 then
		task.delay(duration, function()
			if override and override.token == token then -- only if nobody replaced it meanwhile
				override = nil
				refresh()
			end
		end)
	end
	return true
end

function WeatherService.ClearOverride()
	override = nil
	refresh()
end

-- changes the NATURAL weather (what comes back after an override)
function WeatherService.SetNaturalWeather(name: string): boolean
	if not LightingConfig.Weather[name] then
		warn(`[WeatherService] "{name}" is not in LightingConfig.Weather`)
		return false
	end
	natural = name
	refresh()
	return true
end

function WeatherService.SetAutoChange(enabled: boolean)
	autoChange = enabled
end

-- picks the next natural weather using each weather's Chance (and never the same one twice in a row)
local function pickNext(): string
	local total = 0
	for name, weather in LightingConfig.Weather do
		if name ~= natural then total += weather.Chance or 0 end
	end
	if total <= 0 then return natural end

	local roll = math.random() * total
	for name, weather in LightingConfig.Weather do
		if name ~= natural then
			roll -= weather.Chance or 0
			if roll <= 0 then return name end
		end
	end
	return natural
end

function WeatherService.Start()
	if started then return end
	started = true
	refresh()

	task.spawn(function()
		while true do
			local range = LightingConfig.Weather[natural].Duration or { 300, 600 }
			task.wait(math.random() * (range[2] - range[1]) + range[1])
			if autoChange then
				natural = pickNext()
				refresh()
			end
		end
	end)
end

return WeatherService
