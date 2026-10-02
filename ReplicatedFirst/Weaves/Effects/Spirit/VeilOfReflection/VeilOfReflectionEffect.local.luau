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

local VoRTable = {}
local VoRClean = {}

WeavingFxEvent.OnClientEvent:Connect(function(char: Model, hum: Humanoid, humRP: BasePart, weaveName: string)
	if weaveName ~= "VeilOfReflection" then return end
	
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local userId = player.UserId
	local element_0 = "Spirit"
	local element_1 = "Water"
	local element_2 = "Air"
	
	if not VoRTable[userId] then 
		VoRTable[userId] = {}
	end

	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	local Folder = Instance.new("Folder")
	Folder.Name = "VeilOfReflectionFx"
	Folder.Parent = hum
	
	-- *SETTING UP SPECIAL EFFECTS HERE* --
	local NumberSequence1 = NumberSequence.new(1.5)
	local NumberSequence2 = NumberSequence.new(1.2)
	
	-- Each hand should have the spirit particle, left hand should have water, and right hand should have air
	local SpiritParticleL = Effects.CreateParticle(element_0, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	local SpiritParticleR = Effects.CreateParticle(element_0, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	local WaterParticleL = Effects.CreateParticle(element_1, LeftHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, LeftHand, false)
	local AirParticleR = Effects.CreateParticle(element_2, RightHand.CFrame, Folder, true, NumberSequence1, NumberSequence2, true, RightHand, false)
	
	-- Rotator
	local HumanoidRotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "VoRHumanoidRotator", humRP.CFrame, Folder, true)
	local TrailRotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "VoRTrailRotator", humRP.CFrame * CFrame.new(4, 0, 0), Folder, true)
	
	-- Trails
	local SpiritTrail = Effects.CreateTrail2(element_0, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, 0, -2))
	local WaterTrail = Effects.CreateTrail2(element_1, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, 1, 0))
	local AirTrail = Effects.CreateTrail2(element_2, Folder, false, nil, true, TrailRotator, TrailRotator.CFrame * CFrame.new(0, -1, 0))
	
	-- Create and Play sound effects
	local Sfx1 = SFX:FindFirstChild("Magic Whooshes Growly Magic Whooshes Airy Gu (SFX)"):Clone(); Sfx1.Looped = false; Sfx1.Parent = Folder; Sfx1:Play()
	local Sfx2 = SFX:FindFirstChild("Rift Portal Enter"):Clone(); Sfx2.Looped = false; Sfx2.Parent = Folder; Sfx2:Play()
	local Sfx3 = SFX:FindFirstChild("chemical_rage_cast"):Clone(); Sfx3.Looped = false; Sfx3.Parent = Folder; Sfx3:Play()
	local Sfx4 = SFX:FindFirstChild("portal_loop"):Clone(); Sfx4.Looped = true; Sfx4.Parent = Folder; Sfx4:Play()
	
	local humanoidRotatorAngle = 0
	local trailRotatorAngle = 0
	
	-- Tween Effects here
	VoRTable[userId].Connection = RunService.Heartbeat:Connect(function()
		
		humanoidRotatorAngle = humanoidRotatorAngle + math.rad(5)
		trailRotatorAngle = trailRotatorAngle + math.rad(10)
		
		local newHumanoidRotation = CFrame.Angles((0 + (0)), (humanoidRotatorAngle + (0)), (0 + (0))) 
		local newTrailRotation = CFrame.Angles((0 + (0)), (0 + (0)), (trailRotatorAngle + (0))) 
		
		HumanoidRotator.CFrame = humRP.CFrame * newHumanoidRotation
		TrailRotator.CFrame = (HumanoidRotator.CFrame * CFrame.new(4, 0, 0)) * newTrailRotation
	end)
	
	local function CleanUp()
		-- ANCHOR EVERY BASE PART
		for _, obj in Folder:GetChildren() do
			if obj and obj:IsA("BasePart") then obj.Anchored = true end
		end
		
		-- DESTROY WELDS 
		local weld
		weld = SpiritTrail:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = WaterTrail:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = AirTrail:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = SpiritParticleL:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = SpiritParticleR:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = WaterParticleL:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		weld = AirParticleR:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
		
		-- VISUALLY FADE AWAY NECESSARY EFFECTS
		local ParticleEmitters = {SpiritParticleL:FindFirstChild("Emitters"), SpiritParticleR:FindFirstChild("Emitters"), WaterParticleL:FindFirstChild("Emitters"), AirParticleR:FindFirstChild("Emitters")}
		
		for _, attachment in ipairs(ParticleEmitters) do
			if attachment then
				for _, emitter in ipairs(attachment:GetChildren()) do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = false
					end
				end
			end
		end
		
		for _, Trails in Folder:GetDescendants() do
			Effects.NumberValueTween(Trails, "Trail", "Transparency", 0, 1, 1, 20)
		end
		
		Effects.NumberValueTweenObj(Sfx4, "Sound", "Volume", Sfx4.Volume, 1, 0, 20)
		
		task.wait(2)
		-- DESTROY EFFECTS FOLDER
		Folder:Destroy()
		

		if VoRClean[userId] then
			if VoRClean[userId].Connection then VoRClean[userId].Connection:Disconnect() end
			if VoRClean[userId].ClearConnection then VoRClean[userId].ClearConnection:Disconnect() end

			VoRClean[userId] = nil
		end
			
	end
	
	-- CLEAR EFFECTS
	VoRTable[userId].ClearConnection = WeavingFxClear.OnClientEvent:Connect(function(UID, weaveName)
		if weaveName ~= "VeilOfReflection" then return end
		if UID ~= player.UserId then return end
		-- Move the cleanup task to the VorClean table to process it separately
		if VoRTable[userId] then
			VoRClean[userId] = VoRTable[userId]  -- Move to cleanup table
			VoRTable[userId] = nil  -- Remove from active effects table

			if VoRClean[userId] then
				-- Now process cleanup from VorClean
				CleanUp()
			end

		end
	end)
	
	
end)