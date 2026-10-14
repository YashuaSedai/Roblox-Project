-- SERVICES
local RS = game:GetService("ReplicatedStorage")

-- DEBOUNCE MODULE
local DebounceHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))

-- DEBOUNCE REMOTE
local ToggleDebounce = RS:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Debounces"):WaitForChild("ToggleDebounce")

local ALLOWED = { WeavingDB = true }

ToggleDebounce.OnServerEvent:Connect(function(player: Player, obj: Instance, attribute, duration)
	if obj ~= player.Character then return end
	if typeof(attribute) ~= "string" or not ALLOWED[attribute] then return end
	if typeof(duration) ~= "number" or duration ~= duration then return end
	DebounceHandler.DebounceWait(player, obj, attribute, math.clamp(duration, 0, 5))
end)