-- StarterPlayer > StarterPlayerScripts > AtmosphereController   (LocalScript)
--
-- Reads LightingConfig and paints the world: TIME OF DAY first, then the LOCATION the player stands in, then the WEATHER.
-- Runs on every client on its own, because the location is different for every player. Nothing here touches the server.
--
--   time of day  <- Lighting.ClockTime   (TimeService on the server moves it)
--   weather      <- Lighting attribute "Weather"   (WeatherService on the server sets it)
--   location     <- the tagged zone Parts the player is standing inside (checked here)
--
-- When the location or weather changes, the old look FADES OUT while the new one FADES IN (Transition seconds),
-- and switching again half way through is fine.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("LightingConfig"))
local Settings = Config.Settings
local LocalPlayer = Players.LocalPlayer

-- which instance each name in the config means (the effects are created if they don't exist)
local EFFECT_CLASSES = {
	Atmosphere = "Atmosphere",
	ColorCorrection = "ColorCorrectionEffect",
	Bloom = "BloomEffect",
	SunRays = "SunRaysEffect",
}

local function debugPrint(...)
	if Settings.Debug then print("[Atmosphere]", ...) end
end

-- INSTANCES -------------------------------------------------------------------------------------------
local instances = {}
local function getInstance(key: string): Instance?
	if instances[key] then return instances[key] end
	local instance
	if key == "Lighting" then
		instance = Lighting
	elseif EFFECT_CLASSES[key] then
		instance = Lighting:FindFirstChildOfClass(EFFECT_CLASSES[key])
		if not instance then
			instance = Instance.new(EFFECT_CLASSES[key])
			instance.Name = "Dynamic" .. key
			instance.Parent = Lighting
		end
	else
		warn(`[Atmosphere] LightingConfig mentions "{key}", which is not one of: Lighting, Atmosphere, ColorCorrection, Bloom, SunRays`)
		return nil
	end
	instances[key] = instance
	return instance
end

-- VALUE MATH (numbers and Color3s) --------------------------------------------------------------------
local function lerpValue(a, b, t: number)
	if typeof(a) == "number" then return a + (b - a) * t end
	if typeof(a) == "Color3" then return a:Lerp(b, t) end
	return b
end

local function scaleValue(value, factor: number)
	if typeof(value) == "number" then return value * factor end
	if typeof(value) == "Color3" then
		return Color3.new(math.clamp(value.R * factor, 0, 1), math.clamp(value.G * factor, 0, 1), math.clamp(value.B * factor, 0, 1))
	end
	return value
end

local function differs(a, b): boolean
	if typeof(a) == "number" then return math.abs(a - b) > 1e-4 end
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) > 0.002
end

-- THE PROPERTIES THE CONFIG MENTIONS -------------------------------------------------------------------
-- Each one is remembered with the value you authored in Studio (used as the base when the time of day doesn't set it).
local props = {}      -- list, in the order they were found
local propById = {}   -- ["Atmosphere.Density"] = prop

local function registerProp(key: string, name: string)
	local id = key .. "." .. name
	if propById[id] then return propById[id] end

	local instance = getInstance(key)
	if not instance then return nil end
	local ok, default = pcall(function() return instance[name] end)
	if not ok or (typeof(default) ~= "number" and typeof(default) ~= "Color3") then
		warn(`[Atmosphere] {id} is not a number / Color3 property that exists: skipped`)
		return nil
	end

	local prop = { id = id, instance = instance, name = name, default = default, keyframes = nil, last = nil }
	propById[id] = prop
	table.insert(props, prop)
	return prop
end

-- 1. TIME OF DAY: per property, a sorted list of { hour, value }
for _, keyframe in Config.TimeOfDay do
	for key, section in keyframe.Values do
		for name, value in section do
			local prop = registerProp(key, name)
			if prop then
				if typeof(value) ~= typeof(prop.default) then
					warn(`[Atmosphere] TimeOfDay hour {keyframe.Hour}: {prop.id} has the wrong kind of value: skipped`)
				else
					prop.keyframes = prop.keyframes or {}
					table.insert(prop.keyframes, { hour = keyframe.Hour, value = value })
				end
			end
		end
	end
end
for _, prop in props do
	if prop.keyframes then
		table.sort(prop.keyframes, function(a, b) return a.hour < b.hour end)
	end
end

local function evaluateTime(prop, hour: number)
	local frames = prop.keyframes
	if not frames then return prop.default end
	local count = #frames
	if count == 1 then return frames[1].value end

	local index = 0 -- the last keyframe at or before this hour
	for i = 1, count do
		if frames[i].hour <= hour then index = i else break end
	end

	local a, aHour, b, bHour
	if index == 0 then -- before the first keyframe: blending from the last one of the previous day
		a, aHour = frames[count], frames[count].hour - 24
		b, bHour = frames[1], frames[1].hour
	elseif index == count then -- after the last keyframe: blending toward the first one of the next day
		a, aHour = frames[count], frames[count].hour
		b, bHour = frames[1], frames[1].hour + 24
	else
		a, aHour = frames[index], frames[index].hour
		b, bHour = frames[index + 1], frames[index + 1].hour
	end
	local span = bHour - aHour
	local alpha = span > 0 and (hour - aHour) / span or 0
	return lerpValue(a.value, b.value, alpha)
end

-- 2 + 3. LOCATIONS AND WEATHER: each entry is compiled into { strength, transition, entries = { [propId] = { set, scale } } }
local function compileOverlay(definition, label: string)
	local overlay = {
		strength = math.clamp(definition.Strength or 1, 0, 1),
		transition = definition.Transition or Settings.TransitionTime,
		entries = {},
	}
	for _, mode in { "Set", "Scale" } do
		for key, section in definition[mode] or {} do
			for name, value in section do
				local prop = registerProp(key, name)
				if prop then
					local valid = if mode == "Scale" then typeof(value) == "number" else typeof(value) == typeof(prop.default)
					if not valid then
						warn(`[Atmosphere] {label} {mode} {prop.id} has the wrong kind of value: skipped`)
					else
						local entry = overlay.entries[prop.id]
						if not entry then
							entry = {}
							overlay.entries[prop.id] = entry
						end
						entry[if mode == "Set" then "set" else "scale"] = value
					end
				end
			end
		end
	end
	return overlay
end

local function compileAll(definitions, defaultName: string, kind: string)
	local compiled = {}
	for name, definition in definitions do
		compiled[name] = compileOverlay(definition, `{kind} "{name}"`)
	end
	if not compiled[defaultName] then
		compiled[defaultName] = compileOverlay({}, defaultName)
	end
	return compiled
end

local locationOverlays = compileAll(Config.Locations, "Default", "Location")
local weatherOverlays = compileAll(Config.Weather, "Clear", "Weather")

-- one overlay applied to one value
local function overlayApply(value, overlay, id: string)
	local entry = overlay.entries[id]
	if not entry then return value end
	if entry.set ~= nil then
		value = lerpValue(value, entry.set, overlay.strength)
	end
	if entry.scale ~= nil then
		value = scaleValue(value, 1 + (entry.scale - 1) * overlay.strength)
	end
	return value
end

-- A LAYER (location or weather) keeps a weight for every entry that is fading in or out. The target fades toward 1,
-- everything else toward 0. The picture is the weighted average, so switching again half way never jumps.
local function newLayer(overlays, defaultName: string)
	return { overlays = overlays, defaultName = defaultName, target = defaultName, weights = { [defaultName] = 1 } }
end

local locationLayer = newLayer(locationOverlays, "Default")
local weatherLayer = newLayer(weatherOverlays, "Clear")

local warnedUnknown = {}
local function setTarget(layer, name: string, kind: string)
	if not layer.overlays[name] then
		if not warnedUnknown[kind .. name] then
			warnedUnknown[kind .. name] = true
			warn(`[Atmosphere] {kind} "{name}" is not in LightingConfig: using "{layer.defaultName}" instead`)
		end
		name = layer.defaultName
	end
	if layer.target == name then return end
	layer.target = name
	layer.weights[name] = layer.weights[name] or 0
	debugPrint(kind, "->", name)
end

local function snapLayer(layer) -- no fade: used for what the player joins into
	layer.weights = { [layer.target] = 1 }
end

local function stepLayer(layer, dt: number)
	local duration = math.max(layer.overlays[layer.target].transition, 0.01)
	local step = dt / duration
	for name, weight in layer.weights do
		if name == layer.target then
			layer.weights[name] = math.min(1, weight + step)
		else
			local remaining = weight - step
			layer.weights[name] = if remaining > 0 then remaining else nil
		end
	end
end

local function layerValue(layer, base, id: string)
	local result, total = nil, 0
	for name, weight in layer.weights do
		local value = overlayApply(base, layer.overlays[name], id)
		if result == nil then
			result, total = value, weight
		else
			total += weight
			result = lerpValue(result, value, weight / total) -- keeps a running weighted average
		end
	end
	return result or base
end

-- WHERE THE PLAYER IS -----------------------------------------------------------------------------------
local zoneParts = {}
local function addZone(part: Instance)
	if part:IsA("BasePart") then zoneParts[part] = true end
end
CollectionService:GetInstanceAddedSignal(Settings.ZoneTag):Connect(addZone)
CollectionService:GetInstanceRemovedSignal(Settings.ZoneTag):Connect(function(part) zoneParts[part] = nil end)
for _, part in CollectionService:GetTagged(Settings.ZoneTag) do addZone(part) end

-- the name of the zone the local character is inside ("Default" if none), or nil if there is no character yet
local function findLocation(): string?
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local position = root.Position
	local best, bestPriority, bestVolume = nil, -math.huge, math.huge
	for part in zoneParts do
		if part.Parent then
			local relative = part.CFrame:PointToObjectSpace(position)
			local half = part.Size / 2
			if math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z then
				local priority = part:GetAttribute("Priority") or 0
				local volume = part.Size.X * part.Size.Y * part.Size.Z
				if priority > bestPriority or (priority == bestPriority and volume < bestVolume) then
					best, bestPriority, bestVolume = part, priority, volume
				end
			end
		end
	end
	if not best then return "Default" end
	return best:GetAttribute("Zone") or best.Name
end

task.spawn(function()
	local first = true
	while true do
		local name = findLocation()
		if name then
			setTarget(locationLayer, name, "Location")
			if first then
				first = false
				snapLayer(locationLayer) -- joining inside a cave: no fade from daylight
			end
		end
		task.wait(Settings.ZoneCheckInterval)
	end
end)

-- THE WEATHER (set by the server) ---------------------------------------------------------------------------
local function onWeatherChanged()
	setTarget(weatherLayer, Lighting:GetAttribute("Weather") or "Clear", "Weather")
end
Lighting:GetAttributeChangedSignal("Weather"):Connect(onWeatherChanged)
onWeatherChanged()
snapLayer(weatherLayer) -- joining in a storm: no fade from clear weather

-- EVERY FRAME: base from the time of day, then the location, then the weather, then write it --------------------
RunService.Heartbeat:Connect(function(dt)
	stepLayer(locationLayer, dt)
	stepLayer(weatherLayer, dt)

	local hour = Lighting.ClockTime
	for _, prop in props do
		local value = evaluateTime(prop, hour)
		value = layerValue(locationLayer, value, prop.id)
		value = layerValue(weatherLayer, value, prop.id)

		if prop.last == nil or differs(value, prop.last) then
			prop.last = value
			prop.instance[prop.name] = value
		end
	end
end)
