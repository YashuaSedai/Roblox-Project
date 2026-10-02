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

local BrambleSnareTable = {}
local BrambleSnareTableClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char: Model, hum: Humanoid, humRP: BasePart, weaveName: string, AREA: number, mousePos: Vector3)
	if weaveName ~= "BrambleSnare" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local userId = player.UserId
	local element_0 = "Earth"
	local element_1 = "Water"

	if not BrambleSnareTable[userId] then 
		BrambleSnareTable[userId] = {}
	end

	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")

	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "BrambleSnareFx"
	Folder.Parent = hum

	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)

	-- 0 means right, 1 means left, none means neither
	-- Create Particles On body parts
	local Particle_0, Emitters_0 = Effects.CreateParticle(element_0, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local Particle_1, Emitters_1 = Effects.CreateParticle(element_0, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	local Rotator_0 = Effects.CreatePart(Vector3.new(1,1,1), 1, "RightBrambleSnareRotator", RightHand.CFrame, Folder, false)
	local Rotator_1 = Effects.CreatePart(Vector3.new(1,1,1), 1, "LeftBrambleSnareRotator", LeftHand.CFrame, Folder, false)
	local Trail_0 = Effects.CreateTrail2(element_1, Folder, false, nil, true, Rotator_0, Rotator_0.CFrame * CFrame.new(0, 0, 1.5))
	local Trail_1 = Effects.CreateTrail2(element_1, Folder, false, nil, true, Rotator_1, Rotator_1.CFrame * CFrame.new(0, 0, 1.5))

	local Rotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "BrambleSnareRotator", humRP.CFrame, Folder, true)
	local Trail = Effects.CreateTrail2(element_0, Folder, false, nil, true, Rotator, Rotator.CFrame * CFrame.new(0, 0, 4))
	local Trail1 = Effects.CreateTrail2(element_1, Folder, false, nil, true, Rotator, Rotator.CFrame * CFrame.new(0, 0, 5))
	local Trail2 = Effects.CreateTrail2(element_0, Folder, false, nil, true, Rotator, Rotator.CFrame * CFrame.new(0, 0, -(5)))
	
	-- On Target Point
	local RotatorTarget = Effects.CreatePart(Vector3.new(1,1,1), 1, "BrambleSnareRotator", CFrame.new(mousePos), Folder, true)
	local TrailTarget = Effects.CreateTrail2(element_0, Folder, false, nil, true, RotatorTarget, RotatorTarget.CFrame * CFrame.new(0, 0, AREA))
	local TrailTarget1 = Effects.CreateTrail2(element_1, Folder, false, nil, true, RotatorTarget, RotatorTarget.CFrame * CFrame.new(0, 0, AREA))
	local TrailTarget2 = Effects.CreateTrail2(element_0, Folder, false, nil, true, RotatorTarget, RotatorTarget.CFrame * CFrame.new(0, 0, -(AREA)))

	-- Create and Play sound effects
	local EarthRumble1 = SFX:FindFirstChild("Audio/earth_rumble"):Clone(); EarthRumble1.Parent = Folder; EarthRumble1:Play()
	local EarthRumble2 = SFX:FindFirstChild("Audio/earth_rumble_2"):Clone(); EarthRumble2.Parent = Folder; EarthRumble2:Play()
	local EarthCracking = SFX:FindFirstChild("Earthquake Cracking 3 (SFX)"):Clone(); EarthCracking.Parent = Folder; EarthCracking:Play()

	-- Tween Effects here
	local rotationAngle_0 = 0
	local rotationAngle_1 = 0
	local rotationAngle = 0
	local isAdding = true
	local isAdding2 = true
	BrambleSnareTable[userId].Connection = RunService.Heartbeat:Connect(function()
		-- Locate necessary values
		local rootPosition = humRP.Position
		local yOffset = isAdding and 0.05 or -0.05
		local currentY = Rotator.Position.Y
		local targetY = currentY + yOffset

		-- Determine whether going up or down
		if targetY >= 5 then
			isAdding = false
		elseif targetY <= 0 then
			isAdding = true
		end
		
		-- Calculate Position for rotation 
		local newPosition = Vector3.new(rootPosition.X, targetY, rootPosition.Z)
		
		-- Locate necessary values
		local rootPosition2 = mousePos
		local yOffset2 = isAdding2 and 0.075 or -0.075
		local currentY2 = RotatorTarget.Position.Y
		local targetY2 = currentY2 + yOffset2

		-- Determine whether going up or down
		if targetY2 >= 10 then
			isAdding2 = false
		elseif targetY2 <= 0 then
			isAdding2 = true
		end

		-- Calculate Position for rotation 
		local newPosition2 = Vector3.new(rootPosition2.X, targetY2, rootPosition2.Z)

		-- Increment the rotation angle for Rotate
		rotationAngle_0 = rotationAngle_0 + math.rad(5)  -- Rotate clockwise
		rotationAngle_1 = rotationAngle_1 - math.rad(5)  -- Rotate counter-clockwise

		-- Rotate the parts around the Y-axis
		local newRotation_0 = CFrame.Angles((0 + (0)), (rotationAngle_0 + (0)), (0 + (0))) 
		local newRotation_1 = CFrame.Angles((0 + (0)), (rotationAngle_1 + (0)), (0 + (0))) 
		local newRotation = CFrame.Angles((0 + (0)), (rotationAngle_1 + (0)), (0 + (0))) 

		-- Maintain the position of the Rotate parts relative to HumanoidRP
		Rotator_0.CFrame = RightHand.CFrame * newRotation_0
		Rotator_1.CFrame = LeftHand.CFrame * newRotation_1
		Rotator.CFrame = CFrame.new(newPosition) * newRotation
		RotatorTarget.CFrame = CFrame.new(newPosition2) * newRotation
	end)
	
	Effects.ShakeCamera(userId, false, nil, 0.7, 6, 3)

	local function CleanUp()
		-- ANCHOR EVERY BASE PART
		for _, obj in Folder:GetChildren() do
			if obj and obj:IsA("BasePart") then obj.Anchored = true end
		end
		
		-- STOPS CAMERA SHAKE
		Effects.StopShake(userId)

		-- DESTROY WELDS 
		local weld
		weld = Trail_0:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = Trail_1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = Trail:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = Trail1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = Trail2:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = TrailTarget:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = TrailTarget1:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = TrailTarget2:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
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

		task.spawn(function()
			Effects.NumberValueTween(Trail_0, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(Trail_1, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(Trail, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(Trail1, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(Trail2, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(TrailTarget, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(TrailTarget1, "Trail", "Transparency", 0, 1, 1, 20)
			Effects.NumberValueTween(TrailTarget2, "Trail", "Transparency", 0, 1, 1, 20)
		end)

		task.wait(2)
		-- DESTROY EFFECTS FOLDER
		Folder:Destroy()

		if BrambleSnareTableClean[userId] then
			if BrambleSnareTableClean[userId].Connection then BrambleSnareTableClean[userId].Connection:Disconnect() end
			if BrambleSnareTableClean[userId].ClearConnection then BrambleSnareTableClean[userId].ClearConnection:Disconnect() end

			BrambleSnareTableClean[userId] = nil
		end
	end

	BrambleSnareTable[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UID, weaveName)
		if weaveName ~= "BrambleSnare" then return end
		if UID ~= player.UserId then return end
		-- Move the cleanup task to the BrambleSnareTableClean table to process it separately
		if BrambleSnareTable[userId] then
			BrambleSnareTableClean[userId] = BrambleSnareTable[userId]  -- Move to cleanup table
			BrambleSnareTable[userId] = nil  -- Remove from active effects table

			if BrambleSnareTableClean[userId] then
				-- Now process cleanup from BrambleSnareTableClean
				CleanUp()
			end

		end
	end)

end)