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

local BoulderFx = {} 

WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, mousePos: Vector3, DAMAGE, DURATION, charge, LIFETIME, AREA, PROJECTILE_SPEED, force)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "Boulder" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local UserId = player.UserId
	local element = "Earth"

	-- Locate the projectile
	local ProjFolder = hum:FindFirstChild("BoulderProjectile")
	if not ProjFolder then warn("BoulderFolder cannot be found") return end
	ProjFolder.Parent = workspace

	local Projectile = ProjFolder:FindFirstChild("BoulderEffect")
	if not Projectile then return warn("Projectile cannot be found in the folder") end

	-- Some reference
	local EffectContainer = Projectile:FindFirstChild("EffectContainer")

	if not BoulderFx[UserId] then 
		BoulderFx[UserId] = {}
	end

	-- Set Projectile Owner
	DebuffHandler.SetOwner(Projectile, player.Name)
	
	-- Setup Cleanup
	local function Cleanup()
		if BoulderFx[UserId] then
			if BoulderFx[UserId].Connection then BoulderFx[UserId].Connection:Disconnect() end
			if BoulderFx[UserId].Task1 then BoulderFx[UserId].Task1 = nil end 
			if BoulderFx[UserId] and BoulderFx[UserId].AnimationConnection then BoulderFx[UserId].AnimationConnection:Disconnect(); BoulderFx[UserId].AnimationConnection = nil end
			BoulderFx[UserId] = nil
		end

		if ProjFolder then ProjFolder:Destroy() end
	end
	
	-- Setup Damage Logic
	local function DamageLogic(boolean)
		
		-- Try to cancel Life counter immediately
		if boolean and BoulderFx[UserId].Task1 then task.cancel(BoulderFx[UserId].Task1) end
		
		Projectile.Transparency = 1 -- Set actual boulder to invisible
		-- Shake Camera
		Effects.ShakeCamera(UserId, true, nil, 3.5, 4, 0.5, 0.5)
		
		-- Play sound
		local ExplosionSfx = SFX:FindFirstChild("Earthquake Explosion 1 (SFX)"):Clone(); ExplosionSfx.Parent = EffectContainer
		ExplosionSfx:Play()
		
		-- Store Enemies within range
		local EnemiesinRange = {}
		for _, part in workspace:GetChildren() do -- Look for instances in the workspace
			if part:IsA("Model") and part:FindFirstChild("Humanoid") -- confirm the model if the instance has a Humanoid child
				and part.Name ~= Projectile:GetAttribute("Owner")  -- Exclude the projectile owner
			then
				local char = part -- The part is a character if it has a humanoid child
				local humanoidRootPart = char:FindFirstChild("HumanoidRootPart") -- Locate the root part of every character found
				if humanoidRootPart then
					local mag = (humanoidRootPart.Position - Projectile.Position).magnitude -- Calculate the distance between the position of the hitbox and every hrp found

					if mag < AREA and char.Name ~= Projectile:GetAttribute("Owner") then -- if the magnitude is less than (or inside) the AREA
						
						local raycastParams = RaycastParams.new()
						raycastParams.FilterDescendantsInstances = {workspace.Barriers} 
						raycastParams.FilterType = Enum.RaycastFilterType.Include
						local direction = (humanoidRootPart.Position - Projectile.Position).unit * AREA
						local result = workspace:Raycast(Projectile.Position, direction, raycastParams)


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
			DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)
			
			DebuffHandler.FireKnockback(player, workspace:FindFirstChild(Projectile:GetAttribute("Owner"), true):FindFirstChild("HumanoidRootPart"), Enemies, 1.75, 
				math.clamp(force, 4000, 5000), 2.5, 10)
		end
		
		-- Cast a downward ray from the hitbox
		local rayOrigin = Projectile.Position
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
			Effects.CreateExplosion(nil, hitPosition, 10 * charge, {Min = 1, Max = 1.5}, 7.5 * charge, 4, hitMaterial, hitColor)

			EffectContainer.Parent = ProjFolder
			local weld = EffectContainer:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
			EffectContainer.Anchored = true
			EffectContainer.CFrame = CFrame.new(hitPosition) * CFrame.new(0, 0.75, 0)

			local sizePercentage =  (math.clamp(charge, 0, 100) / 100) + 2
			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Effect1, sizePercentage, 1, 0.1)
			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Smoke, sizePercentage, 1, 0.1)
			EffectContainer.AttachedEffects.Effect1:Emit(1)
			EffectContainer.AttachedEffects.Smoke:Emit(200)
			
		end
		
		task.delay(7, function()
			Projectile:Destroy()
			Cleanup()
		end)
		
	end
	
	-- Setup Hit connection
	local Debounce = true  
	if Projectile then
		BoulderFx[UserId].Connection = Projectile.Touched:Connect(function(hit)
			
			if (hit.Parent:FindFirstChild("Humanoid") or hit:IsA("Part") or hit:IsA("Model")) 
				and hit.Parent.Name ~= Projectile:GetAttribute("Owner") 
				and not hit:IsDescendantOf(workspace.Barriers) then
				if Debounce then
					Debounce = false
					DamageLogic(true)
				end
				
			elseif hit:IsDescendantOf(workspace.Barriers) then -- if projectile hits a barrier
				if Debounce then
					Debounce = false
					task.delay(0.1, function()
						Debounce = true
					end)
					
					local VeilOfReflection = hit
					local BarrierHealth = VeilOfReflection:FindFirstChild("Health")

					-- Set new projectile owner
					DebuffHandler.SetOwner(Projectile, VeilOfReflection:GetAttribute("Owner"))

					-- Retrieve LinearVelocity of the projectile
					local LinearVelocity = Projectile:FindFirstChildOfClass("LinearVelocity")

					if LinearVelocity then 
						LinearVelocity.VectorVelocity = Vector3.new(-LinearVelocity.VectorVelocity.X, LinearVelocity.VectorVelocity.Y, -LinearVelocity.VectorVelocity.Z)  -- Flip direction
					end

					-- Deduct barrier Health
					if BarrierHealth then DebuffHandler.DeductBarrierHealth(BarrierHealth, DAMAGE * 2) end
				end
			end
		end)
	end
	
	-- Start countdown for projectile lifetime
	BoulderFx[UserId].Task1 = task.spawn(function()
		local startTime = tick()

		while tick() - startTime < LIFETIME do
			local remainingTime = LIFETIME - (tick() - startTime)
			task.wait(1) -- Wait 1 second before updating
		end

		if Projectile then
			DamageLogic(false)
		end
		
		if BoulderFx[UserId].Task1 then BoulderFx[UserId].Task1 = nil end
	end)


	-- Add a delay using the animation Signal before proceeding the code
	BoulderFx[UserId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
		if weaveName ~= "Boulder" then return end
		if phase ~= "Cast" then return end
		if player.UserId ~= UserId then return end

		-- Unlock projectile and add velocity
		if Projectile:FindFirstChild("AlignPosition") then Projectile:FindFirstChild("AlignPosition"):Destroy() end
		local newLV = Instance.new("LinearVelocity")
		newLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		local direction = (mousePos - Projectile.Position).unit
		newLV.VectorVelocity = direction * PROJECTILE_SPEED
		newLV.MaxForce = 1000  -- adjust if requiring gravity simulation
		newLV.Attachment0 = Projectile:FindFirstChild("LinearVelocityAttachment")
		newLV.Parent = Projectile

		if BoulderFx[UserId] and BoulderFx[UserId].AnimationConnection then BoulderFx[UserId].AnimationConnection:Disconnect(); BoulderFx[UserId].AnimationConnection = nil end
	end)
		
end)