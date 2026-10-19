-- ReplicatedStorage > SYSTEM > ModuleScripts > MovementService   (ModuleScript)
--
-- THE ONE PLACE that decides whether a character can MOVE, JUMP or CAST, and how FAST they move.
--
--   INPUTS (nobody writes WalkSpeed / JumpPower / Controls any more, they only set one of these):
--     1. STATUS ATTRIBUTES on the character: Frozen, Shielded, Stunned, Ragdolled, Rooted, Immobilized.
--        (DebuffHandler / RagdollService / Shielding already set these. Nothing about them changed.)
--     2. CAST LOCKS / SLOWS registered by SOURCE name, e.g. MovementService.SetSlow(char, "Cast", 0.4).
--        Every source has its own slot, so removing one can never undo another.
--
--   OUTPUT (the server is the only writer):
--     Humanoid.WalkSpeed / JumpPower / JumpHeight, and these attributes on the character so every client
--     (and every script) can read the answer:  CanMove, CanJump, CanCast, SpeedMult
--
--   RULES
--     * A status always wins over a slow. Frozen + a 40% slow = speed 0.
--     * Slows multiply:  0.5 slow + 0.5 slow = 25% speed.
--     * When the last effect goes away the character goes back to the BASE values below.
--     * CanCast is the same list the old DebuffHandler.CheckStatus used (Frozen/Shielded/Rooted/Stunned/Ragdolled).
--     * Any status effect that lands on a character also CANCELS their "Cast" source (same as the client's
--       "Status effect detected, canceling weave").
--
-- Reading (CanCast / CanMove / CanJump) works on the client AND the server.
-- Writing (SetSlow / SetLock / Refresh ...) only does anything on the server.

local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local MovementService = {}

-- SERVER ONLY: fires (char, statusName) the moment a status that blocks casting (Frozen, Shielded, Stunned, Ragdolled, Rooted)
-- lands on a character. Weave scripts connect to it to cancel the cast the character was holding.
local castBlocked = IS_SERVER and Instance.new("BindableEvent") or nil
MovementService.CastBlocked = castBlocked and castBlocked.Event or nil

-- BASE VALUES (what a free character moves like). The first time a character is tracked its own WalkSpeed / JumpPower /
-- JumpHeight are remembered as the Humanoid attributes BaseWalkSpeed / BaseJumpPower / BaseJumpHeight (so NPCs and any
-- StarterPlayer settings keep their own numbers). Change those attributes and the base changes: a future sprint /
-- speed-boost system only has to set BaseWalkSpeed. The numbers below are only the fallback.
local BASE_WALKSPEED = 16
local BASE_JUMPPOWER = 50
local BASE_JUMPHEIGHT = 7.2

-- WHAT EACH STATUS TAKES AWAY
local STATUS = {
	Frozen      = { move = false, jump = false, cast = false },
	Shielded    = { move = false, jump = false, cast = false },
	Stunned     = { move = false, jump = false, cast = false },
	Ragdolled   = { move = false, jump = false, cast = false },
	Rooted      = { move = false, jump = false, cast = false },
	Immobilized = { move = false, jump = false, cast = true },
	Stilling    = { move = false, jump = false, cast = false }, -- being held up by a Stilling in progress
	Stilled     = { move = true,  jump = true,  cast = false }, -- stripped of the Power: can walk (slowly), can't cast
}

-- the "Cast" source is cleared when ANY of these land (the same list the client listens to)
local CANCELS_CAST = { "Frozen", "Shielded", "Stunned", "Ragdolled", "Rooted", "Stilling", "Stilled" }

-- the lock presets a source can use
MovementService.Locks = {
	Hard = { move = false, jump = false, cast = false },  -- can't do anything
	Channel = { move = false, jump = false, cast = true }, -- can't move, but can still let go of the weave
}

-- SERVER STATE ------------------------------------------------------------------------------------------
local weak = { __mode = "k" }
local slows = setmetatable({}, weak)    -- [char] = { [source] = multiplier }
local locks = setmetatable({}, weak)    -- [char] = { [source] = { move, jump, cast } }
local tracked = setmetatable({}, weak)  -- [char] = RBXScriptConnection[]

-- SMALL HELPERS -------------------------------------------------------------------------------------------
local function isOn(char, statusName)
	local value = char:GetAttribute(statusName)
	if value == nil or value == false then return false end
	if typeof(value) == "number" then return value > 0 end
	return true
end

local function isChar(char)
	return typeof(char) == "Instance" and char:IsA("Model")
end

-- READERS (client + server) ----------------------------------------------------------------------------
-- computed straight from the status attributes, so they are right even before the server has refreshed
function MovementService.CanCast(char)
	if not isChar(char) then return false end
	for name, rule in STATUS do
		if not rule.cast and isOn(char, name) then return false end
	end
	return true
end

function MovementService.CanMove(char)
	if not isChar(char) then return false end
	return char:GetAttribute("CanMove") ~= false
end

function MovementService.CanJump(char)
	if not isChar(char) then return false end
	return char:GetAttribute("CanJump") ~= false
end

-- WRITERS (server only) ---------------------------------------------------------------------------------
local function compute(char)
	local canMove, canJump, canCast = true, true, true

	for name, rule in STATUS do
		if isOn(char, name) then
			canMove = canMove and rule.move
			canJump = canJump and rule.jump
			canCast = canCast and rule.cast
		end
	end

	local charLocks = locks[char]
	if charLocks then
		for _, rule in charLocks do
			canMove = canMove and rule.move
			canJump = canJump and rule.jump
			canCast = canCast and rule.cast
		end
	end

	local mult = 1
	local charSlows = slows[char]
	if charSlows then
		for _, m in charSlows do
			mult *= m
		end
	end

	return canMove, canJump, canCast, mult
end

function MovementService.Refresh(char)
	if not IS_SERVER then return end
	if not isChar(char) or not char.Parent then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	MovementService.Track(char)

	local canMove, canJump, canCast, mult = compute(char)
	local baseSpeed = hum:GetAttribute("BaseWalkSpeed") or BASE_WALKSPEED
	local baseJumpPower = hum:GetAttribute("BaseJumpPower") or BASE_JUMPPOWER
	local baseJumpHeight = hum:GetAttribute("BaseJumpHeight") or BASE_JUMPHEIGHT

	-- the outputs. BOTH jump properties are written: which one counts depends on Humanoid.UseJumpPower, and the old code
	-- only ever wrote JumpPower, which does nothing on a character that uses JumpHeight (the "shielded players can jump" bug)
	hum.WalkSpeed = canMove and (baseSpeed * mult) or 0
	hum.JumpPower = canJump and baseJumpPower or 0
	hum.JumpHeight = canJump and baseJumpHeight or 0

	char:SetAttribute("CanMove", canMove)
	char:SetAttribute("CanJump", canJump)
	char:SetAttribute("CanCast", canCast)
	char:SetAttribute("SpeedMult", mult)
end

local function setIn(store, char, source, value)
	if not IS_SERVER or not isChar(char) then return end
	local bucket = store[char]
	if not bucket then
		bucket = {}
		store[char] = bucket
	end
	bucket[source] = value
	MovementService.Refresh(char)
end

local function clearIn(store, char, source)
	if not IS_SERVER or not isChar(char) then return end
	local bucket = store[char]
	if bucket and bucket[source] ~= nil then
		bucket[source] = nil
		MovementService.Refresh(char)
	end
end

-- speed multiplier from a source (0.4 = 40% speed). A multiplier >= 1 is ignored.
function MovementService.SetSlow(char, source, multiplier)
	if typeof(multiplier) ~= "number" or multiplier ~= multiplier then return end
	if multiplier >= 1 then return MovementService.ClearSlow(char, source) end
	setIn(slows, char, source, math.max(multiplier, 0))
end

function MovementService.ClearSlow(char, source)
	clearIn(slows, char, source)
end

-- a lock from a source: { move = bool, jump = bool, cast = bool }  (use MovementService.Locks.Hard / .Channel)
function MovementService.SetLock(char, source, rule)
	if typeof(rule) ~= "table" then return end
	setIn(locks, char, source, {
		move = rule.move ~= false,
		jump = rule.jump ~= false,
		cast = rule.cast ~= false,
	})
end

function MovementService.ClearLock(char, source)
	clearIn(locks, char, source)
end

-- removes everything a source has put on this character
function MovementService.ClearSource(char, source)
	if not IS_SERVER or not isChar(char) then return end
	local hadSlow = slows[char] and slows[char][source] ~= nil
	local hadLock = locks[char] and locks[char][source] ~= nil
	if hadSlow then slows[char][source] = nil end
	if hadLock then locks[char][source] = nil end
	if hadSlow or hadLock then MovementService.Refresh(char) end
end

function MovementService.ClearAll(char)
	if not IS_SERVER or not isChar(char) then return end
	slows[char] = nil
	locks[char] = nil
	MovementService.Refresh(char)
end

-- TRACKING: one listener per character, so a status effect is applied the moment it lands -----------------
function MovementService.Track(char)
	if not IS_SERVER or tracked[char] then return end
	local connections = {}
	tracked[char] = connections

	table.insert(connections, char.AttributeChanged:Connect(function(name)
		local rule = STATUS[name]
		if not rule then return end

		-- a status that lands cancels the cast rule (the weave itself is cancelled by its own script + the client)
		if table.find(CANCELS_CAST, name) and isOn(char, name) then
			MovementService.ClearSource(char, "Cast")
			if castBlocked then castBlocked:Fire(char, name) end
		end
		MovementService.Refresh(char)
	end))

	local function cleanup()
		for _, connection in connections do
			connection:Disconnect()
		end
		tracked[char] = nil
		slows[char] = nil
		locks[char] = nil
	end

	table.insert(connections, char.AncestryChanged:Connect(function(_, parent)
		if not parent then cleanup() end
	end))

	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		-- remember this humanoid's own numbers (only while they are real, never a value another effect already zeroed)
		if hum:GetAttribute("BaseWalkSpeed") == nil and hum.WalkSpeed > 0 then
			hum:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
		end
		if hum:GetAttribute("BaseJumpPower") == nil and hum.JumpPower > 0 then
			hum:SetAttribute("BaseJumpPower", hum.JumpPower)
		end
		if hum:GetAttribute("BaseJumpHeight") == nil and hum.JumpHeight > 0 then
			hum:SetAttribute("BaseJumpHeight", hum.JumpHeight)
		end

		table.insert(connections, hum.Died:Connect(function()
			slows[char] = nil
			locks[char] = nil
		end))
	end
end

return MovementService
