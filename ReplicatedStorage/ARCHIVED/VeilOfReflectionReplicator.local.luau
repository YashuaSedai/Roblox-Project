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
local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))

-- REMOTE
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- VFX
local EffectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("VeilOfReflection")

local VoRTable = {}

WeavingInstantEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, HEALTH, MAX_HEALTH, SIZE_INCREASE_PERCENTAGE, REGEN_RATE, INTERVAL)
	
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
	
	-- *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* MAIN CHECKER *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*
	local flag = false
	local startTime = tick()  -- Start measuring time

	VoRTable[userId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, userId)
		if weaveName ~= "VeilOfReflection" then warn("WeaveName isn't VeilOfReflection, returning from Replicator AnimationConnection") return end
		if phase ~= "Channel" then warn("Phase isn't Channel in VeilOfReflection, returning from Replicator AnimationConnection") return end
		if player.UserId ~= userId then return end

		flag = true
	end)

	-- Standard repeat-until loop
	repeat
		-- Delay before the next loop iteration
		task.wait(0.1)  -- Waits for 1 second
	until flag == true or tick() - startTime >= 3.5  -- Waits for flag to be true or 3 seconds to pass

	-- Code to execute after the loop finishes
	if flag then
		VoRTable[userId].AnimationConnection:Disconnect()
	else
		--warn("VeilOfReflection Replicator did not receive the animation signal")
		VoRTable[userId].AnimationConnection:Disconnect()
		return -- RETURN THE SCRIPT IMMEDIATELY TO AVOID CONNECTING UNNECESSARY STUFF FURTHER
	end

	-- *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* MAIN CODE *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*
	
	-- Prepare Folder for easier cleanup
	local Folder = Instance.new("Folder")
	Folder.Parent = hum
	Folder.Name = "VeilOfReflectionReplicator"
	
	local newBarrier = EffectsFolder:WaitForChild("VeilofReflection"):Clone()
	newBarrier.Parent = workspace.Barriers.VeilOfReflection
	
	-- Position and rotate the model using PrimaryPart's CFrame
	local targetCFrame = humRP.CFrame * CFrame.new(0, 1.5, -4) * CFrame.Angles(0, math.rad(90), 0)
	newBarrier:SetPrimaryPartCFrame(targetCFrame)

	-- Rename the Model
	newBarrier.Name = "VeilOfReflection_"..player.UserId
	
	-- Reidentify to Primary Part
	local newBarrier = newBarrier:WaitForChild("VeilOfReflectionEffect")
	local ModelBarrier = newBarrier.Parent
	
	task.wait() -- Let the code yield
	
	-- Set veil's anchor to false
	newBarrier.Anchored = false
	
	local Health = newBarrier:FindFirstChild("Health")
	local MaxHealth = newBarrier:FindFirstChild("MaxHealth")
	
	-- Configure AlignPos & AlignOrientation
	local AlignPosition = Instance.new("AlignPosition"); AlignPosition.Parent = newBarrier
	AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	AlignPosition.Attachment0 = newBarrier:FindFirstChild("Effects1")
	AlignPosition.Position = humRP.CFrame.Position + Vector3.new(0, 1.5, 0)
	AlignPosition.ApplyAtCenterOfMass = true
	AlignPosition.Responsiveness = 50
	local AlignOrientation = Instance.new("AlignOrientation"); AlignOrientation.Parent = newBarrier
	AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	AlignOrientation.Attachment0 = newBarrier:FindFirstChild("Effects1")
	AlignOrientation.Responsiveness = 50
	
	-- Function that cleans up this whole script easily
	local function Cleanup()

		-- Anchor Barrier
		newBarrier.Anchored = true
		
		-- Play Death sound
		newBarrier:FindFirstChild("Died"):Play()

		-- Immediately disable Aligns
		AlignPosition.Enabled = false
		AlignOrientation.Enabled = false

		-- Disable all particle emitters
		for _, emitters in newBarrier:GetDescendants() do
			if emitters:IsA("ParticleEmitter") then
				emitters.Enabled = false
				Effects.NumberValueTweenObj(emitters, "ParticleEmitter", "Transparency", 0, 0.5, 1, 20)
			end
		end
		
		-- Fade the Mesh children
		for _, beam in newBarrier:GetDescendants() do
			if beam:IsA("Beam") then
				Effects.NumberValueTweenObj(beam, "Beam", "Transparency", 0, 0.5, 1, 20)
			end
		end
		
		task.wait(2)
		newBarrier:Destroy()

		-- Disconnect Signals and Cancel Tasks
		if VoRTable[userId] then
			if VoRTable[userId].Task1 and coroutine.status(VoRTable[userId].Task1) ~= "dead" then task.cancel(VoRTable[userId].Task1); VoRTable[userId].Task1 = nil end
			if VoRTable[userId].Task2 and coroutine.status(VoRTable[userId].Task2) ~= "dead" then task.cancel(VoRTable[userId].Task2); VoRTable[userId].Task2 = nil end
			if VoRTable[userId].Task3 and coroutine.status(VoRTable[userId].Task3) ~= "dead" then task.cancel(VoRTable[userId].Task3); VoRTable[userId].Task3 = nil end
			if VoRTable[userId].HealthListener then VoRTable[userId].HealthListener:Disconnect() end
			if VoRTable[userId].AnimationConnection then VoRTable[userId].AnimationConnection:Disconnect() end
			if VoRTable[userId].ClearConnection then VoRTable[userId].ClearConnection:Disconnect() end
		end
		
		VoRTable[userId] = nil

	end
	
	-- Initialize Values
	Health.Value = HEALTH
	MaxHealth.Value = MAX_HEALTH
	
	-- Set ownership
	DebuffHandler.SetOwner(newBarrier, player.Name)

	-- Causes the Veil to stay in front of the player
	VoRTable[userId].Task1 = task.spawn(function()
		while newBarrier and Health.Value > 0 do
			local BasePosition = humRP.CFrame * CFrame.new(0, 1.5, -4)
			AlignPosition.Position = Effects.ShakeAP(AlignPosition, BasePosition, nil, 0.1)
		end
	end)
	
	VoRTable[userId].Task2 = task.spawn(function()
		while newBarrier and Health.Value > 0 do
			local humanoidLookVector = humRP.CFrame.LookVector
			AlignOrientation.CFrame = CFrame.new(AlignOrientation.Parent.Position, AlignOrientation.Parent.Position + humanoidLookVector)
			AlignOrientation.CFrame = AlignOrientation.CFrame * CFrame.Angles(0, math.rad(90), 0)
			task.wait(0.1)
		end
	end)
	
	-- Causes the Veil to regenerate health
	VoRTable[userId].Task3 = task.spawn(function()
		while Health and Health.Parent and Health.Value > 0 do
			if Health.Value < MaxHealth.Value then
				Health.Value = Health.Value + REGEN_RATE
			end
			task.wait(INTERVAL)
		end
	end)
	
	-- Get current scale (usually 1 by default)
	local baseScale = ModelBarrier:GetScale()
	
	local HealthRecord = Health.Value
	-- Listens for health value changes
	VoRTable[userId].HealthListener = Health.Changed:Connect(function()
		if not newBarrier or not Health or not MaxHealth then return end
		
		if Health.Value <= 0 then Cleanup(); warn(`{newBarrier.Name} health depleted, cleaning up now`) return end

		-- Calculate new scale factor
		local sizeMultiplier = 1 + (math.max(0, Health.Value - 50) * 0.005)
		local newScale = baseScale * sizeMultiplier

		-- Scale the Model
		ModelBarrier:ScaleTo(newScale)
	
		if Health.Value < HealthRecord then newBarrier:FindFirstChild("Effects1"):FindFirstChild("Emitter"):Emit(1) 
			newBarrier:FindFirstChild("Hit"):FindFirstChild("PitchShiftSoundEffect").Octave = math.random(0.75, 1.25)
			newBarrier:FindFirstChild("Hit"):Play() 
		end; HealthRecord = Health.Value
	end)
	
	VoRTable[userId].ClearConnection = WeavingInstantReleaseEvent.OnClientEvent:Connect(function(UID, Weave)
		if UID ~= player.UserId then return end
		if Weave ~= "VeilOfReflection" then return end
		
		Cleanup()
		
	end)
	
end)