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
--
-- OWNERS: a projectile's owner is a Player, or an NPC (a Model with a Humanoid).
-- BARRIERS: Veil of Reflection registers its own part. For testing (or NPC shields) any plain Part can be a
-- barrier too: give it the tag "ReflectBarrier" (see the BARRIERS section below). A barrier nobody owns
-- sends the shot straight back at whoever fired it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local ProjectileEvent = ReplicatedStorage:WaitForChild("SYSTEM")
	:WaitForChild("ModuleScripts")
	:WaitForChild("WeavingModule")
	:WaitForChild("ProjectileEvent")

local MAX_SPEED = 1000
local MAX_LIFETIME = 20
local BARRIER_TAG = "ReflectBarrier" -- put this tag on any Part to make it reflect projectiles

local ProjectileService = {}

local active = {} -- [id] = projectile state
local nextId = 0
local loop = nil

-- an owner is a Player, or an NPC: a Model that has a Humanoid
local function isOwner(owner)
	if typeof(owner) ~= "Instance" then return false end
	if owner:IsA("Player") then return true end
	return owner:IsA("Model") and owner:FindFirstChildOfClass("Humanoid") ~= nil
end

local function getCharacter(owner)
	if typeof(owner) ~= "Instance" then return nil end
	if owner:IsA("Player") then return owner.Character end
	if owner:IsA("Model") then return owner end
	return nil
end

-- everything except the owner's own character can stop the projectile
local function makeParams(owner)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local char = getCharacter(owner)
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
			reflected = p.reflected == true, -- true once an unowned barrier has sent it back (its caster is no longer immune)
		})
		if not ok then
			warn("[ProjectileService] onImpact failed:", err)
		end
	end
end

-- BARRIERS ---------------------------------------------------------------------------------------
-- Barrier parts are looked up with their own cast, so they don't have to be solid (CanCollide can stay off,
-- CanQuery must be on), and a caster's own barrier (Owner attribute = the caster's name) never stops the
-- caster's own projectiles.
--
-- Who owns a barrier is the "Owner" attribute on the part:
--   * the name of a Player   -> the weave decides (Veil of Reflection: the shot is sent back AND now belongs to that player)
--   * the name of an NPC, or no Owner at all (a plain test Part) -> nobody who plays owns it, so the service itself sends
--     the shot straight back at whoever fired it
local barrierParts = {} -- [BasePart] = true

local barrierParams = RaycastParams.new()
barrierParams.FilterType = Enum.RaycastFilterType.Include
barrierParams.RespectCanCollide = false

function ProjectileService.RegisterBarrier(part)
	barrierParts[part] = true
end

function ProjectileService.UnregisterBarrier(part)
	barrierParts[part] = nil
end

-- ANY PART CAN BE A BARRIER: tag it "ReflectBarrier". (Properties > Tags, or in the Command Bar:
--   game:GetService("CollectionService"):AddTag(workspace.MyPart, "ReflectBarrier") )
local function registerTagged(part)
	if not part:IsA("BasePart") then return end
	part.CanQuery = true -- the barrier cast ignores parts that can't be queried
	ProjectileService.RegisterBarrier(part)
end
for _, part in CollectionService:GetTagged(BARRIER_TAG) do
	registerTagged(part)
end
CollectionService:GetInstanceAddedSignal(BARRIER_TAG):Connect(registerTagged)
CollectionService:GetInstanceRemovedSignal(BARRIER_TAG):Connect(ProjectileService.UnregisterBarrier)

-- is this barrier owned by somebody who is actually playing? (then the weave's own onBarrier decides)
local function ownedByPlayer(barrier)
	local name = barrier:GetAttribute("Owner")
	if typeof(name) ~= "string" or name == "" then return false end
	local player = Players:FindFirstChild(name)
	return player ~= nil and player:IsA("Player")
end

local function castBarriers(p, motion)
	local ownerName = p.owner.Name
	local list = {}
	for part in barrierParts do
		if part.Parent and part:GetAttribute("Owner") ~= ownerName then
			table.insert(list, part)
		end
	end
	if #list == 0 then return nil end

	barrierParams.FilterDescendantsInstances = list
	return workspace:Spherecast(p.position, p.radius, motion, barrierParams)
end

-- puts the projectile back in the air going the other way, and tells the clients
local function redirect(p, barrierResult, stepTime, newDirection, newSpeed)
	p.position = barrierResult.Position + barrierResult.Normal * (p.radius + 0.1) -- back off so it doesn't re-hit
	p.direction = newDirection.Unit
	p.speed = newSpeed or p.speed
	p.age += stepTime
	ProjectileEvent:FireAllClients(
		"Redirect", p.id, p.weave, p.position, p.direction, p.speed,
		workspace:GetServerTimeNow(), p.lifetime - p.age
	)
end

-- a barrier nobody plays as (a test Part, an NPC's shield): send the shot straight back where it came from
local function bounceOffUnownedBarrier(p, barrierResult, stepTime)
	local barrier = barrierResult.Instance

	-- optional: the weave can pass barrierDamage in Launch so the barrier's Health (a NumberValue) goes down
	if p.barrierDamage then
		local health = barrier:FindFirstChild("Health")
		if health and health:IsA("NumberValue") then
			health.Value -= p.barrierDamage
		end
	end

	-- nobody owns this barrier, so the one who fired is no longer immune to their own shot
	local char = getCharacter(p.owner)
	if char then
		local filter = p.params.FilterDescendantsInstances
		for i = #filter, 1, -1 do
			if filter[i] == char then table.remove(filter, i) end
		end
		p.params.FilterDescendantsInstances = filter
	end

	p.reflected = true
	redirect(p, barrierResult, stepTime, -p.direction, p.speed)
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
		local barrierResult = castBarriers(p, motion)

		-- a barrier that is closer than anything else takes the hit first
		if barrierResult and (not result or barrierResult.Distance <= result.Distance) then
			local reflected = false

			-- 1) the weave's own handler (Player-owned barriers: sends it back AND hands it to the barrier's owner)
			if p.onBarrier then
				local ok, newDirection, newSpeed, newOwner = pcall(p.onBarrier, p, barrierResult)
				if not ok then
					warn("[ProjectileService] onBarrier failed:", newDirection)
				elseif newDirection then
					reflected = true
					redirect(p, barrierResult, stepTime, newDirection, newSpeed)
					if newOwner then
						p.owner = newOwner
						p.params = makeParams(newOwner)
					end
				end
			end

			-- 2) nobody who plays owns this barrier (plain Part / NPC): the service bounces it itself
			if not reflected and p.reflect ~= false and not ownedByPlayer(barrierResult.Instance) then
				reflected = true
				bounceOffUnownedBarrier(p, barrierResult, stepTime)
			end

			if not reflected then
				finish(p, barrierResult.Position, "Hit", barrierResult.Instance)
			end
			continue
		end

		if result then
			-- piercing: report the character, then keep flying through it
			if p.pierce and p.onHit then
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model:FindFirstChildOfClass("Humanoid") then
					local ok, err = pcall(p.onHit, { id = p.id, position = result.Position, owner = p.owner, model = model })
					if not ok then warn("[ProjectileService] onHit failed:", err) end
					local filter = p.params.FilterDescendantsInstances
					table.insert(filter, model)
					p.params.FilterDescendantsInstances = filter -- never hit this character again
					continue
				end
			end

			finish(p, result.Position, "Hit", result.Instance)
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
--   weave, owner (Player, or an NPC Model with a Humanoid), origin (Vector3), direction (Vector3), speed, lifetime, radius,
--   onImpact(info)          -- info = { id, position, owner, reason, hit }
--   onBarrier(proj, result) -- optional; called when a registered barrier is hit. Return newDirection, newSpeed,
--                              newOwner to reflect, or nothing to leave it to the service (see BARRIERS above)
--   reflect = false         -- optional; never bounce this projectile off unowned barriers
--   barrierDamage = number  -- optional; Health taken from an unowned barrier when it bounces this shot
-- }
function ProjectileService.Launch(spec)
	local owner = spec.owner
	if not isOwner(owner) then return nil end -- a Player, or an NPC (a Model with a Humanoid)
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
		pierce = spec.pierce,
		onHit = spec.onHit,
		reflect = spec.reflect,               -- false = this projectile is never bounced by unowned barriers
		barrierDamage = spec.barrierDamage,   -- optional: Health taken from an unowned barrier each time it bounces this shot
	}
	active[p.id] = p

	ProjectileEvent:FireAllClients(
		"Launch", p.id, p.weave, owner:IsA("Player") and owner.UserId or 0, p.position, p.direction, p.speed, p.lifetime,
		workspace:GetServerTimeNow()
	)

	ensureLoop()
	return p.id
end

function ProjectileService.Cancel(id)
	active[id] = nil
end

return ProjectileService
