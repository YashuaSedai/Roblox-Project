-- SERVICES
local RS = game:GetService("ReplicatedStorage")

-- DEBOUNCE MODULE
local DebounceHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))

-- DEBOUNCE REMOTE
local ToggleDebounce = RS:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Debounces"):WaitForChild("ToggleDebounce")

ToggleDebounce.OnServerEvent:Connect(function(player: Player, obj:Instance, attribute, duration: number)
	
	DebounceHandler.DebounceWait(player, obj, attribute, duration)
	
end)