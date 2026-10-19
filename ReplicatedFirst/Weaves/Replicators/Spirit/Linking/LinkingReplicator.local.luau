-- Linking   (LocalScript, client)
-- The SERVER decides everything. This only plays visuals when the server says so.
-- Several weavers can link into one chain (A -> B -> leader), so every linker has their OWN set of beams to the weaver they linked to.
--
--   HOOK 1  WeavingFxEvent             a weaver tried to link          (E pressed)             once per caster
--   HOOK 2  WeavingInstantEvent        the link was made               (caster -> target)      once per caster
--                                      args: char, hum, humRP, WEAVE, target, leaderChar
--   END     WeavingInstantReleaseEvent a weaver's link broke           (stop THEIR beams)      once per caster
--
-- THE LINK LOOKS LIKE: five beams, one per slot. Idle, beam 1..5 show Fire, Water, Earth, Air, Spirit.
-- When the LEADER casts ANY weave, the server sets the leader's "LinkWeave" attribute to that weave's name,
-- LinkData turns its WeaveKey digits into colors ("41414" = Air Fire Air Fire Air), and beam 1..5 take those colors.
-- Weave with fewer than five digits? The colors repeat, so no beam is ever left without a color.
--
-- THE BEAM ASSET it expects:  ReplicatedStorage > Assets > Weaves > VFX > Linking > Beam
--   Start (Part) > AStart (Attachment)        End (Part) > AEnd (Attachment)        one or more Beam objects joining AStart and AEnd

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local LinkData = require(Modules:WaitForChild("LinkData"))

-- REMOTES
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")

local WEAVE = "Linking"

local beamAsset = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Linking"):WaitForChild("Beam")

-- TUNING (play with these) -----------------------------------------------------------------------------------
local BEAM_COUNT = 5        -- one beam per slot / element
local TRAVEL_TIME = 0.9     -- seconds for the beams to reach the target
local FADE_OUT_TIME = 0.7   -- seconds for the fade to sweep from the caster to the target when a link ends
local FADE_EDGE = 0.25      -- how soft that sweeping edge is (0 = hard line, 0.5 = very soft)
local COLOR_FADE_TIME = 0.4 -- seconds a beam takes to blend from one color to the next
local CURVE_SIZE = 5        -- how far the beams wave sideways (studs). Each beam gets its OWN random amount around this
local CURVE_SPEED = 2       -- how fast they wave. Each beam gets its OWN random speed around this
local CURVE_WANDER = 0.25   -- how quickly the random wander moves per CURVE_SPEED. Lower = slow lazy curves, higher = frantic
local CURVE_GAIN = 1.5      -- how far the wander reaches into its range. Higher = bigger swings
local SPIN_SPEED = 3        -- how fast the attachments spin (radians per second). Also randomized per beam
local EPS = 0.001           -- keypoint times must go UP, so they're never allowed to touch

-- STATE ---------------------------------------------------------------------------------------------------
-- links[linkerChar] = { target = Model, vfx = { setWeave = fn, destroy = fn }, lastWeave = string? }
local links = {}
local heartbeat -- connected only while at least one link exists

-- THE TRAVEL TRICK ---------------------------------------------------------------------------------------
-- A Beam's Transparency is a NumberSequence: a list of KEYPOINTS. Each keypoint is (time, value):
--     time  = where along the beam.  0 = the caster's end, 1 = the target's end.
--     value = how see-through.       0 = solid, 1 = invisible.
-- Roblox blends smoothly between neighbouring keypoints, so we never move anything. We SLIDE the keypoints instead.
-- p says how far the beam has travelled, 0 (just left the caster) to 1 (arrived). The four keypoints are:
--     1st  (0, 1)            the caster's end is always faded out
--     2nd  (0.1 * p, 1 - p)  the "anchor": slides 0 -> 0.1 while fading in
--     3rd  (0.9 * p, 1 - p)  the "head": slides 0 -> 0.9 while fading in. THIS is what looks like it's travelling
--     4th  (1, 1)            the target's end is always faded out
-- At p = 1 that is (0,1) (0.1,0) (0.9,0) (1,1): solid in the middle, faded at both ends.
local function transparencyAt(p: number): NumberSequence
	local anchorTime = math.clamp(0.1 * p, EPS, 0.5)
	local headTime = math.clamp(0.9 * p, anchorTime + EPS, 1 - EPS) -- always AFTER the anchor
	local value = 1 - p
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(anchorTime, value),
		NumberSequenceKeypoint.new(headTime, value),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- THE EXIT SWEEP -----------------------------------------------------------------------------------------
-- When a link ends, the fade travels the same way as the arrival: from the caster to the target.
-- q goes 0 -> 1. A soft "edge" slides from the caster's end to the target's end, and everything BEHIND the edge is invisible.
-- NumberSequences only hold straight lines between keypoints, so instead of placing a few keypoints by hand we SAMPLE the
-- result at 12 evenly spaced points. `base` is what the beam looks like right now (so it also works if the link ends while
-- the beam is still travelling), and each sample is the more see-through of "what it looks like" and "is the edge past it yet".
local EXIT_SAMPLES = 12

-- reads the value of a NumberSequence at time t (blending between its keypoints, the same way Roblox does)
local function evalSequence(sequence: NumberSequence, t: number): number
	local keypoints = sequence.Keypoints
	for i = 2, #keypoints do
		local a, b = keypoints[i - 1], keypoints[i]
		if t <= b.Time then
			local span = b.Time - a.Time
			if span <= 0 then return b.Value end
			return a.Value + (b.Value - a.Value) * (t - a.Time) / span
		end
	end
	return keypoints[#keypoints].Value
end

local function exitSequence(base: NumberSequence, q: number): NumberSequence
	local edgeStart = q * (1 + FADE_EDGE) - FADE_EDGE -- starts fully off the beam (q = 0) and ends fully past it (q = 1)
	local keypoints = {}
	for k = 0, EXIT_SAMPLES - 1 do
		local t = k / (EXIT_SAMPLES - 1)
		local hidden = math.clamp(1 - (t - edgeStart) / FADE_EDGE, 0, 1) -- 1 behind the edge, 0 in front of it
		table.insert(keypoints, NumberSequenceKeypoint.new(t, math.max(evalSequence(base, t), hidden)))
	end
	return NumberSequence.new(keypoints)
end

-- FIND WHAT THE LEADER IS CASTING --------------------------------------------------------------------------
-- A linker's "LinkLeaderId" attribute names the end weaver of their chain. Their "LinkWeave" attribute is the weave name.
local function getLeaderWeave(linkerChar: Model): string?
	local leaderId = linkerChar:GetAttribute("LinkLeaderId")
	local leader = leaderId and Players:GetPlayerByUserId(leaderId)
	local leaderChar = leader and leader.Character
	return leaderChar and leaderChar:GetAttribute("LinkWeave") or nil
end

-- THE VFX --------------------------------------------------------------------------------------------------
-- Builds the five beams for ONE link (caster -> target). Returns { setWeave, destroy } or nil if something is missing.
local function buildLinkVfx(char: Model, humRP: BasePart, targetChar: Model)
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
	if not humRP or not targetRoot then return nil end

	local container = Instance.new("Folder")
	container.Name = "LinkVfx_" .. char.Name

	-- 1. CLONE THE BEAM FIVE TIMES. `for i = 1, 5 do` just means "run this block five times, with i = 1, then 2, ... then 5"
	local copies = {}
	for i = 1, BEAM_COUNT do
		local copy = beamAsset:Clone()
		copy.Name = "Beam" .. i

		local startPart = copy:FindFirstChild("Start", true) -- (true = look inside everything, not just the top level)
		local endPart = copy:FindFirstChild("End", true)
		local aStart = startPart and startPart:FindFirstChild("AStart")
		local aEnd = endPart and endPart:FindFirstChild("AEnd")

		if startPart and endPart and aStart and aEnd then
			local beams = {} -- every Beam object inside this copy
			for _, descendant in copy:GetDescendants() do
				if descendant:IsA("Beam") then
					table.insert(beams, descendant)
				elseif descendant:IsA("BasePart") then
					descendant.Anchored = true -- we move the parts ourselves every frame
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
				end
			end

			copy.Parent = container
			table.insert(copies, {
				startPart = startPart, endPart = endPart,
				aStart = aStart, aEnd = aEnd,
				beams = beams,
				-- RANDOMNESS: every beam gets its own personality, so no two of them wave the same way
				curveSeed0 = math.random() * 1000 + 0.37,     -- where this beam's start-end wanders in the noise
				curveSeed1 = math.random() * 1000 + 0.71,     -- and its target-end, wandering independently
				curveSize = CURVE_SIZE * (0.5 + math.random() * 0.9), -- 50% to 140% of CURVE_SIZE
				curveSpeed = CURVE_SPEED * (0.6 + math.random() * 0.8), -- 60% to 140% of CURVE_SPEED
				spinSpeed = SPIN_SPEED * (0.6 + math.random() * 0.8),   -- 60% to 140% of SPIN_SPEED
				spinDirection = math.random(0, 1) * 2 - 1,            -- -1 or 1: some spin one way, some the other
				-- color blending (see setWeave)
				fromColor = nil, toColor = nil, colorStartedAt = 0, colorDone = true,
			})
		else
			warn("Linking beam asset is missing Start / End / AStart / AEnd, copy " .. i .. " skipped")
			copy:Destroy()
		end
	end
	if #copies == 0 then
		container:Destroy()
		return nil
	end

	-- 2. EVERY FRAME: Start sits on the caster, End on the target, both facing each other.
	--    Because they face each other, spinning an attachment around its own Z axis spins the beam's curve around the
	--    line between the two weavers. That is what makes it look like it swirls.
	local startedAt = os.clock()
	local alive = true

	local function update()
		local from, to = humRP.Position, targetRoot.Position
		if (to - from).Magnitude < 0.01 then return end
		local startCFrame = CFrame.lookAt(from, to)
		local endCFrame = CFrame.lookAt(to, from)
		local elapsed = os.clock() - startedAt

		for _, copy in copies do
			copy.startPart.CFrame = startCFrame
			copy.endPart.CFrame = endCFrame

			-- 5. waving. math.noise gives a smooth random wander between -1 and 1 (not a repeating sine wave), and each end of
			--    each beam wanders on its own, so the curves are irregular. Now and then two line up by chance, which is fine.
			--    (math.noise moves about one "feature" per unit, so the time is scaled down by CURVE_WANDER to keep it lazy.
			--     Without that scaling it swung several times faster than the old sine wave, which is why it looked frantic.)
			local wander = elapsed * copy.curveSpeed * CURVE_WANDER
			local noise0 = math.clamp(math.noise(wander, copy.curveSeed0) * CURVE_GAIN, -1, 1)
			local noise1 = math.clamp(math.noise(wander * 0.8, copy.curveSeed1) * CURVE_GAIN, -1, 1)
			-- the target end is only PARTLY independent: mostly its own wander, plus a bit of the mirror of the start end,
			-- which keeps each beam reading as one smooth curve instead of two ends fighting each other
			local curve0 = noise0 * copy.curveSize
			local curve1 = (noise1 * 0.6 - noise0 * 0.4) * copy.curveSize
			for _, beam in copy.beams do
				beam.CurveSize0 = curve0
				beam.CurveSize1 = curve1
			end

			-- 6. spinning
			local spin = elapsed * copy.spinSpeed * copy.spinDirection
			copy.aStart.CFrame = CFrame.Angles(0, 0, spin)
			copy.aEnd.CFrame = CFrame.Angles(0, 0, -spin)

			-- 7. COLOR BLEND. Color3:Lerp does the "loop over red, green and blue" for us: it moves each of the three channels
			--    the same fraction of the way from the old color to the new one. Runs only while a blend is in progress.
			if not copy.colorDone then
				local alpha = math.clamp((os.clock() - copy.colorStartedAt) / COLOR_FADE_TIME, 0, 1)
				local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				copy.toColorNow = copy.fromColor:Lerp(copy.toColor, eased) -- (what the beam shows right now)
				local sequence = ColorSequence.new(copy.toColorNow)
				for _, beam in copy.beams do
					beam.Color = sequence
				end
				if alpha >= 1 then copy.colorDone = true end
			end
		end
	end

	-- start fully invisible (p = 0) and in the right place BEFORE it appears, so there's no one-frame flash
	local progress = 0 -- how far the arrival has got, so a fade-out can start from whatever the beam looks like right now
	local function setTransparency(sequence: NumberSequence)
		for _, copy in copies do
			for _, beam in copy.beams do
				beam.Transparency = sequence
			end
		end
	end
	local function setProgress(p: number)
		progress = p
		setTransparency(transparencyAt(p))
	end
	setProgress(0)
	update()
	container.Parent = workspace

	local follow = RunService.RenderStepped:Connect(update)

	-- 3 + 4. THE TRAVEL. A `while` loop that runs once per frame until TRAVEL_TIME has passed. All five beams are updated
	-- inside the SAME loop, so they travel together. (A for-loop with task.wait inside would do beam 1, THEN beam 2, ...)
	task.spawn(function()
		while alive do
			local alpha = math.clamp((os.clock() - startedAt) / TRAVEL_TIME, 0, 1) -- 0 -> 1 in a straight line
			setProgress(TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)) -- eased: fast, then slows
			if alpha >= 1 then break end
			RunService.RenderStepped:Wait()
		end
	end)

	-- the colors: beam 1..5 take the 1st..5th color of the weave (they repeat if the weave has fewer than five)
	local function setWeave(weaveName: string?)
		local colors = LinkData.GetColors(weaveName)
		for index, copy in copies do
			local color = colors[(index - 1) % #colors + 1]
			-- blend FROM what the beam shows right now (even mid-blend) TO the new color. The very first call has nothing to
			-- blend from, so it just starts on the right color.
			copy.fromColor = copy.toColorNow or color
			copy.toColor = color
			copy.colorStartedAt = os.clock()
			copy.colorDone = false
		end
	end

	-- THE END: stop the arrival, then sweep the fade from the caster to the target, and only THEN delete everything.
	-- The beams keep following both weavers while they fade (the follow connection stays on until the very end).
	local leaving = false
	local function destroy()
		if leaving then return end
		leaving = true
		alive = false
		local base = transparencyAt(progress)
		local leaveStartedAt = os.clock()
		task.spawn(function()
			while true do
				local alpha = math.clamp((os.clock() - leaveStartedAt) / FADE_OUT_TIME, 0, 1)
				setTransparency(exitSequence(base, alpha))
				if alpha >= 1 then break end
				RunService.RenderStepped:Wait()
			end
			follow:Disconnect()
			container:Destroy()
		end)
	end

	return { setWeave = setWeave, destroy = destroy }
end

local function removeLink(linkerChar: Model)
	local link = links[linkerChar]
	if not link then return end
	links[linkerChar] = nil
	link.vfx.destroy()
	if next(links) == nil and heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

-- 8. WATCH THE LEADER: one cheap pass per frame. If the leader's weave changed, recolor that link.
local function startWatching()
	if heartbeat then return end
	heartbeat = RunService.Heartbeat:Connect(function()
		for linkerChar, link in links do
			if not linkerChar.Parent or not link.target.Parent then
				removeLink(linkerChar)
			else
				local weave = getLeaderWeave(linkerChar)
				if weave ~= link.lastWeave then
					link.lastWeave = weave
					link.vfx.setWeave(weave) -- (nil = idle = all five element colors)
					-- YOUR HOOK: the leader started / stopped casting a link weave.
					-- LinkData.GetElements(weave) = {"Air","Fire","Air","Fire","Air"} (slot order, repeats kept)
					-- LinkData.GetUniqueElements(weave) = {"Air","Fire"}
				end
			end
		end
	end)
end

-- HOOK 1: a weaver tried to link. Hand VFX etc. start here.
WeavingFxEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName)
	if weaveName ~= WEAVE then return end
	-- YOUR HOOK: charge-up on the caster's hands, etc.
end)

-- HOOK 2: the link was made. The beams start here.
WeavingInstantEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, targetChar, leaderChar)
	if weaveName ~= WEAVE or not char or not targetChar then return end

	removeLink(char) -- never two sets of beams from one weaver
	local vfx = buildLinkVfx(char, humRP, targetChar)
	if not vfx then return end

	links[char] = { target = targetChar, vfx = vfx, lastWeave = nil }
	vfx.setWeave(getLeaderWeave(char))
	startWatching()
end)

-- END: this weaver's link broke (released, interrupted, out of range, died...)
WeavingInstantReleaseEvent.OnClientEvent:Connect(function(userId, weaveName, freedTarget)
	if weaveName ~= WEAVE then return end
	local player = Players:GetPlayerByUserId(userId)
	local char = player and player.Character
	if char then removeLink(char) end
	-- YOUR HOOK: the link snapped. freedTarget is the weaver they were linked to.
end)
