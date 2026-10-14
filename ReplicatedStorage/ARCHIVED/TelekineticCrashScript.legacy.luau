-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULES
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))

-- REMOTES
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local InversingRemote = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("InversingRemote")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- DIRECTORIES
local Levitator = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("TelekineticCrash"):WaitForChild("Levitator")

-- TABLE
local Tablefx = {}

-- INSTANT
WeavingInstantEvent.OnServerEvent:Connect(function(player: Player, weaveName: string, mouseTarget: Model, mousePos: Vector3, level: number)
	if weaveName ~= "TelekineticCrash" then return end

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

	-- Recalculate important values here
	CAST_RANGE = CAST_RANGE 
	DAMAGE = DAMAGE + (level/75)
	local force = math.random(8000, 9000)

	-- Fire to Replicator
	WeavingInstantEvent:FireAllClients(char, hum, humRP, weaveName, mouseTarget, DAMAGE, force)
	
	-- Server-Side Effect (Levitation)
	
	-- Create Table for Player
	if not Tablefx[player] then
		Tablefx[player] = {}
	end
	
	-- Retrieve Target Information
	local TargetRP = mouseTarget:FindFirstChild("HumanoidRootPart")
	local TargetHead = mouseTarget:FindFirstChild("Head")
	
	-- Create Folder
	local Folder
	if not hum:FindFirstChild("TelekineticCrashServerFolder") then
		Folder = Instance.new("Folder")
	end
	Folder.Parent = hum
	Folder.Name = "TelekineticCrashServerFolder"
	
	-- Clone Levitator
	local newLevitator = Levitator:Clone()
	newLevitator.Parent = Folder
	newLevitator.CFrame = TargetRP.CFrame + Vector3.new(0, 10, 0)
	
	-- Locate/Create Head Attachment
	local TelekineticAttachment = TargetHead and TargetHead:FindFirstChild("TelekineticAttachment")
	if not TelekineticAttachment then
		TelekineticAttachment = Instance.new("Attachment")
		TelekineticAttachment.Parent = TargetHead
	end
	
	-- Adjust AlignPosition
	local AlignPos = newLevitator:FindFirstChildOfClass("AlignPosition")
	AlignPos.Attachment0 = TelekineticAttachment
	
end)


WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
	if not player then return warn("TelekineticCrash fx didn't receive a player") end
	if weaveName ~= "TelekineticCrash" then return end

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

	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName, AREA, mousePos)
end)


WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName:string)
	if not player then return warn("TelekineticCrash fx didn't receive a player") end
	if weaveName ~= "TelekineticCrash" then return end

	-- Clear Replicator
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, weaveName)
	
	-- Set up Animation Signal listener via Tablefx[Player]
	Tablefx[player].AnimationConnection = AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName: string, phase)
		if weaveName ~= "TelekineticCrash" then return end
		if phase ~= "Cast" then return end
		
		-- Clear Levitator
		local Folder = player.Character.Humanoid:FindFirstChild("TelekineticCrashServerFolder")
		local Levitator = Folder:FindFirstChild("Levitator")
		Levitator:FindFirstChildOfClass("AlignPosition").Enabled = false
		
		for _, emitters in Folder:GetDescendants() do if emitters:IsA("ParticleEmitter") then emitters:Emit(1) end end
		
		task.wait(2)
		if Folder then Folder:Destroy() end
		
		-- Disconnect Animation Connection
		if Tablefx[player] and Tablefx[player].AnimationConnection then Tablefx[player].AnimationConnection:Disconnect(); Tablefx[player] = nil end
	end)
	
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if not player then return warn("TelekineticCrash fx cleaner didn't receive a player") end
	if weaveName ~= "TelekineticCrash" then return end

	local UserId = player.UserId
	WeavingFxClear:FireAllClients(UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName: string, phase)
	if not player then warn(`No player received in Animation Signal server`) return end
	if not weaveName then warn(`No weaveName received in Animation Signal server`) return end

	if weaveName ~= "TelekineticCrash" then return end

	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- notifies a specific weave about an animation signal

end)