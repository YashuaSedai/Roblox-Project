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

-- REMOTE
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- PROJECTILE
local WindCutterProjectile = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("WindCutter"):WaitForChild("WindCutterEffect")

local WindCutterFx = {}
local WindCutterClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "WindCutter" then return end

	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element = "Air"

	if not WindCutterFx[userId] then 
		WindCutterFx[userId] = {}
	end
	
	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "WindCutterFx"
	Folder.Parent = hum
	
	-- Since we're doing a projectile, create a folder for the projectile for the Replicator script to use
	local ProjFolder = Instance.new("Folder")
	ProjFolder.Name = "WindCutterProjectile"
	ProjFolder.Parent = hum
	
	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)
	
	-- 0 means right, 1 means left
	-- Create Particles
	local Particle_0, Emitters_0 = Effects.CreateParticle(element, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local Particle_1, Emitters_1 = Effects.CreateParticle(element, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	
	-- Create Hand Trails
	local Rotator_0 = Effects.CreatePart(Vector3.new(1,1,1), 1, "RightWindCutterRotator", RightHand.CFrame, Folder, false)
	local Rotator_1 = Effects.CreatePart(Vector3.new(1,1,1), 1, "LeftWindCutterRotator", LeftHand.CFrame, Folder, false)
	local Trail_0 = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator_0, Rotator_0.CFrame * CFrame.new(0, 0, 1.5))
	local Trail_1 = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator_1, Rotator_1.CFrame * CFrame.new(0, 0, 1.5))
	
	-- Create Main Body Trail
	-- Rotator
	local HumanoidRotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "VoRHumanoidRotator", humRP.CFrame, Folder, true)
	local TrailRotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "VoRTrailRotator", humRP.CFrame * CFrame.new(4, 0, 0), Folder, true)
	local Trail1 = Effects.CreateTrail2(element, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, 0, -2))
	local Trail2 = Effects.CreateTrail2(element, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, 1, 0))
	local Trail3 = Effects.CreateTrail2(element, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, -1, 0))

	-- Create and Play sound effects
	local Sparkle = SFX["Magic Twirling Small High Pitch Spinning Chi (SFX)"]:Clone()
	Sparkle.Parent = Folder; Sparkle:Play()
	local Air = SFX["Magic Wind Airy Whooshy Wind 3 (SFX)"]:Clone()
	Air.Parent = Folder; Air:Play()
	
	-- Tween Effects here
	local rotationAngle_0 = 0
	local rotationAngle_1 = 0
	
	local humanoidRotatorAngle = 0
	local trailRotatorAngle = 0
	local tiltAngle = math.rad(150) -- 45 degree tilt
	local yOffset = 0.035
	local isMovingUp = true
	local currentY = 5 -- Start height
	WindCutterFx[userId].Connection = RunService.Heartbeat:Connect(function()
		-- *-*-*-* HAND TRAILS ANIMATION *-*-*-*
		-- Increment the rotation angle for Rotate
		rotationAngle_0 = rotationAngle_0 + math.rad(5)  -- Rotate clockwise
		rotationAngle_1 = rotationAngle_1 - math.rad(5)  -- Rotate counter-clockwise

		-- Rotate the parts around the Y-axis
		local newRotation_0 = CFrame.Angles((0 + (0)), (rotationAngle_0 + (0)), (0 + (0))) 
		local newRotation_1 = CFrame.Angles((0 + (0)), (rotationAngle_1 + (0)), (0 + (0))) 

		-- Maintain the position of the Rotate parts relative to HumanoidRP
		Rotator_0.CFrame = RightHand.CFrame * newRotation_0
		Rotator_1.CFrame = LeftHand.CFrame * newRotation_1
		
		-- *-*-*-* BODY TRAIL ANIMATIONS *-*-*-*
		-- Update angles
		humanoidRotatorAngle = humanoidRotatorAngle + math.rad(5)
		trailRotatorAngle = trailRotatorAngle + math.rad(10)

		-- Step 1: Vertical movement in **world space**
		currentY = currentY + (isMovingUp and yOffset or -yOffset)

		-- Bounce at max/min height
		if currentY >= 8 then
			isMovingUp = false
		elseif currentY <= 0.5 then
			isMovingUp = true
		end

		-- Step 2: Apply tilt first in object space (Z-axis tilt)
		local tilt = CFrame.Angles(0, 0, tiltAngle)

		-- Step 3: Then apply rotation along local Y-axis
		local spin = CFrame.Angles(0, humanoidRotatorAngle, 0)

		-- Step 4: Apply world position + local rotation
		HumanoidRotator.CFrame = CFrame.new(humRP.Position.X, currentY, humRP.Position.Z) * tilt * spin

		-- Step 5: Apply trail rotation relative to tilted frame
		local newTrailRotation = CFrame.Angles(0, 0, trailRotatorAngle)
		TrailRotator.CFrame = HumanoidRotator.CFrame * CFrame.new(4, 0, 0) * newTrailRotation
	end)
	
	-- *SETTING UP ACTUAL PROJECTILE AND PROJECTILE EFFECTS HERE* --

	-- (BEFORE THROWN)
	local newProjectile = WindCutterProjectile:Clone()
	newProjectile.CFrame = RightHand.CFrame
	newProjectile:FindFirstChildOfClass("AlignPosition").Position = (RightHand.CFrame * CFrame.new(0,0,-1)).Position
	newProjectile.Parent = ProjFolder
	newProjectile["Spinning Swish 2 (SFX)"]:Play()
	task.wait()
	
	local ProjectileRotation = 0
	WindCutterFx[userId].Connection1 = RunService.Heartbeat:Connect(function()
		ProjectileRotation = ProjectileRotation + math.rad(5)  -- Rotate clockwise
		
		local tilt = CFrame.Angles(-45, 0, 150)
		
		-- Rotate the parts around the Y-axis
		local newRotation = CFrame.Angles((ProjectileRotation + (0)), (0 + (0)), (0 + (0))) 

		-- Maintain the position of the Rotate parts relative to HumanoidRP
		newProjectile.CFrame = (humRP.CFrame * CFrame.new(1.8, 2.25, 1)) * tilt * newRotation
	end)
	
	WindCutterFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "WindCutter" then return end
		if UserId ~= userId then return end
		
		-- Move the cleanup task to the WindCutterClean table to process it separately
		if WindCutterFx[UserId] then
			WindCutterClean[UserId] = WindCutterFx[UserId]  -- Move to cleanup table
			WindCutterFx[UserId] = nil  -- Remove from active effects table
			
			if WindCutterClean[UserId] then
				if WindCutterClean[UserId].TempTask then task.cancel(WindCutterClean[UserId].TempTask) end
				
				WindCutterClean[UserId].TempTask = task.spawn(function()
					
					-- INSTANTLY STOP THIS CONNECTION
					if WindCutterClean[UserId].Connection1 then WindCutterClean[UserId].Connection1:Disconnect() end
					
					-- ANCHOR EFFECTS FIRST
					Trail_0.Anchored = true
					Trail_1.Anchored = true
					Particle_0.Anchored = true
					Particle_1.Anchored = true
					Rotator_0.Anchored = true
					Rotator_1.Anchored = true
					Trail1.Anchored = true
					Trail2.Anchored = true
					Trail3.Anchored = true
					TrailRotator.Anchored = true
					HumanoidRotator.Anchored = true
					
					-- DESTROY WELDS 
					local weld
					weld = Trail_0:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Trail_1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Particle_0:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Particle_1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Trail1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Trail2:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Trail3:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					
					-- VISUALLY FADE AWAY NECESSARY EFFECTS
					for _, emitters in Emitters_0:GetChildren() do
						if emitters:IsA("ParticleEmitter") then
							emitters.Enabled = false
						end
					end

					for _, emitters in Emitters_1:GetChildren() do
						if emitters:IsA("ParticleEmitter") then
							emitters.Enabled = false
						end
					end

					Effects.NumberValueTween(Trail_0, "Trail", "Transparency", 0, 1, 1, 20)
					Effects.NumberValueTween(Trail_1, "Trail", "Transparency", 0, 1, 1, 20)
					Effects.NumberValueTween(Trail1, "Trail", "Transparency", 0, 1, 1, 20)
					Effects.NumberValueTween(Trail2, "Trail", "Transparency", 0, 1, 1, 20)
					Effects.NumberValueTween(Trail3, "Trail", "Transparency", 0, 1, 1, 20)
					
					task.wait(2)

					-- DESTROY EFFECTS FOLDER
					Folder:Destroy()
					
					if WindCutterClean[UserId] then
						if WindCutterClean[UserId].Connection then WindCutterClean[UserId].Connection:Disconnect() end
						if WindCutterClean[UserId].ClearConnection then WindCutterClean[UserId].ClearConnection:Disconnect() end
						WindCutterClean[UserId] = nil
					end
					
				end)
			end
		end
	end)
end)