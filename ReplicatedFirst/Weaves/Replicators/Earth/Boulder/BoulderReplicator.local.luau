-- ReplicatedFirst > Weaves > Replicators > Earth > Boulder > BoulderReplicator   (LocalScript)
-- Replaces the whole old file.
--
-- VISUALS ONLY. No damage, no knockback, no DebuffHandler, no Touched. The server says where the
-- boulder is ("Launch" / "Redirect") and where it landed ("Impact"). The held boulder (a Model now)
-- is still created by BoulderEffect; at "Launch" we take it over and fly it.

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local Effects = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("VFX"))

-- REMOTE
local ProjectileEvent = Modules:WaitForChild("WeavingModule"):WaitForChild("ProjectileEvent")

-- ASSETS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

local WEAVE = "Boulder"
local SHAKE_RANGE = 100 -- studs: players farther than this feel no shake
local LINGER = 7        -- seconds the landing effects stay before they are removed

local LocalPlayer = Players.LocalPlayer
local flights = {} -- [id] = { boulder, folder, connection, origin, direction, speed, serverTime, lifetime, rotation, spin }

-- finds the held boulder that BoulderEffect made for this caster
local function getHeld(ownerUserId)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local char = owner and owner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local folder = hum and hum:FindFirstChild("BoulderProjectile")
	local boulder = folder and folder:FindFirstChild("BoulderEffect") -- the Model
	return folder, boulder
end

local function anchorAll(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

-- LAUNCH: take over the held boulder and fly it along the server's line
local function onLaunch(id, ownerUserId, origin, direction, speed, lifetime, serverTime)
	local folder, boulder = getHeld(ownerUserId)
	if not boulder then return end -- no held boulder (joined mid-cast): nothing to show

	folder.Parent = workspace
	boulder:SetAttribute("Held", false) -- tells BoulderEffect to stop moving it by hand

	local flight = {
		boulder = boulder,
		folder = folder,
		origin = origin,
		direction = direction,
		speed = speed,
		serverTime = serverTime,
		lifetime = lifetime,
		rotation = boulder:GetPivot().Rotation, -- keep tumbling from the way it was facing
		spin = Vector3.new(
			math.rad(math.random(-40, 40)),
			math.rad(math.random(-40, 40)),
			math.rad(math.random(-40, 40))
		),
	}
	flights[id] = flight

	flight.connection = RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow() - flight.serverTime
		if t > flight.lifetime + 2 then
			-- failsafe: the server's Impact never arrived
			flight.connection:Disconnect()
			flights[id] = nil
			folder:Destroy()
			return
		end
		t = math.clamp(t, 0, flight.lifetime)

		flight.rotation *= CFrame.Angles(flight.spin.X * dt, flight.spin.Y * dt, flight.spin.Z * dt)
		local position = flight.origin + flight.direction * flight.speed * t
		boulder:PivotTo(CFrame.new(position) * flight.rotation)
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

-- IMPACT: the server decided where it landed; we only play the show
local function onImpact(id, position, charge)
	local flight = flights[id]
	if not flight then return end
	flights[id] = nil
	flight.connection:Disconnect()

	local boulder, folder = flight.boulder, flight.folder
	boulder:PivotTo(CFrame.new(position)) -- end exactly where the server says

	-- take the landing effects out of the boulder first, so hiding the boulder doesn't hide them
	local container = boulder:FindFirstChild("EffectContainer", true)
	if container then
		container.Parent = folder
		local weld = container:FindFirstChildOfClass("WeldConstraint")
		if weld then weld:Destroy() end
		anchorAll(container)
	end

	-- the boulder itself disappears: hide every part and stop its emitters, trails and beams
	for _, descendant in boulder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = false
		end
	end

	-- explosion sound
	local explosion = SFX:FindFirstChild("Earthquake Explosion 1 (SFX)")
	if explosion then
		local sound = explosion:Clone()
		sound.Parent = container or boulder.PrimaryPart or folder
		sound:Play()
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

	-- ground burst: flying chunks plus dust, scaled by charge
	local filter = { workspace.Terrain }
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then table.insert(filter, baseplate) end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = filter
	rayParams.FilterType = Enum.RaycastFilterType.Include
	local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayParams)

	if result then
		local hitPart = result.Instance
		Effects.CreateExplosion(nil, result.Position, 10 * charge, { Min = 1, Max = 1.5 }, 7.5 * charge, 4, hitPart.Material, hitPart.Color)

		if container then
			container:PivotTo(CFrame.new(result.Position) * CFrame.new(0, 0.75, 0))

			local sizePercentage = (math.clamp(charge, 0, 100) / 100) + 2
			local attached = container:FindFirstChild("AttachedEffects")
			if attached then
				local effect1 = attached:FindFirstChild("Effect1")
				local smoke = attached:FindFirstChild("Smoke")
				if effect1 then
					Effects.SmoothAdjustParticleSize(effect1, sizePercentage, 1, 0.1)
					effect1:Emit(1)
				end
				if smoke then
					Effects.SmoothAdjustParticleSize(smoke, sizePercentage, 1, 0.1)
					smoke:Emit(200)
				end
			end
		end
	end

	task.delay(LINGER, function()
		if folder then folder:Destroy() end
	end)
end

-- FIZZLE: the cast was cancelled before launch (caster died, got ragdolled, or released too early)
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
