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
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

WeavingInstantEvent.OnServerEvent:Connect(function(player: Player, weaveName, _, _, Level)
	if not player then return warn("VeilOfReflection didn't receive a player") end
	if weaveName ~= "VeilOfReflection" then return end
	
	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end
	
	local DB_DURATION = weaveData.DebounceDuration
	local HEALTH = weaveData.Health
	local MAX_HEALTH = weaveData.MaxHealth
	local REGEN_RATE = weaveData.RegenRate
	local INTERVAL = weaveData.Interval
	
	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end
	
	-- Recalculate important values here
	HEALTH = HEALTH + Level
	MAX_HEALTH = MAX_HEALTH + Level
	REGEN_RATE = REGEN_RATE + (Level* 0.01)
	local SIZE_INCREASE_PERCENTAGE = (Level * 0.5) * 0.01
	
	WeavingInstantEvent:FireAllClients(char, hum, humRP, weaveName, HEALTH, MAX_HEALTH, SIZE_INCREASE_PERCENTAGE, REGEN_RATE, INTERVAL)
end)

WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if not player then return warn("VeilOfReflection fx didn't receive a player") end
	if weaveName ~= "VeilOfReflection" then return end
	
	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end
	
	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if not player then return warn("VeilOfReflection fx cleaner didn't receive a player") end
	if weaveName ~= "VeilOfReflection" then return end

	local UserId = player.UserId
	WeavingFxClear:FireAllClients(UserId, weaveName)
end)

WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player, weaveName)
	if not player then return warn("VeilOfReflection fx cleaner didn't receive a player") end
	if weaveName ~= "VeilOfReflection" then return end

	local UserId = player.UserId
	WeavingInstantReleaseEvent:FireAllClients(UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName: string, phase)
	if not player then warn(`No player received in Animation Signal server`) return end
	if not weaveName then warn(`No weaveName received in Animation Signal server`) return end

	if weaveName ~= "VeilOfReflection" then return end

	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- notifies a specific weave about an animation signal

end)