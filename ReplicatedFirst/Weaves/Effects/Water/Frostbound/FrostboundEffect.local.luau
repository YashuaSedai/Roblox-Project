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
local FrostboundProjectile = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Frostbound"):WaitForChild("FrostboundEffect")

local FrostboundFx = {}
local FrostboundClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "Frostbound" then return end
	
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element_0 = "Water"
	local element_1 = "Air"

	if not FrostboundFx[userId] then 
		FrostboundFx[userId] = {}
	end

	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "FrostboundFx"
	Folder.Parent = hum
	
	-- Since we're doing a projectile, create a folder for the projectile for the Replicator script to use
	local ProjFolder = Instance.new("Folder")
	ProjFolder.Name = "FrostboundProjectile"
	ProjFolder.Parent = hum
	
	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)

	-- 0 means right, 1 means left
	-- Create Particles
	local Particle_0, Emitters_0 = Effects.CreateParticle(element_0, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local Particle_1, Emitters_1 = Effects.CreateParticle(element_1, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	local Rotator_0 = Effects.CreatePart(Vector3.new(1,1,1), 1, "RightFrostboundRotator", RightHand.CFrame, Folder, false)
	local Rotator_1 = Effects.CreatePart(Vector3.new(1,1,1), 1, "LeftFrostboundRotator", LeftHand.CFrame, Folder, false)
	local Trail_0 = Effects.CreateTrail2(element_1, Folder, false, nil, true, Rotator_0, Rotator_0.CFrame * CFrame.new(0, 0, 1.5))
	local Trail_1 = Effects.CreateTrail2(element_0, Folder, false, nil, true, Rotator_1, Rotator_1.CFrame * CFrame.new(0, 0, 1.5))
	
	-- Create Beams
	local Beam_0 = Effects.CreateBeam("Water", Folder, RightHand.CFrame, RightHand.CFrame, RightHand, humRP, 5, 5, 2, 5, 3, 5)
	local Beam_1 = Effects.CreateBeam("Air", Folder, LeftHand.CFrame, LeftHand.CFrame, LeftHand, humRP, -5, -5, -2, -5, -3, -5)
	
	task.delay(1, function()
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
	end)
		
	
	-- Create and Play sound effects
	local Blizzard = SFX["Snowstorm Blizzard"]:Clone()
	Blizzard.Parent = Folder
	local IceFreezing = SFX["Ice Freeze Large Piece Crackles Liquid Nitro (SFX)"]:Clone()
	IceFreezing.Parent = Folder
	local IceCast = SFX["Ice magic casting"]:Clone()
	IceCast.Parent = Folder
	
	Blizzard:Play()
	IceFreezing:Play()
	IceCast:Play()
	
	-- Tween Effects here
	local rotationAngle_0 = 0
	local rotationAngle_1 = 0
	FrostboundFx[userId].Connection = RunService.Heartbeat:Connect(function()
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
	
	FrostboundFx[userId].Task3 = task.spawn(function()
		while Folder do
			if Folder and Beam_0 and Beam_1 then
				Effects.TwistBeams(Beam_0:FindFirstChild("Start"):FindFirstChild("AStart"), 1.5)
				Effects.TwistBeams(Beam_1:FindFirstChild("Start"):FindFirstChild("AStart"), 1.5)

				task.wait(1.5)
			else
				break
			end
		end
	end)
	
	-- *SETTING UP ACTUAL PROJECTILE AND PROJECTILE EFFECTS HERE* --
	
	-- (BEFORE THROWN)
	local newProjectile = FrostboundProjectile:Clone()
	newProjectile.CFrame = humRP.CFrame * CFrame.new(0,1,-4)
	newProjectile:FindFirstChildOfClass("AlignPosition").Position = (humRP.CFrame * CFrame.new(0,1,-4)).Position
	newProjectile.Parent = ProjFolder
	
	task.wait()
	-- Adjust Beam Welds
	Beam_0.End:FindFirstChildOfClass("WeldConstraint").Part1 = nil
	Beam_1.End:FindFirstChildOfClass("WeldConstraint").Part1 = nil
	Beam_0.End.CFrame = newProjectile.CFrame
	Beam_1.End.CFrame = newProjectile.CFrame
	Beam_0.End:FindFirstChildOfClass("WeldConstraint").Part1 = newProjectile
	Beam_1.End:FindFirstChildOfClass("WeldConstraint").Part1 = newProjectile
	
	-- Causes the Projectile to have randomized movement as a visual effect
	FrostboundFx[userId].Task2 = task.spawn(function()
		while newProjectile and newProjectile.Parent do
			local BasePosition = humRP.CFrame * CFrame.new(0 , 1, -4)
			local localOffSet = Vector3.new(math.random(-0.5, 0.5), math.random(-0.5, 0.5), math.random(-0.5, 0.5))
			if not newProjectile:FindFirstChild("AlignPosition") then break end
			newProjectile:FindFirstChild("AlignPosition").Position = Effects.ShakeAP(newProjectile.AlignPosition, BasePosition, localOffSet, 0.1)
		end
	end)
	
	-- Add a delay using the animation Signal before reactivating emitters
	FrostboundFx[userId].Connection2 = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, userId)
		if weaveName ~= "Frostbound" then return end
		if phase ~= "Channel" then return end
		if player.UserId ~= userId then return end
		
		local CastSFX = SFX:FindFirstChild("Ice magic casting"):Clone()
		CastSFX.Parent = Folder
		CastSFX:Play()

		local Ice = newProjectile:FindFirstChild("Ice")
		local Mist = newProjectile:FindFirstChild("Mist")
		local Mist2 = newProjectile:FindFirstChild("Mist2")
		local Trail = newProjectile:FindFirstChild("Trail")
		local Trail2 = newProjectile:FindFirstChild("Trail2")
		local Trail3 = newProjectile:FindFirstChild("Trail3")
		
		if newProjectile then
			Ice.Enabled = true
			Mist.Enabled = true
			Mist2.Enabled = true
			Trail.Enabled = true
			Trail2.Enabled = true
			Trail3.Enabled = true
		end
		
		Effects.ShakeCamera(userId, false, nil, 0.4, 3, 5)

		-- Connect charge change event
		if FrostboundFx[userId] then
			FrostboundFx[userId].Connection3 = hum:GetAttributeChangedSignal("Charge"):Connect(function()
				local newCharge = hum:GetAttribute("Charge")
				local sizePercentage = math.clamp(newCharge * 1.5, 0, 100) / 100 -- 1 charge = 1.5% increase

				-- Smoothly adjust sizes
				Effects.SmoothAdjustParticleSize(Ice, sizePercentage, 10, 0.25)   -- 10 steps over 0.25 seconds
				Effects.SmoothAdjustParticleSize(Mist, sizePercentage, 10, 0.25)
				Effects.SmoothAdjustParticleSize(Mist2, sizePercentage, 10, 0.25)
				Effects.SmoothAdjustParticleSize(Trail, sizePercentage, 10, 0.25)
				Effects.SmoothAdjustParticleSize(Trail2, sizePercentage, 10, 0.25)
				Effects.SmoothAdjustParticleSize(Trail3, sizePercentage, 10, 0.25)
			end)
		end


		if FrostboundFx[userId] and FrostboundFx[userId].Connection2 then FrostboundFx[userId].Connection2:Disconnect(); FrostboundFx[userId].Connection2 = nil end
	end)
	
	
	FrostboundFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "Frostbound" then return end
		if UserId ~= userId then return end

		-- Move the cleanup task to the FrostboundClean table to process it separately
		if FrostboundFx[UserId] then
			FrostboundClean[UserId] = FrostboundFx[UserId]  -- Move to cleanup table
			FrostboundFx[UserId] = nil  -- Remove from active effects table

			-- Now process cleanup from FrostboundClean
			if FrostboundClean[UserId] then
				-- This will clean up without affecting other ongoing effects
				if FrostboundClean[UserId].TempTask then task.cancel(FrostboundClean[UserId].TempTask) end

				FrostboundClean[UserId].TempTask = task.spawn(function()
					-- ANCHOR EFFECTS FIRST
					Trail_0.Anchored = true
					Trail_1.Anchored = true
					Particle_0.Anchored = true
					Particle_1.Anchored = true
					Rotator_0.Anchored = true
					Rotator_1.Anchored = true
					
					-- HANDLE BEAMS
					-- Cancel Beam twisting
					if FrostboundClean[UserId] and FrostboundClean[UserId].Task3 then
						local status = coroutine.status(FrostboundClean[UserId].Task3)
						if status ~= "dead" then
							task.cancel(FrostboundClean[UserId].Task3)
						end
						FrostboundClean[UserId].Task3 = nil
					end
					
					task.spawn(function()
						-- Anchor and destroy weld constraint from beam points
						for _, parts in Beam_0:GetChildren() do
							if parts:IsA("Part") then
								parts.Anchored = true
								parts:FindFirstChildOfClass("WeldConstraint"):Destroy()
							end
						end

						for _, parts in Beam_1:GetChildren() do
							if parts:IsA("Part") then
								parts.Anchored = true
								parts:FindFirstChildOfClass("WeldConstraint"):Destroy()
							end
						end

						-- Fade transparency
						for _, beams in Beam_0:GetChildren() do
							if beams:IsA("Beam") then
								Effects.NumberValueTween(Beam_0, "Beam", "Transparency", 0.5, 1, 1, 20)
							end
						end

						for _, beams in Beam_1:GetChildren() do
							if beams:IsA("Beam") then
								Effects.NumberValueTween(Beam_1, "Beam", "Transparency", 0.5, 1, 1, 20)
							end
						end
					end)
					
					Effects.MoveBeams(Beam_0:FindFirstChild("Start"), 1, {CFrame = Beam_0:FindFirstChild("End").CFrame})
					Effects.MoveBeams(Beam_1:FindFirstChild("Start"), 1, {CFrame = Beam_1:FindFirstChild("End").CFrame})
					
					-- PLAY SOUND
					local MagicCast = SFX:FindFirstChild("magic cast 43"):Clone()
					MagicCast.Parent = Folder
					MagicCast:Play()
					
					-- FADE SOUND VOLUME
					EffectsSFX.FadeSound(Blizzard, 0, 2, 20)
					EffectsSFX.FadeSound(IceFreezing, 0, 2, 20)
					
					-- STOPS CAMERA SHAKE
					Effects.StopShake(UserId)

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
					
					task.wait(2)

					-- DESTROY EFFECTS FOLDER
					Folder:Destroy()

					-- CLEAN UP CONNECTIONS AND TASKS
					if FrostboundClean[UserId] and FrostboundClean[UserId].Task1 then FrostboundClean[UserId].Task1 = nil end
					if FrostboundClean[UserId] and FrostboundClean[UserId].Task2 then FrostboundClean[UserId].Task2 = nil end
					if FrostboundClean[UserId] and FrostboundClean[UserId].Connection then FrostboundClean[UserId].Connection:Disconnect() end
					if FrostboundClean[userId] and FrostboundClean[userId].Connection2 then FrostboundClean[userId].Connection2:Disconnect() end
					if FrostboundClean[userId] and FrostboundClean[userId].Connection3 then FrostboundClean[userId].Connection3:Disconnect() end
					if FrostboundClean[UserId] and FrostboundClean[UserId].ClearConnection then FrostboundClean[UserId].ClearConnection:Disconnect() end
					if FrostboundClean[UserId] and FrostboundClean[UserId].TempTask then FrostboundClean[UserId].TempTask = nil end
					if FrostboundClean[UserId] then FrostboundClean[UserId] = nil end

				end)
			end
		end
	end)
	
end)