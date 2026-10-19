-- ServerScriptService > Weaves > Spirit > Stilling > StillingScript   (Script, server)
--
-- STILLING (a LINK weave: cast with R by the LEADER of a link that has 7 linkers).
-- The SERVER owns the whole sequence. Clients only draw things and play animations when told to.
--
-- THE SEQUENCE (stage names are what the clients receive, see StillingReplicator)
--   Opening  R pressed. Cast gate: alive, can cast, leader with LinksRequired links, off cooldown.
--   (Lock)   The target arrives from the client and is validated (weaver, <= 50 studs, not Stilled, not Linked).
--            Target is HELD: anchored root, "Stilling" status (no move / jump / cast / draw), lifted into the air.
--            Clients spawn the 7 needles 50 studs out and play StillingChannel (caster) / StillingTargetChannelingLoop (target).
--   Channel  Waiting for StillingChannel's "Signal" marker (caster client -> AnimationSignal). Fallback timer if it never comes.
--   Firing   Caster plays StillingChannel2 + StillingChanneling, target plays StillingTargetChanneling.
--            That animation's "Signal" markers 1..5 (target client -> StillingRemote) fire the needles:
--            signal 1,2,3,4 = one needle each, signal 5 = the last three together. Fallback timer per signal.
--   Holding  Last needle fired. The caster must keep R held until they RELEASE. Release earlier = fizzle. 20s without a release = fizzle.
--   Cast     Released in time: caster plays StillingCast, target plays StillingTargetCast, needles are pulled back.
--            The target is STILLED (StillingService). Nothing the caster suffers can undo it from here on.
--            The target FLOATS until the end of StillingTargetCast (its marker / the animation ending), or CAST_RELEASE_FALLBACK
--            seconds at the latest. Then they are DROPPED and RAGDOLLED for DROP_RAGDOLL_TIME seconds.
--
-- FIZZLE: everything funnels through endSession(). Anything that can go wrong (caster / linker / link crowd-controlled,
--   link broken, caster or target died / left / out of range, early release, any timeout) calls fizzle(), which tells the
--   clients, pulls the needles back, lowers the target and gives the caster the short FizzleCooldown.

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local Dictionary = require(WeavingFolder:WaitForChild("Dictionary"))
local MovementService = require(Modules:WaitForChild("MovementService"))
local LinkData = require(Modules:WaitForChild("LinkData"))
local SystemFolder = ServerScriptService:WaitForChild("SYSTEM")
local LinkService = require(SystemFolder:WaitForChild("LinkService"))
local RagdollService = require(SystemFolder:WaitForChild("RagdollService"))
local StillingService = require(SystemFolder:WaitForChild("StillingService"))

-- REMOTES
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- Stilling's own remote (created here so you don't have to add it by hand).
--   server -> clients is NOT used (stages go through WeavingEvent like every other weave)
--   target client -> server:  ("Needle", n)  the needle marker n (1..5) of StillingTargetChanneling was reached
--                             ("TargetCastDone")  the StillingTargetCast release marker / end was reached
local StillingRemote = WeavingFolder:FindFirstChild("StillingRemote") or Instance.new("RemoteEvent")
StillingRemote.Name = "StillingRemote"
StillingRemote.Parent = WeavingFolder

local WEAVE = "Stilling"

-- TUNING --------------------------------------------------------------------------------------------------
local SIGNAL_COUNT = 5                     -- needle markers in StillingTargetChanneling (1..5)
local SIGNAL_NEEDLES = { { 1 }, { 2 }, { 3 }, { 4 }, { 5, 6, 7 } } -- which of the 7 needles each marker fires (last three together)
local SPAWN_DISTANCE = 50                  -- studs from the body part the needles spawn
local LIFT_HEIGHT = 6                      -- studs the target is raised
local LIFT_TIME = 1.2                      -- seconds to rise
local LOWER_TIME = 0.8                     -- seconds to come back down
local FAST_LOWER_TIME = 0.4                -- ...when the weave fizzled
local OPEN_TIMEOUT = 2.5                   -- the client sends the target right after the press; none by then = fizzle
local CHANNEL_FALLBACK = 4                 -- StillingChannel's "Signal" never arrived: carry on after this many seconds
local FIRST_SIGNAL_FALLBACK = 1.5         -- needle marker 1 never arrived
local SIGNAL_FALLBACK = 1.5                  -- a later needle marker never arrived (seconds since the previous one)
local CAST_RELEASE_FALLBACK = 10              -- how long the target floats after the cast at the very most (if StillingTargetCast says nothing sooner)
local DROP_RAGDOLL_TIME = 5                   -- seconds the target is ragdolled after being dropped
local MAX_TOTAL = 90                       -- hard cap on the whole cast, a last-resort watchdog
local RANGE_SLACK = 8                      -- the client checked range a moment ago, and the lift adds a little
local MONITOR_STEP = 0.1
local DEBUG_SIGNALS = true                -- prints WHAT fired each needle: the real marker or the fallback timer (turn off when it works)

-- STATE THE SERVER OWNS ---------------------------------------------------------------------------------
local sessions = {}      -- [caster player] = session
local cooldownUntil = {} -- [caster player] = os.clock() when the weave is ready again
local held = {}          -- [target character] = session (so two Stillings can't grab the same target)

-- PLAN: which body parts the 7 needles hit. First four are fixed, the last three are random.
local FIXED_HITS = {
	{ names = { "UpperTorso", "Torso" }, normal = Vector3.new(0, 0, -1) },        -- 1 UpperTorso (front)
	{ names = { "RightUpperArm", "Right Arm" }, normal = Vector3.new(1, 0, 0) },   -- 2 RightUpperArm
	{ names = { "UpperTorso", "Torso" }, normal = Vector3.new(0, 0, 1) },         -- 3 UpperTorso (back)
	{ names = { "LeftLowerLeg", "Left Leg" }, normal = Vector3.new(-1, 0, 0) },    -- 4 Left Lower Leg
}
local RANDOM_PARTS = { "Head", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand",
	"LeftUpperLeg", "RightUpperLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }
local RANDOM_NORMALS = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }

-- HELPERS -----------------------------------------------------------------------------------------------
local function getAlive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return char, hum, root
	end
	return nil
end

local function rand(a, b)
	return a + math.random() * (b - a)
end

local function findPart(char, names)
	for _, name in names do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then return part end
	end
	return nil
end

local function fireStage(s, stage, data)
	WeavingEvent:FireAllClients(s.char, s.hum, s.root, WEAVE, stage, data)
end

-- builds one needle entry: { part, offset (surface point in the part's space), spawn (world position) }
local function makeEntry(part, normal, lift)
	local size = part.Size
	local surface = Vector3.new(normal.X * size.X / 2, normal.Y * size.Y / 2, normal.Z * size.Z / 2)
	local jitter = Vector3.new(
		(1 - math.abs(normal.X)) * rand(-0.25, 0.25) * size.X,
		(1 - math.abs(normal.Y)) * rand(-0.3, 0.3) * size.Y,
		(1 - math.abs(normal.Z)) * rand(-0.25, 0.25) * size.Z
	)
	local offset = surface + jitter
	local hitWorld = part.CFrame:PointToWorldSpace(offset) + Vector3.new(0, lift, 0) -- where it WILL be once lifted
	local outward = part.CFrame:VectorToWorldSpace(normal)
	-- a little randomness in the approach direction
	local approach = CFrame.lookAt(Vector3.zero, outward) * CFrame.Angles(math.rad(rand(-12, 12)), math.rad(rand(-25, 25)), 0)
	return { part = part, offset = offset, spawn = hitWorld + approach.LookVector * SPAWN_DISTANCE }
end

local function buildPlan(targetChar)
	local plan = {}
	local used = {}
	for _, hit in FIXED_HITS do
		local part = findPart(targetChar, hit.names)
		if part then
			table.insert(plan, makeEntry(part, hit.normal, LIFT_HEIGHT))
			used[part.Name] = (used[part.Name] or 0) + 1
		end
	end
	-- the last three: different body parts, random sides
	local pool = {}
	for _, name in RANDOM_PARTS do
		local part = targetChar:FindFirstChild(name)
		if part and part:IsA("BasePart") and not used[name] then table.insert(pool, part) end
	end
	for _ = 1, 3 do
		local part
		if #pool > 0 then
			part = table.remove(pool, math.random(1, #pool))
		else
			part = findPart(targetChar, { "UpperTorso", "Torso" }) -- tiny rigs: fall back to the torso
		end
		if part then
			table.insert(plan, makeEntry(part, RANDOM_NORMALS[math.random(1, #RANDOM_NORMALS)], LIFT_HEIGHT))
		end
	end
	return plan
end

-- HOLDING THE TARGET --------------------------------------------------------------------------------------
-- The root is ANCHORED and moved by the server every frame (works whatever the target was doing: shielded, frozen,
-- rooted, mid-jump, animated on the LowerTorso...). The "Stilling" attribute is a MovementService status: no moving,
-- jumping, casting. The client blocks drawing on it, and so does the server (ElementAssignment).
local function setHoldCFrame(s, y)
	local tChar, tRoot = s.targetChar, s.tRoot
	if not tRoot or not tRoot.Parent then return end
	local cf = s.baseCF + Vector3.new(0, y, 0)
	tRoot.Anchored = true
	if tChar:GetAttribute("Frozen") or tChar:GetAttribute("Rooted") then
		tChar:PivotTo(cf) -- those effects anchor every part, so the whole model has to be moved
	else
		tRoot.CFrame = cf
	end
	s.offset = y
end

local function finishLanding(s)
	if s.hbConn then s.hbConn:Disconnect(); s.hbConn = nil end
	local tChar, tRoot = s.targetChar, s.tRoot
	if tRoot and tRoot.Parent then
		if not (tChar:GetAttribute("Frozen") or tChar:GetAttribute("Rooted")) then
			tRoot.Anchored = false -- (a Freeze / Root that is still running owns the anchor)
		end
	end
	if tChar and tChar.Parent then tChar:SetAttribute("Stilling", nil) end
	if tChar then held[tChar] = nil end
	s.mode = "free"
	local cb = s.onLanded
	s.onLanded = nil
	if cb then cb() end
end

local function updateHold(s)
	if not s.tRoot or not s.tRoot.Parent or not s.targetChar.Parent then
		finishLanding(s)
		return
	end
	local now = os.clock()
	if s.mode == "rising" then
		local a = math.clamp((now - s.t0) / LIFT_TIME, 0, 1)
		a = a * a * (3 - 2 * a)
		setHoldCFrame(s, LIFT_HEIGHT * a)
		if now - s.t0 >= LIFT_TIME then s.mode = "holding"; s.holdT0 = now end
	elseif s.mode == "holding" then
		setHoldCFrame(s, LIFT_HEIGHT + math.sin((now - s.holdT0) * 2) * 0.2)
	elseif s.mode == "lowering" then
		local a = math.clamp((now - s.t0) / s.lowerDur, 0, 1)
		a = a * a * (3 - 2 * a)
		setHoldCFrame(s, s.lowerFrom * (1 - a))
		if now - s.t0 >= s.lowerDur then finishLanding(s) end
	end
end

local function startHold(s)
	local tChar, tRoot = s.targetChar, s.tRoot
	if RagdollService.IsRagdolled(tChar) then RagdollService.Release(tChar) end -- a ragdoll can't play the animations
	held[tChar] = s
	s.baseCF = tRoot.CFrame
	s.mode = "rising"
	s.t0 = os.clock()
	s.offset = 0
	tChar:SetAttribute("Stilling", true)
	tRoot.Anchored = true
	s.hbConn = RunService.Heartbeat:Connect(function() updateHold(s) end)
end

local function beginLowering(s, fast, onLanded)
	if s.mode == "free" or not s.hbConn then
		if onLanded then onLanded() end
		return
	end
	s.onLanded = onLanded
	s.mode = "lowering"
	s.t0 = os.clock()
	s.lowerFrom = s.offset or 0
	s.lowerDur = fast and FAST_LOWER_TIME or LOWER_TIME
end

-- ENDING --------------------------------------------------------------------------------------------------
-- the ONE place a cast ends. outcome: "Fizzle" or "Done"
local function endSession(s, outcome, reason)
	if s.ended then return end
	s.ended = true
	if sessions[s.player] == s then sessions[s.player] = nil end
	local weaveData = Dictionary[WEAVE]
	if outcome ~= "Done" then
		-- (a successful cast already started its cooldown in succeed(). Restarting it here, when the target LANDS,
		-- made the server's cooldown end ~10s after the client's, so the next cast was silently ignored.)
		cooldownUntil[s.player] = os.clock() + (weaveData.FizzleCooldown or 5)
	end

	-- the caster's cast lock (MovementServer also clears it when the client releases)
	if s.char and s.char.Parent then
		MovementService.ClearSource(s.char, "Cast")
		s.char:SetAttribute("Charging", false)
		if s.hum then s.hum:SetAttribute("Charge", 0) end
	end

	if outcome == "Fizzle" then
		if reason then warn(`[Stilling] fizzled: {reason}`) end
		fireStage(s, "Fizzle", { target = s.targetChar })
		beginLowering(s, true, nil)
	else
		fireStage(s, "End", { target = s.targetChar })
		if s.mode ~= "free" then beginLowering(s, false, nil) end
	end
end

local function fizzle(s, reason)
	if s.ended or s.committed then return end
	endSession(s, "Fizzle", reason)
end

-- STAGES --------------------------------------------------------------------------------------------------
local function startFiring(s, source)
	if s.stage ~= "Channel" then return end
	if DEBUG_SIGNALS then
		if source == "fallback" then warn("[Stilling] StillingChannel's Signal never arrived: the fallback timer started the firing")
		else print("[Stilling] StillingChannel Signal received") end
	end
	s.stage = "Firing"
	s.nextSignal = 1
	s.stageAt = os.clock()
	s.lastSignalAt = os.clock()
	fireStage(s, "Fire", { target = s.targetChar })
end

local function fireSignal(s, n, source)
	if DEBUG_SIGNALS then
		if source == "fallback" then warn(`[Stilling] needle signal {n} fired by the FALLBACK TIMER (its marker never arrived)`)
		else print(`[Stilling] needle signal {n} fired by the animation marker`) end
	end
	s.nextSignal = n + 1
	s.lastSignalAt = os.clock()
	fireStage(s, "Needle", { n = n, needles = SIGNAL_NEEDLES[n] })
	if n >= SIGNAL_COUNT then
		s.stage = "Holding"
		s.holdDeadline = os.clock() + (Dictionary[WEAVE].HoldTimeout or 20)
	end
end

local function succeed(s)
	s.stage = "Cast"
	s.committed = true -- from here nothing the caster suffers can undo it
	s.castAt = os.clock()
	cooldownUntil[s.player] = os.clock() + (Dictionary[WEAVE].DebounceDuration or 20)
	fireStage(s, "Cast", { target = s.targetChar })
	-- the target is stripped of the Power the moment StillingCast plays
	StillingService.Apply(s.tPlayer, Dictionary[WEAVE].StilledDuration or 300)
end

-- the float is over: let go of the target and ragdoll them. (A fizzled weave still lowers the target gently, see beginLowering.)
local function releaseTarget(s)
	if s.ended or s.releasing then return end
	s.releasing = true
	local tChar = s.targetChar
	-- ragdoll FIRST (it needs the joints as they are), THEN unanchor, so they fall limp instead of landing on their feet.
	-- (Ragdoll does nothing for a target that is already dead or gone, which is fine.)
	if tChar and tChar.Parent then
		RagdollService.Ragdoll(tChar, DROP_RAGDOLL_TIME)
	end
	finishLanding(s)       -- unanchors, clears the "Stilling" hold status, frees the target
	endSession(s, "Done")  -- tells every client ("End") so the trails stop and the effects fade
end

-- THE MONITOR: one loop per cast. Watches everything that can go wrong and drives the fallback timers.
local function monitor(s)
	local weaveData = Dictionary[WEAVE]
	task.spawn(function()
		while not s.ended do
			task.wait(MONITOR_STEP)
			if s.ended then return end
			local now = os.clock()

			-- the target must still exist (applies even after the cast is committed)
			local tHum = s.targetChar and s.targetChar:FindFirstChildOfClass("Humanoid")
			local targetGone = not s.targetChar.Parent or not s.tPlayer.Parent or not tHum or tHum.Health <= 0
			if s.committed then
				if targetGone then
					releaseTarget(s)
				elseif s.stage == "Cast" and now - s.castAt > CAST_RELEASE_FALLBACK then
					releaseTarget(s) -- the StillingTargetCast marker never reached us
				end
				continue
			end

			-- CASTER: alive, same character, still allowed to cast, not ragdolled
			local char, hum, root = getAlive(s.player)
			if not char or char ~= s.char then return fizzle(s, "caster died or left") end
			if RagdollService.IsRagdolled(char) or not MovementService.CanCast(char) then
				return fizzle(s, "caster crowd controlled")
			end
			-- LINK: leader still the leader with enough linkers (a CC'd linker lets go of the link, which lands here)
			if not LinkData.CheckRequirement(char, weaveData) then return fizzle(s, "link broken") end

			-- TARGET
			if targetGone then return fizzle(s, "target died or left") end
			if s.targetChar:GetAttribute("Linked") == true then return fizzle(s, "target got linked") end
			if (s.baseCF.Position - root.Position).Magnitude > weaveData.CastRange + RANGE_SLACK + LIFT_HEIGHT then
				return fizzle(s, "target out of range")
			end

			-- WATCHDOGS
			if now - s.startedAt > MAX_TOTAL then return fizzle(s, "took too long") end
			if s.stage == "Channel" and now - s.stageAt > CHANNEL_FALLBACK then
				startFiring(s, "fallback") -- StillingChannel's Signal never arrived
			elseif s.stage == "Firing" then
				local wait = (s.nextSignal == 1) and FIRST_SIGNAL_FALLBACK or SIGNAL_FALLBACK
				if now - s.lastSignalAt > wait then
					fireSignal(s, s.nextSignal, "fallback") -- a needle marker never arrived
				end
			elseif s.stage == "Holding" and now > s.holdDeadline then
				return fizzle(s, "caster never released")
			end
		end
	end)
end

-- 1. R PRESSED --------------------------------------------------------------------------------------------
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	-- casting any OTHER weave abandons a Stilling in progress
	if weaveName ~= WEAVE then
		local old = sessions[player]
		if old then fizzle(old, "caster cast another weave") end
		return
	end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, root = getAlive(player)
	if not char then return end
	if RagdollService.IsRagdolled(char) or not MovementService.CanCast(char) then return end
	if not LinkService.CanCast(char, weaveData) then return end -- leader of a link with enough linkers

	local old = sessions[player]
	if old and not old.ended and os.clock() - old.startedAt < MAX_TOTAL + 5 then return end -- already casting
	if os.clock() < (cooldownUntil[player] or 0) then return end                              -- on cooldown

	local s = {
		player = player, char = char, hum = hum, root = root,
		stage = "Opening", startedAt = os.clock(), stageAt = os.clock(),
		ended = false, committed = false,
	}
	sessions[player] = s

	task.delay(OPEN_TIMEOUT, function()
		if sessions[player] == s and s.stage == "Opening" then
			fizzle(s, "no target arrived")
		end
	end)
end)

-- 2. TARGET CHOSEN ----------------------------------------------------------------------------------------
WeavingInstantEvent.OnServerEvent:Connect(function(player: Player, weaveName, mouseTarget)
	if weaveName ~= WEAVE then return end
	local s = sessions[player]
	if not s or s.stage ~= "Opening" or s.ended then return end

	local weaveData = Dictionary[WEAVE]
	local char, _, root = getAlive(player)
	if not char or char ~= s.char then return fizzle(s, "caster died") end

	-- VALIDATE THE TARGET
	if typeof(mouseTarget) ~= "Instance" or not mouseTarget:IsA("Model") or mouseTarget == char then
		return fizzle(s, "invalid target")
	end
	local tPlayer = Players:GetPlayerFromCharacter(mouseTarget)
	local tHum = mouseTarget:FindFirstChildOfClass("Humanoid")
	local tRoot = mouseTarget:FindFirstChild("HumanoidRootPart")
	if not tPlayer or not tHum or not tRoot or tHum.Health <= 0 then return fizzle(s, "target is not a player") end
	if tPlayer:GetAttribute("Role") ~= "Weaver" then return fizzle(s, "target is not a weaver") end -- only weavers can be stilled
	if StillingService.IsStilled(tPlayer) then return fizzle(s, "target already stilled") end
	if held[mouseTarget] then return fizzle(s, "target already held") end
	if mouseTarget:GetAttribute("Linked") == true then return fizzle(s, "linked weavers are immune") end
	-- (shields, freezes, roots... do NOT protect the target. That is intended.)
	if (tRoot.Position - root.Position).Magnitude > weaveData.CastRange + RANGE_SLACK then
		return fizzle(s, "target out of range")
	end

	s.targetChar, s.tPlayer, s.tHum, s.tRoot = mouseTarget, tPlayer, tHum, tRoot
	s.stage = "Channel"
	s.stageAt = os.clock()
	s.plan = buildPlan(mouseTarget)

	startHold(s)
	fireStage(s, "Lock", { target = mouseTarget, plan = s.plan })
	monitor(s)
end)

-- caster's StillingChannel reached its "Signal" marker (sent by AnimationHandler.PlayWeaveAnimation on the caster's client)
AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName, phase)
	if weaveName ~= WEAVE or phase ~= "Channel" then return end
	local s = sessions[player]
	if s and s.stage == "Channel" then startFiring(s, "marker") end
end)

-- the target's client: needle markers and "put me down" marker
StillingRemote.OnServerEvent:Connect(function(player: Player, kind, value)
	local s
	for _, candidate in sessions do
		if candidate.tPlayer == player and not candidate.ended then s = candidate break end
	end
	if not s then return end

	if kind == "Needle" then
		if typeof(value) ~= "number" or value % 1 ~= 0 or value < 1 or value > SIGNAL_COUNT then return end
		if s.stage ~= "Firing" then return end
		-- fire this marker and any earlier one we missed, in order
		while s.stage == "Firing" and s.nextSignal <= value do
			fireSignal(s, s.nextSignal, "marker")
		end
	elseif kind == "TargetCastDone" then
		if s.stage == "Cast" then releaseTarget(s) end
	end
end)

-- 3. R RELEASED -------------------------------------------------------------------------------------------
WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end
	local s = sessions[player]
	if not s or s.ended or s.committed then return end -- not casting / already cast: ignore (also stops double releases)

	if s.stage == "Holding" then
		local char = getAlive(player)
		if not char or char ~= s.char or RagdollService.IsRagdolled(char) or not MovementService.CanCast(char) then
			return fizzle(s, "caster was disrupted at the release")
		end
		succeed(s)
	else
		fizzle(s, "released too early") -- the weave fails if the button is released before the last needle
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local s = sessions[player]
	if s then fizzle(s, "caster left") end
	for _, candidate in sessions do
		if candidate.tPlayer == player then
			if candidate.committed then releaseTarget(candidate) else fizzle(candidate, "target left") end
		end
	end
	cooldownUntil[player] = nil
end)

-- the caster's character dying / respawning is caught by the monitor, but be quick about it
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		local s = sessions[player]
		if s then fizzle(s, "caster character removed") end
	end)
end)
for _, player in Players:GetPlayers() do
	player.CharacterRemoving:Connect(function()
		local s = sessions[player]
		if s then fizzle(s, "caster character removed") end
	end)
end

StillingService.Init()
