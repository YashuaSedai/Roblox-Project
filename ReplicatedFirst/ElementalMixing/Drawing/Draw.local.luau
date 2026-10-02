-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
local RemoveEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Remove")

-- MODULES
local DrawHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))

-- BEZIER MODULE
local Bezier = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))

-- ASSETS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ElementalFolder = Assets:WaitForChild("Elements")
-- BEAMS
local Beams = ElementalFolder:WaitForChild("Beams")
-- PARTICLES
local Particles = ElementalFolder:WaitForChild("Particles")
-- TRAILS
local Trails = ElementalFolder:WaitForChild("Trails")

RemoveEvent.OnClientEvent:Connect(function(name)
	DrawHandler.ClearElementalFx(name)
end)

DrawEvent.OnClientEvent:Connect(function(char, name, element, slot, slotNo)
	DrawHandler.SetupElementalFx(char, name, element, slot, slotNo)
end)
