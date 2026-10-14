-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local EffectsSFX = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("SFX"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))

-- REMOTE
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- VFX
local EffectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("TelekineticCrash")

local ScriptFx = {}

WeavingInstantEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, mouseTarget, DAMAGE, force)
	if weaveName ~= "TelekineticCrash" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local userId = player.UserId

	if not ScriptFx[userId] then 
		ScriptFx[userId] = {}
	end

	-- Define enemy target
	local Enemy = mouseTarget
	local EnemyHum = Enemy and Enemy:FindFirstChild("Humanoid")
	local EnemyRP = Enemy and Enemy:FindFirstChild("HumanoidRootPart")
	local EnemyPlayer = Players:GetPlayerFromCharacter(Enemy) or nil
	
	-- Shake Cameras
	if EnemyPlayer then Effects.ShakeCamera(EnemyPlayer.UserId, false, nil, 0.4, 3, 5) end
	
	-- Stun Target immediately
	DebuffHandler.FireStun(player, userId, Enemy, true)
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "TelekineticCrashReplicator"
	Folder.Parent = hum
	
	-- Create and Play sound effects
	local Sfx1 = SFX["Generic Body Ragdoll Impact Sound 4"]:Clone()
	Sfx1.Parent = Folder
	local Sfx2 = SFX["Whoosh Burst 1 (SFX)"]:Clone()
	Sfx2.Parent = Folder
	
	-- Create new Effects
	local LevitatorEffect = EffectsFolder:WaitForChild("TelekineticCrashLevitatorEffect"):Clone()
	LevitatorEffect.Parent = Folder
	LevitatorEffect.CFrame = EnemyRP.CFrame + Vector3.new(0, -3, 0)
	
	-- Setup Animation Listener
	ScriptFx[userId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName, phase, UserId)
		if weaveName ~= "TelekineticCrash" then return end
		if UserId ~= userId then return end
		if phase ~= "Cast" then return end
		
		-- Simulate Knockback
		DebuffHandler.FireKnockback(player, humRP, Enemy, 1.75, math.clamp(force, 8000, 9000), 2.5, 5)
		
		-- Remove the previous ragdoll
		DebuffHandler.FireStun(player, userId, Enemy, false)
		
		-- Damage
		DebuffHandler.FireDamage(player, player.UserId, EnemyHum, DAMAGE)

		-- Shake Camera for target
		if EnemyPlayer then Effects.ShakeCamera(EnemyPlayer.UserId, true, nil, 6.5, 7, 0.25, 0.25) end
		
		-- Turn Off emitters
		for _, emitters in Folder:GetDescendants() do
			if emitters:IsA("ParticleEmitter") then emitters.Enabled = false end
		end
	end)
	
	ScriptFx[userId].ClearConnection = WeavingInstantReleaseEvent.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "TelekineticCrash" then return end
		if UserId ~= userId then return end

		if ScriptFx[UserId] then
			
			-- Play SFX
			Sfx1:Play()
			Sfx2:Play()
			
			-- Stop Camera Shake
			if EnemyPlayer then Effects.StopShake(EnemyPlayer.UserId) end
			
			task.wait(2)
			Folder:Destroy()
			
			ScriptFx[userId].AnimationConnection:Disconnect()
			ScriptFx[userId].ClearConnection:Disconnect()
			ScriptFx[userId] = nil
		end
	end)
	
	
	
end)
	
