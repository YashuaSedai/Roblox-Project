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

local WEAVE = "WindCutter"
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

-- BARRIER REFLECTION: returns newDirection, newSpeed, newOwner (or nil = no reflection)
-- Dormant until barriers exist on the server (Veil of Reflection is still built on each client).
local function reflect(proj, result, ctx)
	local barrier = result.Instance
	local newOwner = Players:FindFirstChild(tostring(barrier:GetAttribute("Owner") or ""))
	if not newOwner or not newOwner:IsA("Player") or not newOwner.Character then return nil end

	local health = barrier:FindFirstChild("Health")
	if health then
		health.Value -= ctx.damage
	end

	return -proj.direction, proj.speed, newOwner
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

	local now = os.clock()
	local session = { startedAt = now, paidUntil = now, level = getLevel(player), char = char }
	sessions[player] = session
	
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

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

	cooldownUntil[player] = os.clock() + weaveData.DebounceDuration

	-- the server's own numbers, never the client's
	local level = session.level
	local chance = weaveData.CriticalChance + math.clamp(level, 0, 33)
	local critMultiplier = weaveData.CriticalDamage + (level * 0.01)
	local lifetime = weaveData.Lifetime + (level / 50)
	local speed = weaveData.ProjectileSpeed + (level / 100)

	-- one crit roll per cast (same as the old script)
	local damage = weaveData.Damage
	if math.random(0, 100) <= chance then
		damage = damage * critMultiplier
	end

	local ctx = { damage = damage } -- used by reflect, when you turn it on

	-- the blade leaves the hand after the cast wind-up
	task.delay(weaveData.CastDelay or DEFAULT_CAST_DELAY, function()
		local c, _, root = getAlive(player)
		if not c or c ~= char or RagdollService.IsRagdolled(c) then
			ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE)
			return
		end

		local origin = (root.CFrame * CFrame.new(1.8, 2.25, 1)).Position
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
			pierce = true,

			-- runs once for every character the blade passes through
			onHit = function(info)
				local targetHum = info.model:FindFirstChildOfClass("Humanoid")
				if not targetHum or targetHum.Health <= 0 then return end
				targetHum:TakeDamage(damage)
				targetHum:SetAttribute("LastAttacker", info.owner.UserId)
				targetHum:SetAttribute("LastDamage", damage)
				ProjectileEvent:FireAllClients("Hit", info.id, WEAVE, info.position)
			end,

			-- runs when the blade hits a wall or its lifetime ends
			onImpact = function(info)
				ProjectileEvent:FireAllClients("Impact", info.id, WEAVE, info.position)
			end,

			-- turn on when Veil of Reflection is ported:
			-- onBarrier = function(proj, result) return reflect(proj, result, ctx) end,
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
