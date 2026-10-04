-- ReplicatedFirst > Weaves > Replicators > Air > WindCutter > WindCutterReplicator   (LocalScript)
-- Replaces the whole old file.
--
-- VISUALS ONLY. No damage, no DebuffHandler, no Touched. The server says where the blade is
-- ("Launch" / "Redirect"), when it cut someone ("Hit") and when it ended ("Impact").
-- The held blade is still created by WindCutterEffect; at "Launch" we take it over and fly it.

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- REMOTE
local ProjectileEvent = ReplicatedStorage:WaitForChild("SYSTEM")
	:WaitForChild("ModuleScripts")
	:WaitForChild("WeavingModule")
	:WaitForChild("ProjectileEvent")

local WEAVE = "WindCutter"
local HIT_SOUNDS = { "sword enemy hit", "sword_hit_hi_armor_hi_dmg_1" } -- children of the blade part
local SPIN_SPEED = math.rad(600)                -- radians per second (the old script did 10 degrees per frame at 60 fps)
local TILT = CFrame.Angles(0, 0, math.rad(90))  -- lays the blade flat, same as the old script

local flights = {} -- [id] = { blade, folder, connection, origin, direction, speed, serverTime, lifetime, spin }

-- finds the held blade that WindCutterEffect made for this caster
local function getHeld(ownerUserId)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local char = owner and owner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local folder = hum and hum:FindFirstChild("WindCutterProjectile")
	local blade = folder and folder:FindFirstChild("WindCutterEffect")
	return folder, blade
end

local function destroyFlight(id)
	local flight = flights[id]
	if not flight then return end
	flights[id] = nil
	if flight.connection then flight.connection:Disconnect() end
	if flight.folder then flight.folder:Destroy() end
end

-- LAUNCH: take over the held blade and fly it along the server's line
local function onLaunch(id, ownerUserId, origin, direction, speed, lifetime, serverTime)
	local folder, blade = getHeld(ownerUserId)
	if not blade then return end -- no held blade (joined mid-cast): nothing to show

	folder.Parent = workspace

	-- the constraints held the blade at the hand; we move it ourselves now
	local alignPosition = blade:FindFirstChildOfClass("AlignPosition")
	if alignPosition then alignPosition:Destroy() end
	local alignOrientation = blade:FindFirstChildOfClass("AlignOrientation")
	if alignOrientation then alignOrientation:Destroy() end
	blade.Anchored = true

	local flight = {
		blade = blade,
		folder = folder,
		origin = origin,
		direction = direction,
		speed = speed,
		serverTime = serverTime,
		lifetime = lifetime,
		spin = 0,
	}
	flights[id] = flight

	flight.connection = RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow() - flight.serverTime
		if t > flight.lifetime + 2 then
			destroyFlight(id) -- failsafe: the server's Impact never arrived
			return
		end
		t = math.clamp(t, 0, flight.lifetime)

		flight.spin -= SPIN_SPEED * dt
		local position = flight.origin + flight.direction * flight.speed * t
		blade:PivotTo(CFrame.new(position) * TILT * CFrame.Angles(flight.spin, 0, 0))
	end)
end

-- REDIRECT: the server bounced the blade (barrier); continue from its new line
local function onRedirect(id, position, direction, speed, serverTime, lifetimeLeft)
	local flight = flights[id]
	if not flight then return end
	flight.origin = position
	flight.direction = direction
	flight.speed = speed
	flight.serverTime = serverTime
	flight.lifetime = lifetimeLeft
end

-- HIT: the server says the blade cut someone; play a random hit sound
local function onHit(id)
	local flight = flights[id]
	if not flight then return end

	local sound = flight.blade:FindFirstChild(HIT_SOUNDS[math.random(#HIT_SOUNDS)])
	if sound then
		local clone = sound:Clone()
		clone.Parent = flight.blade
		clone:Play()
		clone.Ended:Once(function()
			clone:Destroy()
		end)
	end
end

-- FIZZLE: the cast was cancelled before launch (caster died or got ragdolled)
local function onFizzle(ownerUserId)
	local folder = getHeld(ownerUserId)
	if folder then
		folder:Destroy()
	end
end

ProjectileEvent.OnClientEvent:Connect(function(kind, a, weaveName, ...)
	if weaveName ~= WEAVE then return end

	if kind == "Launch" then
		onLaunch(a, ...)
	elseif kind == "Redirect" then
		onRedirect(a, ...)
	elseif kind == "Hit" then
		onHit(a)
	elseif kind == "Impact" then
		destroyFlight(a)
	elseif kind == "Fizzle" then
		onFizzle(a)
	end
end)


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


--local ScriptFx = {} 
--local CleanFx = {}

--WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, mousePos: Vector3, DAMAGE, LIFETIME, PROJECTILE_SPEED)
--	if not char then warn("Character not found") return end  
--	if not hum then warn("Humanoid not found") return end  
--	if not humRP then warn("HumanoidRootPart not found") return end  
--	if not weaveName then warn("WeaveName is missing") return end  

--	if weaveName ~= "WindCutter" then return end

--	local player = Players:GetPlayerFromCharacter(char)
--	if not player then return end -- Safety check
	
--	local UserId = player.UserId
--	local element = "Air"
	
--	-- Locate the projectile
--	local ProjFolder = hum:WaitForChild("WindCutterProjectile")
--	if not ProjFolder then warn("ProjectileFolder cannot be found") return end
--	ProjFolder.Parent = workspace
	
--	local Projectile = ProjFolder:WaitForChild("WindCutterEffect")
--	if not Projectile then return warn("Projectile cannot be found in the folder") end
	
--	if not ScriptFx[UserId] then 
--		ScriptFx[UserId] = {}
--	end
	
--	-- Make it constantly spin
--	local AlignOri = Projectile:FindFirstChildOfClass("AlignOrientation")
--	local rotationAngle = 0
--	local tiltAngle = math.rad(90) -- Tilt to make it flat
--	AlignOri.Enabled = true
--	--AlignOri.CFrame = CFrame.new(Projectile.Position) * CFrame.Angles(0, 0, tiltAngle) -- Set tilt once
--	ScriptFx[UserId].SpinConnection = RunService.Heartbeat:Connect(function()
--		if AlignOri then
--			rotationAngle = rotationAngle - math.rad(10)

--			-- First tilt to make it flat, THEN spin along the Y-axis
--			AlignOri.CFrame = CFrame.new(Projectile.Position) 
--				* CFrame.Angles(0, 0, tiltAngle) -- Tilt first
--				* CFrame.Angles(rotationAngle, 0, 0) -- Then spin along Y-axis
--		end
--	end)

	
--	-- Remove AlignPosition to make it loose
--	DebuffHandler.SetOwner(Projectile, player.Name)
	
--	-- Setup Cleanup
--	local function Cleanup()

--		if Projectile then -- If projectile still exists
--			Projectile:Destroy()
--		end

--		if ScriptFx[UserId] then
--			if ScriptFx[UserId].Task1 then ScriptFx[UserId].Task1 = nil end -- Ensure it's nil after canceling
--			if ScriptFx[UserId].SpinConnection then ScriptFx[UserId].SpinConnection:Disconnect() end
--			if ScriptFx[UserId].Connection then ScriptFx[UserId].Connection:Disconnect() end
--			if ScriptFx[UserId].AnimationConnection then ScriptFx[UserId].AnimationConnection:Disconnect() end
--			ScriptFx[UserId] = nil
--		end

--		if ProjFolder then ProjFolder:Destroy() end
--	end
	
--	-- Setup Damage Logic
--	local function DamageLogic(boolean, target)
--		-- Cancel the life counter
--		if boolean then task.cancel(ScriptFx[UserId].Task1) end
		
--		-- Sound options
--		local soundOptions = {
--			"sword enemy hit",
--			"sword_hit_hi_armor_hi_dmg_1"
--		}

--		-- Randomly pick a sound
--		local randomSound = soundOptions[math.random(1, #soundOptions)]

--		-- Clone, play, and remove after playing
--		if Projectile:FindFirstChild(randomSound) then
--			local soundClone = Projectile[randomSound]:Clone()
--			soundClone.Parent = Projectile
--			soundClone:Play()

--			-- Destroy after it finishes playing
--			soundClone.Ended:Connect(function()
--				soundClone:Destroy()
--			end)
--		end
		
--		-- Shake Camera

--		-- Enemy damage logic
--		local EnemiesinRange = {}
--		table.insert(EnemiesinRange, target) -- Add the enemy in the table	

--		-- Deal damage and handle status effects
--		for _, Enemies in EnemiesinRange do
--			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
--			DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)
--		end

--		task.delay(LIFETIME, function()
--			-- Destroy projectile?
--			Cleanup()
--		end)
--	end
	
--	local DebounceTable = {}

--	if Projectile then
--		ScriptFx[UserId].Connection = Projectile.Touched:Connect(function(hit)
--			if (hit.Parent:FindFirstChild("Humanoid") or hit:IsA("Part") or hit:IsA("Model")) 
--				and hit.Parent.Name ~= Projectile:GetAttribute("Owner") 
--				and not hit:IsDescendantOf(workspace.Barriers) then

--				local targetchar = hit.Parent

--				-- Use target as key in the debounce table
--				if not DebounceTable[targetchar] then
--					DebounceTable[targetchar] = true
--					DamageLogic(true, targetchar)

--					-- Reset debounce for this target after 0.4 seconds
--					task.delay(0.4, function()
--						DebounceTable[targetchar] = nil
--					end)
--				end

--			elseif hit:IsDescendantOf(workspace.Barriers) then
--				if not DebounceTable["Barrier"] then
--					DebounceTable["Barrier"] = true
--					task.delay(0.1, function()
--						DebounceTable["Barrier"] = nil
--					end)

--					local VeilOfReflection = hit
--					local BarrierHealth = VeilOfReflection:FindFirstChild("Health")

--					-- Set new projectile owner
--					DebuffHandler.SetOwner(Projectile, VeilOfReflection:GetAttribute("Owner"))

--					-- Retrieve LinearVelocity of the projectile
--					local LinearVelocity = Projectile:FindFirstChildOfClass("LinearVelocity")

--					if LinearVelocity then 
--						LinearVelocity.VectorVelocity = -LinearVelocity.VectorVelocity -- Flip direction
--					end

--					if BarrierHealth then 
--						DebuffHandler.DeductBarrierHealth(BarrierHealth, DAMAGE) 
--					end
--				end
--			end
--		end)
--	end

--	-- Start countdown for projectile lifetime
--	ScriptFx[UserId].Task1 = task.spawn(function()
--		local startTime = tick()

--		while tick() - startTime < LIFETIME do
--			local remainingTime = LIFETIME - (tick() - startTime)
--			task.wait(1) -- Wait 1 second before updating
--		end

--		if Projectile then
--			DamageLogic(false)
--		end

--		if ScriptFx[UserId] and ScriptFx[UserId].Task1 then ScriptFx[UserId].Task1 = nil end
--	end)
	
--	-- Add a delay using the animation Signal before proceeding the code
--	ScriptFx[UserId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, UserId)
--		if weaveName ~= "WindCutter" then return end
--		if phase ~= "Cast" then return end
--		if player.UserId ~= UserId then return end

--		-- Unlock projectile and add velocity
--		Projectile.Anchored = false
--		if Projectile:FindFirstChild("AlignPosition") then Projectile:FindFirstChild("AlignPosition"):Destroy() end
--		local newLV = Instance.new("LinearVelocity")
--		newLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
--		local direction = (mousePos - Projectile.Position).unit
--		newLV.VectorVelocity = direction * PROJECTILE_SPEED
--		newLV.MaxForce = 10 -- adjust if requiring gravity simulation
--		newLV.Attachment0 = Projectile:FindFirstChild("LinearVelocityAttachment")
--		newLV.Parent = Projectile

--		if ScriptFx[UserId] and ScriptFx[UserId].AnimationConnection then ScriptFx[UserId].AnimationConnection:Disconnect(); ScriptFx[UserId].AnimationConnection = nil end
--	end)
	
--end)