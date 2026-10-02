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
local BezierModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))
local DrawHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))

-- REMOTE
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- PROJECTILE
local AirPulseProjectile = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("AirPulse"):WaitForChild("AirPulseEffect")

local ScriptFx = {}
local CleanFx = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "AirPulse" then return end
	
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element = "Air"

	if not ScriptFx[userId] then 
		ScriptFx[userId] = {}
	end
	
	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "AirPulseFx"
	Folder.Parent = hum
	
	-- Since we're doing a projectile, create a folder for the projectile for the Replicator script to use
	local ProjFolder = Instance.new("Folder")
	ProjFolder.Name = "AirPulseProjectile"
	ProjFolder.Parent = hum
	
	-- Create and Play sound effects
	local Sfx1 = SFX["Mithrix Power"]:Clone()
	Sfx1.Parent = Folder
	local Sfx2 = SFX["ui_starbar_launch"]:Clone()
	Sfx2.Parent = Folder
	local Sfx3 = SFX["wind_loop_02"]:Clone()
	Sfx3.Parent = Folder
	local Sfx4 = SFX["Giant Air Blast Low Bursts Pound Many Versio (SFX)"]:Clone()
	Sfx4.Parent = Folder
		
	Sfx1:Play()
	Sfx2:Play()
	Sfx3.Volume = 0
	Sfx3:Play()
	EffectsSFX.FadeSound(Sfx3, 1, 0.5, 20)
	
	Effects.ShakeCamera(userId, false, nil, 0.4, 3, 5)
	
	-- *SETTING UP ACTUAL PROJECTILE AND PROJECTILE EFFECTS HERE* --
	-- (BEFORE THROWN)
	
	local newProjectile = AirPulseProjectile:Clone()
	newProjectile.CFrame = RightHand.CFrame * CFrame.new(-1.5,0,0)
	newProjectile:FindFirstChildOfClass("AlignPosition").Position = (RightHand.CFrame * CFrame.new(-1.5,0, 0)).Position
	newProjectile.Parent = ProjFolder
	task.wait()
	
	local ProjectileRotation = 0
	ScriptFx[userId].Connection1 = RunService.Heartbeat:Connect(function()
		ProjectileRotation = ProjectileRotation + math.rad(5)  -- Rotate clockwise

		local tilt = CFrame.Angles(0, 0, 0)

		-- Rotate the parts around the Y-axis
		local newRotation = CFrame.Angles((ProjectileRotation + (0)), (0 + (0)), (0 + (0))) 

		-- Maintain the position of the Rotate parts relative to HumanoidRP
		newProjectile.CFrame = (RightHand.CFrame * CFrame.new(0,-1,0)) * tilt * newRotation
	end)
	
	ScriptFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "AirPulse" then return end
		if UserId ~= userId then return end
		
		if ScriptFx[UserId] then
			CleanFx[UserId] = ScriptFx[UserId]  -- Move to cleanup table
			ScriptFx[UserId] = nil  -- Remove from active effects table
			
			
			if CleanFx[UserId] then
				if CleanFx[UserId].TempTask then task.cancel(CleanFx[UserId].TempTask) end

				CleanFx[UserId].TempTask = task.spawn(function()
					
					-- ANCHOR PROJECTILE AND DISCONNECT SPINNING CONNECTION
					newProjectile.Anchored = true
					if CleanFx[UserId].Connection1 then CleanFx[UserId].Connection1:Disconnect() end
					
					-- FADE OUT LOOPING SOUND
					EffectsSFX.FadeSound(Sfx3, 0, 0.5, 20)
					
					-- STOP CAMERA SHAKE
					Effects.StopShake(UserId)
					
					-- ADJUST TRAIL LIFE FOR BETTER VISUALS
					for _, trail in newProjectile:GetChildren() do
						if trail:IsA("Trail") then
							trail.Lifetime = 0.75
						end
					end
					
					Sfx4:Play()
					
					task.wait(2)
					Sfx3:Stop()
					-- DESTROY EFFECTS FOLDER
					Folder:Destroy()

					if CleanFx[UserId] then
						if CleanFx[UserId].Connection then CleanFx[UserId].Connection:Disconnect() end
						if CleanFx[UserId].ClearConnection then CleanFx[UserId].ClearConnection:Disconnect() end
						CleanFx[UserId] = nil
					end
				end)
			end
		end
	end)
	
end)