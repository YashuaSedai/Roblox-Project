-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local EffectsSFX = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("SFX"))

-- REMOTE
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")

local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

local FireballEffect = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Fireball")

local Fireballfx = {} 
local FireballCleanup = {} 

WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, mousePos: Vector3, DAMAGE, DURATION, charge, LIFETIME, AREA, PROJECTILE_SPEED, DOT, force)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  
	
	if weaveName ~= "Fireball" then return end
	
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check
	
	local UserId = player.UserId
	local element = "Fire"
	
	warn(`PROJECTILE RELEASED`)
	
	-- Locate the projectile
	local ProjFolder = hum:FindFirstChild("FireballProjectile")
	if not ProjFolder then warn("FireballFolder cannot be found") return end
	ProjFolder.Parent = workspace
	
	local Projectile = ProjFolder:FindFirstChild("FireballEffect")
	if not Projectile then return warn("Projectile cannot be found in the folder") end
	
	if not Fireballfx[UserId] then 
		Fireballfx[UserId] = {}
	end
	
	-- Some reference
	local Hitbox = Projectile:FindFirstChild("Hitbox")
	local BurningEffect = FireballEffect:FindFirstChild("BurningEffect")
	local EffectContainer = FireballEffect:FindFirstChild("EffectContainer"):Clone()
	
	-- Set Projectile Owner
	DebuffHandler.SetOwner(Hitbox, player.Name)
	
	-- Setup Cleanup
	local function Cleanup()
		if Fireballfx[UserId] then
			
			local startTime = tick()  -- Start measuring time
			repeat
				task.wait()
			until FireballCleanup[UserId] == nil or tick() - startTime >= 1
			
			FireballCleanup[UserId] = FireballCleanup[UserId]
			Fireballfx[UserId] = nil
			
			if FireballCleanup[UserId] then
				if FireballCleanup[UserId].TempTask then task.cancel(FireballCleanup[UserId].TempTask) end
				
				FireballCleanup[UserId].TempTask = task.spawn(function()
					if FireballCleanup[UserId].Connection then FireballCleanup[UserId].Connection:Disconnect() end
					if FireballCleanup[UserId].Task1 then FireballCleanup[UserId].Task1 = nil end 
					if FireballCleanup[UserId] and FireballCleanup[UserId].AnimationConnection then FireballCleanup[UserId].AnimationConnection:Disconnect(); FireballCleanup[UserId].AnimationConnection = nil end
					FireballCleanup[UserId] = nil
				end)
			end
		end

		if ProjFolder then ProjFolder:Destroy() end
	end
	
	local function DamageLogic(boolean)
		-- Try to cancel Life counter immediately
		if boolean and Fireballfx[UserId] then 
			Fireballfx[UserId].Task1Running = false -- Stop the loop
			if Fireballfx[UserId].Task1 then
				print("Canceling Fireball Task")
				task.cancel(Fireballfx[UserId].Task1) -- This will cancel if the task is waiting
				Fireballfx[UserId].Task1 = nil
			end
		elseif boolean and FireballCleanup[UserId] then 
			FireballCleanup[UserId].Task1Running = false
			if FireballCleanup[UserId].Task1 then
				print("Canceling Cleanup Task")
				task.cancel(FireballCleanup[UserId].Task1)
				FireballCleanup[UserId].Task1 = nil
			end
		end
		
		
		Hitbox.Anchored = true	
		Effects.NumberValueTweenObj(Projectile, "Part", "Transparency", 0, 1, 1, 10)
		
		-- Turn off Emitters
		for _, emitters in Projectile:GetChildren() do
			if emitters:IsA("ParticleEmitter") then
				emitters.Enabled = false
				Effects.NumberValueTweenObj(emitters, "ParticleEmitter", "Transparency", 0, 1, 1, 10)
			end
		end
		
		-- Shake Camera
		Effects.ShakeCamera(UserId, true, nil, 6.5, 7, 0.25, 0.25)

		-- Play sound
		local Explosion1 = SFX["Big Explosion"]:Clone(); Explosion1.Parent = Projectile; Explosion1:Play()
		local Explosion2 = SFX["ExplosionSfx"]:Clone(); Explosion2.Parent = Projectile; Explosion2:Play()

		-- Store Enemies within range
		local EnemiesinRange = {}
			for _, part in workspace:GetChildren() do -- Look for instances in the workspace
				if part:IsA("Model") and part:FindFirstChild("Humanoid") -- confirm the model if the instance has a Humanoid child
					and part.Name ~= Hitbox:GetAttribute("Owner")  -- Exclude the projectile owner
				then
					local char = part -- The part is a character if it has a humanoid child
					local humanoidRootPart = char:FindFirstChild("HumanoidRootPart") -- Locate the root part of every character found
					if humanoidRootPart then
						local mag = (humanoidRootPart.Position - Hitbox.Position).magnitude -- Calculate the distance between the position of the hitbox and every hrp found

						if mag < AREA and char.Name ~= Hitbox:GetAttribute("Owner") then -- if the magnitude is less than (or inside) the AREA

							local raycastParams = RaycastParams.new()
							raycastParams.FilterDescendantsInstances = {workspace.Barriers} 
							raycastParams.FilterType = Enum.RaycastFilterType.Include
							local direction = (humanoidRootPart.Position - Hitbox.Position).unit * AREA
							local result = workspace:Raycast(Hitbox.Position, direction, raycastParams)


							if result == nil then
								table.insert(EnemiesinRange, char) -- Add the enemy in the table	
							end
							
						end
					end	
				end
			end
		
		
		-- Deal damage and handle status effects
		for _, Enemies in EnemiesinRange do
			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
			local EnemyRootPart = Enemies:FindFirstChild("HumanoidRootPart")

			-- Burn Enemies
			task.spawn(function() DebuffHandler.FireDoT(player, player.UserId, EnemyHumanoid, DOT, DURATION, 0.1) end) 

			-- Create Burning Visual Effect
			local newBurn = BurningEffect:Clone()
			newBurn.Parent = ProjFolder
			newBurn.CFrame = EnemyRootPart.CFrame
			newBurn.WeldConstraint.Part0 = EnemyRootPart

			-- Create Burning Sfx
			local FireCrackingSFX = SFX["Fireplace Constant Burning Flame 4 (SFX)"]:Clone()
			FireCrackingSFX.Parent = EnemyRootPart
			local FlameLoopSFX = SFX["Flamethrower Loop"]:Clone()
			FlameLoopSFX.Parent = EnemyRootPart
			local WhooshSFX = SFX["Magic Whooshes Growly Magic Whooshes Airy Gu (SFX)"]:Clone()
			WhooshSFX.Parent = EnemyRootPart

			FireCrackingSFX:Play()
			FlameLoopSFX:Play()
			WhooshSFX:Play()

			-- Burning Cleanup
			task.spawn(function()
				task.delay(DURATION, function()

					EffectsSFX.FadeSound(FireCrackingSFX, 0, 1, 10)
					EffectsSFX.FadeSound(FlameLoopSFX, 0, 1, 10)
					EffectsSFX.FadeSound(WhooshSFX, 0, 1, 10)

					Debris:AddItem(FireCrackingSFX, 1)
					Debris:AddItem(FlameLoopSFX, 1)
					Debris:AddItem(WhooshSFX, 1)

					for _, emitters in newBurn:GetChildren() do
						if emitters:IsA("ParticleEmitter") then
							emitters.Enabled = false
						end
					end
				end)
			end)
		end

		-- Cast a downward ray from the hitbox Vfx
		local rayOrigin = Projectile.Position + Vector3.new(0, 5, 0)
		local rayDirection = Vector3.new(0, -50, 0) -- Cast downwards with a length of 50 studs
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {workspace.Terrain, workspace.Baseplate} 
		raycastParams.FilterType = Enum.RaycastFilterType.Include

		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if result then
			local hitPart = result.Instance
			local hitPosition = result.Position
			local hitMaterial = hitPart.Material
			local hitColor = hitPart.Color

			-- Create blocks upon explosion
			local Bits = FireballEffect:FindFirstChild("Bits") 
			Effects.CreateExplosion(Bits, hitPosition, 10 * charge, {Min = 0.5, Max = 0.75}, 10 * charge, 4, hitMaterial, hitColor, 50)

			EffectContainer.Parent = ProjFolder
			EffectContainer.Anchored = true
			EffectContainer.CFrame = CFrame.new(hitPosition) * CFrame.new(0, 0.75, 0)

			local sizePercentage =  (math.clamp(charge * 5, 0, 100) / 100) + 1
			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Effect1, sizePercentage, 1, 0.1)
			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Effect2, sizePercentage, 1, 0.1)
			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Effect3, sizePercentage, 1, 0.1)
			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Smoke, sizePercentage, 1, 0.1)
			EffectContainer.AttachedEffects.Effect1:Emit(1)
			EffectContainer.AttachedEffects.Effect2:Emit(2)
			EffectContainer.AttachedEffects.Effect3:Emit(3)
			EffectContainer.AttachedEffects.Smoke:Emit(100)
			
			local LightSize = {NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 10)}
			EffectContainer.AttachedEffects.Light.Size = Effects.ScaleNumberSequence(LightSize, sizePercentage)
			EffectContainer.AttachedEffects.Light:Emit(5)

		end
		
		-- Deal damage and handle status effects
		for _, Enemies in EnemiesinRange do
			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
			-- Deal initial blast damage
			DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)

			-- Knockback enemies
			DebuffHandler.FireKnockback(player, workspace:FindFirstChild(Hitbox:GetAttribute("Owner"), true):FindFirstChild("HumanoidRootPart"), Enemies, 1.75, 
				math.clamp(force, 4000, 5000), 2.5, 10)
		end

		Debris:AddItem(Projectile, DURATION)
		task.delay(DURATION, function()
			Cleanup()
		end)
		
	end
	
	-- Setup Hit connection
	local Debounce = true  

	if Hitbox then
		Fireballfx[UserId].Connection = Hitbox.Touched:Connect(function(hit)

			if ((hit.Parent and hit.Parent:FindFirstChild("Humanoid")) or hit:IsA("Part") or hit:IsA("Model")) 
				and hit.Parent.Name ~= Hitbox:GetAttribute("Owner") 
				and not hit:IsDescendantOf(workspace.Barriers) then
				if Debounce then
					Debounce = false
					DamageLogic(true)
				end

			elseif hit:IsDescendantOf(workspace.Barriers) then -- if projectile hits a barrier
				if Debounce then
					Debounce = false
					task.delay(0.05, function()
						Debounce = true
					end)

					local VeilOfReflection = hit
					local BarrierHealth = VeilOfReflection:FindFirstChild("Health")

					-- Set new projectile owner
					DebuffHandler.SetOwner(Hitbox, VeilOfReflection:GetAttribute("Owner"))

					-- Retrieve LinearVelocity of the projectile
					local LinearVelocity = Projectile:FindFirstChildOfClass("LinearVelocity")

					if LinearVelocity then 
						--LinearVelocity.VectorVelocity = -LinearVelocity.VectorVelocity -- Flip direction
						 
						LinearVelocity.LineDirection = Vector3.new(-LinearVelocity.LineDirection.X, LinearVelocity.LineDirection.Y, -LinearVelocity.LineDirection.Z).Unit -- Use new direction
						LinearVelocity.LineVelocity = Vector3.new(-LinearVelocity.LineDirection.X, LinearVelocity.LineDirection.Y, -LinearVelocity.LineDirection.Z).Magnitude * (PROJECTILE_SPEED/3) -- Keep original speed

					end

					if BarrierHealth then DebuffHandler.DeductBarrierHealth(BarrierHealth, DAMAGE * 2) end
				end
			end
		end)
	end
	
	-- Start countdown for projectile lifetime
	Fireballfx[UserId].Task1Running = true -- Add this flag

	Fireballfx[UserId].Task1 = task.spawn(function()
		local startTime = tick()

		while Fireballfx[UserId] and Fireballfx[UserId].Task1Running and (tick() - startTime < LIFETIME) do
			task.wait(1) -- Wait 1 second before updating
		end

		if Fireballfx[UserId] and Fireballfx[UserId].Task1Running then
			if Projectile then
				DamageLogic(false)
			end
		end

		-- Cleanup task reference properly
		if Fireballfx[UserId] then Fireballfx[UserId].Task1 = nil end
		if FireballCleanup[UserId] then FireballCleanup[UserId].Task1 = nil end
	end)

	-- Add a delay using the animation Signal before proceeding the code
	Fireballfx[UserId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
		if weaveName ~= "Fireball" then return end
		if phase ~= "Cast" then return end
		if player.UserId ~= UserId then return end

		-- Unlock projectile and add velocity
		if Projectile:FindFirstChild("AlignPosition") then Projectile:FindFirstChild("AlignPosition"):Destroy() end
		local newLV = Instance.new("LinearVelocity")
		newLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
		local direction = (mousePos - Projectile.Position).unit
		local yCorrection = 0.2 -- Adjust this value to tweak accuracy

		direction = Vector3.new(direction.X, direction.Y + yCorrection, direction.Z).unit
	--	newLV.VectorVelocity = direction * PROJECTILE_SPEED
		newLV.LineDirection = direction
		newLV.LineVelocity = PROJECTILE_SPEED
		newLV.MaxForce = 1000 -- adjust if requiring gravity simulation
		newLV.Attachment0 = Projectile:FindFirstChild("LinearVelocityAttachment")
		newLV.Parent = Projectile
		
		-- Play Sounds
		local Takeoff = SFX["Loki Invisibility"]:Clone(); Takeoff.Parent = ProjFolder; Takeoff:Play()

		if Fireballfx[UserId] and Fireballfx[UserId].AnimationConnection then Fireballfx[UserId].AnimationConnection:Disconnect(); Fireballfx[UserId].AnimationConnection = nil end
	end)
	
end)