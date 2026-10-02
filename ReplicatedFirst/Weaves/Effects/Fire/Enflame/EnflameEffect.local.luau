-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))

-- REMOTE
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

local EnflameFx = {}
local EnflameClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "Enflame" then return end
	
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local element = "Fire"

	if not EnflameFx[userId] then 
		EnflameFx[userId] = {}
	end

	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local Folder = Instance.new("Folder")
	Folder.Name = "EnflameFx"
	Folder.Parent = hum

	-- Setup Vfx
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)

	local Particle, Emitters = Effects.CreateParticle(element, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local Rotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "EnflameRotator", RightHand.CFrame, Folder, false)
	local Trail = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator, Rotator.CFrame * CFrame.new(0, 0, 2.5))

	-- Create sound effects
	local FireCrackingSFX = SFX["Fireplace Constant Burning Flame 4 (SFX)"]:Clone()
	FireCrackingSFX.Parent = Folder
	local FlameLoopSFX = SFX["Flamethrower Loop"]:Clone()
	FlameLoopSFX.Parent = Folder
	local WhooshSFX = SFX["Magic Whooshes Growly Magic Whooshes Airy Gu (SFX)"]:Clone()
	WhooshSFX.Parent = Folder

	FireCrackingSFX:play()
	FlameLoopSFX:Play()
	WhooshSFX:Play()

	-- Initial Rotation Angle
	local rotationAngle = 0
	EnflameFx[userId].Connection = RunService.Heartbeat:Connect(function()
		-- Increment the rotation angle for Rotate
		rotationAngle = rotationAngle + math.rad(5)  -- Rotate clockwise

		-- Rotate the parts around the Y-axis
		local newRotation = CFrame.Angles((rotationAngle + (0)), (rotationAngle + (0)), (rotationAngle + (0))) 

		-- Maintain the position of the Rotate parts relative to HumanoidRP
		Rotator.CFrame = RightHand.CFrame * newRotation
	end)

	EnflameFx[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName)
		if weaveName ~= "Enflame" then return end

		-- Move the cleanup task to the EnflameClean table to process it separately
		if EnflameFx[UserId] then
			EnflameClean[UserId] = EnflameFx[UserId]  -- Move to cleanup table
			EnflameFx[UserId] = nil  -- Remove from active effects table

			-- Now process cleanup from EnflameClean
			if EnflameClean[UserId] then
				-- This will clean up without affecting other ongoing effects
				if EnflameClean[UserId].TempTask then task.cancel(EnflameClean[UserId].TempTask) end

				EnflameClean[UserId].TempTask = task.spawn(function()
					-- ANCHOR EFFECTS FIRST
					Trail.Anchored = true
					Particle.Anchored = true
					Rotator.Anchored = true

					-- DESTROY WELDS 
					Trail.WeldConstraint:Destroy()
					Particle.WeldConstraint:Destroy()

					-- VISUALLY FADE AWAY NECESSARY EFFECTS
					for _, emitters in Emitters:GetChildren() do
						if emitters:IsA("ParticleEmitter") then
							emitters.Enabled = false
						end
					end

					Effects.NumberValueTween(Trail, "Trail", "Transparency", 0, 1, 1, 20)

					-- DESTROY EFFECTS FOLDER
					Folder:Destroy()

					-- CLEAN UP CONNECTIONS
					if EnflameClean[UserId] and EnflameClean[UserId].TempTask then EnflameClean[UserId].TempTask = nil end
					if EnflameClean[UserId] and EnflameClean[UserId].Connection then EnflameClean[UserId].Connection:Disconnect() end
					if EnflameClean[UserId] and EnflameClean[UserId].ClearConnection then EnflameClean[UserId].ClearConnection:Disconnect() end
					if EnflameClean[UserId] then EnflameClean[UserId] = nil end

				end)
			end
		end
	end)
end)
