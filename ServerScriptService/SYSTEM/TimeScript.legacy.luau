-- ServerScriptService > SYSTEM > TimeServiceStart   (Script)
-- Starts the day / night cycle when the server starts. All the logic (and the functions your spells call) is in TimeService.

local ServerScriptService = game:GetService("ServerScriptService")

local TimeService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("TimeService"))
TimeService.Start()
