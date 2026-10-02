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
local BoulderProjectile = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Boulder"):WaitForChild("BoulderEffect")

local BoulderFx = {}
local BoulderClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "Boulder" then return end
	
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element = "Earth"

	if not BoulderFx[userId] then 
		BoulderFx[userId] = {}
	end

	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "BoulderFx"
	Folder.Parent = hum
	
	-- Since we're doing a projectile, create a folder for the projectile for the Replicator script to use
	local ProjFolder = Instance.new("Folder")
	ProjFolder.Name = "BoulderProjectile"
	ProjFolder.Parent = hum
	
	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)

	-- 0 means right, 1 means left
	-- Create Particles
	local Particle_0, Emitters_0 = Effects.CreateParticle(element, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local Particle_1, Emitters_1 = Effects.CreateParticle(element, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	local Rotator_0 = Effects.CreatePart(Vector3.new(1,1,1), 1, "RightBoulderRotator", RightHand.CFrame, Folder, false)
	local Rotator_1 = Effects.CreatePart(Vector3.new(1,1,1), 1, "LeftBoulderRotator", LeftHand.CFrame, Folder, false)
	local Trail_0 = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator_0, Rotator_0.CFrame * CFrame.new(0, 0, 1.5))
	local Trail_1 = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator_1, Rotator_1.CFrame * CFrame.new(0, 0, 1.5))
	
	-- Tween Effects here
	local rotationAngle_0 = 0
	local rotationAngle_1 = 0
	BoulderFx[userId].Connection = RunService.Heartbeat:Connect(function()
		-- Increment the rotation angle for Rotate
		rotationAngle_0 = rotationAngle_0 + math.rad(5)  -- Rotate clockwise
		rotationAngle_1 = rotationAngle_1 - math.rad(5)  -- Rotate counter-clockwise

		-- Rotate the parts around the Y-axis
		local newRotation_0 = CFrame.Angles((0 + (0)), (rotationAngle_0 + (0)), (0 + (0))) 
		local newRotation_1 = CFrame.Angles((0 + (0)), (rotationAngle_1 + (0)), (0 + (0))) 

		-- Maintain the position of the Rotate parts relative to HumanoidRP
		Rotator_0.CFrame = RightHand.CFrame * newRotation_0
		Rotator_1.CFrame = LeftHand.CFrame * newRotation_1
	end)
	
	-- Create and Play sound effects
	local Voodoo = SFX["voodoo_restoration"]:Clone(); Voodoo.Parent = Folder
	local EarthquakeLoop = SFX["Loop Earthquake Sound"]:Clone(); EarthquakeLoop.Parent = Folder
	local RockSfx = SFX["Rock Scrape Huge Boulder Movement Across Dir (SFX)"]:Clone(); RockSfx.Parent = Folder

	Voodoo:Play()
	EarthquakeLoop.Volume = 0; EffectsSFX.FadeSound(EarthquakeLoop, 0.5, 2, 20); EarthquakeLoop:Play()
	RockSfx:Play()
	
	-- DECLARE VARIABLES FIRST
	local Beam_0
	local Beam_1
	local Beam2_0
	local Beam2_1
	
	BoulderFx[userId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
		if weaveName ~= "Boulder" then return end
		if phase ~= "Channel" then return end
		if player.UserId ~= UserId then return end
		
		-- Create Beams
		Beam_0 = Effects.CreateBeam("Earth", Folder, humRP.CFrame * CFrame.new(0,-5,-5), RightHand.CFrame, nil, RightHand, 5, 5, 2, 5, 3, 5)
		Beam_1 = Effects.CreateBeam("Earth", Folder, humRP.CFrame * CFrame.new(0,-5,-5), LeftHand.CFrame, nil, LeftHand,  -5, -5, -2, -5, -3, -5)

		-- Anchor start positions
		Beam_0.Start.Anchored = true
		Beam_1.Start.Anchored = true

		-- Fade transparency
		for _, beams in Beam_0:GetChildren() do
			if beams:IsA("Beam") then
				Effects.NumberValueTweenObj(beams, "Beam", "Transparency", 1, 1, 0.5, 20)
			end
		end

		for _, beams in Beam_1:GetChildren() do
			if beams:IsA("Beam") then
				Effects.NumberValueTweenObj(beams, "Beam", "Transparency", 1, 1, 0.5, 20)
			end
		end

		-- Create more beams that will connect to the actual projectile
		Beam2_0 = Effects.CreateBeam("Earth", Folder, humRP.CFrame * CFrame.new(-5,-5,0), humRP.CFrame * CFrame.new(0, 15, 0), nil, nil, 5, 5, 2, 5, 3, 5)
		Beam2_1 = Effects.CreateBeam("Earth", Folder, humRP.CFrame * CFrame.new(5,-5,0), humRP.CFrame * CFrame.new(0, 15, 0), nil, nil,  -5, -5, -2, -5, -3, -5)
		
		-- Anchor start positions
		Beam2_0.Start.Anchored = true
		Beam2_1.Start.Anchored = true
		Beam2_0.End.Anchored = true
		Beam2_1.End.Anchored = true
		
		-- Fade transparency
		for _, beams in Beam2_0:GetChildren() do
			if beams:IsA("Beam") then
				Effects.NumberValueTweenObj(beams, "Beam", "Transparency", 1, 2, 0.5, 20)
			end
		end

		for _, beams in Beam2_1:GetChildren() do
			if beams:IsA("Beam") then
				Effects.NumberValueTweenObj(beams, "Beam", "Transparency", 1, 2, 0.5, 20)
			end
		end
		
		-- */*/*/*/*/*/*/*/*/ PROJECTILE */*/*/*/*/*/*/*/*/*/*/*/
		local newProjectile = BoulderProjectile:Clone()
		newProjectile.AlignPosition.Position = (humRP.CFrame * CFrame.new(0, 15, 0)).Position
		newProjectile.Parent = ProjFolder
		newProjectile.CFrame = humRP.CFrame * CFrame.new(0, 15, 0)
		
		--task.wait() -- let the code yield
		
		newProjectile.Anchored = false
		newProjectile:FindFirstChildOfClass("AlignPosition").Enabled = true
		newProjectile:FindFirstChildOfClass("AlignOrientation").Enabled = true
		-- Setup Projectile AlignPosition
		BoulderFx[UserId].Task1 = task.spawn(function()
			while newProjectile and newProjectile:FindFirstChildOfClass("AlignPosition") do
				local BasePosition = humRP.CFrame * CFrame.new(0, 15, 0)
				local localOffSet = Vector3.new(math.random(-0.5, 0.5), math.random(-0.5, 0.5), math.random(-0.5, 0.5))
				newProjectile:FindFirstChildOfClass("AlignPosition").Position = Effects.ShakeAP(newProjectile.AlignPosition, BasePosition, localOffSet, 0.1)
			end
		end)
		
		-- Allow the Projectile to have randomized Rotation
		BoulderFx[UserId].Task2 = task.spawn(function()
			while newProjectile and newProjectile.Parent do
				Effects.TwistOrientation(newProjectile)
				task.wait(0.5)
			end
		end)
		
		Effects.ShakeCamera(userId, false, nil, 0.4, 3, 1)

		-- Connect charge change event
		if BoulderFx[userId] then
			BoulderFx[userId].Connection2 = hum:GetAttributeChangedSignal("Charge"):Connect(function()
				local newCharge = hum:GetAttribute("Charge")
				local sizePercentage = 1 + (math.clamp(newCharge * 3.5, 0, 100) / 100) -- 1 charge = 3.5% increase

				-- Smoothly adjust size
				Effects.GrowSize(newProjectile, sizePercentage, 20, 0.5)
			end)
		end
		
		-- Disconnect this whole connection
		if BoulderFx[userId] and BoulderFx[userId].AnimationConnection then BoulderFx[userId].AnimationConnection:Disconnect(); BoulderFx[userId].AnimationConnection = nil end
	end)
	
	BoulderFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "Boulder" then return end
		if UserId ~= userId then return end
		-- Move the cleanup task to the BoulderClean table to process it separately
		if BoulderFx[UserId] then
			BoulderClean[UserId] = BoulderFx[UserId]  -- Move to cleanup table
			BoulderFx[UserId] = nil  -- Remove from active effects table

			-- Now process cleanup from BoulderClean
			if BoulderClean[UserId] then
				-- This will clean up without affecting other ongoing effects
				if BoulderClean[UserId].TempTask then task.cancel(BoulderClean[UserId].TempTask) end

				-- Begin Clean up here
				BoulderClean[UserId].TempTask = task.spawn(function()
					
					-- STOPS CAMERA SHAKE
					Effects.StopShake(UserId)

					-- ANCHOR EFFECTS FIRST
					Trail_0.Anchored = true
					Trail_1.Anchored = true
					Particle_0.Anchored = true
					Particle_1.Anchored = true
					Rotator_0.Anchored = true
					Rotator_1.Anchored = true
					
					-- DESTROY WELDS 
					local weld
					weld = Trail_0:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Trail_1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Particle_0:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
					weld = Particle_1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end

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
					
					-- Stop Projectile from Moving
					if BoulderClean[UserId] and BoulderClean[UserId].Task1 then
						local status = coroutine.status(BoulderClean[UserId].Task1)
						if status ~= "dead" then
							task.cancel(BoulderClean[UserId].Task1)
						end
						BoulderClean[UserId].Task1 = nil
					end
					
					-- Stop Projectile from Rotating
					if BoulderClean[UserId] and BoulderClean[UserId].Task2 then
						local status = coroutine.status(BoulderClean[UserId].Task2)
						if status ~= "dead" then
							task.cancel(BoulderClean[UserId].Task2)
						end
						BoulderClean[UserId].Task2 = nil
					end
					
					local beamGroups = {Beam_0, Beam_1, Beam2_0, Beam2_1}
					
					-- Anchor and destroy weld constraint from beam points; Tween Transparency as well
					for _, group in ipairs(beamGroups) do
						for _, part in ipairs(group:GetChildren()) do
							if part:IsA("Part") then
								part.Anchored = true
								local weld = part:FindFirstChildOfClass("WeldConstraint")
								if weld then
									weld:Destroy()
								end
							end

							if part:IsA("Beam") then
								Effects.NumberValueTweenObj(part, "Beam", "Transparency", 0.5, 1, 1, 20)
							end
						end
					end
					
					-- FADE SOUND VOLUME
					EffectsSFX.FadeSound(EarthquakeLoop, 0, 2, 20)
					
					-- PLAY LAST SOUND
					local CastSound = SFX:FindFirstChild("black_flash"):Clone(); CastSound.Parent = Folder
					CastSound:Play()
					
					task.wait(2)
					
					-- DESTROY EFFECTS FOLDER
					Folder:Destroy()
					
					-- CLEAN UP CONNECTIONS AND TASKS
					if BoulderClean[UserId] then
						if BoulderClean[UserId].Connection then BoulderClean[UserId].Connection:Disconnect(); BoulderClean[UserId].Connection = nil end
						if BoulderClean[UserId].Connection2 then BoulderClean[UserId].Connection2:Disconnect(); BoulderClean[UserId].Connection2 = nil end
						if BoulderClean[userId].AnimationConnection then BoulderClean[userId].AnimationConnection:Disconnect() end; BoulderClean[userId].AnimationConnection = nil
						if BoulderClean[UserId].Task1 and coroutine.status(BoulderClean[UserId].Task1) ~= "dead" then task.cancel(BoulderClean[UserId].Task1) end; BoulderClean[UserId].Task1 = nil 
						if BoulderClean[UserId].Task2 and coroutine.status(BoulderClean[UserId].Task2) ~= "dead" then task.cancel(BoulderClean[UserId].Task2) end; BoulderClean[UserId].Task2 = nil
						if BoulderClean[UserId].ClearConnection then BoulderClean[UserId].ClearConnection:Disconnect(); BoulderClean[UserId].ClearConnection = nil end
						if BoulderClean[UserId].TempTask then BoulderClean[UserId].TempTask = nil end
						
						BoulderClean[UserId] = nil -- Clear the table
					end
				end)
				
			end
		end
	end)
end)