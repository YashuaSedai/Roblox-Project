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

WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, mousePos: Vector3, DAMAGE, LIFETIME, PROJECTILE_SPEED)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  

	if weaveName ~= "WindCutter" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check
	
	local UserId = player.UserId
	local element = "Air"
	
	-- Locate the projectile
	local ProjFolder = hum:WaitForChild("WindCutterProjectile")
	if not ProjFolder then warn("ProjectileFolder cannot be found") return end
	ProjFolder.Parent = workspace
	
	local Projectile = ProjFolder:WaitForChild("WindCutterEffect")
	if not Projectile then return warn("Projectile cannot be found in the folder") end
	
	if not ScriptFx[UserId] then 
		ScriptFx[UserId] = {}
	end
	
	-- Make it constantly spin
	local AlignOri = Projectile:FindFirstChildOfClass("AlignOrientation")
	local rotationAngle = 0
	local tiltAngle = math.rad(90) -- Tilt to make it flat
	AlignOri.Enabled = true
	--AlignOri.CFrame = CFrame.new(Projectile.Position) * CFrame.Angles(0, 0, tiltAngle) -- Set tilt once
	ScriptFx[UserId].SpinConnection = RunService.Heartbeat:Connect(function()
		if AlignOri then
			rotationAngle = rotationAngle - math.rad(10)

			-- First tilt to make it flat, THEN spin along the Y-axis
			AlignOri.CFrame = CFrame.new(Projectile.Position) 
				* CFrame.Angles(0, 0, tiltAngle) -- Tilt first
				* CFrame.Angles(rotationAngle, 0, 0) -- Then spin along Y-axis
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
		if boolean then task.cancel(ScriptFx[UserId].Task1) end
		
		-- Sound options
		local soundOptions = {
			"sword enemy hit",
			"sword_hit_hi_armor_hi_dmg_1"
		}

		-- Randomly pick a sound
		local randomSound = soundOptions[math.random(1, #soundOptions)]

		-- Clone, play, and remove after playing
		if Projectile:FindFirstChild(randomSound) then
			local soundClone = Projectile[randomSound]:Clone()
			soundClone.Parent = Projectile
			soundClone:Play()

			-- Destroy after it finishes playing
			soundClone.Ended:Connect(function()
				soundClone:Destroy()
			end)
		end
		
		-- Shake Camera

		-- Enemy damage logic
		local EnemiesinRange = {}
		table.insert(EnemiesinRange, target) -- Add the enemy in the table	

		-- Deal damage and handle status effects
		for _, Enemies in EnemiesinRange do
			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
			DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)
		end

		task.delay(LIFETIME, function()
			-- Destroy projectile?
			Cleanup()
		end)
	end
	
	local DebounceTable = {}

	if Projectile then
		ScriptFx[UserId].Connection = Projectile.Touched:Connect(function(hit)
			if (hit.Parent:FindFirstChild("Humanoid") or hit:IsA("Part") or hit:IsA("Model")) 
				and hit.Parent.Name ~= Projectile:GetAttribute("Owner") 
				and not hit:IsDescendantOf(workspace.Barriers) then

				local targetchar = hit.Parent

				-- Use target as key in the debounce table
				if not DebounceTable[targetchar] then
					DebounceTable[targetchar] = true
					DamageLogic(true, targetchar)

					-- Reset debounce for this target after 0.4 seconds
					task.delay(0.4, function()
						DebounceTable[targetchar] = nil
					end)
				end

			elseif hit:IsDescendantOf(workspace.Barriers) then
				if not DebounceTable["Barrier"] then
					DebounceTable["Barrier"] = true
					task.delay(0.1, function()
						DebounceTable["Barrier"] = nil
					end)

					local VeilOfReflection = hit
					local BarrierHealth = VeilOfReflection:FindFirstChild("Health")

					-- Set new projectile owner
					DebuffHandler.SetOwner(Projectile, VeilOfReflection:GetAttribute("Owner"))

					-- Retrieve LinearVelocity of the projectile
					local LinearVelocity = Projectile:FindFirstChildOfClass("LinearVelocity")

					if LinearVelocity then 
						LinearVelocity.VectorVelocity = -LinearVelocity.VectorVelocity -- Flip direction
					end

					if BarrierHealth then 
						DebuffHandler.DeductBarrierHealth(BarrierHealth, DAMAGE) 
					end
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
		if weaveName ~= "WindCutter" then return end
		if phase ~= "Cast" then return end
		if player.UserId ~= UserId then return end

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