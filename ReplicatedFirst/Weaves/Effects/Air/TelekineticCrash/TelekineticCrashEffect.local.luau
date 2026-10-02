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

local ScriptFx = {}
local CleanFx = {}

WeavingFxEvent.OnClientEvent:Connect(function(char: Model, hum: Humanoid, humRP: BasePart, weaveName: string)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "TelekineticCrash" then return end

	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element = "Air"

	if not ScriptFx[userId] then 
		ScriptFx[userId] = {}
	end

	-- Required References
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "TelekineticCrashFx"
	Folder.Parent = hum
	
	-- Create and Play sound effects
	local Sfx1 = SFX["Telekinesis "]:Clone()
	Sfx1.Parent = Folder
	local Sfx2 = SFX["Magic Wind Airy Whooshy Wind 3 (SFX)"]:Clone()
	Sfx2.Parent = Folder
	local Sfx3 = SFX["wind_loop_02"]:Clone()
	Sfx3.Parent = Folder
	local Sfx4 = SFX["Airy Pass By Fast Breathing Rush Of Air 2 (SFX)"]:Clone()
	Sfx4.Parent = Folder
	
	Sfx1:Play()
	Sfx2:Play()
	Sfx3.Volume = 0
	Sfx3:Play()
	EffectsSFX.FadeSound(Sfx3, 1, 0.5, 20)
	Sfx4:Play()
	
	-- Camera Shake
	Effects.ShakeCamera(userId, false, nil, 0.4, 3, 5)
	
	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)
	
	local Rotator_1 = Effects.CreatePart(Vector3.new(1,1,1), 1, "LeftTCRotator", LeftHand.CFrame, Folder, false)
	local Trail_0 = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator_1, Rotator_1.CFrame * CFrame.new(0.75, 0, 0))
	local Trail_1 = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator_1, Rotator_1.CFrame * CFrame.new(-0.75, 0, 0))
	
	-- Setting Texture Length
	for _, trail in Folder:GetDescendants() do
		if trail:IsA("Trail") then
			trail.TextureLength = 0.5
		end
	end
	
	-- Create Beams
	local Beam_0 = Effects.CreateBeam(element, Folder, humRP.CFrame * CFrame.new(0,-2.5,-5), LeftHand.CFrame, nil, LeftHand, 1, 1, 1.2, 1.5, 1.3, 1.5)
	local Beam_1 = Effects.CreateBeam(element, Folder, humRP.CFrame * CFrame.new(0,-2.5,-5), LeftHand.CFrame, nil, LeftHand,  -1, -1, -1.2, -1.5, -1.3, -1.5)
	
	-- Adjust Beam Transparency
	local transparencySequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),  -- At time 0, value is 1 (fully visible)
		NumberSequenceKeypoint.new(1, 0)   -- At time 1, value is 0 (fully transparent)
	})

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
	
	for _, beams in Folder:GetDescendants() do
		if beams:IsA("Beam") then
			beams.Transparency = transparencySequence
			beams.Width0 = 0
		end
	end
	
	-- Setup animation for the rotator
	local rotationAngle_1 = 0
	local isAdding = true
	local moveSpeed = 0.01 -- Speed per frame
	local maxOffset = 0.5    -- Max forward/backward distance
	ScriptFx[userId].Connection = RunService.Heartbeat:Connect(function()
		local rootPosition = LeftHand.Position
		local currentZ = Rotator_1.Position.Z
		local targetZ = isAdding and (currentZ + moveSpeed) or (currentZ - moveSpeed)

		-- Reverse direction when reaching maxOffset
		if targetZ >= rootPosition.Z + maxOffset then
			isAdding = false
		elseif targetZ <= rootPosition.Z - maxOffset then
			isAdding = true
		end

		-- Increment rotation angle
		rotationAngle_1 = rotationAngle_1 + math.rad(5) -- Rotate counter-clockwise

		-- Compute new position with movement along Z
		local newPosition = Vector3.new(rootPosition.X, rootPosition.Y, targetZ)
		local newRotation_1 = CFrame.Angles(0, 0, rotationAngle_1)

		-- Apply new position and rotation
		Rotator_1.CFrame = CFrame.new(newPosition) * newRotation_1
	end)

	
	ScriptFx[userId].Task = task.spawn(function()
		while Folder do
			if Folder and Beam_0 and Beam_1 then
				Effects.TwistBeams(Beam_0:FindFirstChild("Start"):FindFirstChild("AStart"), 2)
				Effects.TwistBeams(Beam_1:FindFirstChild("Start"):FindFirstChild("AStart"), 2)
				Effects.TwistBeams(Beam_0:FindFirstChild("End"):FindFirstChild("AEnd"), 2)
				Effects.TwistBeams(Beam_1:FindFirstChild("End"):FindFirstChild("AEnd"), 2)

				task.wait(2)
			else
				break
			end
		end
	end)
	
	-- Create Main Body Trail
	-- Rotator
	local HumanoidRotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "VoRHumanoidRotator", humRP.CFrame, Folder, true)
	local TrailRotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "VoRTrailRotator", humRP.CFrame * CFrame.new(4, 0, 0), Folder, true)
	local Trail1 = Effects.CreateTrail2(element, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, 0, -2))
	local Trail2 = Effects.CreateTrail2(element, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, 1, 0))
	local Trail3 = Effects.CreateTrail2(element, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, -1, 0))

	-- Animation Variables
	local humanoidRotatorAngle = 0
	local trailRotatorAngle = 0

	local yOffset = 0.05
	local xOffset = 0.05
	local isMovingUp = true
	local isMovingOutward = true

	local currentY = 5 -- Start height
	local currentX = 3 -- Start X position (for TrailRotator)

	ScriptFx[userId].Connection2 = RunService.Heartbeat:Connect(function()
		-- *-*-*-* BODY TRAIL ANIMATIONS *-*-*-*
		-- Update angles
		humanoidRotatorAngle = humanoidRotatorAngle + math.rad(5)
		trailRotatorAngle = trailRotatorAngle + math.rad(10)

		-- **Vertical movement** (world space)
		currentY = currentY + (isMovingUp and yOffset or -yOffset)

		-- **Bounce vertically**
		if currentY >= 6 then
			isMovingUp = false
		elseif currentY <= 0.5 then
			isMovingUp = true
		end

		-- **Side-to-side movement (4 to 6 on X-axis)**
		currentX = currentX + (isMovingOutward and xOffset or -xOffset)

		-- **Bounce between 4 and 6**
		if currentX >= 6 then
			isMovingOutward = false
		elseif currentX <= 3 then
			isMovingOutward = true
		end

		-- Step 1: Apply rotation to the main rotator
		local spin = CFrame.Angles(0, humanoidRotatorAngle, 0)
		HumanoidRotator.CFrame = CFrame.new(humRP.Position.X, currentY, humRP.Position.Z) * spin

		-- Step 2: Move the TrailRotator back and forth
		local newTrailRotation = CFrame.Angles(0, 0, trailRotatorAngle)
		TrailRotator.CFrame = HumanoidRotator.CFrame * CFrame.new(currentX, 0, 0) * newTrailRotation
	end)

	ScriptFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "TelekineticCrash" then return end
		if UserId ~= userId then return end

		if ScriptFx[UserId] then
			CleanFx[UserId] = ScriptFx[UserId]  -- Move to cleanup table
			ScriptFx[UserId] = nil  -- Remove from active effects table


			if CleanFx[UserId] then
				if CleanFx[UserId].TempTask then task.cancel(CleanFx[UserId].TempTask) end

				CleanFx[UserId].TempTask = task.spawn(function()
					
					-- Move beams towards hand or end position
					Effects.MoveBeams(Beam_0:FindFirstChild("Start"), 1, {CFrame = Beam_0:FindFirstChild("End").CFrame})
					Effects.MoveBeams(Beam_1:FindFirstChild("Start"), 1, {CFrame = Beam_1:FindFirstChild("End").CFrame})

					-- Visually fade away trails
					for _, objparticle in Folder:GetDescendants() do
						if objparticle:IsA("Trail") then
							Effects.NumberValueTweenObj(objparticle, "Trail", "Transparency", 0, 1, 1, 20)
						end
						
						if objparticle:IsA("Beam") then
							Effects.NumberValueTweenObj(objparticle, "Beam", "Transparency", 0, 1, 1, 20)
						end
					end
					
					-- STOP CAMERA SHAKE
					Effects.StopShake(UserId)
					
					EffectsSFX.FadeSound(Sfx3, 0, 0.5, 20)
				
					task.wait(2)
					
					Folder:Destroy()

					if CleanFx[UserId] then
						if CleanFx[UserId].Connection then CleanFx[UserId].Connection:Disconnect() end
						if CleanFx[UserId].Connection2 then CleanFx[UserId].Connection2:Disconnect() end
						if CleanFx[UserId].Task and coroutine.status(CleanFx[UserId].Task) ~= "dead" then task.cancel(CleanFx[UserId].Task) end
						if CleanFx[UserId].ClearConnection then CleanFx[UserId].ClearConnection:Disconnect() end
						CleanFx[UserId] = nil
					end
				end)
			end
		end
	end)
	
	
end)