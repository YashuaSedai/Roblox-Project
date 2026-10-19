-- ReplicatedStorage > SYSTEM > ModuleScripts > LightingConfig   (ModuleScript)
--
-- THE DICTIONARY. Everything about how the world LOOKS lives in this one file. The scripts only read it.
--
-- HOW IT WORKS (read this once, then you only ever edit the tables below)
--
--   Think of three layers, painted one on top of the other:
--
--     1. TIME OF DAY   the base picture. A list of "keyframes": at hour 12 the world looks like this, at hour 19 like that.
--                      Between two keyframes everything is blended smoothly, so the sunset fades by itself.
--     2. LOCATION      paint over the base, depending on WHERE THE PLAYER STANDS (a cave, a desert, a swamp...).
--     3. WEATHER       paint over that, for the whole server (rain, storm, fog...).
--
--   A location or weather entry doesn't need to list everything. It only lists what it CHANGES, in two ways:
--
--     Set    = "make this property THIS value".   Cave: Brightness = 0.2.  (a cave is dark at noon too)
--     Scale  = "multiply what is there by this".  Rain: Brightness x 0.55. (rain darkens the day AND the night by the same amount)
--
--   Strength (0 to 1) is how much of the change you get. 1 = all of it, 0.5 = halfway. Leave it out for 1.
--   Transition is how many seconds it takes to fade in when it becomes active. Leave it out to use the default.
--
--   WHAT YOU CAN CHANGE: any number or Color3 property of these. They are the names you write inside Set / Scale / Values:
--     Lighting         Brightness, Ambient, OutdoorAmbient, ColorShift_Top, ExposureCompensation ...
--     Atmosphere       Density, Offset, Color, Decay, Glare, Haze
--     ColorCorrection  Brightness, Contrast, Saturation, TintColor
--     Bloom            Intensity, Size, Threshold
--     SunRays          Intensity, Spread
--   (a property you never mention is left exactly as you authored it in Studio. The effects are created if missing.)
--
-- ADDING SOMETHING NEW: copy one of the blocks below, rename it, change the numbers. That's all.
--   * a new WEATHER: add a block to Weather, then call WeatherService.SetWeather("YourName") from a spell.
--   * a new LOCATION: add a block to Locations, then make a Part named exactly the same (see SETUP in the Locations section).

local LightingConfig = {}

-- SETTINGS --------------------------------------------------------------------------------------------
LightingConfig.Settings = {
	ZoneTag = "LightingZone",   -- the CollectionService tag that marks a Part as a location zone
	ZoneCheckInterval = 0.2,    -- how often (seconds) the client checks which zone the player is standing in
	TransitionTime = 3,         -- default seconds for a location / weather to fade in (an entry can set its own Transition)
	Debug = false,              -- true = prints every zone / weather change in the Output window
}

LightingConfig.WeatherSettings = {
	StartWeather = "Clear",     -- the weather when the server starts
	AutoChange = true,          -- true = the weather changes by itself over time (using each weather's Chance and Duration)
}

-- 1. TIME OF DAY ---------------------------------------------------------------------------------------
-- Hour is 0..24 (the same clock as TimeService). The list wraps around: after the last keyframe it blends
-- back into the first one, so keep the first and last ones close (here both are "night").
-- Every keyframe can have different properties. A property is blended between the keyframes that mention it.
LightingConfig.TimeOfDay = {
	{ Hour = 0, Values = { -- NIGHT
		Lighting = { Brightness = 0.5, Ambient = Color3.fromRGB(20, 25, 45), OutdoorAmbient = Color3.fromRGB(25, 30, 55) },
		Atmosphere = { Density = 0.35, Offset = 0.25, Color = Color3.fromRGB(40, 50, 90), Decay = Color3.fromRGB(10, 10, 30), Glare = 0, Haze = 1.2 },
		ColorCorrection = { TintColor = Color3.fromRGB(190, 205, 255), Saturation = -0.1, Contrast = 0.05 },
	} },
	{ Hour = 5, Values = { -- STILL NIGHT, just before the sun comes up
		Lighting = { Brightness = 0.6, Ambient = Color3.fromRGB(25, 28, 50), OutdoorAmbient = Color3.fromRGB(35, 38, 65) },
		Atmosphere = { Density = 0.36, Offset = 0.25, Color = Color3.fromRGB(60, 65, 110), Decay = Color3.fromRGB(40, 30, 60), Glare = 0.1, Haze = 1.3 },
		ColorCorrection = { TintColor = Color3.fromRGB(200, 205, 255), Saturation = -0.05, Contrast = 0.05 },
	} },
	{ Hour = 6.5, Values = { -- SUNRISE
		Lighting = { Brightness = 2, Ambient = Color3.fromRGB(90, 85, 90), OutdoorAmbient = Color3.fromRGB(150, 130, 120) },
		Atmosphere = { Density = 0.4, Offset = 0.1, Color = Color3.fromRGB(230, 190, 160), Decay = Color3.fromRGB(250, 190, 120), Glare = 0.8, Haze = 1.2 },
		ColorCorrection = { TintColor = Color3.fromRGB(255, 235, 215), Saturation = 0.1, Contrast = 0.05 },
	} },
	{ Hour = 12, Values = { -- NOON
		Lighting = { Brightness = 3, Ambient = Color3.fromRGB(100, 100, 110), OutdoorAmbient = Color3.fromRGB(140, 140, 150) },
		Atmosphere = { Density = 0.3, Offset = 0, Color = Color3.fromRGB(190, 205, 230), Decay = Color3.fromRGB(106, 112, 125), Glare = 0.2, Haze = 0.4 },
		ColorCorrection = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.05, Contrast = 0.05 },
	} },
	{ Hour = 17.5, Values = { -- SUNSET
		Lighting = { Brightness = 2, Ambient = Color3.fromRGB(100, 80, 80), OutdoorAmbient = Color3.fromRGB(160, 120, 100) },
		Atmosphere = { Density = 0.38, Offset = 0.1, Color = Color3.fromRGB(240, 170, 130), Decay = Color3.fromRGB(255, 150, 90), Glare = 1, Haze = 1.6 },
		ColorCorrection = { TintColor = Color3.fromRGB(255, 215, 185), Saturation = 0.15, Contrast = 0.05 },
	} },
	{ Hour = 19, Values = { -- DUSK
		Lighting = { Brightness = 1, Ambient = Color3.fromRGB(60, 55, 80), OutdoorAmbient = Color3.fromRGB(80, 70, 100) },
		Atmosphere = { Density = 0.4, Offset = 0.2, Color = Color3.fromRGB(110, 90, 130), Decay = Color3.fromRGB(90, 60, 110), Glare = 0.2, Haze = 1.4 },
		ColorCorrection = { TintColor = Color3.fromRGB(225, 215, 255), Saturation = 0, Contrast = 0.05 },
	} },
	{ Hour = 21, Values = { -- NIGHT again (same as hour 0, so the night stays steady until 5)
		Lighting = { Brightness = 0.5, Ambient = Color3.fromRGB(20, 25, 45), OutdoorAmbient = Color3.fromRGB(25, 30, 55) },
		Atmosphere = { Density = 0.35, Offset = 0.25, Color = Color3.fromRGB(40, 50, 90), Decay = Color3.fromRGB(10, 10, 30), Glare = 0, Haze = 1.2 },
		ColorCorrection = { TintColor = Color3.fromRGB(190, 205, 255), Saturation = -0.1, Contrast = 0.05 },
	} },
}

-- 2. LOCATIONS ----------------------------------------------------------------------------------------
-- SETUP (once per area on the map):
--   1. Make a Part that covers the area. Shape = Block (it is checked as a box). Anchored, CanCollide off, Transparency 1.
--   2. Name it EXACTLY like an entry below ("Cave", "Desert"...). Or leave the name alone and give it a string attribute "Zone".
--   3. Give it the tag "LightingZone" (Properties > Tags, or the Command Bar line in the notes).
--   4. Overlapping zones: the one with the higher number attribute "Priority" wins; if equal, the smaller one wins.
-- Standing in no zone = "Default" (the time of day alone).
LightingConfig.Locations = {
	Default = {}, -- no changes

	Cave = {
		Transition = 2,
		Set = {
			Lighting = { Brightness = 0.2, Ambient = Color3.fromRGB(15, 15, 20), OutdoorAmbient = Color3.fromRGB(10, 10, 15) },
			Atmosphere = { Density = 0.55, Haze = 2.5, Glare = 0, Color = Color3.fromRGB(20, 20, 28) },
			ColorCorrection = { Saturation = -0.2 },
		},
	},

	Indoors = {
		Transition = 1,
		Set = {
			Lighting = { Brightness = 1, Ambient = Color3.fromRGB(110, 100, 90), OutdoorAmbient = Color3.fromRGB(110, 100, 90) },
			Atmosphere = { Density = 0.1, Haze = 0, Glare = 0 },
		},
	},

	Desert = {
		Strength = 0.6,
		Set = {
			Atmosphere = { Haze = 2, Density = 0.4 },
			ColorCorrection = { TintColor = Color3.fromRGB(255, 232, 195), Saturation = 0.15 },
		},
	},

	Snowfield = {
		Strength = 0.6,
		Set = {
			Atmosphere = { Density = 0.45, Haze = 1.5 },
			ColorCorrection = { TintColor = Color3.fromRGB(232, 244, 255), Saturation = -0.1 },
		},
	},

	Swamp = {
		Strength = 0.7,
		Set = {
			Atmosphere = { Density = 0.6, Haze = 2.2 },
			ColorCorrection = { TintColor = Color3.fromRGB(215, 235, 205), Saturation = -0.05 },
		},
		Scale = {
			Lighting = { Brightness = 0.8 },
		},
	},
}

-- 3. WEATHER ------------------------------------------------------------------------------------------
-- Chance   = how likely it is picked when the weather changes by itself (bigger = more often). 0 = never by itself.
-- Duration = { shortest, longest } seconds it lasts before the next one is picked.
-- Weather applies to the WHOLE server. A spell can force one:  WeatherService.SetWeather("Storm", 30)
-- Weather uses Scale for brightness and colors so it darkens a night by the same amount as a day.
LightingConfig.Weather = {
	Clear = { Chance = 50, Duration = { 300, 600 } },

	Cloudy = {
		Chance = 25, Duration = { 180, 420 },
		Strength = 0.7,
		Scale = {
			Lighting = { Brightness = 0.7, Ambient = 0.9, OutdoorAmbient = 0.9 },
		},
		Set = {
			Atmosphere = { Density = 0.45, Haze = 2, Glare = 0 },
			ColorCorrection = { Saturation = -0.1 },
		},
	},

	Rain = {
		Chance = 15, Duration = { 120, 300 },
		Strength = 0.85,
		Scale = {
			Lighting = { Brightness = 0.55, Ambient = 0.8, OutdoorAmbient = 0.8 },
			Atmosphere = { Color = 0.7 },
		},
		Set = {
			Atmosphere = { Density = 0.55, Haze = 3, Glare = 0 },
			ColorCorrection = { Saturation = -0.2, TintColor = Color3.fromRGB(200, 210, 225) },
		},
	},

	Storm = {
		Chance = 5, Duration = { 60, 180 },
		Strength = 1,
		Scale = {
			Lighting = { Brightness = 0.35, Ambient = 0.6, OutdoorAmbient = 0.6 },
			Atmosphere = { Color = 0.5 },
		},
		Set = {
			Atmosphere = { Density = 0.65, Haze = 4, Glare = 0 },
			ColorCorrection = { Saturation = -0.3, Contrast = 0.1, TintColor = Color3.fromRGB(170, 180, 200) },
		},
	},

	Fog = {
		Chance = 5, Duration = { 120, 300 },
		Strength = 0.9,
		Scale = {
			Lighting = { Brightness = 0.8 },
		},
		Set = {
			Atmosphere = { Density = 0.8, Haze = 4, Glare = 0 },
			ColorCorrection = { Saturation = -0.1 },
		},
	},
}

return LightingConfig
