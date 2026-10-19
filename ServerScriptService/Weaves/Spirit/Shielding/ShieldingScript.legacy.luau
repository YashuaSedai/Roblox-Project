-- Shielding   (Script, server)   -- MULTIPLE CASTERS VERSION
--
-- THE SHIELD, step by step
--   1. E pressed ......... the cast opens (checks, first Source payment)                  -> CLIENT HOOK 1
--   2. target locked ..... range / validity checked. The caster JOINS the target's shield (or starts it)
--                          and their channel loop starts                                  -> CLIENT HOOK 2
--                          From this moment the caster is already DRAINING the target's Source (see 4), shield or not.
--   3. THE SHIELD TAKES HOLD the moment the target has LESS than 20% Source OR LESS than 20% Burn.
--                          Checked right at lock-on (so it can be immediate) and again every Interval, right after the drain.
--                          The target is SHIELDED (can't move, can't draw, can't cast).
--                          This happens once per shield.                                  -> CLIENT HOOK 3
--   4. every Interval .... EVERY caster pays SourceCost.
--                          EVERY caster also drains Source from the target, continuously, from the moment they lock on
--                          (the shield does NOT have to be holding yet), at ShieldBalance.drainPerSecond(casterLevel)
--                          per second (scaled by real elapsed time). A target that out-regenerates the drain is never shielded.
--                          (a caster's drain is skipped for 5s after THAT caster takes damage)
--   4b. THE TARGET BREAKS FREE once it has recovered: Source is FULL and Burn is at or above weaveData.BurnMaximum.
--                          Every caster is released at once (the same cooldown as a normal release).
--   (LINKED weavers, leader or linker, are IMMUNE: they can't be targeted, and a shield on somebody who gets linked is cut.)
--   5. each caster must KEEP HOLDING it. A caster who releases / is interrupted / runs out of Source /
--      goes out of range / casts another weave just LEAVES the shield (END).
--      The target stays shielded while at least ONE caster remains. When the last one leaves, the target is free.
--
-- MOVEMENT: this script never touches WalkSpeed / JumpPower. It only sets the "Shielded" attribute; MovementService
--   sees that and locks the target (no walking, no jumping, no casting) and frees them again when it goes back to false.
--
-- THE TABLES
--   sessions[player]  = one caster's cast (the "notebook page"). Created on press, deleted ONLY inside finish().
--   shields[target]   = everything about one shielded target, shared by all its casters:
--                         { target, casters = { [player] = session, ... }, shielded = false }
--   Every loop/timer re-checks  sessions[player] == session  so a stale one can never touch a newer cast.

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
local MovementService = require(Modules:WaitForChild("MovementService"))
local ShieldBalance = require(Modules:WaitForChild("ShieldBalance"))

-- REMOTES
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local WEAVE = "Shielding"

-- TUNING
local SOURCE_LIMIT = 0.2     -- the target is shielded if their Source is BELOW this fraction of MaxSource...
-- ...OR their Burn is below weaveData.BurnMaximum (reused as the "20% Burn" cutoff, so set it in the Dictionary)
local DAMAGE_PAUSE = 5       -- seconds a caster's drain pauses if THEY take damage
local TARGET_TIMEOUT = 2     -- the client sends the target right after the press; no target by then = the cast fizzles
local DEFAULT_MAX_HOLD = 300  -- or set MaxHold in the Dictionary
local RANGE_SLACK = 6        -- the client already checked range; allow a little movement since
-- optional Dictionary field:  MaxCasters = number  (how many casters may shield one target; unlimited if missing)

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}      -- [caster player] = that caster's cast in progress
local cooldownUntil = {} -- [caster player] = os.clock() time when the weave is ready again (separate: it outlives the session)
local shields = {}       -- [target model]  = { target, casters = {[player] = session}, shielded }

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

-- a valid target is alive and has Source to drain (so Warders / NPCs without Source can't be shielded)
local function getTargetParts(target)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return end
	local tHum = target:FindFirstChildOfClass("Humanoid")
	local tRoot = target:FindFirstChild("HumanoidRootPart")
	if not tHum or not tRoot or tHum.Health <= 0 then return end
	local source = tHum:FindFirstChild("Source")
	local maxSource = tHum:FindFirstChild("MaxSource")
	if not source or not maxSource then return end
	return tHum, tRoot, source, maxSource
end

local function countCasters(shield)
	local count = 0
	for _ in shield.casters do
		count += 1
	end
	return count
end

local function listCasterChars(shield)
	local chars = {}
	for _, session in shield.casters do
		table.insert(chars, session.char)
	end
	return chars
end

-- the new rule: low Source OR low Burn = the target can be shielded
local function canShield(tHum, tSource, tMaxSource)
	if tSource.Value < tMaxSource.Value * SOURCE_LIMIT then
		return true
	end
	local burn = tHum:FindFirstChild("Burn")
	if burn and burn.Value < Dictionary[WEAVE].BurnMaximum then
		return true
	end
	return false
end

-- the opposite of canShield: the target has fully recovered, so a held shield breaks.
-- Source must be FULL and Burn must be at or above the Burn cutoff (a target with no Burn meter has nothing to wait for).
local function hasRecovered(tHum, tSource, tMaxSource)
	if tSource.Value < tMaxSource.Value then
		return false
	end
	local burn = tHum:FindFirstChild("Burn")
	if burn and burn.Value < Dictionary[WEAVE].BurnMaximum then
		return false
	end
	return true
end

-- THIS caster drains Source from the target at ShieldBalance.drainPerSecond(session.level) per second, scaled by the real time
-- since THIS caster's last drain call. The drain scales with the SHIELDER's level: a full-slot target needs to be
-- LEVELS_AHEAD_TO_BEAT (5) levels above the shielder to out-regenerate it; fewer slots need many more levels.
-- The clock starts when the caster locks on (session.lastDrainAt) and keeps running during the damage pause,
-- so nothing is "owed" afterwards.
local function drainTarget(session, tSource)
	local now = os.clock()
	local last = session.lastDrainAt
	session.lastDrainAt = now
	if not last then return end
	if now < session.pausedUntil then return end
	tSource.Value = math.max(0, tSource.Value - ShieldBalance.drainPerSecond(session.level) * (now - last))
end

-- The lock on a shielded target is the "Shielded" attribute and nothing else. MovementService reacts to it (WalkSpeed 0,
-- JumpPower 0, JumpHeight 0, can't cast) and is the ONLY thing that writes those, so nothing can quietly undo it,
-- and when the attribute goes back to false the target gets exactly the speed they should have (other slows included).
local function unlockTarget(shield)
	local target = shield.target
	if not target.Parent then return end
	target:SetAttribute("Shielded", false)
end

-- a caster joins the target's shield (creating it if this is the first caster)
local function joinShield(player, session, target)
	local shield = shields[target]
	if not shield then
		shield = { target = target, casters = {}, shielded = false }
		shields[target] = shield
	end
	shield.casters[player] = session
	session.shield = shield
	return shield
end

-- THE ONE PLACE A CAST ENDS. Everything that can end a cast calls this, and nothing else deletes a session.
-- The caster leaves the shield. If they were the LAST caster, the target is freed.
local function finish(player, session, cooldown, notifyClear)
	if sessions[player] ~= session then return end -- already ended
	sessions[player] = nil
	cooldownUntil[player] = os.clock() + cooldown

	local freedTarget = nil
	local shield = session.shield
	if shield then
		shield.casters[player] = nil
		if next(shield.casters) == nil then -- nobody is maintaining it any more
			shields[shield.target] = nil
			if shield.shielded then
				unlockTarget(shield) -- the shield is cut: the target is free again
			end
			freedTarget = shield.target
		end
	end

	local char = session.char
	if char and char.Parent then
		char:SetAttribute("Charging", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetAttribute("Charge", 0) end
	end

	-- END (for THIS caster). freedTarget is the target ONLY when this was the last caster, i.e. the target is now free.
	if notifyClear then
		WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled
	end
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, WEAVE, freedTarget)
end

-- THE SHIELD TAKES HOLD (once per shield, whichever caster triggers it first)
local function succeed(shield, session, char, hum, humRP)
	shield.shielded = true
	local target = shield.target

	target:SetAttribute("Shielded", true) -- the existing status: Source regen stops, the target's own cast is cancelled,
	-- and MovementService locks their movement, jump and casting

	-- CLIENT HOOK 3: shield successful. The client plays ShieldedChannel + ShieldedChanneling on the target and its VFX.
	-- The last argument is every caster who is shielding right now (characters), if your VFX wants to draw from each of them.
	WeavingEvent:FireAllClients(char, hum, humRP, WEAVE, target, listCasterChars(shield))
end

-- THE TARGET BROKE FREE: every caster leaves the shield. finish() frees the target when the last one is gone.
local function endShield(shield, cooldown)
	local casters = {}
	for player, session in shield.casters do -- copy first: finish() removes casters from shield.casters
		table.insert(casters, { player = player, session = session })
	end
	for _, entry in casters do
		finish(entry.player, entry.session, cooldown, true)
	end
end

-- THE CHANNEL: one loop per caster
local function runChannel(player, session)
	local weaveData = Dictionary[WEAVE]
	local shield = session.shield
	local target = shield.target
	local interval = weaveData.Interval or 0.1
	local range = weaveData.CastRange + session.level + RANGE_SLACK
	local holdUntil = session.startedAt + (weaveData.MaxHold or DEFAULT_MAX_HOLD)
	local endCooldown = weaveData.DebounceDuration

	task.spawn(function()
		while sessions[player] == session do
			task.wait(interval)
			if sessions[player] ~= session then return end -- it ended while we were waiting

			-- THIS CASTER: dead, ragdolled, frozen, rooted, stunned or shielded themselves = they leave the shield
			local char, hum, humRP = getAlive(player)
			if not char or char ~= session.char or not DebuffHandler.CheckStatus(char) then
				return finish(player, session, endCooldown, true)
			end
			if os.clock() > holdUntil then
				return finish(player, session, endCooldown, true)
			end

			-- this caster only TOOK DAMAGE (not crowd controlled): THEIR drain pauses
			if hum.Health < session.lastHealth - 0.01
				and not char:GetAttribute("BurningOut") then -- burnout damage doesn't count
				session.pausedUntil = os.clock() + DAMAGE_PAUSE
			end
			session.lastHealth = hum.Health

			-- THE TARGET: gone, dead, or out of range of this caster = this caster leaves
			local tHum, tRoot, tSource, tMaxSource = getTargetParts(target)
			if not tHum or not target:IsDescendantOf(workspace) or (tRoot.Position - humRP.Position).Magnitude > range then
				return finish(player, session, endCooldown, true)
			end

			-- THIS CASTER PAYS every Interval. Can't pay = can't maintain the channel.
			if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
				return finish(player, session, endCooldown, true)
			end

			-- the target got linked (leader or linker): linked weavers are immune, so the shield is cut
			if target:GetAttribute("Linked") == true then
				return endShield(shield, endCooldown)
			end

			-- a HELD shield breaks if the target has fully recovered (Source full, Burn past the cutoff)
			if shield.shielded and hasRecovered(tHum, tSource, tMaxSource) then
				return endShield(shield, endCooldown)
			end

			-- EVERY caster drains the target from lock-on, shield or not
			drainTarget(session, tSource)

			-- not shielded yet: the moment the target is low enough on Source or Burn, the shield takes hold.
			-- (checked AFTER the drain on purpose: passive regen refills Source to exactly 20%, which is not "below 20%",
			-- so the dip the drain just made is the only moment this can be seen)
			if not shield.shielded and canShield(tHum, tSource, tMaxSource) then
				succeed(shield, session, char, hum, humRP)
			end
		end
	end)
end

-- 1. E PRESSED: the cast opens
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	-- the caster casting ANY OTHER weave leaves the shield they are holding
	if weaveName ~= WEAVE then
		local session = sessions[player]
		if session then
			finish(player, session, Dictionary[WEAVE].DebounceDuration, true)
		end
		return
	end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if not DebuffHandler.CheckStatus(char) then return end -- ragdolled / frozen / rooted / stunned / shielded: can't cast

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < (weaveData.MaxHold or DEFAULT_MAX_HOLD) + 5 then return end -- already casting
	if os.clock() < (cooldownUntil[player] or 0) then return end                                                            -- on cooldown

	-- first payment (the loop pays the rest, every Interval)
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

	local session = {
		player = player,
		startedAt = os.clock(),
		level = getLevel(player),
		char = char,
		shield = nil,         -- the target's shield record this caster has joined (step 2)
		targeted = false,
		pausedUntil = 0,      -- THIS caster's drain is paused until this time (they took damage)
		lastDrainAt = nil,    -- os.clock() of this caster's last drainTarget call (set when they lock on)
		lastHealth = hum.Health,
	}
	sessions[player] = session

	-- the target should arrive any moment; if it never does, don't leave a half-open cast behind
	task.delay(TARGET_TIMEOUT, function()
		if sessions[player] == session and not session.shield then
			finish(player, session, weaveData.FizzleCooldown or 1, true)
		end
	end)

	-- CLIENT HOOK 1: the caster tries to cast. Hand VFX etc. start here.
	-- (the caster's ShieldingChannel / ShieldingChanneling animations are played by ElementalSetting, on the caster's own client)
	WeavingFxEvent:FireAllClients(char, hum, humRP, WEAVE)
end)

-- 2. TARGET CHOSEN (the client sends this right after the press)
WeavingInstantEvent.OnServerEvent:Connect(function(player: Player, weaveName, mouseTarget)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session or session.targeted then return end -- no open cast, or the target was already chosen
	session.targeted = true

	local weaveData = Dictionary[WEAVE]
	local failCooldown = weaveData.FizzleCooldown or 1

	local char, hum, humRP = getAlive(player)
	if not char or char ~= session.char then
		return finish(player, session, failCooldown, true)
	end

	-- is it somebody who can be shielded?
	local tHum, tRoot = getTargetParts(mouseTarget)
	if not tHum or mouseTarget == char then
		return finish(player, session, failCooldown, true)
	end

	if mouseTarget:GetAttribute("Linked") == true then
		return finish(player, session, failCooldown, true) -- linked weavers are immune to shielding
	end
	if mouseTarget:GetAttribute("Stilled") == true then
		return finish(player, session, failCooldown, true) -- Stilled weavers can't be shielded
	end

	local existing = shields[mouseTarget]
	if not existing and mouseTarget:GetAttribute("Shielded") then
		return finish(player, session, failCooldown, true) -- shielded by something that isn't this weave
	end
	if existing and weaveData.MaxCasters and countCasters(existing) >= weaveData.MaxCasters then
		return finish(player, session, failCooldown, true) -- already enough casters on this target
	end

	-- CHECK THE RANGE (the same formula the client uses)
	local range = weaveData.CastRange + session.level
	if (tRoot.Position - humRP.Position).Magnitude > range + RANGE_SLACK then
		return finish(player, session, failCooldown, true)
	end

	-- join the target's shield (an existing one, or start it)
	local shield = joinShield(player, session, mouseTarget)
	session.lastDrainAt = os.clock() -- the drain starts now, whether or not the shield has taken hold yet

	-- CLIENT HOOK 2: this caster is locked on the target. A beam / link between them can start here.
	-- (fires once per caster, including casters who join a shield that is already holding)
	WeavingInstantEvent:FireAllClients(char, hum, humRP, WEAVE, mouseTarget)

	if shield.shielded then
		-- THE SHIELD IS ALREADY HOLDING (an earlier caster made it take hold), so succeed() will never run again.
		-- This caster's link (shield model + channel particles) was just built by Hook 2 and still needs Hook 3 to switch
		-- to the "held" look. Without this the new caster's effects stayed stuck at the lock-on stage (bug 3).
		-- The last two arguments: only THIS caster's link, and "the target already has the shield" (so the target's own
		-- animations / body effects aren't started a second time).
		WeavingEvent:FireAllClients(char, hum, humRP, WEAVE, mouseTarget, { char }, true)
	else
		-- IMMEDIATE SHIELD: Hook 2 is fired first so the client has built this caster's link before Hook 3 arrives
		local tHum2, _, tSource, tMaxSource = getTargetParts(mouseTarget)
		if tHum2 and canShield(tHum2, tSource, tMaxSource) then
			succeed(shield, session, char, hum, humRP)
		end
	end

	runChannel(player, session)
end)

-- 3. E RELEASED: this caster stops maintaining it, so they leave the shield
WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	if session.shield and session.shield.shielded then
		finish(player, session, weaveData.DebounceDuration, false)
	else
		finish(player, session, weaveData.FizzleCooldown or 1, false) -- let go before it took hold
	end
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if weaveName ~= WEAVE then return end
	WeavingFxClear:FireAllClients(player.UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName, phase)
	if weaveName ~= WEAVE or typeof(phase) ~= "string" then return end
	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- visuals only
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		finish(player, session, 0, true) -- never leave somebody locked
	end
	cooldownUntil[player] = nil
end)