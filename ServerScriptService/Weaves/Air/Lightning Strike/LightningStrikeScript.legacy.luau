-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULES
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))

-- REMOTES
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, charge: number, mouseTarget: Instance?, mousePos: Vector3?, Level)
	if weaveName ~= "LightningStrike" then return end
	
	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end
	
	local DB_DURATION = weaveData.DebounceDuration
	local DAMAGE = weaveData.Damage
	local AREA = weaveData.Area
	local CAST_RANGE = weaveData.CastRange
	local MAX_CHARGE = weaveData.MaxCharge
	
	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end
	
	-- Recalculate important values here 
	DAMAGE = DAMAGE + ((Level * charge)/ 100)
	CAST_RANGE = CAST_RANGE + ((Level * charge)/10)
	
	-- Fire the weaving event (The local scripts will assess via WeaveName whether they will process the weave)
	WeavingEvent:FireAllClients(char, hum, humRP, weaveName, mousePos, DAMAGE, AREA, CAST_RANGE, MAX_CHARGE)
end)


WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
	if weaveName ~= "LightningStrike" then return end

	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end

	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end

	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)