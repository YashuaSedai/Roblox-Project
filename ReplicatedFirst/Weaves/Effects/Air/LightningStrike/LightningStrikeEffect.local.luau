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
local BezierModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))
local DrawHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))
local Utility = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))

-- REMOTE
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- VFX
local LightningStrike = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("LightningStrike")

-- Helper function for randomizing
local function R(x,y)
	return math.random(x,y)
end

-- Helper function for validating instance
local function isValidInstance(instance)
	return instance and typeof(instance) == "Instance" and instance.Parent ~= nil
end

local function CleanupClient(InitializeTable, player, castId)
	local userId = player.UserId
	local entry = InitializeTable[userId]

	if not entry then return end

	local data = entry.Casts[castId]

	if not data or data.__cleaned then return end
	data.__cleaned = true
	data.active = false

	print(`[Lightning Strike Client] Cleaning up cast {castId} for {player.Name}`)

	-- Disconnect connections
	if data.connections then
		for name, conn in pairs(data.connections) do
			if conn then
				conn:Disconnect()
				data.connections[name] = nil
			end
		end
	end
	
	if data.folder then
		for i, v in data.folder:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
			
			if v:IsA("Part") then
				v.Anchored = true
			end
			
			if v:IsA("Sound") then
				EffectsSFX.FadeSound(v, 0, 1, 60)
			end
		end
	end

	-- Destroy folder after delay
	task.delay(5, function()
		if data.folder and isValidInstance(data.folder) then
			data.folder:Destroy()
		end
	end)

	-- Remove this specific cast
	entry.Casts[castId] = nil

	-- Remove player entry if no casts remain
	if next(entry.Casts) == nil then
		InitializeTable[userId] = nil
	end

	return true
end

local ScriptFx = {}
local CleanFx = {}

WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, castId)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  
	
	
	-- Checker for weaveName
	if weaveName ~= "LightningStrike" then return end
	
	-- Setup base references
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local elements = {"Fire", "Water", "Air"}
	
	-- Initialize Table
	if not ScriptFx[userId] then 
		ScriptFx[userId] = {
			Counter = 0,
			ExitCounter = 0,
			Casts = {},
		}
	end
	
	local entry = ScriptFx[userId]
	
	-- Create Cast State
	entry.Casts[castId] = {
		folder = nil,
		connections = {},
		tasks = {},
		trails = {},
		sounds = {},
		active = true,
		__cleaned = false,
	}
	
	local data = entry.Casts[castId]
	
	-- Required References
	local RightHand = char:FindFirstChild("RightHand")
	local LeftHand = char:FindFirstChild("LeftHand")
	
	-- Create Folder for Effects
	data.folder = Instance.new("Folder")
	data.folder.Name = "LightningFx "..player.Name.." "..castId
	data.folder.Parent = game.Workspace
	
	-- SCENE 1: Trails appear from the ground and rise up to the sky while the spell is held
	
	data.tasks.Task1 = task.spawn(function()
		while data.active do
			-- Setup Points:
			local PointsTable = {
				Point1 = humRP.Position + Vector3.new(R(-20, 20), -10, R(-20, 20)),
				Point2 = humRP.Position + Vector3.new(R(-20, 20), 0, R(-20, 20)),
				Point3 = humRP.Position + Vector3.new(R(-20, 20), 25, R(-20, 20)),
				Point4 = humRP.Position + Vector3.new(R(-20, 20), 75, R(-20, 20)),
				Point5 = humRP.Position + Vector3.new(R(-20, 20), 125, R(-20, 20)),
			}

			-- Create Trails
			local trail = Effects.CreateTrail2(elements[R(1,#elements)], data.folder, false, nil, nil, nil, CFrame.new(PointsTable.Point1))

			-- Create Sound
			local sfx = SFX:FindFirstChild("Magic Twirling Small High Pitch Spinning Chi (SFX)"):Clone()
			sfx.Parent = trail
			sfx.Volume = 0.25
			local pitch = Instance.new("PitchShiftSoundEffect")
			pitch.Octave = R(0.85, 1.15)
			pitch.Parent = sfx
			
			-- Play the Sound
			sfx:Play()
			
			-- Insert to data table for later manipulation
			table.insert(data.trails, trail)
			
			-- Create Tween Info
			local tweenInfo = TweenInfo.new(
				math.random(50, 150) / 100,
				Enum.EasingStyle.Cubic,
				Enum.EasingDirection.InOut
			)
			
			local bezier, tween = Utility.BezierSetup(PointsTable, true, trail, tweenInfo)
			tween:Play()
			
			-- Cleanup trail after completion
			tween.Completed:Once(function()
				trail.Anchored = true
				for _, emitter in trail:GetDescendants() do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = false
					end
				end

				task.delay(6, function()
					if isValidInstance(trail) then
						trail:Destroy()
					end
				end)

				Effects.NumberValueTweenObj(trail, "Trail", "Transparency", 0, 1, 1, 60)
			end)
			
			task.wait(0.25)
		end
	end)
	
	-- SCENE 2: Smoke and electricity emits from the character
	
	local FX = script.CasterEffect:Clone()
	FX.Position = char.Head.Position
	FX.Parent = data.folder
	
	local soundNames = {
		"wind sound effect",
		"Electrical charge up sound",
		"electricity cute",
	}

	for _, soundName in soundNames do
		local sound = SFX:FindFirstChild(soundName):Clone()
		sound.Looped = true
		sound.Parent = FX
		sound:Play()
		
		table.insert(data.sounds, sound)
	end
	
	
	data.connections.FXGlue = RunService.RenderStepped:Connect(function()
		local head = char:FindFirstChild("Head")
		if not head then
			CleanupClient(ScriptFx, player, castId)
			return
		end
		FX.Position = head.Position
	end)
	
	-- Clean-up once cast animation finishes
	data.connections.AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
		if weaveName ~= "LightningStrike" then return end
		if phase ~= "Cast" then return end
		if player.UserId ~= UserId then return end

		print("CAST ANIMATION PASSED")
		-- Clean Up
		CleanupClient(ScriptFx, player, castId)
	end)
	
	-- Fallbacks
	data.connections.Died = hum.Died:Connect(function()
		CleanupClient(ScriptFx, player, castId)
	end)

	data.connections.Clear = WeavingFxClear.OnClientEvent:Connect(function(UserId, weaveName, cancelled)
		if weaveName ~= "LightningStrike" or UserId ~= player.UserId then return end
		if cancelled then
			CleanupClient(ScriptFx, player, castId)
		else
			task.delay(5, function() CleanupClient(ScriptFx, player, castId) end)
		end
	end)
	
end)

-- Lightning Object, cast and forget
WeavingEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, mousePos, damage, area, castRange, maxCharge)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	-- Checker for weaveName
	if weaveName ~= "LightningStrike" then return end

	-- Setup base references
	local player = Players:GetPlayerFromCharacter(char)
	local userId = player.UserId
	local elements = {"Fire", "Water", "Air"}
	
	-- Duplicate Lightning Object
	local newLightning = LightningStrike:Clone()
	newLightning.Parent = workspace
	
	local basePosition = mousePos
	local peakHeight = 250

	for i = 0, 5 do
		local lightning = newLightning.Lightning[tostring(i)]
		local alpha = i / 5

		local height = peakHeight * alpha

		local x = 0
		local z = 0

		if i ~= 0 and i ~= 5 then
			x = R(-15, 15)
			z = R(-15, 15)
		end

		lightning.Position = basePosition + Vector3.new(x,height,z)
	end
	
	newLightning.Emitters.Emitters.CFrame = CFrame.new(mousePos)
	
	-- Raycast the Mark Emitter to the ground
	local rayOrigin = mousePos
	local rayDirection = Vector3.new(0, -1000, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result then
		newLightning.Emitters.Emitters.Mark.WorldPosition = result.Position + Vector3.new(0, 0.05, 0)
	end
	
	for i, v in newLightning.Emitters:GetDescendants() do
		if v:IsA("ParticleEmitter") and v:GetAttribute("EmitCount") then
			v:Emit(v:GetAttribute("EmitCount"))
		end
		
		if v:IsA("Sound") then
			v:Play()
		end
	end
	
	-- Shake Camera
	Effects.ShakeCamera(userId, true, nil, 6.5, 7, 0.25, 0.25)
	
	task.spawn(function()
		for i = 5, 0, -1 do
			local joint = newLightning.Lightning:FindFirstChild(tostring(i))

			if joint then
				joint:Destroy()
			end

			task.wait(0.05)
		end
	end)
	
	task.spawn(function()
		local light = newLightning.Emitters.Emitters.PointLight
		Effects.NumberValueTweenObj(light, "PointLight", "Brightness", light.Brightness, 0.25, 0, 60)
	end)
	
	task.delay(5, function()
		if newLightning then
			newLightning:Destroy()
		end
	end)
end)