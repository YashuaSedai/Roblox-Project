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
local MovementService = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("MovementService"))
local ProjectileService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("ProjectileService"))

-- REMOTES
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local ProjectileEvent = WeavingFolder:WaitForChild("ProjectileEvent")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local WEAVE = "AirPulse"
local DamageService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("DamageService"))
local KNOCKBACK_TIME = 1.75
local DEFAULT_CAST_DELAY = 0.35 -- seconds between release and launch; tune to your Cast animation, or set CastDelay in the Dictionary
local DEFAULT_MAX_HOLD = 30 -- seconds a charging weave can be held before it collapses; or set MaxHold in the Dictionary

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
	MovementService.ClearSource(char, "Cast") -- the cast's slow / lock ends with the cast

	WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled
	ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE) -- remove the held fireball
end

local function reflect(proj, result, damage)
	local barrier = result.Instance
	local newOwner = Players:FindFirstChild(tostring(barrier:GetAttribute("Owner") or ""))
	if not newOwner or not newOwner:IsA("Player") or not newOwner.Character then return nil end

	local health = barrier:FindFirstChild("Health")
	if health then health.Value -= damage end

	return -proj.direction, proj.speed, newOwner
end

RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		cancelCast(player, char)
	end
end)

-- ANY status effect that blocks casting (Frozen, Shielded, Stunned, Rooted...) cancels the cast the same way a ragdoll does
if MovementService.CastBlocked then
	MovementService.CastBlocked:Connect(function(char)
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			cancelCast(player, char)
		end
	end)
end

-- START OF CAST (client fires this when E is pressed)
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < 30 then return end -- already channeling
	if os.clock() < (cooldownUntil[player] or 0) then return end                   -- on cooldown

	-- no Source, no cast
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

	local now = os.clock()
	local session = { startedAt = now, paidUntil = now, level = getLevel(player), char = char }
	sessions[player] = session

	-- keep paying Source for as long as E is HELD. Charge only counts for time that was actually paid for and stops at MaxCharge,
	-- but holding at max charge still costs Source every Interval (and so still raises Burn).
	-- Out of Source (or a status effect blocking the cast, or held too long) = the weave collapses and does NOT fire.
	local interval = weaveData.Interval
	if weaveData.Charging and interval and interval > 0 then
		local maxHold = weaveData.MaxHold or DEFAULT_MAX_HOLD
		task.spawn(function()
			while sessions[player] == session and hum.Health > 0 do
				task.wait(interval)
				if sessions[player] ~= session then break end
				if os.clock() - session.startedAt > maxHold or not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
					cancelCast(player, char)
					break
				end
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

	-- The session is already gone at this point, so EVERY rejection below has to remove the held visuals on the clients.
	-- (before, these just returned: the held visuals were left behind for good)
	local char, hum = getAlive(player)
	if not char or char ~= session.char then
		ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE)
		return
	end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then
		cooldownUntil[player] = os.clock() + weaveData.DebounceDuration
		ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE)
		return
	end
	if typeof(mousePos) ~= "Vector3" or not (mousePos.Magnitude < 1e5) then
		ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE)
		return
	end

	-- Out of Source while holding: the channel could not be held, so the weave does NOT fire.
	-- (the pay loop normally cancels it first; this closes the gap before its next tick)
	if hum and WeavingModule.CannotAffordTick(hum, weaveData, session.paidUntil) then
		cooldownUntil[player] = os.clock() + weaveData.DebounceDuration
		char:SetAttribute("Charging", false)
		hum:SetAttribute("Charge", 0)
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
		damage = weaveData.Damage + (level * charge) / 100,
		force = (charge * 100) + 2000,
		charge = charge,
	}

	local damage = weaveData.Damage + (level * charge) / 100
	local force = (charge * 100) + 2000
	local speed = weaveData.ProjectileSpeed + (level / 100)
	local lifetime = weaveData.Lifetime + (level / 50)

	-- the fireball leaves the hand after the cast wind-up
	task.delay(weaveData.CastDelay or DEFAULT_CAST_DELAY, function()
		local c, _, root = getAlive(player)
		if not c or c ~= char or (RagdollService.IsRagdolled(c) or not MovementService.CanCast(c)) then
			ProjectileEvent:FireAllClients("Fizzle", player.UserId, WEAVE) -- caster died or got ragdolled first
			return
		end

		local hand = c:FindFirstChild("RightHand")
		local origin = hand and (hand.CFrame * CFrame.new(-1.5, 0, 0)).Position or (root.CFrame * CFrame.new(0, 1, -4)).Position
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
			onBarrier = function(proj, result) return reflect(proj, result, ctx) end,
			onImpact = function(info)
				local model = info.hit and info.hit:FindFirstAncestorOfClass("Model")
				local targetHum = model and model:FindFirstChildOfClass("Humanoid")

				if targetHum and targetHum.Health > 0 and model ~= c then
					DamageService.Damage(targetHum, damage, info.owner, { Source = WEAVE })

					RagdollService.Ragdoll(model, KNOCKBACK_TIME)
					local ownerRoot = info.owner.Character and info.owner.Character:FindFirstChild("HumanoidRootPart")
					task.defer(function()
						if targetHum.Health <= 0 or not model.Parent then return end
						local from = (ownerRoot and ownerRoot.Parent) and ownerRoot or { Position = info.position }
						task.spawn(DebuffHandler.Knockback, from, model, KNOCKBACK_TIME, math.clamp(force, 4000, 5000), 2.5, 5)
					end)
				else
					model = nil -- hit a wall or timed out: no victim
				end

				ProjectileEvent:FireAllClients("Impact", info.id, WEAVE, info.position, model)
			end,
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
