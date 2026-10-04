-- ReplicatedFirst > Weaves > Replicators > Water > Frostbound > FrostboundReplicator   (LocalScript)
-- Replaces the whole old file.
--
-- VISUALS ONLY. No damage, no freeze, no DebuffHandler, no Touched. The server says where the
-- projectile is ("Launch" / "Redirect") and where it burst ("Impact"). The held projectile is still
-- created by FrostboundEffect; at "Launch" we take it over and fly it.

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local Effects = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("VFX"))

-- REMOTE
local ProjectileEvent = Modules:WaitForChild("WeavingModule"):WaitForChild("ProjectileEvent")

local WEAVE = "Frostbound"
local SHAKE_RANGE = 100 -- studs: players farther than this feel no shake
local LINGER = 4        -- seconds the burst effect stays before it is removed
local TRAIL_NAMES = { "Ice", "Mist", "Mist2", "Trail", "Trail2", "Trail3" } -- emitters/trails that stop at impact

local LocalPlayer = Players.LocalPlayer
local flights = {} -- [id] = { projectile, folder, connection, origin, direction, speed, serverTime, lifetime, rotation }

-- finds the held projectile that FrostboundEffect made for this caster
local function getHeld(ownerUserId)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local char = owner and owner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local folder = hum and hum:FindFirstChild("FrostboundProjectile")
	local projectile = folder and folder:FindFirstChild("FrostboundEffect")
	return folder, projectile
end

-- LAUNCH: take over the held projectile and fly it along the server's line
local function onLaunch(id, ownerUserId, origin, direction, speed, lifetime, serverTime)
	local folder, projectile = getHeld(ownerUserId)
	if not projectile then return end -- no held projectile (joined mid-cast): nothing to show

	folder.Parent = workspace

	-- the constraint held it in front of the caster; we move it ourselves now
	local alignPosition = projectile:FindFirstChildOfClass("AlignPosition")
	if alignPosition then alignPosition:Destroy() end
	projectile.Anchored = true

	local flight = {
		projectile = projectile,
		folder = folder,
		origin = origin,
		direction = direction,
		speed = speed,
		serverTime = serverTime,
		lifetime = lifetime,
		rotation = projectile.CFrame.Rotation, -- keep the way it was facing
	}
	flights[id] = flight

	flight.connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - flight.serverTime
		if t > flight.lifetime + 2 then
			-- failsafe: the server's Impact never arrived
			flight.connection:Disconnect()
			flights[id] = nil
			folder:Destroy()
			return
		end
		t = math.clamp(t, 0, flight.lifetime)

		local position = flight.origin + flight.direction * flight.speed * t
		projectile:PivotTo(CFrame.new(position) * flight.rotation)
	end)
end

-- REDIRECT: the server bounced it (barrier); continue from its new line
local function onRedirect(id, position, direction, speed, serverTime, lifetimeLeft)
	local flight = flights[id]
	if not flight then return end
	flight.origin = position
	flight.direction = direction
	flight.speed = speed
	flight.serverTime = serverTime
	flight.lifetime = lifetimeLeft
end

-- IMPACT: the server decided where it burst; we only play the show
local function onImpact(id, position, charge)
	local flight = flights[id]
	if not flight then return end
	flights[id] = nil
	flight.connection:Disconnect()

	local projectile, folder = flight.projectile, flight.folder
	projectile:PivotTo(CFrame.new(position)) -- end exactly where the server says

	local container = projectile:FindFirstChild("EffectContainer")

	-- ice sounds
	if container then
		local ice1 = container:FindFirstChild("Ice 2 SFX")
		local ice2 = container:FindFirstChild("Ice Spread SFX")
		if ice1 then ice1:Play() end
		if ice2 then ice2:Play() end
	end

	-- camera shake: only within range, stronger the closer you are
	local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if localRoot then
		local distance = (localRoot.Position - position).Magnitude
		if distance < SHAKE_RANGE then
			local strength = (1 - distance / SHAKE_RANGE) ^ 2
			Effects.ShakeCamera(LocalPlayer.UserId, true, nil, 3.5 * strength, 4, 0.5, 0.5)
		end
	end

	-- ground burst: snow and frost where it landed, scaled by charge
	if container then
		local filter = { workspace.Terrain }
		local baseplate = workspace:FindFirstChild("Baseplate")
		if baseplate then table.insert(filter, baseplate) end

		local rayParams = RaycastParams.new()
		rayParams.FilterDescendantsInstances = filter
		rayParams.FilterType = Enum.RaycastFilterType.Include
		local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayParams)

		if result then
			container.Parent = folder
			local weld = container:FindFirstChildOfClass("WeldConstraint")
			if weld then weld:Destroy() end
			container.Anchored = true
			container.Position = result.Position + Vector3.new(0, 0.75, 0)

			local sizePercentage = (math.clamp(charge * 10, 0, 100) / 100) + 2.5
			local attached = container.AttachedEffects
			Effects.SmoothAdjustParticleSize(attached.Effect1, sizePercentage, 20, 0.1)
			Effects.SmoothAdjustParticleSize(attached.Effect2, sizePercentage, 20, 0.1)
			Effects.SmoothAdjustParticleSize(attached.Smoke, sizePercentage, 20, 0.1)
			attached.Effect1:Emit(1)
			attached.Effect2:Emit(1)
			attached.Smoke:Emit(200)

			if container:FindFirstChild("Snowy") then
				container.Snowy.Enabled = true
				task.delay(1, function()
					if container.Parent then container.Snowy.Enabled = false end
				end)
			end
		end
	end

	-- the flying ice stops
	for _, name in TRAIL_NAMES do
		local emitter = projectile:FindFirstChild(name)
		if emitter then
			emitter.Enabled = false
		end
	end

	task.delay(LINGER, function()
		if folder then folder:Destroy() end
	end)
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
	elseif kind == "Impact" then
		onImpact(a, ...)
	elseif kind == "Fizzle" then
		onFizzle(a)
	end
end)


