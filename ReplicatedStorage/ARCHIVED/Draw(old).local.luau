-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
local RemoveEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Remove")

-- BEZIER MODULE
local Bezier = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))

-- ASSETS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ElementalFolder = Assets:WaitForChild("Elements")
-- BEAMS
local Beams = ElementalFolder:WaitForChild("Beams")
-- PARTICLES
local Particles = ElementalFolder:WaitForChild("Particles")
-- TRAILS
local Trails = ElementalFolder:WaitForChild("Trails")

local PlayerFx = {}

RemoveEvent.OnClientEvent:Connect(function(name)
	if name then
		if PlayerFx[name] then
			for i = 1, 5 do
				local Slotname = "Slot"..i
				local Slot = PlayerFx[name].Slots[Slotname]
				if Slot then
					-- Destroy the current particle effect and trail, if any, from the last slot
					if Slot.newParticle then
						for _, emitters in pairs (Slot.newParticle:GetDescendants()) do
							if emitters:IsA("ParticleEmitter") then
								emitters.Enabled = false
							end
						end
						task.delay(2,function()
							Slot.newParticle:Destroy()
							Slot.newParticle = nil
						end)
					end

					if Slot.newTrail then
						for _, trails in pairs (Slot.newTrail:GetDescendants()) do
							if trails:IsA("Trail") then
								trails.Enabled = false
							end
						end
						task.delay(2,function()
						Slot.newTrail:Destroy()
						Slot.newTrail = nil
						end)
					end

					for taskIndex = 1, 4 do
						local taskKey = "Task" .. taskIndex
						if Slot[taskKey] then
							task.cancel(Slot[taskKey])
							Slot[taskKey] = nil
						end
					end

					if Slot.Connection then
						Slot.Connection:Disconnect()
						Slot.Connection = nil
					end

					if Slot.NewBezier then
						Slot.NewBezier = nil
					end
					
				end
			end
		end
	end
end)

DrawEvent.OnClientEvent:Connect(function(char, name, element, slot, slotNo)
	
	local originalPlayer = Players:GetPlayerFromCharacter(char)
	local HumanoidRP = char:FindFirstChild("HumanoidRootPart")
	local UpperTorso = char:FindFirstChild("UpperTorso")
	
	if not PlayerFx[name] then
		-- Initializing the table
		PlayerFx[name] = {
			Slots = {
				Slot1 = {},
				Slot2 = {},
				Slot3 = {},
				Slot4 = {},
				Slot5 = {}
			}
		}
	end
	
	local Slot = PlayerFx[name].Slots[slot] -- A reference table for storing the variables. Basically always start with Slot.'variable_name' = 'value'
	
	-- Check if the element is "Default"
	if element == "Default" then
		-- Destroy the current particle effect and trail, if any, from the last slot
		if Slot.newParticle then
			for _, emitters in pairs (Slot.newParticle:GetDescendants()) do
				if emitters:IsA("ParticleEmitter") then
					emitters.Enabled = false
				end
			end
			task.delay(2,function()
				Slot.newParticle:Destroy()
				Slot.newParticle = nil
			end)
		end

		if Slot.newTrail then
			for _, trails in pairs (Slot.newTrail:GetDescendants()) do
				if trails:IsA("Trail") then
					trails.Enabled = false
				end
			end
			task.delay(2,function()
				Slot.newTrail:Destroy()
				Slot.newTrail = nil
			end)
		end
		
		if Slot.Task1 then
			task.cancel(Slot.Task1)
			Slot.Task1 = nil
		end
		
		if Slot.Task2 then
			task.cancel(Slot.Task2)
			Slot.Task2 = nil
		end
		
		if Slot.Task3 then
			task.cancel(Slot.Task3)
			Slot.Task3 = nil
		end
		
		if Slot.Task4 then
			task.cancel(Slot.Task4)
			Slot.Task4 = nil
		end
		
		if Slot.Connection then
			Slot.Connection:Disconnect()
			Slot.Connection = nil
		end
		
		if Slot.NewBezier then
			Slot.NewBezier = nil
		end

		-- Reset the slot to an empty state
		PlayerFx[name].Slots[slot] = {}
		return -- Exit the function since the slot is cleared
	end
	
	Slot.SlotNo = slotNo and (slotNo % 2 == 0 and true or false)
	local SlotBoolean = Slot.SlotNo
	
	-- Create the Particle Effect
	Slot.newParticle = Particles:FindFirstChild(element):Clone()
	local newParticle = Slot.newParticle
	newParticle.CFrame = UpperTorso.CFrame * CFrame.new(0, 0, -2)
	newParticle.Parent = workspace
	local Emitters = newParticle:FindFirstChild("Emitters")
	
	for _, emitters in pairs (Emitters:GetChildren()) do
		if emitters and emitters:IsA("ParticleEmitter") then
			emitters.Enabled = false
		end
	end
	
	local AlignPosition = newParticle and newParticle:FindFirstChild("AlignPosition")
	AlignPosition.Attachment0 = newParticle:FindFirstChild("AP")
	
	
	Slot.Task1 = task.spawn(function()
		while newParticle do
			local BasePosition = UpperTorso.CFrame * CFrame.new(0 , 1, -2)
			local localOffSet = Vector3.new(math.random(-0.5, 0.5), math.random(-0.5, 0.5), math.random(-0.5, 0.5))
			local worldPosition = BasePosition * localOffSet
			AlignPosition.Position = worldPosition
			task.wait(0.1)
		end
	end)
	
	-- Create the Draw Effect
	Slot.newTrail = Trails:FindFirstChild(element):Clone()
	local newTrail = Slot.newTrail
	newTrail.Parent = workspace
	newTrail:FindFirstChild("AlignPosition").Attachment1 = newParticle:FindFirstChild("AP")
	
	-- Base positioning near the HumanoidRootPart
	local basePosition = HumanoidRP.Position
	local directionOffset = Vector3.new(0, 0, 0)  -- Default (forward)

	-- Modify the direction of the trail based on SlotBoolean
	if SlotBoolean then
		-- Coming from the right side (positive X direction)
		directionOffset = Vector3.new(math.random(20, 30), math.random(5, 10), math.random(0, 0))
	else
		-- Coming from the left side (negative X direction)
		directionOffset = Vector3.new(-math.random(20, 30), math.random(5, 10), math.random(0, 0))
	end

	-- Position adjustments based on the direction
	Slot.Point1 = basePosition + directionOffset
	Slot.Point2 = basePosition + Vector3.new(math.random(10, 20), math.random(-10, 10), math.random(-10, 10))
	Slot.Point3 = basePosition + Vector3.new(math.random(0, 10), math.random(-10, 10), math.random(-10, 10))
	Slot.Point4 = newParticle.Position + Vector3.new(0, 1, 0) -- Targeting the new particle position

	local Point1 = Slot.Point1
	local Point2 = Slot.Point2
	local Point3 = Slot.Point3
	local Point4 = Slot.Point4
	
	Slot.NewBezier = Bezier.new(Point1, Point2, Point3, Point4)
	local NewBezier = Slot.NewBezier

	newTrail.CFrame =  CFrame.new(Point1)
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut, 0, false, 0)
	local Tween = NewBezier:CreateCFrameTween(newTrail, {"CFrame"}, tweenInfo)
	
	Slot.Task2 = task.spawn(function()
		Tween:Play()
	end)
	
	Slot.Connection = Tween.Completed:Connect(function()
		Slot.Task4 = task.delay(2, function()
			local value = 0.5 -- Initial transparency
			local duration = 1 -- Total duration of the fade effect
			local targetValue = 1 -- Final transparency
			local steps = 20 -- Number of steps in the loop
			local increment = (targetValue - value) / steps -- Transparency increment per step
			local interval = duration / steps -- Time interval per step

			-- Iterate through the steps
			for i = 1, steps do
				-- Update the transparency value
				value = value + increment

				-- Apply the transparency to all trails in newTrail
				for _, trail in ipairs(newTrail:GetDescendants()) do
					if trail:IsA("Trail") then
						local transparency = trail.Transparency
						transparency = NumberSequence.new(value)
						trail.Transparency = transparency
					end
				end

				-- Wait for the interval before the next step
				task.wait(interval)
			end
			
			newTrail:Destroy()
			Slot.newTrail = nil
		end)
		
		
		for _, emitters in pairs (Emitters:GetChildren()) do
			if emitters and emitters:IsA("ParticleEmitter") then
				emitters.Enabled = true
			end
		end
		
		Slot.Connection = nil
		Slot.Task2 = nil
	end)
end)

