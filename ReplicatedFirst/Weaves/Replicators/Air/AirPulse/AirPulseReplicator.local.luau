-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))

-- REMOTE
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")

local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")


local ScriptFx = {} 
local CleanFx = {}

WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, mousePos: Vector3, DAMAGE, LIFETIME, PROJECTILE_SPEED, charge, force)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "AirPulse" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local UserId = player.UserId
	local element = "Air"

	-- Locate the projectile
	local ProjFolder = hum:WaitForChild("AirPulseProjectile")
	if not ProjFolder then warn("ProjectileFolder cannot be found") return end
	ProjFolder.Parent = workspace

	local Projectile = ProjFolder:WaitForChild("AirPulseEffect")
	if not Projectile then return warn("Projectile cannot be found in the folder") end

	if not ScriptFx[UserId] then 
		ScriptFx[UserId] = {}
	end

	-- Make it constantly spin
	local AlignOri = Projectile:FindFirstChildOfClass("AlignOrientation")
	local rotationAngle = 0
	local tiltAngle = math.rad(0) -- Tilt to make it flat
	AlignOri.Enabled = true
	--AlignOri.CFrame = CFrame.new(Projectile.Position) * CFrame.Angles(0, 0, tiltAngle) -- Set tilt once
	ScriptFx[UserId].SpinConnection = RunService.Heartbeat:Connect(function()
		if AlignOri then
			rotationAngle = rotationAngle + math.rad(20)

			-- First tilt to make it flat, THEN spin along the Y-axis
			AlignOri.CFrame = CFrame.new(Projectile.Position) 
				* CFrame.Angles(0, 0, tiltAngle) -- Tilt first
				* CFrame.Angles(0, 0, rotationAngle) -- Then spin along Z-axis
		end
	end)


	-- Remove AlignPosition to make it loose
	DebuffHandler.SetOwner(Projectile, player.Name)

	-- Setup Cleanup
	local function Cleanup()

		if Projectile then -- If projectile still exists
			Projectile:Destroy()
		end

		if ScriptFx[UserId] then
			if ScriptFx[UserId].Task1 then ScriptFx[UserId].Task1 = nil end -- Ensure it's nil after canceling
			if ScriptFx[UserId].SpinConnection then ScriptFx[UserId].SpinConnection:Disconnect() end
			if ScriptFx[UserId].Connection then ScriptFx[UserId].Connection:Disconnect() end
			if ScriptFx[UserId].AnimationConnection then ScriptFx[UserId].AnimationConnection:Disconnect() end
			ScriptFx[UserId] = nil
		end

		if ProjFolder then ProjFolder:Destroy() end
	end

	-- Setup Damage Logic
	local function DamageLogic(boolean, target)
		-- Cancel the life counter
		if boolean and ScriptFx[UserId] and ScriptFx[UserId].Task1 then
			task.cancel(ScriptFx[UserId].Task1)
		end

		-- Anchor Projectile
		Projectile.Anchored = true
		Effects.NumberValueTweenObj(Projectile, "", "Transparency", 1, 1, 0, 20)

		-- Stop spinning
		if ScriptFx[UserId] then
			if ScriptFx[UserId].SpinConnection then ScriptFx[UserId].SpinConnection:Disconnect() end
		end

		-- Emit hit Particles
		local ParticleEmitters = Projectile.Effect
		for _, effect in ParticleEmitters:GetChildren() do
			if effect:IsA("ParticleEmitter") then
				effect:Emit(5)
			end
		end

		-- Create and Play sound effects
		local Sfx1 = SFX["Smoke_Teleport_Poof_4"]:Clone()
		Sfx1.Parent = Projectile
		Sfx1:Play()

		-- Shake Camera
		for _, people in workspace:GetChildren() do
			if people:FindFirstChild("Humanoid") then
				local peoplePlayer = Players:GetPlayerFromCharacter(people)
				if peoplePlayer then
					local peopleRootPart = people:FindFirstChild("HumanoidRootPart")
					local distance = (Projectile.Position - peopleRootPart.Position).Magnitude
					if distance <= 100 then
						Effects.ShakeCamera(peoplePlayer.UserId, true, nil, 3.5, 2, 0.5, 0.5)
					end
				end
			end
		end

		-- If no valid target or humanoid, stop here
		if not target or not target:FindFirstChild("Humanoid") then
			task.delay(1.5, Cleanup) -- Still cleanup but after effects
			return
		end

		-- Enemy damage logic
		local EnemiesinRange = {}
		table.insert(EnemiesinRange, target) -- Add the enemy in the table	

		-- Deal damage and handle status effects
		for _, Enemies in EnemiesinRange do
			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
			if EnemyHumanoid then
				DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)
				-- Knockback enemies
				DebuffHandler.FireKnockback(player, workspace:FindFirstChild(Projectile:GetAttribute("Owner"), true):FindFirstChild("HumanoidRootPart"), Enemies, 1.75, 
					math.clamp(force, 4000, 5000), 2.5, 5)
			end
		end

		task.delay(1.5, Cleanup)
	end

	local Debounce = false

	if Projectile then
		ScriptFx[UserId].Connection = Projectile.Touched:Connect(function(hit)
			if (hit.Parent:FindFirstChild("Humanoid") or hit:IsA("Part") or hit:IsA("Model")) 
				and hit.Parent.Name ~= Projectile:GetAttribute("Owner") 
				and not hit:IsDescendantOf(workspace.Barriers) then

				local targetchar = hit.Parent

				-- Use target as key in the debounce table
				if not Debounce then
					Debounce = true
					DamageLogic(true, targetchar)
				end

			elseif hit:IsDescendantOf(workspace.Barriers) then
				if not Debounce then
					Debounce = true
					DamageLogic(true, nil)
				end
			end
		end)
	end

	-- Start countdown for projectile lifetime
	ScriptFx[UserId].Task1 = task.spawn(function()
		local startTime = tick()

		while tick() - startTime < LIFETIME do
			local remainingTime = LIFETIME - (tick() - startTime)
			task.wait(1) -- Wait 1 second before updating
		end

		if Projectile then
			DamageLogic(false)
		end

		if ScriptFx[UserId] and ScriptFx[UserId].Task1 then ScriptFx[UserId].Task1 = nil end
	end)

	-- Add a delay using the animation Signal before proceeding the code
	ScriptFx[UserId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
		if weaveName ~= "AirPulse" then return end
		if phase ~= "Cast" then return end
		if player.UserId ~= UserId then return end
		
		print(`Passed`)

		-- Unlock projectile and add velocity
		Projectile.Anchored = false
		if Projectile:FindFirstChild("AlignPosition") then Projectile:FindFirstChild("AlignPosition"):Destroy() end
		local newLV = Instance.new("LinearVelocity")
		newLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		local direction = (mousePos - Projectile.Position).unit
		newLV.VectorVelocity = direction * PROJECTILE_SPEED
		newLV.MaxForce = 10 -- adjust if requiring gravity simulation
		newLV.Attachment0 = Projectile:FindFirstChild("LinearVelocityAttachment")
		newLV.Parent = Projectile

		if ScriptFx[UserId] and ScriptFx[UserId].AnimationConnection then ScriptFx[UserId].AnimationConnection:Disconnect(); ScriptFx[UserId].AnimationConnection = nil end
	end)

end)