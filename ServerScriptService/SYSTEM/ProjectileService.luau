-- ServerScriptService > SYSTEM > ProjectileService   (ModuleScript, server only)
--
-- The server owns every projectile: where it is, what it hits, and when it ends.
-- Clients never decide a hit. They receive "Launch", draw a projectile that follows the
-- same straight line, and play the explosion when the server says "Impact".
--
-- Messages sent on ProjectileEvent (server -> clients):
--   "Launch",   id, weave, ownerUserId, origin, direction, speed, lifetime, serverTime
--   "Redirect", id, weave, position, direction, speed, serverTime, lifetimeLeft
-- ("Impact" and "Fizzle" are sent by the weave script, because only it knows the extra data.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProjectileEvent = ReplicatedStorage:WaitForChild("SYSTEM")
	:WaitForChild("ModuleScripts")
	:WaitForChild("WeavingModule")
	:WaitForChild("ProjectileEvent")

local MAX_SPEED = 1000
local MAX_LIFETIME = 20

local ProjectileService = {}

local active = {} -- [id] = projectile state
local nextId = 0
local loop = nil

-- everything except the owner's own character can stop the projectile
local function makeParams(owner)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local char = owner and owner.Character
	params.FilterDescendantsInstances = char and { char } or {}
	return params
end

local function finish(p, position, reason, hit)
	if active[p.id] ~= p then return end
	active[p.id] = nil

	if p.onImpact then
		local ok, err = pcall(p.onImpact, {
			id = p.id,
			position = position,
			owner = p.owner,
			reason = reason, -- "Hit" or "Lifetime"
			hit = hit,
		})
		if not ok then
			warn("[ProjectileService] onImpact failed:", err)
		end
	end
end

local function step(dt)
	for _, p in active do
		local timeLeft = p.lifetime - p.age
		local stepTime = math.min(dt, timeLeft)

		if stepTime <= 0 then
			finish(p, p.position, "Lifetime")
			continue
		end

		-- sweep a sphere along this frame's movement so a fast projectile can't skip through thin parts
		local motion = p.direction * (p.speed * stepTime)
		local result = workspace:Spherecast(p.position, p.radius, motion, p.params)

		if result then
			local barriers = workspace:FindFirstChild("Barriers")
			local reflected = false

			if p.onBarrier and barriers and result.Instance:IsDescendantOf(barriers) then
				local ok, newDirection, newSpeed, newOwner = pcall(p.onBarrier, p, result)
				if ok and newDirection then
					reflected = true
					p.position = result.Position + result.Normal * (p.radius + 0.1) -- back off so it doesn't re-hit
					p.direction = newDirection.Unit
					p.speed = newSpeed or p.speed
					p.age += stepTime
					if newOwner then
						p.owner = newOwner
						p.params = makeParams(newOwner)
					end
					ProjectileEvent:FireAllClients(
						"Redirect", p.id, p.weave, p.position, p.direction, p.speed,
						workspace:GetServerTimeNow(), p.lifetime - p.age
					)
				end
			end

			if not reflected then
				finish(p, result.Position, "Hit", result.Instance)
			end
		else
			p.position += motion
			p.age += stepTime
			if p.age >= p.lifetime then
				finish(p, p.position, "Lifetime")
			end
		end
	end
end

local function ensureLoop()
	if loop then return end
	loop = RunService.Heartbeat:Connect(function(dt)
		step(dt)
		if next(active) == nil then
			loop:Disconnect()
			loop = nil
		end
	end)
end

-- spec = {
--   weave, owner (Player), origin (Vector3), direction (Vector3), speed, lifetime, radius,
--   onImpact(info)          -- info = { id, position, owner, reason, hit }
--   onBarrier(proj, result) -- optional; return newDirection, newSpeed, newOwner to reflect, or nil
-- }
function ProjectileService.Launch(spec)
	local owner = spec.owner
	if typeof(owner) ~= "Instance" or not owner:IsA("Player") then return nil end
	if typeof(spec.origin) ~= "Vector3" or typeof(spec.direction) ~= "Vector3" then return nil end
	if spec.direction.Magnitude < 0.001 then return nil end

	nextId += 1
	local p = {
		id = nextId,
		weave = spec.weave,
		owner = owner,
		position = spec.origin,
		direction = spec.direction.Unit,
		speed = math.clamp(spec.speed, 1, MAX_SPEED),
		lifetime = math.clamp(spec.lifetime, 0.1, MAX_LIFETIME),
		radius = math.clamp(spec.radius or 1, 0.1, 10),
		age = 0,
		params = makeParams(owner),
		onImpact = spec.onImpact,
		onBarrier = spec.onBarrier,
	}
	active[p.id] = p

	ProjectileEvent:FireAllClients(
		"Launch", p.id, p.weave, owner.UserId, p.position, p.direction, p.speed, p.lifetime,
		workspace:GetServerTimeNow()
	)

	ensureLoop()
	return p.id
end

function ProjectileService.Cancel(id)
	active[id] = nil
end

return ProjectileService
