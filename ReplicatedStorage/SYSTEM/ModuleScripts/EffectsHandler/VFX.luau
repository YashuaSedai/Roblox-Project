-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- VARIABLES
local Camera = game.Workspace.Camera

-- ASSETS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ElementalFolder = Assets:WaitForChild("Elements")
-- BEAMS
local Beams = ElementalFolder:WaitForChild("Beams")
-- PARTICLES
local Particles = ElementalFolder:WaitForChild("Particles")
-- TRAILS
local Trails = ElementalFolder:WaitForChild("Trails")

local VFX = {}

-- MODULES
local CameraShaker = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("CameraShaker"):WaitForChild("CameraShaker"))

VFX.CameraShake = {}

-- CREATES A PARTICLE EFFECT
function VFX.CreateParticle(element: string, 
	targetCFrame: CFrame, 
	parent: Instance,
	emit: boolean, 
	size1: NumberSequence, 
	size2: NumberSequence, 
	weld: boolean, 
	weldPart: Instance,
	align: boolean)

	local newParticle = Particles:FindFirstChild(element):Clone()
	newParticle.Parent = parent
	newParticle.CFrame = targetCFrame

	local Emitters = newParticle:FindFirstChild("Emitters")

	for _, emitters in Emitters:GetChildren() do
		if emitters and emitters:IsA("ParticleEmitter") then
			emitters.Enabled = emit

			if size1 and emitters.Name == "1" then
				emitters.Size = size1
			elseif size2 and emitters.Name == "2" then
				emitters.Size = size2
			end
		end
	end

	if weld then
		newParticle:FindFirstChild("WeldConstraint").Part1 = weldPart
		local AlignPosition: AlignPosition = newParticle and newParticle:FindFirstChild("AlignPosition")
		if AlignPosition then AlignPosition:Destroy() end
	end

	if align then
		local AlignPosition: AlignPosition = newParticle and newParticle:FindFirstChild("AlignPosition")
		AlignPosition.Attachment0 = newParticle:FindFirstChild("AP")
		AlignPosition.Position = newParticle.Position
	end

	return newParticle, Emitters
end

-- CREATES A TRAIL (for Slots)
function VFX.CreateTrail(element: string, parent: Instance, particleAttachment: Attachment, basePos: Vector3, slotBoolean: boolean, character: Model)

	-- Create New Trail and assign AlignPosition attachment
	local newTrail = Trails:FindFirstChild(element):Clone()
	newTrail.Parent = parent
	local alignPosition = newTrail:FindFirstChild("AlignPosition")
	alignPosition.Attachment1 = particleAttachment

	-- Get the character's orientation
	local charCFrame = character:GetPivot()

	-- Generate random offset in local space (relative to character)
	local localOffset = Vector3.new(
		math.random(10, 30) * (slotBoolean and 1 or -1), -- X: Right/Left based on slotBoolean
		math.random(-5, 10), -- Y: Unchanged
		math.random(-10, 10) -- Z: Randomized forward/backward
	)

	-- Convert localOffset to world space using character CFrame
	local worldOffset = (charCFrame.RightVector * localOffset.X) + (charCFrame.UpVector * localOffset.Y) + (charCFrame.LookVector * localOffset.Z)

	-- Apply the offset relative to the character's orientation
	local finalPosition = basePos + worldOffset

	return newTrail, finalPosition
end


-- CREATES A TRAIL
function VFX.CreateTrail2(element: string, parent: Instance, align:boolean, alignAttachment: Attachment, weld:boolean, weldPart: Instance, cframe: CFrame)

	-- Create New Trail and assign AlignPosition attachment
	local newTrail = Trails:FindFirstChild(element):Clone()
	newTrail.Parent = parent
	newTrail.CFrame = cframe

	if align then
		local alignPosition = newTrail:FindFirstChild("AlignPosition")
		alignPosition.Attachment1 = alignAttachment
	end

	if weld then
		newTrail:FindFirstChild("WeldConstraint").Part1 = weldPart
	end

	return newTrail
end

-- CREATES A BEAM
function VFX.CreateBeam(element: string, parent: Instance, startCFrame: CFrame, endCFrame: CFrame, startWeld: Instance, endWeld: Instance, AS0, AS1, BS0, BS1, CS0, CS1)

	-- Clone the specified beams folder
	local newBeams = Beams:FindFirstChild(element):Clone()
	newBeams.Parent = parent

	-- Set up the Starting and Ending point of the Beam
	local Start = newBeams.Start
	local End = newBeams.End 
	Start.CFrame = startCFrame
	End.CFrame = endCFrame
	Start.WeldConstraint.Part1 = startWeld
	End.WeldConstraint.Part1 = endWeld

	newBeams.ElementalColor.CurveSize0 = AS0 or 0
	newBeams.ElementalColor.CurveSize1 = AS1 or 0
	newBeams.ElementalColor2.CurveSize0 = BS0 or 0
	newBeams.ElementalColor2.CurveSize1 = BS1 or 0
	newBeams.ElementalColor3.CurveSize0 = CS0 or 0
	newBeams.ElementalColor3.CurveSize1 = CS1 or 0

	-- Set up the beams attachments
	for _, beams in newBeams:GetChildren() do
		if Beams:IsA("Beam") then
			Beams.Attachment0 = Start.AStart
			Beams.Attachment1 = End.AEnd
		end
	end

	return newBeams
end

-- CREATES A PART
function VFX.CreatePart(size, transparency, name, cframe, parent, anchor)
	local newPart = Instance.new("Part")
	newPart.Size = size
	newPart.Transparency = transparency
	newPart.Name = name
	newPart.CFrame = cframe
	newPart.Parent = parent
	newPart.Anchored = anchor
	newPart.CanCollide = false
	newPart.CanTouch = false
	newPart.CanQuery = false
	return newPart
end

-- SHAKES THE ALIGN POSITION by extension the PARTICLE
function VFX.ShakeAP(alignPosition: AlignPosition, basePos: CFrame, offset: Vector3?, duration: number)
	local worldPosition = basePos * (offset or Vector3.new(0,0,0))

	task.wait(duration)

	return worldPosition
end

-- SIMULATES A TWEEN FOR NUMBERVALUES OR NUMBERSEQUENCES WHERE OBJ IS THE PARENT
function VFX.NumberValueTween(obj, kind, property, initialT: number, duration: number, finalT: number, steps: number)
	task.spawn(function()
		local increment = (finalT - initialT) / steps
		local interval = duration / steps
		local value = initialT

		for i = 1, steps do
			value = value + increment

			for _, valuesToTween in obj:GetDescendants() do
				if valuesToTween:IsA(kind) then
					if typeof(valuesToTween[property]) == "NumberSequence" then
						valuesToTween[property] = NumberSequence.new(value) -- Handles NumberSequences
					elseif typeof(valuesToTween[property]) == "number" then
						valuesToTween[property] = value -- Handles normal numerical properties
					end
				end
			end

			task.wait(interval)
		end
	end)

end

-- SIMULATE A TWEEN FOR NUBMERVALUES OR NUMBERSEQUENCES FROM A PROPRETY OF AN OBJECT ie. Trail Transparency
function VFX.NumberValueTweenObj(obj, kind, property, initialT: number, duration: number, finalT: number, steps: number)
	task.spawn(function()
		local increment = (finalT - initialT) / steps
		local interval = duration / steps
		local value = initialT

		for i = 1, steps do
			value = value + increment
			local valuesToTween = obj
			if valuesToTween:IsA(kind) then
				if typeof(valuesToTween[property]) == "NumberSequence" then
					valuesToTween[property] = NumberSequence.new(value) -- Handles NumberSequences
				elseif typeof(valuesToTween[property]) == "number" then
					valuesToTween[property] = value -- Handles normal numerical properties
				end
			end


			task.wait(interval)
		end
	end)
end

-- TWEENS THE SIZE OF A PART
function VFX.TweenSize(part, targetSize, duration, steps)
	if part and part:IsA("BasePart") then
		task.spawn(function()
			local interval = duration / steps
			local initialSize = part.Size
			local sizeChange = targetSize - initialSize

			for i = 1, steps do
				part.Size = initialSize + (sizeChange * (i / steps))
				task.wait(interval)
			end

			part.Size = targetSize -- Ensure it reaches the exact target size
		end)
	end
end

-- ADJUST PARTICLE SIZE BY PERCENTAGE
function VFX.SmoothAdjustParticleSize(particleEmitter, targetPercentage, steps, duration)
	task.spawn(function()

		if particleEmitter and particleEmitter.Size then
			local originalSequence = particleEmitter.Size
			local newKeypoints = {}

			-- Store original sizes to interpolate properly
			for _, keypoint in ipairs(originalSequence.Keypoints) do
				table.insert(newKeypoints, {Time = keypoint.Time, Value = keypoint.Value})
			end

			local interval = duration / steps
			for i = 1, steps do
				local progress = i / steps -- Progress from 0 to 1
				local adjustedKeypoints = {}

				for _, keypoint in ipairs(newKeypoints) do
					local newSize = keypoint.Value * (1 + (targetPercentage * progress))
					table.insert(adjustedKeypoints, NumberSequenceKeypoint.new(keypoint.Time, newSize))
				end

				particleEmitter.Size = NumberSequence.new(adjustedKeypoints)
				task.wait(interval) -- Smooth transition over time
			end
		end

	end)
end

-- ADJUST OBJECT SIZE
function VFX.GrowSize(instance, targetPercentage, steps, duration)

	local originalSize = instance.Size
	local targetSize = originalSize * targetPercentage
	local stepSize = (targetSize - originalSize) / steps
	local stepDuration = duration / steps

	task.spawn(function()
		for i = 1, steps do
			instance.Size += stepSize
			task.wait(stepDuration)
		end
		instance.Size = targetSize -- Ensure final size is exact
	end)
end

-- SMOOTHLY ADJUST PARTICLE TRANSPARENCY OVER TIME
function VFX.SmoothAdjustParticleTransparency(particleEmitter, targetTransparency, steps, duration)
	task.spawn(function()
		if particleEmitter and particleEmitter.Transparency then
			local originalSequence = particleEmitter.Transparency
			local newKeypoints = {}

			-- Store original transparency values
			for _, keypoint in ipairs(originalSequence.Keypoints) do
				table.insert(newKeypoints, {Time = keypoint.Time, Value = keypoint.Value})
			end

			local interval = duration / steps
			for i = 1, steps do
				local progress = i / steps -- Progress from 0 to 1
				local adjustedKeypoints = {}

				for _, keypoint in ipairs(newKeypoints) do
					local newTransparency = keypoint.Value + ((targetTransparency - keypoint.Value) * progress)
					table.insert(adjustedKeypoints, NumberSequenceKeypoint.new(keypoint.Time, newTransparency))
				end

				particleEmitter.Transparency = NumberSequence.new(adjustedKeypoints)
				task.wait(interval) -- Smooth transition over time
			end
		end
	end)
end


-- SHAKES CAMERA
function VFX.ShakeCamera(userId: number, once: boolean, Type: string, magnitude: number, roughness: number, fadein: number, fadeout: number)

	local function Shake(shakCf)
		Camera.CFrame = Camera.CFrame * shakCf
	end

	local renderPriority = Enum.RenderPriority.Camera.Value + 1

	-- Setup Table
	if not VFX.CameraShake[userId] then
		VFX.CameraShake[userId] = {}
	end

	-- Setup Camera Shaker
	local camShake = CameraShaker.new(renderPriority, Shake)
	VFX.CameraShake[userId].camShake = camShake

	camShake:Start()

	if once then
		if Type then
			camShake:Shake(CameraShaker.Presets[Type])
		else
			camShake:ShakeOnce(magnitude, roughness, fadein, fadeout)
		end
	else
		camShake:StartShake(magnitude, roughness)
	end
end

-- STOPS CAMERA SHAKE
function VFX.StopShake(userId: number)

	if not VFX.CameraShake[userId] then warn("No camera shake table found") return end

	VFX.CameraShake[userId].camShake:Stop()

end

-- TWEEN BEAMS
function VFX.MoveBeams(part: Instance, duration, Goal, EasingStyle, EasingDirection)
	task.spawn(function()
		local newInfo = TweenInfo.new(duration, EasingStyle or Enum.EasingStyle.Linear, EasingDirection or Enum.EasingDirection.InOut)
		local tween = TweenService:Create(part, newInfo, Goal)
		tween:Play()

		return tween
	end)
end

-- TWIST BEAMS via attachment
function VFX.TwistBeams (attachment, duration: number, EasingStyle, EasingDirection)
	local randomX = math.rad(math.random(0, 360))
	local randomY = math.rad(math.random(0, 360))
	local randomZ = math.rad(math.random(0, 360))

	-- Tween settings
	local tweenInfo = TweenInfo.new(
		duration, -- Duration in seconds
		EasingStyle or Enum.EasingStyle.Linear, -- Easing style
		EasingDirection or Enum.EasingDirection.InOut, -- Easing direction
		0, -- Repeat count (0 means no repeat)
		false -- Don't reverse
	)

	-- Goal orientation with randomized angles
	local goal = {CFrame = CFrame.Angles(randomX, randomY, randomZ)}

	-- Create and play tween
	local tween = TweenService:Create(attachment, tweenInfo, goal)
	tween:Play()

end

-- TWISTS ALIGN ORIENTATION
function VFX.TwistOrientation(attachment)
	local alignOrientation = attachment:FindFirstChildOfClass("AlignOrientation")
	-- Generate random rotation
	local randomX = math.random(0, 360)
	local randomY = math.random(0, 360)
	local randomZ = math.random(0, 360)

	-- Apply new orientation
	alignOrientation.CFrame = CFrame.Angles(math.rad(randomX), math.rad(randomY), math.rad(randomZ))
end

function VFX.CreateExplosion(part, position, numBlocks, sizeRange, velocityStrength, lifespan, material, color, chance)
	for i = 1, numBlocks do
		local shouldUseCustomPart = part and (math.random(1, 100) > (chance or 100))
		local newPart

		if shouldUseCustomPart then
			-- Use the provided part
			newPart = part:Clone()
			newPart.Position = position
			newPart.Anchored = false
			newPart.CanCollide = true
			newPart.CanTouch = false
			newPart.CanQuery = false
		else
			-- Create a new part
			newPart = Instance.new("Part")
			newPart.Size = Vector3.new(
				math.random(sizeRange.Min, sizeRange.Max),
				math.random(sizeRange.Min, sizeRange.Max),
				math.random(sizeRange.Min, sizeRange.Max)
			)
			newPart.Material = material
			newPart.Color = color
		end

		newPart.Position = position
		newPart.Anchored = false
		newPart.CanCollide = true
		newPart.CanTouch = false
		newPart.CanQuery = false
		newPart.Parent = game.Workspace

		local velocity = Instance.new("BodyVelocity")
		velocity.Velocity = Vector3.new(
			math.random(-velocityStrength, velocityStrength),
			math.random(velocityStrength / 2, velocityStrength),
			math.random(-velocityStrength, velocityStrength)
		)
		velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		velocity.Parent = newPart

		task.delay(0.2, function()
			velocity:Destroy()
		end)

		Debris:AddItem(newPart, lifespan)
	end
end

function VFX.ScaleNumberSequence(originalKeypoints, multiplier)
	local newKeypoints = {}

	for _, keypoint in ipairs(originalKeypoints) do
		local newSize = keypoint.Value * multiplier
		table.insert(newKeypoints, NumberSequenceKeypoint.new(keypoint.Time, newSize))
	end

	return NumberSequence.new(newKeypoints)
end

return VFX
