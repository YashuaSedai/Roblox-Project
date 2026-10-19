-- Stilling   (LocalScript, client, runs for EVERY player)
-- The SERVER decides everything (see StillingScript). This only plays animations and draws the needles when told to.
--
--   stage "Lock"    server grabbed the target. Everyone: spawn the 7 needles 50 studs out.
--                   TARGET's client: stop their current animations, loop StillingTargetChannelingLoop.
--                   (the CASTER's StillingChannel is played by ElementalSetting on press)
--   stage "Fire"    CASTER's client: StillingChannel2 + loop StillingChanneling.
--                   TARGET's client: StillingTargetChanneling, whose "Signal" markers 1..5 are sent to the server.
--   stage "Needle"  fly these needles into the target's body parts. {n, needles = {indices}}
--   stage "Cast"    CASTER: StillingCast.  TARGET: StillingTargetCast (+ loops stop), its marker tells the server to put them down.
--                   Everyone: the needles are pulled back to where they started and dissolve.
--   stage "Fizzle"  everything stops, needles pulled back fast, the target gets their shield animations back.
--   stage "End"     the target was dropped: stop the trail burst, fade the effects, tidy up.
--
-- EFFECTS (everyone sees them, all built locally):
--   StillingCaster (StillingLeft + StillingRight)  on the caster from "Lock" until the needles are pulled out.
--       CenterPart rides on the caster's HumanoidRootPart, joints 1..4 float around it (AlignPosition), beams wave like Linking's.
--   StillingTarget                                 on the target from "Lock" until they are dropped ("End") or it fizzles.
--       Pivoted onto the target's HumanoidRootPart every frame.
--   TRAIL BURST  once the needles are out: ~5 trails per second burst out of the target's upper torso along random
--       bezier paths ~100 studs long, until the target is dropped (or DISPERSE_TIME runs out). Each trail cleans itself up.
--
-- ANIMATIONS: tracks are loaded here on the animator of the character that is meant to play them (the owner's client),
-- using the ids in AnimationHandler, so priorities / looping are set explicitly:  loops = Action1, one-shots = Action2.

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- MODULES / REMOTES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local AnimationHandler = require(Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))
local Utilities = require(Modules:WaitForChild("UTILITIES")) -- BezierSetup
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local StillingRemote = WeavingFolder:WaitForChild("StillingRemote")

local WEAVE = "Stilling"
local DEBUG_SIGNALS = true -- prints what fires each needle and how long it flew. Turn off once the timing is right.
local LocalPlayer = Players.LocalPlayer

-- THE ASSETS
local stillingVfx = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Stilling")
local needleTemplate = stillingVfx:WaitForChild("StillingNeedle")
local trailAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Elements"):WaitForChild("Trails")
-- the new effects wait at most 10s, so a misnamed asset only costs you THAT effect, not the needles and animations too
local casterAsset = stillingVfx:WaitForChild("StillingCaster", 10)  -- Folder: StillingLeft, StillingRight (Models)
local targetAsset = stillingVfx:WaitForChild("StillingTarget", 10)  -- Model
if not casterAsset then warn("[Stilling] no StillingCaster in Assets.Weaves.VFX.Stilling: no caster effect") end
if not targetAsset then warn("[Stilling] no StillingTarget in Assets.Weaves.VFX.Stilling: no target effect") end
local sfx = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- TUNING --------------------------------------------------------------------------------------------------
-- How long a needle takes to fly in. A needle LANDS this long after its numbered marker fires, so put the markers in
-- StillingTargetChanneling about this many seconds BEFORE the hit reaction (0.12s is roughly 4 frames at 30fps).
local NEEDLE_FLIGHT_TIME = 0.12
local RETRACT_DELAY = 1           -- seconds after StillingCast starts before the needles are pulled back out
-- Needle 1 sits on the caster's LEFT PALM until it is fired. The palm is found through LeftGripAttachment (R15), which
-- sits on the palm. Only if a hand has no grip attachment is this hand-local offset used instead (palm = -Y of the hand).
local PALM_FALLBACK_OFFSET = Vector3.new(0, -0.5, 0)
-- which needles each numbered marker fires. Keep in step with SIGNAL_NEEDLES in StillingScript.
local SIGNAL_NEEDLES = { { 1 }, { 2 }, { 3 }, { 4 }, { 5, 6, 7 } }
local EMBED = 0.6                 -- how far the tip goes past the body part's surface
local RETURN_TIME = 0.7           -- seconds for the needles to be pulled back (Cast)
local FAST_RETURN_TIME = 0.35     -- ...when the weave fizzled
local DISSOLVE_TIME = 0.3
-- CASTER EFFECT (StillingCaster)
local CASTER_OFFSET = CFrame.identity -- where each CenterPart sits relative to the caster's HumanoidRootPart
local CASTER_EXPAND_TIME = 0.8        -- the joints start inside the center and spread out to their places over this long
local CASTER_WAVE = 2                 -- studs: how far each Beam's curve wanders on top of what you authored (0 = leave beams alone)
local CASTER_WAVE_SPEED = 0.5         -- how lazily it wanders
local CASTER_FADE_TIME = 0.6
local DEBUG_CASTER_FX = true          -- prints each joint's offset from its CenterPart, to compare with your table
-- TARGET EFFECT (StillingTarget)
local TARGET_OFFSET = CFrame.identity -- relative to the target's HumanoidRootPart
local TARGET_FADE_TIME = 0.6
-- TRAIL BURST out of the target's upper torso, once the needles are pulled out
local DISPERSE_TIME = 8               -- the burst loop runs this long at most (it also stops when the target is dropped)
local TRAILS_PER_SECOND = 10
local BURST_DISTANCE = 65            -- studs from the torso to where each trail ends...
local BURST_DISTANCE_JITTER = 0.4     -- ...give or take this fraction (bigger = the ends spread over a thick shell, not one thin sphere)
-- How a trail moves along its path. Quad + Out = very fast at the start, slowing to a stop at the end, so the trails
-- pile up and linger at the far end (that looks like a hollow ball around the target). Linear = steady speed, so they
-- keep flying and just disappear. Try Quad + In for a slow start from the chest that whooshes away.
local BURST_EASING = Enum.EasingStyle.Linear
local BURST_EASING_DIRECTION = Enum.EasingDirection.Out
local DEBUG_TRAILS = true             -- prints (once) where the Trail attachments of the template sit relative to its part
local BURST_CURVE = 30                -- studs the two bezier control points are pushed sideways (bigger = curvier)
local BURST_TRAVEL_TIME = 0.7         -- seconds a trail takes along its path
local FX_TAIL = 2.5                   -- seconds a faded effect is kept so its particles / trails can finish
local END_TAIL = 4                    -- seconds after the target is dropped before the whole session is deleted
local MAX_SESSION_TIME = 120          -- failsafe: a session is deleted this long after it started no matter what
-- Needle orientation. The needle is pointed so that its LONG axis lies along its travel direction.
-- If your needle's tip ends up at the wrong end, set NEEDLE_FLIP = true.
local NEEDLE_FLIP = true

-- LOOKS UP THE NEEDLE'S SHAPE ONCE (works whether the asset is a Part / MeshPart or a Model) -----------------
local function measure(template)
	local size
	if template:IsA("Model") then size = template:GetExtentsSize()
	elseif template:IsA("BasePart") then size = template.Size
	else
		local part = template:FindFirstChildWhichIsA("BasePart", true)
		size = part and part.Size or Vector3.new(0.2, 0.2, 3)
	end
	local length, axis = size.X, "X"
	if size.Y > length then length, axis = size.Y, "Y" end
	if size.Z > length then length, axis = size.Z, "Z" end
	return length, axis
end
local NEEDLE_LENGTH, NEEDLE_AXIS = measure(needleTemplate)

-- rotation that sends the needle's long axis onto the look direction (-Z)
local AXIS_FIX = CFrame.identity
if NEEDLE_AXIS == "Y" then AXIS_FIX = CFrame.Angles(-math.pi / 2, 0, 0)
elseif NEEDLE_AXIS == "X" then AXIS_FIX = CFrame.Angles(0, math.pi / 2, 0) end
local FLIP = NEEDLE_FLIP and CFrame.Angles(0, math.pi, 0) or CFrame.identity

local function needleCF(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction) * FLIP * AXIS_FIX
end

-- FX FOLDER (local) ---------------------------------------------------------------------------------------
local fxFolder = workspace:FindFirstChild("StillingFx") or Instance.new("Folder")
fxFolder.Name = "StillingFx"
fxFolder.Parent = workspace

local function prepare(clone)
	local parts = {}
	if clone:IsA("BasePart") then table.insert(parts, clone) end
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then table.insert(parts, d) end
	end
	for _, p in parts do
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
	end
	return parts
end

local function setCF(needle, cf)
	local inst = needle.inst
	if inst:IsA("Model") then inst:PivotTo(cf) else inst.CFrame = cf end
end

local function getCF(needle)
	local inst = needle.inst
	if inst:IsA("Model") then return inst:GetPivot() end
	return inst.CFrame
end

-- the caster's left palm in world space (nil if the character has no hand)
local function palmPosition(char)
	if not char then return nil end
	local hand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
	if not hand or not hand:IsA("BasePart") then return nil end
	local grip = hand:FindFirstChild("LeftGripAttachment")
	if grip and grip:IsA("Attachment") then return grip.WorldPosition end
	return hand.CFrame:PointToWorldSpace(PALM_FALLBACK_OFFSET)
end

-- ANIMATION HELPERS ---------------------------------------------------------------------------------------
local ACTION_PRIORITIES = {
	[Enum.AnimationPriority.Action] = true, [Enum.AnimationPriority.Action2] = true,
	[Enum.AnimationPriority.Action3] = true, [Enum.AnimationPriority.Action4] = true,
}

local function getAnimator(char)
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator")
end

local function loadTrack(char, animName, priority, looped)
	local animator = getAnimator(char)
	local data = AnimationHandler[animName]
	if not animator or not data or not data.id then
		warn(`[Stilling] can't load animation {animName}`)
		return nil
	end
	local track = AnimationHandler.AnimationLoader(animator, data.id)
	if not track then return nil end
	track.Priority = priority
	track.Looped = looped
	return track
end

local function stopTrack(track, fade)
	if track then pcall(function() track:Stop(fade or 0.15) end) end
end

-- the target's own client: the Shielded animations (and any other action animation) give way to the Stilling ones
local function stopActionTracks(char)
	local animator = getAnimator(char)
	if not animator then return end
	for _, track in animator:GetPlayingAnimationTracks() do
		if ACTION_PRIORITIES[track.Priority] then
			track:Stop(0.1)
		end
	end
end

-- if the weave failed (or ended) and the target is still shielded, their shield animations come back
local function restoreShieldAnimations(char)
	if char and char.Parent and char:GetAttribute("Shielded") == true then
		AnimationHandler.PlayWeaveAnimation(char, "Shielded", "Channel", false)
		AnimationHandler.PlayWeaveAnimation(char, "Shielded", "Channeling", false)
	end
end

-- EFFECTS: CASTER BEAMS, TARGET AURA, TRAIL BURST -----------------------------------------------------------
local rng = Random.new()

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- the same NumberSequence, pushed toward fully invisible by f (0 = as authored, 1 = gone)
local function lerpSequence(base: NumberSequence, f: number): NumberSequence
	local points = {}
	for _, key in base.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value + (1 - key.Value) * f))
	end
	return NumberSequence.new(points)
end

-- switches an effect off: emitters / trails stop, beams fade out over `duration`
local function fadeOutEffects(root: Instance, duration: number)
	local beams = {}
	for _, d in root:GetDescendants() do
		if d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		elseif d:IsA("Beam") then
			table.insert(beams, { beam = d, base = d.Transparency })
		end
	end
	if #beams == 0 then return end
	local startedAt = os.clock()
	task.spawn(function()
		while root.Parent do
			local f = math.clamp((os.clock() - startedAt) / duration, 0, 1)
			for _, b in beams do
				if b.beam.Parent then b.beam.Transparency = lerpSequence(b.base, f) end
			end
			if f >= 1 then break end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- fx = { models = {...}, conn = RBXScriptConnection }
local function stopFx(fx, fadeTime: number)
	if not fx or fx.stopped then return end
	fx.stopped = true
	for _, model in fx.models do fadeOutEffects(model, fadeTime) end
	task.delay(fadeTime + FX_TAIL, function() -- keep following the weaver while it fades, THEN delete
		if fx.conn then fx.conn:Disconnect() end
		for _, model in fx.models do model:Destroy() end
	end)
end

-- ONE of the two caster models. Returns the model and a function that must be called every frame.
local function buildCasterModel(src: Instance, humRP: BasePart, parent: Instance, label: string)
	local model = src:Clone()

	-- the CenterPart (rides on the humanoid root part) and the numbered joints around it
	local center
	local joints = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name:lower():find("center") then center = child else table.insert(joints, child) end
		end
	end
	if not center and model:IsA("Model") and model.PrimaryPart then
		center = model.PrimaryPart
		local index = table.find(joints, center)
		if index then table.remove(joints, index) end
	end
	if not center then
		warn(`[Stilling] {label} has no part named CenterPart: skipped`)
		model:Destroy()
		return nil
	end
	center.Anchored = true
	center.CanCollide, center.CanQuery, center.CanTouch = false, false, false

	-- where each joint sits relative to the CenterPart, read from the asset itself BEFORE anything moves
	local frame0 = humRP.CFrame * CASTER_OFFSET
	local entries = {}
	for _, part in joints do
		local rel = center.CFrame:ToObjectSpace(part.CFrame)
		local align = part:FindFirstChildOfClass("AlignPosition")
		local orient = part:FindFirstChildOfClass("AlignOrientation")
		-- Position / CFrame properties only drive the part in OneAttachment mode (same as the Shielding spirit joints)
		local driven = align ~= nil and align.Mode == Enum.PositionAlignmentMode.OneAttachment
		part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		if driven then
			part.Anchored = false -- an AlignPosition can't move an anchored part
			part.Massless = true
			align.Enabled = true
		else
			part.Anchored = true -- no usable AlignPosition: we place this joint by hand every frame
			if align then align.Enabled = false end
		end
		if orient and orient.Mode ~= Enum.OrientationAlignmentMode.OneAttachment then orient = nil end
		if DEBUG_CASTER_FX then
			print(`[Stilling] {label}.{part.Name}: offset from the center = {string.format("%.2f, %.2f, %.2f", rel.X, rel.Y, rel.Z)}{driven and " (AlignPosition)" or " (placed by hand)"}`)
		end
		table.insert(entries, { part = part, rel = rel, align = align, orient = orient, driven = driven })
		part.CFrame = frame0 -- every joint starts inside the center and spreads out
	end
	center.CFrame = frame0

	-- every Beam gets its own wander on top of its authored curve (like the Linking beams)
	local beams = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Beam") then
			table.insert(beams, {
				beam = d, c0 = d.CurveSize0, c1 = d.CurveSize1,
				seed0 = rng:NextNumber(0, 1000), seed1 = rng:NextNumber(0, 1000),
				speed = CASTER_WAVE_SPEED * rng:NextNumber(0.6, 1.4),
			})
		end
	end

	model.Parent = parent

	local startedAt = os.clock()
	local function update()
		if not humRP.Parent then return end
		local elapsed = os.clock() - startedAt
		local frame = humRP.CFrame * CASTER_OFFSET
		center.CFrame = frame
		local expand = smooth(math.clamp(elapsed / CASTER_EXPAND_TIME, 0, 1))
		for _, j in entries do
			local goal = frame * j.rel
			local position = frame.Position:Lerp(goal.Position, expand)
			if j.driven then
				j.align.Position = position
			else
				j.part.CFrame = CFrame.new(position) * goal.Rotation
			end
			if j.orient then j.orient.CFrame = frame.Rotation * j.rel.Rotation end
		end
		if CASTER_WAVE ~= 0 then
			for _, b in beams do
				if b.beam.Parent then
					b.beam.CurveSize0 = b.c0 + math.noise(elapsed * b.speed, b.seed0) * CASTER_WAVE
					b.beam.CurveSize1 = b.c1 + math.noise(elapsed * b.speed * 0.8, b.seed1) * CASTER_WAVE
				end
			end
		end
	end
	return model, update
end

local function buildCasterFx(s)
	if not casterAsset then return end
	local humRP = s.caster:FindFirstChild("HumanoidRootPart")
	if not humRP then return end

	local fx = { models = {} }
	local updates = {}
	for _, name in { "StillingLeft", "StillingRight" } do
		local src = casterAsset:FindFirstChild(name)
		if src then
			local model, update = buildCasterModel(src, humRP, s.folder, name)
			if model then
				table.insert(fx.models, model)
				table.insert(updates, update)
			end
		else
			warn(`[Stilling] StillingCaster has no {name}`)
		end
	end
	if #fx.models == 0 then return end

	fx.conn = RunService.RenderStepped:Connect(function()
		for _, update in updates do update() end
	end)
	s.casterFx = fx
end

-- the target effect: a model stuck to the target's HumanoidRootPart (PivotTo every frame)
local function buildTargetFx(s)
	if not targetAsset then return end
	local hrp = s.target:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local model = targetAsset:Clone()
	prepare(model) -- anchored, no collisions: we move it ourselves
	model:PivotTo(hrp.CFrame * TARGET_OFFSET)
	model.Parent = s.folder
	
	-- Play Sound
	model:FindFirstChild("1"):FindFirstChild("StillingTarget_Airy Pass By Fast Breathing Rush Of Air 2 (SFX)"):Play()

	local fx = { models = { model } }
	fx.conn = RunService.RenderStepped:Connect(function()
		if hrp.Parent and model.Parent then
			model:PivotTo(hrp.CFrame * TARGET_OFFSET)
		end
	end)
	s.targetFx = fx
end

-- disconnects the effect loops at once (the models go with the session's folder)
local function destroyEffects(s)
	for _, fx in { s.casterFx, s.targetFx } do
		if fx and fx.conn then fx.conn:Disconnect() end
	end
end

-- TRAIL BURST ----------------------------------------------------------------------------------------------
-- a uniformly random direction (normalizing a random vector from a cube would favour the corners)
local function randomDirection(): Vector3
	local z = rng:NextNumber(-1, 1)
	local angle = rng:NextNumber(0, 2 * math.pi)
	local radius = math.sqrt(1 - z * z)
	return Vector3.new(radius * math.cos(angle), z, radius * math.sin(angle))
end

-- a random vector at right angles to `direction`, up to BURST_CURVE studs long
local function randomSideways(direction: Vector3): Vector3
	local helper = math.abs(direction.Y) < 0.9 and Vector3.yAxis or Vector3.xAxis
	local right = direction:Cross(helper).Unit
	local up = direction:Cross(right).Unit
	local angle = rng:NextNumber(0, 2 * math.pi)
	return (right * math.cos(angle) + up * math.sin(angle)) * rng:NextNumber(0.4, 1) * BURST_CURVE
end

-- the trail reached the end of its path: switch it off, let what it drew fade, then delete it
local function finishTrail(trail: BasePart)
	local lifetime = 0
	for _, d in trail:GetDescendants() do
		if d:IsA("Trail") then
			d.Enabled = false
			lifetime = math.max(lifetime, d.Lifetime)
		elseif d:IsA("ParticleEmitter") then
			d.Enabled = false
			lifetime = math.max(lifetime, d.Lifetime.Max)
		end
	end
	task.delay(lifetime + 0.2, function()
		if trail.Parent then trail:Destroy() end
	end)
end

local printedTrailDebug = false

local function spawnBurstTrail(s)
	local torso = s.target:FindFirstChild("UpperTorso") or s.target:FindFirstChild("Torso")
	if not torso then return end

	-- a random element's trail (the children of Assets.Elements.Trails are named after the elements)
	local templates = {}
	for _, child in trailAssets:GetChildren() do
		if child:IsA("BasePart") then table.insert(templates, child) end
	end
	if #templates == 0 then return end
	local template = templates[rng:NextInteger(1, #templates)]

	local trail = template:Clone()
	-- the template is built to be pulled around by constraints; here the bezier moves it, so they would only fight it
	for _, d in trail:GetDescendants() do
		if d:IsA("AlignPosition") or d:IsA("AlignOrientation") or d:IsA("WeldConstraint") then d:Destroy() end
	end
	trail.Anchored = true
	trail.CanCollide, trail.CanQuery, trail.CanTouch = false, false, false

	-- WHERE THE VISIBLE TRAIL IS: a Trail is drawn between its two attachments, which may sit away from the part's own
	-- center. Measure how far (the middle of each Trail's two attachments, relative to the part) and shift the whole
	-- path by the opposite amount, so it is the TRAIL, not the part, that leaves the chest.
	local offsetSum, offsetCount = Vector3.zero, 0
	for _, d in trail:GetDescendants() do
		if d:IsA("Trail") and d.Attachment0 and d.Attachment1 then
			local middle = (d.Attachment0.WorldPosition + d.Attachment1.WorldPosition) / 2
			offsetSum += middle - trail.Position
			offsetCount += 1
		end
	end
	local shift = offsetCount > 0 and -(offsetSum / offsetCount) or Vector3.zero
	if DEBUG_TRAILS and not printedTrailDebug then
		printedTrailDebug = true
		print(`[Stilling] trail template {template.Name}: {offsetCount} Trail(s), the visible trail sits {string.format("%.2f", -shift.Magnitude)} studs ({string.format("%.2f, %.2f, %.2f", -shift.X, -shift.Y, -shift.Z)}) from the part's center, and is shifted back by that`)
	end

	-- THE POINTS TABLE: start on the chest, two control points pushed sideways, end ~100 studs away
	local start = torso.Position + shift
	local direction = randomDirection()
	local distance = BURST_DISTANCE * (1 + rng:NextNumber(-BURST_DISTANCE_JITTER, BURST_DISTANCE_JITTER))
	local points = {
		Point1 = start,
		Point2 = start + direction * (distance / 3) + randomSideways(direction),
		Point3 = start + direction * (distance * 2 / 3) + randomSideways(direction),
		Point4 = start + direction * distance,
	}
	local bezier = Utilities.BezierSetup(points)
	if not bezier then
		trail:Destroy()
		return
	end

	trail.Position = start -- BEFORE it is parented, so it never draws a streak from the template's own position
	trail.Parent = s.folder

	-- CreateVector3Tween only sets Position (like the Shielding rotator)
	local tween = bezier:CreateVector3Tween(trail, { "Position" }, TweenInfo.new(BURST_TRAVEL_TIME, BURST_EASING, BURST_EASING_DIRECTION))
	tween.Completed:Once(function() finishTrail(trail) end)
	tween:Play()
	
	-- Play Sound
	local sound = sfx:FindFirstChild("StillingTrail_Magic Twirling Small High Pitch Spinning Chi (SFX)"):Clone()
	sound.Parent = trail
	sound:FindFirstChildOfClass("PitchShiftSoundEffect").Octave = math.random(90, 120)/100
	sound:Play()
	
	task.delay(BURST_TRAVEL_TIME + 6, function() -- failsafe: nothing can outlive this
		if trail.Parent then trail:Destroy() end
	end)
end

local function startBurst(s)
	if s.bursting or s.destroyed then return end
	s.bursting = true
	task.spawn(function()
		local endsAt = os.clock() + DISPERSE_TIME
		while not s.destroyed and not s.stopBurst and os.clock() < endsAt do
			local ok, err = pcall(spawnBurstTrail, s)
			if not ok then
				warn(`[Stilling] trail burst stopped: {err}`)
				break
			end
			task.wait(1 / TRAILS_PER_SECOND)
		end
		s.bursting = false
	end)
end

-- SESSIONS ------------------------------------------------------------------------------------------------
local sessions = {} -- [caster character] = session

local function ease(a) return a * a * (3 - 2 * a) end

local function landing(needle)
	-- the point on the body part the needle goes to, and the center it should have when fully embedded
	local part = needle.part
	if not part or not part.Parent then return nil end
	local hit = part.CFrame:PointToWorldSpace(needle.offset)
	local dir = (hit - needle.spawn)
	if dir.Magnitude < 0.01 then return nil end
	dir = dir.Unit
	return hit - dir * (NEEDLE_LENGTH / 2) + dir * EMBED, dir
end

local function dissolve(needle)
	if needle.dissolving then return end
	needle.dissolving = true
	needle.mode = "gone"
	local parts = prepare(needle.inst)
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(DISSOLVE_TIME), { Transparency = 1 }):Play()
	end
	task.delay(DISSOLVE_TIME + 0.05, function()
		if needle.inst then needle.inst:Destroy() end
	end)
end

local function destroySession(s)
	if s.destroyed then return end
	s.destroyed = true
	s.stopBurst = true
	if s.hb then s.hb:Disconnect() end
	for _, c in s.conns do c:Disconnect() end
	destroyEffects(s)
	for _, needle in s.needles do
		if needle.inst then needle.inst:Destroy() end
	end
	if s.folder then s.folder:Destroy() end -- the effects, the needles and every trail still in the air
	if sessions[s.caster] == s then sessions[s.caster] = nil end
end

local function returnNeedles(s, duration)
	if s.retracting then return end
	s.retracting = true
	for _, needle in s.needles do
		if needle.mode ~= "gone" then
			needle.mode = "returning"
			needle.retT0 = os.clock()
			needle.retDur = duration
			needle.retFrom = getCF(needle)
			local _, dir = landing(needle)
			needle.retTo = needleCF(needle.spawn, dir or needle.retFrom.LookVector)
		end
	end
	-- (each needle dissolves and destroys itself. The SESSION lives on: it still owns the caster / target effects and the
	-- trail burst, and is deleted by onEnd / onFizzle.)
end

local function stepNeedles(s)
	local now = os.clock()
	for _, needle in s.needles do
		local mode = needle.mode
		if mode == "hover" then
			if needle.palm then
				-- needle 1 rides on the caster's left palm, pointing at where it will go
				local palm = palmPosition(s.caster)
				if palm then needle.spawn = palm end
				local _, dir = landing(needle)
				if dir then setCF(needle, needleCF(needle.spawn + dir * (NEEDLE_LENGTH / 2 - 0.3), dir)) end
			else
				local _, dir = landing(needle)
				if dir then setCF(needle, needleCF(needle.spawn, dir)) end
			end
		elseif mode == "flying" then
			
			local center, dir = landing(needle)
			if not center then
				needle.mode = "gone"; dissolve(needle)
			else
				local a = math.clamp((now - needle.t0) / needle.dur, 0, 1)
				local startPos = needle.startPos or needle.spawn
				local pos = startPos:Lerp(center, a * a) -- accelerates into the body
				setCF(needle, needleCF(pos, dir))
				if a >= 1 then
					if DEBUG_SIGNALS then
						print(`[Stilling] needle {needle.index} landed {string.format("%.2f", now - needle.t0)}s after launch`)
					end
					needle.mode = "stuck"
					needle.rel = needle.part.CFrame:ToObjectSpace(getCF(needle))
				end
			end
		elseif mode == "stuck" then
			if needle.part and needle.part.Parent then
				setCF(needle, needle.part.CFrame * needle.rel)
			end
		elseif mode == "returning" then
			local a = ease(math.clamp((now - needle.retT0) / needle.retDur, 0, 1))
			-- keeps the needle's own orientation, slides back along the line it came in on
			local from, to = needle.retFrom, needle.retTo
			local toPos = to.Position
			if needle.palm then toPos = palmPosition(s.caster) or toPos end -- needle 1 goes back to the palm
			setCF(needle, CFrame.new(from.Position:Lerp(toPos, a)) * (from - from.Position))
			if a >= 1 then dissolve(needle) end
		end
	end
end

local function newSession(casterChar, targetChar, plan)
	if sessions[casterChar] then destroySession(sessions[casterChar]) end
	local s = {
		caster = casterChar, target = targetChar, needles = {}, conns = {},
		isCaster = casterChar == LocalPlayer.Character,
		isTarget = targetChar == LocalPlayer.Character,
		tracks = {},
	}
	sessions[casterChar] = s

	-- everything this cast draws lives in one folder, so deleting it deletes all of it
	s.folder = Instance.new("Folder")
	s.folder.Name = "Stilling_" .. casterChar.Name
	s.folder.Parent = fxFolder
	task.delay(MAX_SESSION_TIME, function() destroySession(s) end)

	for i, entry in plan do
		local clone = needleTemplate:Clone()
		prepare(clone)
		clone.Parent = s.folder
		local needle = {
			inst = clone, part = entry.part or targetChar:FindFirstChild("HumanoidRootPart"),
			offset = entry.offset, spawn = entry.spawn, mode = "hover", index = i,
			palm = (i == 1), -- the first needle always comes from the caster's left palm
		}
		s.needles[i] = needle
	end
	
	local first = s.needles[1]
	if first then
		for _, name in { "StillingCast_Leviathan Spell Cast Sound Effect", "StillingCast2_Magic Spell" } do
			local sound = first.inst:FindFirstChild(name, true)
			if sound and sound:IsA("Sound") then sound:Play() end
		end
	end

	s.hb = RunService.Heartbeat:Connect(function() stepNeedles(s) end)
	table.insert(s.conns, casterChar.Destroying:Connect(function() destroySession(s) end))
	table.insert(s.conns, targetChar.Destroying:Connect(function() destroySession(s) end))
	return s
end

-- STAGES --------------------------------------------------------------------------------------------------
-- sends these needles flying (used by the server's "Needle" stage AND by the target's own marker, see onFire)
local function launch(s, indices, source)
	for _, index in indices or {} do
		local needle = s.needles[index]
		if needle and needle.mode == "hover" then
			if DEBUG_SIGNALS then
				print(`[Stilling] needle {index} launched by {source or "?"}`)
			end
			needle.startPos = getCF(needle).Position -- (needle 1 starts from wherever the palm is right now)
			needle.dur = NEEDLE_FLIGHT_TIME
			needle.t0 = os.clock()
			needle.mode = "flying"
			
			-- Play Sounds
			local octave = s.octave or 0.8
			for _, name in { "StillingNeedle1_Whoosh2", "StillingNeedle2_Magica Record Shoot3" } do
				local sound = needle.inst:FindFirstChild(name, true)
				if sound and sound:IsA("Sound") then
					local pitch = sound:FindFirstChildOfClass("PitchShiftSoundEffect")
					if pitch then pitch.Octave = octave end
					sound:Play()
				end
			end
			s.octave = octave + 0.1 -- goes up once per needle, after both sounds
		end
	end
end

local function onLock(char, data)
	local s = newSession(char, data.target, data.plan or {})
	buildCasterFx(s)
	buildTargetFx(s)
	if s.isTarget then
		stopActionTracks(s.target)
		s.tracks.loop = loadTrack(s.target, "StillingTargetChannelingLoop", Enum.AnimationPriority.Action, true)
		if s.tracks.loop then s.tracks.loop:Play(0.15) end
	end
end

local function onFire(s)
	if s.isCaster then
		s.tracks.channel2 = loadTrack(s.caster, "StillingChannel2", Enum.AnimationPriority.Action2, false)
		s.tracks.channeling = loadTrack(s.caster, "StillingChanneling", Enum.AnimationPriority.Action, true)
		if s.tracks.channeling then s.tracks.channeling:Play(0.2) end
		if s.tracks.channel2 then s.tracks.channel2:Play(0.1) end
	end
	if s.isTarget then
		local track = loadTrack(s.target, "StillingTargetChanneling", Enum.AnimationPriority.Action2, false)
		s.tracks.targetChanneling = track
		if track then
			-- an animation that hasn't finished loading can miss its markers: wait for it (max 3s)
			local waited = os.clock()
			while track.Length == 0 and os.clock() - waited < 3 do task.wait() end
			if DEBUG_SIGNALS then
				local data = AnimationHandler["StillingTargetChanneling"]
				print(`[Stilling] StillingTargetChanneling: id = {data and data.id}, length = {string.format("%.2f", track.Length)}s ({string.format("%.0f", track.Length * 60)} frames at 60fps)`)
			end
			-- "Signal" markers carry the needle number (1..5) as their parameter
			table.insert(s.conns, track:GetMarkerReachedSignal("Signal"):Connect(function(param)
				local n = tonumber(param) or tonumber(string.match(tostring(param), "%d+"))
				if DEBUG_SIGNALS then
					print(`[Stilling] marker Signal("{tostring(param)}") reached at {string.format("%.2f", track.TimePosition)}s of the animation`)
				end
				if n and SIGNAL_NEEDLES[n] then
					StillingRemote:FireServer("Needle", n)
					-- the TARGET sees the needle at once, without waiting for the server round trip. The server's
					-- broadcast arrives a moment later and finds these needles already flying, so nothing doubles up.
					launch(s, SIGNAL_NEEDLES[n], "the target's own marker (no network)")
				end
			end))
			track:Play(0.1)
		end
	end
end

local function onNeedle(s, data)
	launch(s, data.needles, "the SERVER broadcast")
end

local function onCast(s)
	local targetModel = s.targetFx and s.targetFx.models[1]
	if targetModel then
		-- a sound inside it (use your Sound's real name)
		local sound = targetModel:FindFirstChild("StillingDisperse_Red Mist Spell Cast (Short)", true)
		if sound and sound:IsA("Sound") then sound:Play() end
		
		local sound1 = targetModel:FindFirstChild("StillingTarget_Leviathan Spell Cast Sound Effect", true)
		if sound1 and sound1:IsA("Sound") then sound1:Play() end
		
		task.delay(RETRACT_DELAY,function()
			local sound2 = targetModel:FindFirstChild("StillingBlast_Jean(Marvel Girl) Shockwave", true)
			if sound2 and sound2:IsA("Sound") then sound2:Play() end
			
			local blast = targetModel:FindFirstChild("3")
			if blast then
				for i, v in blast:GetChildren() do
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount") or 15)
					end
				end
			end
		end)
	end
	
	if s.isCaster then
		stopTrack(s.tracks.channel2, 0.1)
		stopTrack(s.tracks.channeling, 0.15)
		AnimationHandler.StopWeaveAnimation(s.caster, WEAVE, "Channel")
		local cast = loadTrack(s.caster, "StillingCast", Enum.AnimationPriority.Action2, false)
		s.tracks.cast = cast
		if cast then cast:Play(0.1) end
	end
	if s.isTarget then
		stopTrack(s.tracks.loop, 0.15)
		stopTrack(s.tracks.targetChanneling, 0.15)
		local cast = loadTrack(s.target, "StillingTargetCast", Enum.AnimationPriority.Action2, false)
		s.tracks.targetCast = cast
		local told = false
		local function tell()
			if told then return end
			told = true
			StillingRemote:FireServer("TargetCastDone") -- "put me down on the ground"
		end
		if cast then
			-- the release event inside StillingTargetCast (named "Signal" or "Release"), or the end of the animation
			table.insert(s.conns, cast:GetMarkerReachedSignal("Signal"):Connect(tell))
			table.insert(s.conns, cast:GetMarkerReachedSignal("Release"):Connect(tell))
			table.insert(s.conns, cast.Stopped:Connect(tell))
			cast:Play(0.1)
		else
			tell()
		end
	end
	-- the needles stay in the body for a moment while StillingCast plays, then are pulled out. The caster's effect ends
	-- with them, and the moment they are out the trails start bursting from the target's upper torso.
	task.delay(RETRACT_DELAY, function()
		if s.destroyed then return end
		returnNeedles(s, RETURN_TIME)
		stopFx(s.casterFx, CASTER_FADE_TIME)
		task.delay(RETURN_TIME, function() startBurst(s) end)
	end)
end

local function stopAllTracks(s)
	for _, track in s.tracks do stopTrack(track, 0.15) end
end

local function onFizzle(s)
	stopAllTracks(s)
	if s.isCaster then AnimationHandler.StopWeaveAnimation(s.caster, WEAVE, "Channel") end
	returnNeedles(s, FAST_RETURN_TIME)
	s.stopBurst = true
	stopFx(s.casterFx, CASTER_FADE_TIME)
	stopFx(s.targetFx, TARGET_FADE_TIME)
	task.delay(FAST_RETURN_TIME + DISSOLVE_TIME + FX_TAIL + TARGET_FADE_TIME, function() destroySession(s) end)
end

-- the target was dropped: no more trails, the target effect fades, and the session is deleted a moment later
local function onEnd(s)
	s.stopBurst = true
	stopFx(s.casterFx, CASTER_FADE_TIME) -- (already gone in a normal cast; this covers the odd one that never retracted)
	stopFx(s.targetFx, TARGET_FADE_TIME)
	task.delay(END_TAIL, function() destroySession(s) end)
end

WeavingEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, stage, data)
	if weaveName ~= WEAVE or typeof(stage) ~= "string" then return end
	data = data or {}

	if stage == "Lock" then
		if typeof(data.target) ~= "Instance" then return end
		onLock(char, data)
		return
	end

	-- the target's shield animations come back when the weave fizzled or finished (the shield itself never broke).
	-- Handled here, not on the session, because the session may already be gone by the time "End" arrives.
	if (stage == "Fizzle" or stage == "End") and data.target == LocalPlayer.Character then
		task.delay(0.3, function() restoreShieldAnimations(LocalPlayer.Character) end)
	end

	local s = sessions[char]
	if not s or s.destroyed then return end
	if stage == "Fire" then onFire(s)
	elseif stage == "Needle" then onNeedle(s, data)
	elseif stage == "Cast" then onCast(s)
	elseif stage == "Fizzle" then onFizzle(s)
	elseif stage == "End" then onEnd(s)
	end
end)
