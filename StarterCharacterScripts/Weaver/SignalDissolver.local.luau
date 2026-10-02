-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- REMOTES
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

WeavingEvent.OnClientEvent:Connect(function()
	
end)

WeavingFxEvent.OnClientEvent:Connect(function()
	
end)

WeavingFxClear.OnClientEvent:Connect(function()
	
end)

WeavingInstantEvent.OnClientEvent:Connect(function()
	
end)

WeavingInstantReleaseEvent.OnClientEvent:Connect(function()
	
end)

AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, userId)
	
end)

