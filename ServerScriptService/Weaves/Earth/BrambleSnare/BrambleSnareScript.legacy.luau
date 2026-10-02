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

-- INSTANT
WeavingInstantEvent.OnServerEvent:Connect(function(player: Player, weaveName: string, mouseTarget: Model, mousePos: Vector3, level: number)
	if weaveName ~= "BrambleSnare" then return end
	
	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")

	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end
	
	local DB_DURATION = weaveData.DebounceDuration
	local CAST_RANGE = weaveData.CastRange
	local DAMAGE = weaveData.Damage
	local AREA = weaveData.Area
	
	-- Recalculate important values here
	CAST_RANGE = CAST_RANGE + level
	AREA = AREA + (level/10)
	DAMAGE = DAMAGE + (level/75)
	
	WeavingInstantEvent:FireAllClients(char, hum, humRP, weaveName, mousePos, DAMAGE, AREA, CAST_RANGE)
end)

WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName:string)
	if not player then return warn("BrambleSnare fx didn't receive a player") end
	if weaveName ~= "BrambleSnare" then return end
	
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, weaveName)
end)

WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
	if not player then return warn("BrambleSnare fx didn't receive a player") end
	if weaveName ~= "BrambleSnare" then return end

	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end

	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end
	
	local CAST_RANGE = weaveData.CastRange
	local AREA = weaveData.Area
	AREA = AREA + (level/10)
	
	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName, AREA, mousePos)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if not player then return warn("BrambleSnare fx cleaner didn't receive a player") end
	if weaveName ~= "BrambleSnare" then return end
	
	local UserId = player.UserId
	WeavingFxClear:FireAllClients(UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName: string, phase)
	if not player then warn(`No player received in Animation Signal server`) return end
	if not weaveName then warn(`No weaveName received in Animation Signal server`) return end

	if weaveName ~= "BrambleSnare" then return end

	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- notifies a specific weave about an animation signal

end)