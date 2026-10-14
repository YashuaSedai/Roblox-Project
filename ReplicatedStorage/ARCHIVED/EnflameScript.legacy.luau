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
local InversingRemote = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("InversingRemote")

WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, charge: number, mouseTarget: Instance?, mousePos: Vector3?, Level)
	if not player then return warn("Enflame didn't receive a player") end
	if weaveName ~= "Enflame" then return end
	
	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end

	local DB_DURATION = weaveData.DebounceDuration
	local DAMAGE_OVER_TIME = weaveData.DamageOverTime
	local DURATION = weaveData.Duration
	local CAST_RANGE = weaveData.CastRange
	
	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end
	
	-- Setup cast distance
	if mousePos then
		local distance = (humRP.Position - mousePos).Magnitude
		if distance > CAST_RANGE then
			GuiRelatedThings.ErrorMessage(player, "Target is out of reach")
		end
	end
	
	-- Recalculate important values here 
	DAMAGE_OVER_TIME = (DAMAGE_OVER_TIME * (Level / 100)) + DAMAGE_OVER_TIME
	
	-- Fire weaving event (The local scripts will assess via WeaveName whether they will process the weave)
	WeavingEvent:FireAllClients(char, hum, humRP, weaveName, mouseTarget, DAMAGE_OVER_TIME, DURATION)
	
end)

WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
	if not player then return warn("Enflame fx didn't receive a player") end
	if weaveName ~= "Enflame" then return end
	
	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end

	local CAST_RANGE = weaveData.CastRange

	-- Set up some references	
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end

	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName, mousePos)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if not player then return warn("Enflame fx cleaner didn't receive a player") end
	if weaveName ~= "Enflame" then return end
	
	local UserId = player.UserId
	WeavingFxClear:FireAllClients(UserId, weaveName)
end)

InversingRemote.OnServerEvent:Connect(function(player: Player, InverseName: string, InverseKey: string, IncomingWeave: CFrame)
	-- IN THE SERVER: (Replication)
	-- Validate the player
	if not InverseName then warn("Inverse name not provided") return end
	if not InverseKey then warn("Inverse key not provided") return end
	
	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[InverseName]
	if not weaveData then return warn("Weave data not found for " .. InverseName) end
	
	-- Analyze the InverseKey, inverse key only have 5 digits but passed as string
	if InverseKey ~= weaveData.InverseKey then warn(`Inverse Key did not match the provided InverseName: {InverseName}`) return end
	
	-- Decode the key into elements
	local e1, e2, e3, e4, e5 = WeavingModule.DecodeInverseKey(InverseKey)
	
	-- Process InverseKey and store it as elementTable[e1], elementTable[e2]
	local char = player and player.Character
	local hum = char and char.Humanoid
	local humRP = char and char.HumanoidRootPart
	
	-- FireAllClients to InversingRemote
	-- Send the analyzed values as parameters (Char, Hum, HumRP, e1, e2, e3, e4, e5); e stands for element
	InversingRemote:FireAllClients(char, hum, humRP, InverseName, IncomingWeave, e1, e2, e3, e4, e5) 
	
end)