-- ReplicatedFirst > Weaves > Replicators > Fire > Fireball > FireballReplicator   (LocalScript)
-- Replaces the whole old file.
--
-- VISUALS ONLY. This script never decides a hit and never calls DebuffHandler.
-- The server says where the fireball is ("Launch"/"Redirect") and where it exploded ("Impact").
-- The held fireball is still created by FireballEffect; at "Launch" we take it over and fly it.

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local Effects = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local EffectsSFX = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("SFX"))

-- REMOTE
local ProjectileEvent = Modules:WaitForChild("WeavingModule"):WaitForChild("ProjectileEvent")

-- ASSETS
local Assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves")
local SFX = Assets:WaitForChild("SFX")
local FireballAssets = Assets:WaitForChild("VFX"):WaitForChild("Fireball")

local WEAVE = "Fireball"
local SHAKE_RANGE = 100 -- studs: players farther than this feel no shake

local LocalPlayer = Players.LocalPlayer
local flights = {} -- [id] = { projectile, folder, connection, origin, direction, speed, serverTime, lifetime }

-- finds the held fireball that FireballEffect made for this caster
local function getHeld(ownerUserId)
	local owner = Players:GetPlayerByUserId(ownerUserId)
	local char = owner and owner.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local folder = hum and hum:FindFirstChild("FireballProjectile")
	local projectile = folder and folder:FindFirstChild("FireballEffect")
	return folder, projectile
end

local function destroyFlight(id)
	local flight = flights[id]
	if not flight then return end
	flights[id] = nil
	if flight.connection then flight.connection:Disconnect() end
	if flight.folder then flight.folder:Destroy() end
end

-- LAUNCH: take over the held fireball and fly it along the server's line
local function onLaunch(id, ownerUserId, origin, direction, speed, lifetime, serverTime)
	local folder, projectile = getHeld(ownerUserId)

	if not projectile then
		-- the held fireball was never made (joined mid-cast, missed signal): make one
		folder = Instance.new("Folder")
		folder.Name = "FireballProjectile"
		projectile = FireballAssets:WaitForChild("FireballEffect"):Clone()
		projectile.Parent = folder
	end
	folder.Parent = workspace

	local align = projectile:FindFirstChildOfClass("AlignPosition")
	if align then align:Destroy() end -- this also ends FireballEffect's hand-shake loop
	projectile.Anchored = true

	local takeoff = SFX["Loki Invisibility"]:Clone()
	takeoff.Parent = folder
	takeoff:Play()

	local flight = {
		projectile = projectile,
		folder = folder,
		origin = origin,
		direction = direction,
		speed = speed,
		serverTime = serverTime,
		lifetime = lifetime,
	}
	flights[id] = flight

	flight.connection = RunService.RenderStepped:Connect(function()
		local t = workspace:GetServerTimeNow() - flight.serverTime
		if t > flight.lifetime + 2 then
			destroyFlight(id) -- failsafe: the server's Impact never arrived
			return
		end
		t = math.clamp(t, 0, flight.lifetime)
		projectile:PivotTo(CFrame.new(flight.origin + flight.direction * flight.speed * t))
	end)
end

-- REDIRECT: the server bounced the fireball (barrier); continue from its new line
local function onRedirect(id, position, direction, speed, serverTime, lifetimeLeft)
	local flight = flights[id]
	if not flight then return end
	flight.origin = position
	flight.direction = direction
	flight.speed = speed
	flight.serverTime = serverTime
	flight.lifetime = lifetimeLeft
end

-- IMPACT: the server decided where it exploded and who it hit; we only play the show
local function onImpact(id, position, targets, duration, charge)
	local flight = flights[id]
	flights[id] = nil

	local projectile, folder
	if flight then
		if flight.connection then flight.connection:Disconnect() end
		projectile, folder = flight.projectile, flight.folder
	else
		folder = Instance.new("Folder")
		folder.Name = "FireballProjectile"
		folder.Parent = workspace
	end

	if projectile then
		projectile:PivotTo(CFrame.new(position)) -- end exactly where the server says

		Effects.NumberValueTweenObj(projectile, "Part", "Transparency", 0, 1, 1, 10)
		for _, emitter in projectile:GetChildren() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
				Effects.NumberValueTweenObj(emitter, "ParticleEmitter", "Transparency", 0, 1, 1, 10)
			end
		end

		local explosion1 = SFX["Big Explosion"]:Clone(); explosion1.Parent = projectile; explosion1:Play()
		local explosion2 = SFX["ExplosionSfx"]:Clone(); explosion2.Parent = projectile; explosion2:Play()
	end

	-- camera shake: only within range, stronger the closer you are
	local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if localRoot then
		local distance = (localRoot.Position - position).Magnitude
		if distance < SHAKE_RANGE then
			local strength = (1 - distance / SHAKE_RANGE) ^ 2
			Effects.ShakeCamera(LocalPlayer.UserId, true, nil, 6.5 * strength, 7, 0.25, 0.25)
		end
	end

	-- burning visuals on everyone the server says was hit
	local burningEffect = FireballAssets:FindFirstChild("BurningEffect")
	for _, model in targets do
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if root and burningEffect then
			local burn = burningEffect:Clone()
			burn.Parent = folder
			burn.CFrame = root.CFrame
			burn.WeldConstraint.Part0 = root

			local crackle = SFX["Fireplace Constant Burning Flame 4 (SFX)"]:Clone(); crackle.Parent = root
			local flame = SFX["Flamethrower Loop"]:Clone(); flame.Parent = root
			local whoosh = SFX["Magic Whooshes Growly Magic Whooshes Airy Gu (SFX)"]:Clone(); whoosh.Parent = root
			crackle:Play(); flame:Play(); whoosh:Play()

			task.delay(duration, function()
				EffectsSFX.FadeSound(crackle, 0, 1, 10)
				EffectsSFX.FadeSound(flame, 0, 1, 10)
				EffectsSFX.FadeSound(whoosh, 0, 1, 10)
				Debris:AddItem(crackle, 1)
				Debris:AddItem(flame, 1)
				Debris:AddItem(whoosh, 1)

				for _, emitter in burn:GetChildren() do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = false
					end
				end
			end)
		end
	end

	-- ground explosion: flying blocks + dust, scaled by charge
	local filter = { workspace.Terrain }
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then table.insert(filter, baseplate) end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = filter
	rayParams.FilterType = Enum.RaycastFilterType.Include
	local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), rayParams)

	if result then
		local hitPart = result.Instance
		local hitPosition = result.Position

		local bits = FireballAssets:FindFirstChild("Bits")
		Effects.CreateExplosion(bits, hitPosition, 10 * charge, { Min = 0.5, Max = 0.75 }, 10 * charge, 4, hitPart.Material, hitPart.Color, 50)

		local container = FireballAssets:FindFirstChild("EffectContainer"):Clone()
		container.Parent = folder
		container.Anchored = true
		container.CFrame = CFrame.new(hitPosition) * CFrame.new(0, 0.75, 0)

		local sizePercentage = (math.clamp(charge * 5, 0, 100) / 100) + 1
		local attached = container.AttachedEffects
		Effects.SmoothAdjustParticleSize(attached.Effect1, sizePercentage, 1, 0.1)
		Effects.SmoothAdjustParticleSize(attached.Effect2, sizePercentage, 1, 0.1)
		Effects.SmoothAdjustParticleSize(attached.Effect3, sizePercentage, 1, 0.1)
		Effects.SmoothAdjustParticleSize(attached.Smoke, sizePercentage, 1, 0.1)
		attached.Effect1:Emit(1)
		attached.Effect2:Emit(2)
		attached.Effect3:Emit(3)
		attached.Smoke:Emit(100)

		local lightSize = { NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 10) }
		attached.Light.Size = Effects.ScaleNumberSequence(lightSize, sizePercentage)
		attached.Light:Emit(5)
	end

	if projectile then
		Debris:AddItem(projectile, duration)
	end
	task.delay(duration + 1, function()
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
