-- Shielding   (LocalScript, client)
-- The SERVER decides everything. This only plays visuals and animations when the server says so.
-- Several casters can shield one target, so each caster has their OWN effects, but the target has ONE shield.
--
--   HOOK 1  WeavingFxEvent             a caster tried to cast                 (E pressed)           once per caster
--   HOOK 2  WeavingInstantEvent        a caster locked onto the target        (link caster->target)  once per caster
--   HOOK 3  WeavingEvent               the shield took hold on the target     (ShieldedChannel...)   ONCE per shield
--   END     WeavingInstantReleaseEvent a caster left the shield               (stop THEIR effects)   once per caster
--                                      freedTarget ~= nil  -> that was the LAST caster: the target is free

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local AnimationHandler = require(Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))
local Utilities = require(Modules:WaitForChild("UTILITIES"))
local Effects = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local Sfx = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("SFX"))

-- REMOTES
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")

local WEAVE = "Shielding"
local LocalPlayer = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Shielding")
local sounds = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- TUNING ------------------------------------------------------------------------------------------
local CAST_EXIT_TIME = 5                  -- seconds the caster's effect keeps playing after they leave the shield
local ROTATOR_TWEEN_TIME = 0.75           -- the rotator flying to the hand, and the trails closing in
local TRAIL_START = 5                     -- studs between each trail and the rotator at the start...
local TRAIL_END = 1                       -- ...and at the end
local ROTATOR_SPIN = math.rad(300)        -- radians per second (the same as 5 degrees per frame at 60 FPS)
local SHIELD_SPIN = math.rad(30)         
local MIN_SPIN_TIME = 10                  -- every spirit joint turns once every MIN..MAX seconds (picks a new time after each turn)
local MAX_SPIN_TIME = 20

-- where each spirit joint sits relative to the torso. The key is the joint part's NAME ("1", "2", ...).
local SPIRIT_OFFSETS = {
	[1] = Vector3.new(2.7, -1.9, -0.3),
	[2] = Vector3.new(-2.5, 1.0, -2.1),
	[3] = Vector3.new(4.0, -1.4, 1.9),
	[4] = Vector3.new(-3.5, 0, -1.5),
	[5] = Vector3.new(2.6, -1.0, -1.8),
	[6] = Vector3.new(-0.5, 2.3, 0.6),
	[7] = Vector3.new(-0.8, -3.4, 2.7),
	[8] = Vector3.new(1.9, 1.5, 0.1),
}

-- THE DATA --------------------------------------------------------------------------------------------
-- Prepared up front: every field exists from the start (nil until it is built), then each builder fills it in.

-- one cast = the effect around the CASTER (rotator, trails, spirit joints)
local function newCast()
	return {
		folder = nil,          -- everything below is parented here, so destroying it removes it all
		rotator = nil,
		trail1 = nil,
		trail2 = nil,
		spirit = nil,          -- the model of joints that float around the torso
		shieldCaster = nil,    -- the part at the hand
		joints = {},           -- one entry per spirit joint (part, align, orient, offset, axis, angle, speed)
		connections = {},      -- connections.rotator, connections.spirit
	}
end

-- one link = the effect on the TARGET, made by one caster
local function newLink()
	return {
		target = nil,
		folder = nil,
		shield = nil,          -- the shield model on the target
		channel = nil,         -- the particles on the target
		connections = {},      -- connections.follow
		sounds = {},
	}
end

local casts = {} -- [caster's UserId] = { cast, cast, ... }   casts that haven't ended yet, oldest first
local links = {} -- [caster's UserId] = link

-- SMALL HELPERS -------------------------------------------------------------------------------------
local rng = Random.new()

local function randomAxis()
	local axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	if axis.Magnitude < 0.1 then return Vector3.yAxis end
	return axis.Unit
end

local function randomSpinSpeed() -- radians per second, in a random direction
	local sign = rng:NextInteger(0, 1) == 0 and -1 or 1
	return sign * (2 * math.pi) / rng:NextNumber(MIN_SPIN_TIME, MAX_SPIN_TIME)
end

local function disconnectAll(connections)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local shieldedFx = {} -- [target character] = { clones placed on the target's body parts }

-- turns ONE instance's effect off (emitters, trails, beams, sounds)
local function fadeOutInstance(v)
	if v:IsA("ParticleEmitter") or v:IsA("Trail") then
		v.Enabled = false
	elseif v:IsA("Sound") then
		Sfx.FadeSound(v, 0, 2, 60)
	elseif v:IsA("Beam") then
		local lowest = 1
		for _, keypoint in v.Transparency.Keypoints do
			lowest = math.min(lowest, keypoint.Value)
		end
		if lowest < 1 then -- already invisible beams have nothing to fade
			Effects.NumberValueTweenObj(v, "Beam", "Transparency", lowest, 1, 1, 60)
		end
	end
end

-- the instance itself AND everything inside it
local function fadeOutEffects(root)
	fadeOutInstance(root)
	for _, v in root:GetDescendants() do
		fadeOutInstance(v)
	end
end

local function endCast(cast)
	-- fade starts now; the connections stay alive so the parts keep following the caster while they fade
	fadeOutEffects(cast.folder)

	task.delay(CAST_EXIT_TIME, function()
		disconnectAll(cast.connections)
		cast.folder:Destroy()
	end)
end

local function endLink(link)
	-- stop following the target, so everything freezes where it is
	disconnectAll(link.connections)

	for _, v in link.folder:GetDescendants() do
		if v:IsA("BasePart") then
			v.Anchored = true
		end
	end

	fadeOutEffects(link.folder)
	for i, v in link.sounds do
		fadeOutInstance(v)
		task.delay(3, function() 
			if v then v:Destroy() end
		end)
	end
	
	task.delay(5, function()
		if link.folder then link.folder:Destroy() end
	end)
end

-- BUILDERS (each one fills in part of the cast) ---------------------------------------------------
-- the rotator flies from above the caster to the hand, spinning. The two trails circle it and close in.
local function startRotator(cast, humRP, hand)
	cast.rotator = assets:WaitForChild("Rotator"):Clone()
	cast.rotator.CFrame = humRP.CFrame * CFrame.new(0, 10, -10) -- above and in front of the caster (-Z is forward)
	cast.rotator.Parent = cast.folder
	
	-- Play Sounds
	local sfx1 = sounds:WaitForChild("Shielding1_Magic"):Clone(); sfx1.Parent = cast.rotator; sfx1:Play()
	local sfx2 = sounds:WaitForChild("Shielding2_Magic WHOOSH  Sound FX"):Clone(); sfx2.Parent = cast.rotator; sfx2:Play()

	cast.trail1 = Effects.CreateTrail2("Spirit", cast.folder, false, false, false, cast.rotator, cast.rotator.CFrame * CFrame.new(TRAIL_START, 0, 0))
	cast.trail2 = Effects.CreateTrail2("Spirit", cast.folder, false, false, false, cast.rotator, cast.rotator.CFrame * CFrame.new(-TRAIL_START, 0, 0))

	-- THE PATH: start -> a control point -> the hand (the hand is a Part, so the curve follows it as it moves)
	local bezier = Utilities.BezierSetup({
		Point1 = cast.rotator.Position,
		Point2 = (humRP.CFrame * CFrame.new(3, 5, -5)).Position,
		Point3 = hand,
	})

	-- CreateVector3Tween only sets Position, so the spin below is kept (CreateCFrameTween would wipe it out)
	local tweenInfo = TweenInfo.new(ROTATOR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local tween = bezier:CreateVector3Tween(cast.rotator, { "Position" }, tweenInfo)
	local arrived = false
	tween.Completed:Connect(function()
		arrived = true
	end)
	tween:Play()

	local startTime = os.clock()
	local angle = 0
	cast.connections.rotator = RunService.RenderStepped:Connect(function(dt)
		angle += ROTATOR_SPIN * dt

		if arrived then
			cast.rotator.CFrame = hand.CFrame * CFrame.Angles(0, angle, 0) -- stuck to the hand
		else
			cast.rotator.CFrame = CFrame.new(cast.rotator.Position) * CFrame.Angles(0, angle, 0) -- still travelling
		end

		-- the distance between the trails and the rotator goes from TRAIL_START to TRAIL_END
		local alpha = math.clamp((os.clock() - startTime) / ROTATOR_TWEEN_TIME, 0, 1)
		local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		local distance = TRAIL_START + (TRAIL_END - TRAIL_START) * eased

		cast.trail1.CFrame = cast.rotator.CFrame * CFrame.new(distance, 0, 0)
		cast.trail2.CFrame = cast.rotator.CFrame * CFrame.new(-distance, 0, 0)
	end)
end

-- the spirit joints float around the torso (AlignPosition) and each one spins on its own axis (AlignOrientation)
local function startSpirit(cast, humRP, torso, hand)
	cast.spirit = assets:WaitForChild("Spirit"):Clone()
	cast.spirit.Parent = cast.folder

	cast.shieldCaster = assets:WaitForChild("ShieldCaster"):Clone()
	cast.shieldCaster.Parent = cast.folder

	-- look everything up ONCE, not every frame
	for _, part in cast.spirit:GetChildren() do
		if part:IsA("BasePart") then
			part.Position = torso.Position -- every joint starts inside the torso

			local offset = SPIRIT_OFFSETS[tonumber(part.Name)]
			if offset then
				local joint = {
					part = part,
					align = part:FindFirstChildOfClass("AlignPosition"),
					orient = part:FindFirstChildOfClass("AlignOrientation"),
					offset = offset,
					axis = randomAxis(),
					angle = rng:NextNumber(0, 2 * math.pi), -- random starting pose, so they never look alike
					speed = randomSpinSpeed(),
				}
				if joint.align then
					joint.align.Responsiveness = rng:NextInteger(5, 10) -- each one catches up at its own pace
				end
				table.insert(cast.joints, joint)
			end
		end
	end

	cast.connections.spirit = RunService.RenderStepped:Connect(function(dt)
		if hand.Parent then
			cast.shieldCaster.Position = hand.Position + Vector3.new(0, 0, 1.25)
		end

		-- the direction the caster faces, as a pure rotation
		local facing = CFrame.lookAt(Vector3.zero, humRP.CFrame.LookVector)

		for _, joint in cast.joints do
			-- position: follow the torso
			if joint.align then
				if not joint.align.Enabled then joint.align.Enabled = true end
				joint.align.Position = torso.CFrame * joint.offset
			end

			-- orientation: face the caster's direction, then spin on this joint's own axis
			joint.angle += joint.speed * dt
			if math.abs(joint.angle) >= 2 * math.pi then
				joint.angle = 0                  -- a full turn looks identical, so there's no snap
				joint.speed = randomSpinSpeed()  -- and the next turn takes a new random time
			end
			if joint.orient then
				joint.orient.CFrame = facing * CFrame.fromAxisAngle(joint.axis, joint.angle)
			end
		end
	end)
end

-- the shield took hold: speed up the particles, switch them off after a second, and rescale the shield
local function onShielded(link, target)
	-- Play sfx
	link.sounds.sfxabsorb1:Play()
	link.sounds.sfxabsorb2:Play()
	link.sounds.sfxloop3:Play()
	link.sounds.sfxloop4:Play()
	
	-- Stop some Shield loop sounds
	link.sounds.sfxloop1:Stop()
	link.sounds.sfxloop2:Stop()
	
	-- Change speed to make it look like vfx is absorbing in
	for _, emitter in link.channel:GetChildren() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Speed = NumberRange.new(30, 50) 
		end
	end

	task.delay(1, function()
		if not link.channel.Parent then return end -- the link ended in the meantime
		for _, emitter in link.channel:GetDescendants() do
			if emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
			end
		end
	end)

	-- NOTE: ScaleModel scales TO the number you give it (here 4x, over 1 second). Use a number below 1 to shrink it.
	Utilities.ScaleModel(link.shield, 4, 1)
	
	task.delay(3, function()
		if not link.shield or not link.shield.Parent then return end -- link ended and was destroyed

		for _, v in link.shield:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				v.Enabled = false
			end
		end

		Utilities.ScaleModel(link.shield, 0.05, 1)
		task.wait(5)
		if link.shield and link.shield.Parent then link.shield:Destroy() end
	end)
	
	local bodyParts = {
		"Head",
		"LeftUpperArm",
		"LeftLowerArm",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"LeftHand",
		"LeftFoot",
		"RightUpperArm",
		"RightLowerArm",
		"RightUpperLeg",
		"RightLowerLeg",
		"RightHand",
		"RightFoot",
		"UpperTorso",
		"LowerTorso",
	}
	
	local shieldAssets = assets:FindFirstChild("Shielded")

	-- ONE set per target, no matter how many casters are shielding it
	if shieldAssets and not shieldedFx[target] then
		local fx = {}
		shieldedFx[target] = fx

		for _, bodyPartName in bodyParts do
			local part = target:FindFirstChild(bodyPartName)
			if part then
				for _, asset in shieldAssets:GetChildren() do
					local clone = asset:Clone()
					clone.Parent = part
					table.insert(fx, clone)
				end
			end
		end
	end
end

-- HOOK 1: a caster tried to cast
WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if weaveName ~= WEAVE then return end

	-- The caster's ShieldingChannel + ShieldingChanneling animations are already played by ElementalSetting
	-- on the caster's own client (and replicate to everyone), so they are NOT played here.

	local plr = Players:GetPlayerFromCharacter(char)
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	local torso = char:FindFirstChild("UpperTorso")
	if not plr or not hand or not torso then return end

	local cast = newCast()
	cast.folder = Instance.new("Folder")
	cast.folder.Name = "Shielding" .. plr.Name
	cast.folder.Parent = workspace

	startRotator(cast, humRP, hand)
	startSpirit(cast, humRP, torso, hand)

	casts[plr.UserId] = casts[plr.UserId] or {}
	table.insert(casts[plr.UserId], cast)
end)

-- HOOK 2: a caster locked onto the target (fires for EVERY caster, including ones joining a shield that is already holding)
WeavingInstantEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, target)
	if weaveName ~= WEAVE then return end

	local plr = Players:GetPlayerFromCharacter(char)
	if not plr then return end

	if links[plr.UserId] then
		endLink(links[plr.UserId]) -- a leftover link from this caster's earlier cast
	end

	local link = newLink()
	link.target = target
	link.folder = Instance.new("Folder")
	link.folder.Name = "ShieldingLink" .. plr.Name
	link.folder.Parent = workspace
	link.shield = assets:WaitForChild("Shield"):Clone()
	link.shield.Parent = link.folder
	link.channel = assets:WaitForChild("ShieldChannel"):Clone()
	link.channel.Parent = link.folder
	links[plr.UserId] = link
	
	-- Play Sounds
	link.sounds.sfxloop1 = sounds:WaitForChild("ShieldingLoop1_Telekinesis or Siphon"):Clone(); link.sounds.sfxloop1.Parent = char.HumanoidRootPart; link.sounds.sfxloop1:Play()
	link.sounds.sfxloop2 = sounds:WaitForChild("ShieldingLoop2_Telekinesis_select_lp"):Clone(); link.sounds.sfxloop2.Parent = char.HumanoidRootPart; link.sounds.sfxloop2:Play()
	link.sounds.sfxloop3 = sounds:WaitForChild("ShieldingLoop3_void ambience"):Clone(); link.sounds.sfxloop3.Parent = target.HumanoidRootPart;
	link.sounds.sfxloop4 = sounds:WaitForChild("ShieldingLoop4_Portal ambience sound effect"):Clone(); link.sounds.sfxloop4.Parent = target.HumanoidRootPart;
	link.sounds.sfxabsorb1 = sounds:WaitForChild("ShieldingAbsorb1_Sand_Absorb 3"):Clone(); link.sounds.sfxabsorb1.Parent = target.HumanoidRootPart;
	link.sounds.sfxabsorb2 = sounds:WaitForChild("ShieldingAbsorb2_portal_disappear"):Clone(); link.sounds.sfxabsorb2.Parent = target.HumanoidRootPart;
	
	-- keep the effects on the target and spin the shield
	local angle = 0
	link.connections.follow = RunService.RenderStepped:Connect(function(dt)
		if not target.Parent then return end
		local center = target:GetPivot().Position

		link.shield:PivotTo(target:GetPivot())
		link.channel.Position = center

		angle += SHIELD_SPIN * dt
		for _, part in link.shield:GetChildren() do
			if part:IsA("BasePart") then
				part.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0)
			end
		end
	end)
end)

-- waits (a moment) for a caster's link on this target. Hook 2 builds it, and Hook 3 can be handled first if the two remotes
-- are delivered out of order, so Hook 3 never assumes the link is already there.
local function waitForLink(plr, target)
	local deadline = os.clock() + 2
	local link = links[plr.UserId]
	while (not link or link.target ~= target) and os.clock() < deadline do
		task.wait()
		link = links[plr.UserId]
	end
	if link and link.target == target then return link end
	return nil
end

-- HOOK 3: the shield took hold.
--   Fires once when the shield first holds (alreadyHeld = nil, casterChars = every current caster) AND once more for every
--   caster who JOINS a shield that is already holding (alreadyHeld = true, casterChars = { that caster }).
--   Before, late casters never got this at all, so their link stayed stuck at the lock-on look (bug 3).
WeavingEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, target, casterChars, alreadyHeld)
	if weaveName ~= WEAVE then return end

	-- The target's animations are played ONLY by the target's own client, so everybody sees them.
	-- (the keys are "Shielded" .. "Channel" and "Shielded" .. "Channeling" in AnimationHandler)
	-- A caster joining a shield that is already holding doesn't restart them.
	if target == LocalPlayer.Character and not alreadyHeld then
		AnimationHandler.PlayWeaveAnimation(target, "Shielded", "Channel", false)
		AnimationHandler.PlayWeaveAnimation(target, "Shielded", "Channeling", false)
	end

	-- every caster named here has their OWN link on the target, so update each of them
	for _, casterChar in casterChars or { char } do
		local plr = Players:GetPlayerFromCharacter(casterChar)
		if plr then
			task.spawn(function()
				local link = waitForLink(plr, target)
				if link then
					onShielded(link, target)
				end
			end)
		end
	end

	-- YOUR "SHIELDED" VFX / SFX ON THE TARGET HERE (every client can draw those)
end)

-- END: a caster left the shield (released, interrupted, out of Source, out of range, target dead...)
WeavingInstantReleaseEvent.OnClientEvent:Connect(function(userId, weaveName, freedTarget)
	if weaveName ~= WEAVE then return end

	-- this caster's rotator / spirit effect: the oldest cast that hasn't ended yet
	local queue = casts[userId]
	local cast = queue and table.remove(queue, 1)
	if cast then endCast(cast) end

	-- this caster's link on the target
	local link = links[userId]
	links[userId] = nil
	if link then endLink(link) end

	-- the target is only free when the LAST caster has left
	if freedTarget then
		if freedTarget == LocalPlayer.Character then
			AnimationHandler.StopWeaveAnimation(freedTarget, "Shielded", "Channel")
			AnimationHandler.StopWeaveAnimation(freedTarget, "Shielded", "Channeling")
		end

		if freedTarget then
			if freedTarget == LocalPlayer.Character then
				AnimationHandler.StopWeaveAnimation(freedTarget, "Shielded", "Channel")
				AnimationHandler.StopWeaveAnimation(freedTarget, "Shielded", "Channeling")
			end

			local fx = shieldedFx[freedTarget]
			shieldedFx[freedTarget] = nil
			if fx then
				for _, v in fx do
					fadeOutEffects(v)
				end
				task.delay(5, function()
					for _, v in fx do
						v:Destroy()
					end
				end)
			end
		end
	end
end)
