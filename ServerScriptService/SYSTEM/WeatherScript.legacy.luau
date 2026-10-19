-- ServerScriptService > SYSTEM > WeatherServiceStart   (Script)
-- Starts the weather when the server starts. All the logic (and the functions your spells call) is in WeatherService.

local ServerScriptService = game:GetService("ServerScriptService")

local WeatherService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("WeatherService"))
WeatherService.Start()
