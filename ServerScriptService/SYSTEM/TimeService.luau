-- ServerScriptService > SYSTEM > TimeService   (ModuleScript)
--
-- THE DAY / NIGHT CYCLE, plus functions other scripts (your spells) can call to read or change the time.
-- It only runs once TimeServiceStart (a Script) calls  TimeService.Start().
-- Everything happens on the SERVER: it writes Lighting.ClockTime, which replicates to every client.
--
-- HOW SPELLS SHOULD USE IT
--   local TimeService = require(game.ServerScriptService.SYSTEM.TimeService)
--
--   TimeService.GetTime()                         -- 0..24, e.g. 14.5 = 2:30 PM
--   TimeService.GetPhase()                        -- "Dawn" | "Day" | "Dusk" | "Night"
--   TimeService.IsNight()                         -- true during "Night"
--   TimeService.SetTime(0)                        -- jump to midnight at once
--   TimeService.TweenTo(0, 3)                     -- slide to midnight over 3 seconds (sun / moon visibly move)
--   TimeService.Freeze(10)                        -- stop time for 10 seconds ("time stop")
--   TimeService.AddSpeedModifier(20, 15, "Haste_"..player.UserId)   -- time runs 20x faster for 15 seconds
--   TimeService.RemoveSpeedModifier("Haste_"..player.UserId)        -- ...or end it early
--
-- WHY SPEED "MODIFIERS" AND NOT ONE SPEED NUMBER: two spells can change the speed at the same time without
-- overwriting each other. Every modifier has an id; the real speed is all of them multiplied together
-- (freeze = 0, haste = 20, slow = 0.5, rewind = -1). Casting the SAME spell again with the SAME id refreshes it
-- instead of stacking it. A modifier with a duration removes itself.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local TimeService = {}

-- CONFIG ----------------------------------------------------------------------------------------------
local DAY_LENGTH = 3600       -- REAL seconds a full 24-hour day takes at normal speed (3600 = 60 minutes)
local START_TIME = math.random(0, 23)         -- the hour the server starts at (12 = noon)
local UPDATE_INTERVAL = 0.1  -- how often the normal cycle writes to Lighting (every frame during a TweenTo)

-- the phases, in hours (0..24). A phase whose "to" is smaller than its "from" wraps past midnight.
local PHASES = {
	{ name = "Dawn",  from = 5,    to = 7 },
	{ name = "Day",   from = 7,    to = 17.5 },
	{ name = "Dusk",  from = 17.5, to = 19 },
	{ name = "Night", from = 19,   to = 5 },
}

-- STATE -----------------------------------------------------------------------------------------------
local clock = START_TIME % 24    -- the current time of day, 0..24
local dayLength = DAY_LENGTH
local modifiers = {}             -- [id] = { multiplier, expiresAt }   expiresAt is nil = until removed
local activeTween = nil          -- { from, delta, duration, startedAt, done } while a TweenTo is running
local nextModifierId = 0
local started = false
local sinceWrite = 0

local function phaseAt(hour: number): string
	for _, phase in PHASES do
		if phase.from < phase.to then
			if hour >= phase.from and hour < phase.to then return phase.name end
		elseif hour >= phase.from or hour < phase.to then
			return phase.name
		end
	end
	return "Day"
end

local currentPhase = phaseAt(clock)

-- fires (newPhase, oldPhase) whenever the phase changes
local phaseChanged = Instance.new("BindableEvent")
TimeService.PhaseChanged = phaseChanged.Event

local function isFiniteNumber(n): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- pushes the current time to Lighting and announces a phase change
local function writeLighting()
	Lighting.ClockTime = clock

	local phase = phaseAt(clock)
	if phase ~= currentPhase then
		local old = currentPhase
		currentPhase = phase
		Lighting:SetAttribute("Phase", phase) -- clients can read / listen to this for ambience and VFX
		phaseChanged:Fire(phase, old)
	end
end

local function cancelTween(finished: boolean)
	local tween = activeTween
	if not tween then return end
	activeTween = nil
	tween.done:Fire(finished)
end

-- the speed right now: every modifier multiplied together (expired ones are removed on the way)
local function currentSpeed(now: number): number
	local product = 1
	for id, modifier in modifiers do
		if modifier.expiresAt and now >= modifier.expiresAt then
			modifiers[id] = nil
		else
			product *= modifier.multiplier
		end
	end
	return product
end

-- THE LOOP (one Heartbeat connection, created by Start) -----------------------------------------------
local function onHeartbeat(dt: number)
	local now = os.clock()

	-- a TweenTo is running: it moves the clock itself and ignores the normal speed for its duration
	if activeTween then
		local tween = activeTween
		local alpha = math.clamp((now - tween.startedAt) / tween.duration, 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha) -- smoothstep: eases in and out
		clock = (tween.from + tween.delta * eased) % 24
		writeLighting()
		if alpha >= 1 then
			activeTween = nil
			tween.done:Fire(true)
		end
		return
	end

	-- the normal cycle
	local speed = currentSpeed(now)
	if speed == 0 then return end -- frozen: nothing to do (and nothing to replicate)
	clock = (clock + dt * (24 / dayLength) * speed) % 24
	sinceWrite += dt
	if sinceWrite >= UPDATE_INTERVAL then
		sinceWrite = 0
		writeLighting()
	end
end

function TimeService.Start()
	if started then return end
	started = true
	Lighting:SetAttribute("Phase", currentPhase)
	writeLighting()
	RunService.Heartbeat:Connect(onHeartbeat)
end

-- QUERIES ---------------------------------------------------------------------------------------------
-- the time of day, 0..24 (14.5 = 2:30 PM)
function TimeService.GetTime(): number
	return clock
end

-- "02:30" style text, handy for a clock in the UI
function TimeService.GetClockString(): string
	local hours = math.floor(clock)
	local minutes = math.floor((clock - hours) * 60)
	return string.format("%02d:%02d", hours, minutes)
end

-- "Dawn" | "Day" | "Dusk" | "Night"
function TimeService.GetPhase(): string
	return currentPhase
end

function TimeService.IsNight(): boolean
	return currentPhase == "Night"
end

-- the sun is up (Dawn, Day or Dusk)
function TimeService.IsDay(): boolean
	return currentPhase ~= "Night"
end

-- the speed right now: every modifier multiplied together (1 = normal, 0 = frozen)
function TimeService.GetSpeed(): number
	return currentSpeed(os.clock())
end

-- real seconds one full day takes at normal speed
function TimeService.GetDayLength(): number
	return dayLength
end

-- a copy of the active speed modifiers: { [id] = { multiplier, secondsLeft } }  (for debugging / UI)
function TimeService.GetModifiers()
	local now = os.clock()
	local copy = {}
	for id, modifier in modifiers do
		if not modifier.expiresAt or now < modifier.expiresAt then
			copy[id] = {
				multiplier = modifier.multiplier,
				secondsLeft = modifier.expiresAt and (modifier.expiresAt - now) or nil,
			}
		end
	end
	return copy
end

-- CHANGING THE TIME -----------------------------------------------------------------------------------
-- jumps to an hour at once. Cancels a running TweenTo.
function TimeService.SetTime(hour: number)
	if not isFiniteNumber(hour) then return end
	cancelTween(false)
	clock = hour % 24
	sinceWrite = 0
	writeLighting()
end

-- changes how long a full day takes (real seconds). This is the BASE speed; modifiers multiply on top of it.
function TimeService.SetDayLength(seconds: number)
	if not isFiniteNumber(seconds) or seconds <= 0 then return end
	dayLength = seconds
end

-- slides the clock to `hour` over `duration` seconds, so players see the sun / moon move.
--   direction: "Forward" (default: the way time normally goes), "Backward", or "Shortest"
-- Returns a signal that fires once with true (arrived) or false (cancelled by SetTime or another TweenTo):
--   TimeService.TweenTo(0, 3):Once(function(arrived) ... end)
function TimeService.TweenTo(hour: number, duration: number, direction: string?): RBXScriptSignal
	local done = Instance.new("BindableEvent")
	if not isFiniteNumber(hour) then
		task.defer(function() done:Fire(false) end)
		return done.Event
	end

	cancelTween(false) -- a new tween replaces the running one

	local target = hour % 24
	local forward = (target - clock) % 24
	local delta = forward
	if direction == "Backward" then
		delta = -((clock - target) % 24)
	elseif direction == "Shortest" and forward > 12 then
		delta = forward - 24
	end

	if not isFiniteNumber(duration) or duration <= 0 or delta == 0 then
		clock = target
		sinceWrite = 0
		writeLighting()
		task.defer(function() done:Fire(true) end)
		return done.Event
	end

	activeTween = { from = clock, delta = delta, duration = duration, startedAt = os.clock(), done = done }
	return done.Event
end

-- SPEED MODIFIERS -------------------------------------------------------------------------------------
-- multiplier: 2 = twice as fast, 0.5 = half speed, 0 = stopped, -1 = time runs backwards
-- duration:   seconds until it removes itself (nil = until you remove it)
-- id:         a name for it. Using the SAME id again replaces / refreshes it. Default: a unique one.
-- Returns the id (keep it if you want to remove the modifier early).
function TimeService.AddSpeedModifier(multiplier: number, duration: number?, id: string?): string?
	if not isFiniteNumber(multiplier) then return nil end
	if duration ~= nil and not isFiniteNumber(duration) then return nil end

	if not id then
		nextModifierId += 1
		id = "Modifier" .. nextModifierId
	end
	modifiers[id] = {
		multiplier = multiplier,
		expiresAt = duration and (os.clock() + duration) or nil,
	}
	return id
end

function TimeService.RemoveSpeedModifier(id: string)
	modifiers[id] = nil
end

-- stops time (a modifier of 0). duration nil = until Unfreeze. Returns the id.
function TimeService.Freeze(duration: number?, id: string?): string?
	return TimeService.AddSpeedModifier(0, duration, id)
end

function TimeService.Unfreeze(id: string)
	modifiers[id] = nil
end

-- removes every modifier (back to normal speed)
function TimeService.ClearModifiers()
	table.clear(modifiers)
end

return TimeService
