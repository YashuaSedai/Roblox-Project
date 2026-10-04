-- ServerScriptService > Weaves > Fire > Fireball > FireballScript   (Script)
-- Replaces the whole old file.
--
-- The client asks ("I'm casting", "release, aiming here"). The server decides everything else:
-- Source, cooldown, charge, where the fireball is, what it hits, damage, burn, knockback.

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local WeavingModule = require(WeavingFolder:WaitForChild("WeavingModule"))
local Dictionary = require(WeavingFolder:WaitForChild("Dictionary"))
local DebuffHandler = require(Modules:WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local RagdollService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("RagdollService"))
local ProjectileService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("ProjectileService"))

-- REMOTES
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local ProjectileEvent = WeavingFolder:WaitForChild("ProjectileEvent")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local WEAVE = "Frostbound"
local DEFAULT_CAST_DELAY = 0.35 -- seconds between release and launch; tune to your Cast animation, or set CastDelay in the Dictionary

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}      -- [player] = { startedAt, paidUntil, level, char }  while a cast is being channeled
local cooldownUntil = {} -- [player] = os.clock() time when the weave is ready again

local function getLevel(player)
	local stats = player:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	return level and level.Value or 1
end

local function getAlive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if hum and humRP and hum.Health > 0 then
		return char, hum, humRP
	end
	return nil
end

-- kills a cast that's being channeled (used when the caster gets ragdolled)
local function cancelCast(player, char)
	if not sessions[player] then return end
	sessions[player] = nil

	cooldownUntil[player] = os.clock() + Dictionary[WEAVE].DebounceDuration

	char:SetAttribute("Charging", false)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum:SetAttribute("Charge", 0) end

	WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled
	ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE) -- remove the held fireball
end

RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		cancelCast(player, char)
	end
end)

-- THE EXPLOSION: the server finds the targets and applies everything
local function explode(info, ctx)
	local owner = info.owner
	local position = info.position
	local ownerChar = owner and owner.Character
	local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart")

	-- barriers block the blast (only matters once barriers exist on the server)
	local barriers = workspace:FindFirstChild("Barriers")
	local barrierParams
	if barriers then
		barrierParams = RaycastParams.new()
		barrierParams.FilterType = Enum.RaycastFilterType.Include
		barrierParams.FilterDescendantsInstances = { barriers }
	end

	local targets, seen = {}, {}
	for _, part in workspace:GetPartBoundsInRadius(position, ctx.area) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and model ~= ownerChar then
			seen[model] = true
			local hum = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 and (root.Position - position).Magnitude <= ctx.area then
				if not barrierParams or not workspace:Raycast(position, root.Position - position, barrierParams) then
					table.insert(targets, model)
				end
			end
		end
	end

	for _, model in targets do
		local hum = model:FindFirstChildOfClass("Humanoid")
		hum:TakeDamage(ctx.damage)
		hum:SetAttribute("LastAttacker", owner.UserId)
		hum:SetAttribute("LastDamage", ctx.damage)
		if hum.Health > 0 then
			DebuffHandler.Freeze(owner, model, ctx.duration)
		end
	end

	ProjectileEvent:FireAllClients("Impact", info.id, WEAVE, position, ctx.charge)
end

-- BARRIER REFLECTION: returns newDirection, newSpeed, newOwner (or nil = no reflection)
-- Dormant until barriers exist on the server (Veil of Reflection is still built on each client).
local function reflect(proj, result, ctx)
	local barrier = result.Instance
	local newOwner = Players:FindFirstChild(tostring(barrier:GetAttribute("Owner") or ""))
	if not newOwner or not newOwner:IsA("Player") or not newOwner.Character then return nil end

	local health = barrier:FindFirstChild("Health")
	if health then
		health.Value -= ctx.damage * 2
	end

	local d = proj.direction
	return Vector3.new(-d.X, d.Y, -d.Z).Unit, proj.speed / 3, newOwner
end

-- START OF CAST (client fires this when E is pressed)
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if RagdollService.IsRagdolled(char) then return end

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < 30 then return end -- already channeling
	if os.clock() < (cooldownUntil[player] or 0) then return end                   -- on cooldown

	-- no Source, no cast
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

	local now = os.clock()
	local session = { startedAt = now, paidUntil = now, level = getLevel(player), char = char, ready = not weaveData.RequiresReady }
	sessions[player] = session

	-- keep paying Source while charging. Charge only counts for time that was actually paid for.
	local interval = weaveData.Interval
	if weaveData.Charging and interval and interval > 0 then
		local maxTime = weaveData.MaxCharge * WeavingModule.ChargeInterval(session.level)
		task.spawn(function()
			while sessions[player] == session and hum.Health > 0 and os.clock() - session.startedAt < maxTime do
				task.wait(interval)
				if sessions[player] ~= session then break end
				if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then break end
				session.paidUntil = os.clock()
			end
		end)
	end

	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)

-- RELEASE (client fires this when E is released)
WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, _charge, _mouseTarget, mousePos, _level)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)
	sessions[player] = nil

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char = getAlive(player)
	if not char or char ~= session.char then return end
	if RagdollService.IsRagdolled(char) then return end
	if typeof(mousePos) ~= "Vector3" or not (mousePos.Magnitude < 1e5) then return end
	
	-- spells that must finish charging before they can be released
	if weaveData.RequiresReady and os.clock() - session.startedAt < weaveData.ReadyTime then
		-- released too early: the spell breaks, nothing launches
		cooldownUntil[player] = os.clock() + (weaveData.FizzleCooldown or 1)
		char:SetAttribute("Charging", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetAttribute("Charge", 0) end
		ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE)
		return
	end

	cooldownUntil[player] = os.clock() + weaveData.DebounceDuration

	-- the server's own numbers, never the client's
	local level = session.level
	local charge = 0
	if weaveData.Charging then
		local chargeInterval = WeavingModule.ChargeInterval(level)
		local heldTime = math.max(session.paidUntil - session.startedAt, 0)
		charge = math.clamp(math.floor(heldTime / chargeInterval) + 1, 0, weaveData.MaxCharge)
	end

	local ctx = {
		damage = weaveData.Damage + (level * charge) / 150,
		duration = weaveData.Duration + (charge / 75),
		area = weaveData.Area + (level * charge) / 100,
		charge = charge,
	}
	local speed = weaveData.ProjectileSpeed + (level * charge) / 200
	local lifetime = weaveData.Lifetime + (level / 50)

	-- the fireball leaves the hand after the cast wind-up
	task.delay(weaveData.CastDelay or DEFAULT_CAST_DELAY, function()
		local c, _, root = getAlive(player)
		if not c or c ~= char or RagdollService.IsRagdolled(c) then
			ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE) -- caster died or got ragdolled first
			return
		end

		local origin = (root.CFrame * CFrame.new(0, 1, -4)).Position -- same spot the held fireball is drawn
		local aim = mousePos - origin
		local direction = aim.Magnitude >= 1 and aim.Unit or root.CFrame.LookVector

		ProjectileService.Launch({
			weave = WEAVE,
			owner = player,
			origin = origin,
			direction = direction,
			speed = speed,
			lifetime = lifetime,
			radius = weaveData.ProjectileRadius or 1.5,
			onImpact = function(info) explode(info, ctx) end,
		})
	end)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if weaveName ~= WEAVE then return end
	WeavingFxClear:FireAllClients(player.UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName, phase)
	if weaveName ~= WEAVE or typeof(phase) ~= "string" then return end
	AnimationSignal:FireAllClients(weaveName, phase, player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	cooldownUntil[player] = nil
end)
