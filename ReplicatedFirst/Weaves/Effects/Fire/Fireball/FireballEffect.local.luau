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
local FireballProjectile = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Fireball"):WaitForChild("FireballEffect")

local FireballFx = {}
local FireballClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  
	
	-- Checker for weaveName
	if weaveName ~= "Fireball" then return end
	
	-- Setup base references
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element = "Fire"
	
	-- Initialize Table
	if not FireballFx[userId] then 
		FireballFx[userId] = {}
	end
	
	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "FireballFx"
	Folder.Parent = hum
	
	-- Since we're doing a projectile, create a folder for the projectile for the Replicator script to use
	local ProjFolder = Instance.new("Folder")
	ProjFolder.Name = "FireballProjectile"
	ProjFolder.Parent = hum
	
	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)

	-- Create Particles
	local Particle_0, Emitters_0 = Effects.CreateParticle(element, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local Particle_1, Emitters_1 = Effects.CreateParticle(element, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	local Rotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "CentralFireballRotator", humRP.CFrame, Folder, true)
	local Trail = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator, Rotator.CFrame * CFrame.new(0, 0, 1.5))
	
	-- Setup animation for the rotator
	local rotationAngle = 0
	local isAdding = true
	local distance = 1.5  -- Initial distance
	local isExpanding = true  -- Controls expansion and contraction
	FireballFx[userId].Connection = RunService.Heartbeat:Connect(function()
		
		-- Set Central Position
		local rootPosition = humRP
		
		-- Set Offsets / This also sets the speed at which the rotator oscillates and expands/contracts its trail
		local yOffset = isAdding and 0.035 or -0.035
		local distanceOffset = isExpanding and 0.075 or -0.075  -- Change distance
		
		-- Set Vertical Movement
		local currentY = Rotator.Position.Y
		local targetY = currentY + yOffset

		-- Bounce Y movement
		if targetY >= 8 then
			isAdding = false
		elseif targetY <= 0.5 then
			isAdding = true
		end
		
		-- Expand and contract distance
		distance = distance + distanceOffset
		if distance >= 5 then  -- Max expansion
			isExpanding = false
		elseif distance <= 0.5 then  -- Min contraction
			isExpanding = true
		end

		-- Rotation Speed?
		rotationAngle = rotationAngle + math.rad(5)
		
		--Setting Positions
		local newPosition = Vector3.new(rootPosition.Position.X, targetY, rootPosition.Position.Z)
		local newRotation = CFrame.Angles(0, rotationAngle + math.rad(5), 0)

		-- Keep rotator centered, only modify trail attachment
		Rotator.CFrame = CFrame.new(newPosition) * newRotation

		-- Adjust the trail’s end position
		Trail.A0.Position = Vector3.new(0, 1, distance)
		Trail.A1.Position = Vector3.new(0, -1, distance)
	end)
	
	-- Create and Play sound effects
	local Voodoo = SFX["voodoo_restoration"]:Clone(); Voodoo.Parent = Folder
	local FlameLoop = SFX["Flamethrower Loop"]:Clone(); FlameLoop.Parent = Folder
	local Fire = SFX["Fireball 2 (SFX)"]:Clone(); Fire.Parent = Folder

	Voodoo:Play()
	FlameLoop.Volume = 0; EffectsSFX.FadeSound(FlameLoop, 0.5, 2, 20); FlameLoop:Play()
	Fire:Play()
	
	-- Declare beam variables first in a wider scope
	local Beam_0
	local Beam_1
	
	FireballFx[userId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
		if weaveName ~= "Fireball" then return end
		if phase ~= "Channel" then return end
		if player.UserId ~= UserId then return end
		
		-- Create Beams
		Beam_0 = Effects.CreateBeam(element, Folder, RightHand.CFrame, humRP.CFrame * CFrame.new(0, 1, -4), nil, nil, 12, 12, 12, 12, 12, 12)
		Beam_1 = Effects.CreateBeam(element, Folder, LeftHand.CFrame, humRP.CFrame * CFrame.new(0, 1, -4), nil, nil,  12, 12, 12, 12, 12, 12)

		-- Apply orientations relative to the player's root part
		Beam_0.Start.CFrame = humRP.CFrame * CFrame.Angles(0, math.rad(-90), math.rad(-30)) -- Right Start
		Beam_0.End.CFrame = humRP.CFrame * CFrame.Angles(0, math.rad(180), math.rad(-60)) -- Right End
		Beam_1.Start.CFrame = humRP.CFrame * CFrame.Angles(0, math.rad(-90), math.rad(-30)) -- Left Start
		Beam_1.End.CFrame = humRP.CFrame * CFrame.Angles(0, math.rad(0), math.rad(-60)) -- Left End

		-- Restore positions after setting orientation
		Beam_0.Start.Position = RightHand.Position
		Beam_0.End.Position =  humRP.Position + Vector3.new(0, 1, -4)
		Beam_1.Start.Position = LeftHand.Position
		Beam_1.End.Position =  humRP.Position + Vector3.new(0, 1, -4)
		
		-- Set Welds
		Beam_0.Start.WeldConstraint.Part1 = humRP
		Beam_0.End.WeldConstraint.Part1 = humRP
		Beam_1.Start.WeldConstraint.Part1 = humRP
		Beam_1.End.WeldConstraint.Part1 = humRP
		
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
		
		Beam_0.End.AlignPosition.Position = (humRP.CFrame * CFrame.new(0, 1, -4)).Position
		Beam_1.End.AlignPosition.Position = (humRP.CFrame * CFrame.new(0, 1, -4)).Position

		task.wait(0.1) -- let the code yield

		-- Enable AlignPosition and AlignOrientation
		Beam_0.End.AlignPosition.Enabled = true
		Beam_1.End.AlignPosition.Enabled = true
		Beam_0.End.AlignOrientation.Enabled = true
		Beam_1.End.AlignOrientation.Enabled = true
		
		-- */*/*/*/*/*/*/*/*/ PROJECTILE */*/*/*/*/*/*/*/*/*/*/*/
		local newProjectile = FireballProjectile:Clone()
		newProjectile.AlignPosition.Position = (humRP.CFrame * CFrame.new(0, 1, -4)).Position
		newProjectile.Parent = ProjFolder
		newProjectile.CFrame = humRP.CFrame * CFrame.new(0, 1, -4)
		
		-- For the beams, use their inactive AlignPosition to make it less visually weird
		-- Disconnect the welds first
		Beam_0.End.WeldConstraint.Part0 = nil
		Beam_0.End.WeldConstraint.Part1 = nil
		Beam_1.End.WeldConstraint.Part0 = nil
		Beam_1.End.WeldConstraint.Part1 = nil
		
		task.wait() -- let the code yield
		
		newProjectile.Anchored = false
		newProjectile.AlignPosition.Enabled = true
		
		-- Setup Projectile AlignPosition
		FireballFx[UserId].Task1 = task.spawn(function()
			while newProjectile and newProjectile:FindFirstChildOfClass("AlignPosition") do
				local BasePosition = humRP.CFrame * CFrame.new(0, 1, -4)
				local localOffSet = Vector3.new(math.random(-0.5, 0.5), math.random(-0.5, 0.5), math.random(-0.5, 0.5))
				task.spawn(function() newProjectile:FindFirstChildOfClass("AlignPosition").Position = Effects.ShakeAP(newProjectile.AlignPosition, BasePosition, localOffSet, 0.1) end)
				task.spawn(function() Beam_0.End.AlignPosition.Position = Effects.ShakeAP(newProjectile.AlignPosition, BasePosition, localOffSet, 0.1) end) 
				task.spawn(function() Beam_1.End.AlignPosition.Position = Effects.ShakeAP(newProjectile.AlignPosition, BasePosition, localOffSet, 0.1) end)
				Beam_0.End.AlignOrientation.CFrame = humRP.CFrame * CFrame.Angles(0, math.rad(180), math.rad(-60))
				Beam_1.End.AlignOrientation.CFrame = humRP.CFrame * CFrame.Angles(0, math.rad(0), math.rad(-60)) 
				task.wait(0.1)
			end
		end)
		
		-- Fix the Start positions of beams once
		Beam_0.Start.WeldConstraint.Enabled = false
		Beam_1.Start.WeldConstraint.Enabled = false
		task.wait()
		Beam_0.Start.Position = RightHand.Position
		Beam_1.Start.Position = LeftHand.Position
		Beam_0.Start.WeldConstraint.Enabled = true
		Beam_1.Start.WeldConstraint.Enabled = true
		
		Effects.ShakeCamera(userId, false, nil, 0.4, 3, 1)
		
		-- Connect charge change event to grow projectile size
		if FireballFx[userId] then
			FireballFx[userId].Connection2 = hum:GetAttributeChangedSignal("Charge"):Connect(function()
				local newCharge = hum:GetAttribute("Charge")
				local sizePercentage = math.clamp(newCharge * 2, 0, 100) / 100 -- 1 charge = 2% increase

				-- Smoothly adjust size
				for _, emitter in newProjectile:GetChildren() do
					if emitter:IsA("ParticleEmitter") then
						Effects.SmoothAdjustParticleSize(emitter, sizePercentage, 10, 0.1)
					end
				end
				
			end)
		end
		
		-- Disconnect this whole connection
		if FireballFx[userId] and FireballFx[userId].AnimationConnection then FireballFx[userId].AnimationConnection:Disconnect(); FireballFx[userId].AnimationConnection = nil end
	end)
	
	FireballFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "Fireball" then return end
		if UserId ~= userId then return end
		
		-- Move the cleanup task to the FireballClean table to process it separately
		if FireballFx[UserId] then
			FireballClean[UserId] = FireballFx[UserId]  -- Move to cleanup table
			FireballFx[UserId] = nil  -- Remove from active effects table
			
			-- Now process cleanup from FireballClean
			if FireballClean[UserId] then
				-- This will clean up without affecting other ongoing effects
				if FireballClean[UserId].TempTask and coroutine.status(FireballClean[UserId].TempTask) ~= "dead" then task.cancel(FireballClean[UserId].TempTask) end
				-- Begin Clean up here
				FireballClean[UserId].TempTask = task.spawn(function()
					
					-- FADE SOUNDS
					FlameLoop.Volume = 0.5; EffectsSFX.FadeSound(FlameLoop, 0, 1, 2)					
					
					-- STOPS CAMERA SHAKE
					Effects.StopShake(UserId)
					
					-- ANCHOR EFFECTS FIRST
					Trail.Anchored = true
					Particle_0.Anchored = true
					Particle_1.Anchored = true
					Rotator.Anchored = true
					
					-- DESTROY WELDS 
					local weld
					weld = Trail:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
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
					
					Effects.NumberValueTween(Trail, "Trail", "Transparency", 0, 1, 1, 20)
					
					-- Stop Projectile from Moving
					if FireballClean[UserId] and FireballClean[UserId].Task1 then
						local status = coroutine.status(FireballClean[UserId].Task1)
						if status ~= "dead" then
							task.cancel(FireballClean[UserId].Task1)
						end
						FireballClean[UserId].Task1 = nil
					end
					
					local beamGroups = {Beam_0, Beam_1}
					
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
					
					task.wait(2)

					-- DESTROY EFFECTS FOLDER
					Folder:Destroy()
					
					-- CLEAN UP CONNECTIONS AND TASKS
					if FireballClean[UserId] then
						if FireballClean[UserId].Connection then FireballClean[UserId].Connection:Disconnect(); FireballClean[UserId].Connection = nil end
						if FireballClean[userId].AnimationConnection then FireballClean[userId].AnimationConnection:Disconnect() end; FireballClean[userId].AnimationConnection = nil
						if FireballClean[UserId].Task1 and coroutine.status(FireballClean[UserId].Task1) ~= "dead" then task.cancel(FireballClean[UserId].Task1) end; FireballClean[UserId].Task1 = nil 
						if FireballClean[UserId].TempTask then FireballClean[UserId].TempTask = nil end
						if FireballClean[UserId].ClearConnection then FireballClean[UserId].ClearConnection:Disconnect(); FireballClean[UserId].ClearConnection = nil end

						FireballClean[UserId] = nil -- Clear the table
					end
					
				end)
			end
			
		end
		
	end)
	
end)