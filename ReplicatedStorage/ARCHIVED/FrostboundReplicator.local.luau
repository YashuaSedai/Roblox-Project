---- SERVICES
--local ReplicatedStorage = game:GetService("ReplicatedStorage")
--local Players = game:GetService("Players")
--local RunService = game:GetService("RunService")

---- MODULES
--local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
--local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))
--local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
--local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))

---- REMOTE
--local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")

--local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

---- SOUNDS
--local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")


--local FrostboundFx = {} 

--WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, mousePos: Vector3, DAMAGE, DURATION, charge, LIFETIME, AREA, PROJECTILE_SPEED)
--	if not char then warn("Character not found") return end  
--	if not hum then warn("Humanoid not found") return end  
--	if not humRP then warn("HumanoidRootPart not found") return end  
--	if not weaveName then warn("WeaveName is missing") return end  

--	if weaveName ~= "Frostbound" then return end

--	local player = Players:GetPlayerFromCharacter(char)
--	if not player then return end -- Safety check

--	local UserId = player.UserId
--	local element_0 = "Water"
--	local element_1 = "Air"

--	-- Locate the projectile
--	local ProjFolder = hum:WaitForChild("FrostboundProjectile")
--	if not ProjFolder then warn("ProjectileFolder cannot be found") return end
--	ProjFolder.Parent = workspace

--	local Projectile = ProjFolder:WaitForChild("FrostboundEffect")
--	if not Projectile then return warn("Projectile cannot be found in the folder") end

--	-- Some reference
--	local Hitbox = Projectile:FindFirstChild("Hitbox")
--	local EffectContainer = Projectile:FindFirstChild("EffectContainer")

--	if not FrostboundFx[UserId] then 
--		FrostboundFx[UserId] = {}
--	end

--	-- Remove AlignPosition to make it loose
--	DebuffHandler.SetOwner(Hitbox, player.Name)

--	-- Setup Cleanup
--	local function Cleanup()

--		if Projectile then -- If projectile still exists
--			Projectile:Destroy()
--		end

--		if FrostboundFx[UserId] then
--			if FrostboundFx[UserId].Task1 then FrostboundFx[UserId].Task1 = nil end -- Ensure it's nil after canceling
--			if FrostboundFx[UserId].Connection then FrostboundFx[UserId].Connection:Disconnect() end
--			if FrostboundFx[UserId].AnimationConnection then FrostboundFx[UserId].AnimationConnection:Disconnect() end
--			FrostboundFx[UserId] = nil
--		end

--		if ProjFolder then ProjFolder:Destroy() end
--	end

--	-- Setup Damage Logic
--	local function DamageLogic(boolean)
--		-- Cancel the life counter
--		if boolean then task.cancel(FrostboundFx[UserId].Task1) end

--		Hitbox.Anchored = true

--		-- Play sounds
--		EffectContainer["Ice 2 SFX"]:Play()
--		EffectContainer["Ice Spread SFX"]:Play()

--		-- Shake Camera
--		Effects.ShakeCamera(UserId, true, nil, 3.5, 4, 0.5, 0.5)

--		-- Enemy damage logic
--		local EnemiesinRange = {}
--		for _, part in workspace:GetChildren() do -- Look for instances in the workspace
--			if part:IsA("Model") and part:FindFirstChild("Humanoid") -- confirm the model if the instance has a Humanoid child
--				and part.Name ~= Hitbox:GetAttribute("Owner")  -- Exclude the projectile owner
--			then
--				local char = part -- The part is a character if it has a humanoid child
--				local humanoidRootPart = char:FindFirstChild("HumanoidRootPart") -- Locate the root part of every character found
--				if humanoidRootPart then
--					local mag = (humanoidRootPart.Position - Hitbox.Position).magnitude -- Calculate the distance between the position of the hitbox and every hrp found

--					if mag < AREA and char.Name ~= Hitbox:GetAttribute("Owner") then -- if the magnitude is less than (or inside) the AREA

--						local raycastParams = RaycastParams.new()
--						raycastParams.FilterDescendantsInstances = {workspace.Barriers} 
--						raycastParams.FilterType = Enum.RaycastFilterType.Include
--						local direction = (humanoidRootPart.Position - Hitbox.Position).unit * AREA
--						local result = workspace:Raycast(Hitbox.Position, direction, raycastParams)


--						if result == nil then
--							table.insert(EnemiesinRange, char) -- Add the enemy in the table	
--						end
--					end
--				end	
--			end
--		end

--		-- Deal damage and handle status effects
--		for _, Enemies in EnemiesinRange do
--			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
--			DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)
--			DebuffHandler.FireFreeze(player, player.UserId, Enemies, DURATION)
--		end

--		-- Do Visual effects
--		-- Cast a downward ray from the hitbox
--		local rayOrigin = Hitbox.Position
--		local rayDirection = Vector3.new(0, -50, 0) -- Cast downwards with a length of 50 studs
--		local raycastParams = RaycastParams.new()
--		raycastParams.FilterDescendantsInstances = {workspace.Terrain, workspace.Baseplate} 
--		raycastParams.FilterType = Enum.RaycastFilterType.Include

--		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

--		if result then
--			local hitPart = result.Instance
--			local hitPosition = result.Position

--			EffectContainer.Parent = ProjFolder
--			local weld = EffectContainer:FindFirstChildOfClass("WeldConstraint"); if weld then weld:Destroy() end
--			EffectContainer.Anchored = true
--			EffectContainer.Position = hitPosition + Vector3.new(0, 0.75, 0)
--			EffectContainer.Snowy.Enabled = true

--			local sizePercentage =  (math.clamp(charge * 10, 0, 100) / 100) + 2.5
--			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Effect1, sizePercentage, 20, 0.1)
--			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Effect2, sizePercentage, 20, 0.1)
--			Effects.SmoothAdjustParticleSize(EffectContainer.AttachedEffects.Smoke, sizePercentage, 20, 0.1)
--			EffectContainer.AttachedEffects.Effect1:Emit(1)
--			EffectContainer.AttachedEffects.Effect2:Emit(1)
--			EffectContainer.AttachedEffects.Smoke:Emit(200)
--		end

--		Projectile.Ice.Enabled = false
--		Projectile.Mist.Enabled = false
--		Projectile.Mist2.Enabled = false
--		Projectile.Trail.Enabled = false
--		Projectile.Trail2.Enabled = false
--		Projectile.Trail3.Enabled = false
--		EffectContainer.Snowy.Enabled = false
--		Projectile.Anchored = true

--		task.delay(4, function()
--			Hitbox:Destroy()
--			Cleanup()
--		end)
--	end

--	-- Setup Hit connection
--	local Debounce = true  

--	if Hitbox then
--		FrostboundFx[UserId].Connection = Hitbox.Touched:Connect(function(hit)

--			if (hit.Parent:FindFirstChild("Humanoid") or hit:IsA("Part") or hit:IsA("Model")) 
--				and hit.Parent.Name ~= Hitbox:GetAttribute("Owner") 
--				and not hit:IsDescendantOf(workspace.Barriers) then

--				if Debounce then
--					Debounce = false
--					DamageLogic(true)
--				end

--			elseif hit:IsDescendantOf(workspace.Barriers) then -- if projectile hits a barrier
--				if Debounce then
--					Debounce = false
--					task.delay(0.1, function()
--						Debounce = true
--					end)

--					local VeilOfReflection = hit
--					local BarrierHealth = VeilOfReflection:FindFirstChild("Health")

--					-- Set new projectile owner
--					DebuffHandler.SetOwner(Hitbox, VeilOfReflection:GetAttribute("Owner"))

--					-- Retrieve LinearVelocity of the projectile
--					local LinearVelocity = Projectile:FindFirstChildOfClass("LinearVelocity")

--					if LinearVelocity then 
--						LinearVelocity.VectorVelocity = -LinearVelocity.VectorVelocity -- Flip direction
--					end

--					if BarrierHealth then DebuffHandler.DeductBarrierHealth(BarrierHealth, DAMAGE * 2) end
--				end
--			end
--		end)
--	end

--	-- Start countdown for projectile lifetime
--	FrostboundFx[UserId].Task1 = task.spawn(function()
--		local startTime = tick()

--		while tick() - startTime < LIFETIME do
--			local remainingTime = LIFETIME - (tick() - startTime)
--			task.wait(1) -- Wait 1 second before updating
--		end

--		if Hitbox then
--			DamageLogic(false)
--		end

--		if FrostboundFx[UserId].Task1 then FrostboundFx[UserId].Task1 = nil end
--	end)


--	-- Add a delay using the animation Signal before proceeding the code
--	FrostboundFx[UserId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
--		if weaveName ~= "Frostbound" then return end
--		if phase ~= "Cast" then return end
--		if player.UserId ~= UserId then return end

--		-- Unlock projectile and add velocity
--		if Projectile:FindFirstChild("AlignPosition") then Projectile:FindFirstChild("AlignPosition"):Destroy() end
--		local newLV = Instance.new("LinearVelocity")
--		newLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
--		local direction = (mousePos - Projectile.Position).unit
--		newLV.VectorVelocity = direction * PROJECTILE_SPEED
--		newLV.MaxForce = 10 -- adjust if requiring gravity simulation
--		newLV.Attachment0 = Projectile:FindFirstChild("LinearVelocityAttachment")
--		newLV.Parent = Projectile

--		if FrostboundFx[UserId] and FrostboundFx[UserId].AnimationConnection then FrostboundFx[UserId].AnimationConnection:Disconnect(); FrostboundFx[UserId].AnimationConnection = nil end
--	end)


--end)