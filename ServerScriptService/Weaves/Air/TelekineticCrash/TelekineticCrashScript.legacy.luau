-- ServerScriptService > Weaves > Air > TelekineticCrash > TelekineticCrashScript   (Script)
-- Replaces the whole old file.
--
-- The client asks ("I'm casting", "I'm aiming at this model", "I let go"). The server decides everything else:
-- cooldown, Source, whether the target is valid and in range, the lift, the ragdoll, damage and knockback.
--
-- Flow (the client fires these in this order on E press, then one more on release):
--   1. WeavingFxEvent               -> open a cast (checks + hand visuals)
--   2. WeavingInstantEvent          -> "my target is this model": validate it, charge Source, lift the target
--   3. WeavingInstantReleaseEvent   -> release: after a short wind-up the target is dropped, damaged and knocked back

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

-- REMOTES
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- ASSETS
local Levitator = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("TelekineticCrash"):WaitForChild("Levitator")

local WEAVE = "TelekineticCrash"
local DEFAULT_CAST_DELAY = 0.35 -- seconds between release and the strike; tune to your Cast animation, or set CastDelay in the Dictionary
local DEFAULT_MAX_HOLD = 5      -- seconds a target can stay lifted if the caster never lets go; or set MaxHold in the Dictionary
local KNOCKBACK_TIME = 1.75     -- same value the old client script used
local RANGE_SLACK = 6           -- the client measured range a moment ago; the target may have moved since

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}      -- [player] = { startedAt, level, char, target, levitator, ... }  while a cast is open
local cooldownUntil = {} -- [player] = os.clock() time when the weave is ready again
local lifted = {}        -- [target model] = true while somebody is holding it up (so two casters can't fight over it)

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

-- stops the lift: switches the AlignPosition off, pops the particles, removes the folder shortly after
local function stopLevitation(session)
	local folder = session.folder
	if not folder then return end
	session.folder = nil

	local levitator = folder:FindFirstChild("Levitator")
	local align = levitator and levitator:FindFirstChildOfClass("AlignPosition")
	if align then align.Enabled = false end

	for _, emitter in folder:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then emitter:Emit(1) end
	end
	task.delay(2, function()
		if folder then folder:Destroy() end
	end)
end

-- lets the target go without hurting it (cast cancelled, caster ragdolled / died / left, hold timed out)
local function dropTarget(session)
	stopLevitation(session)
	local target = session.target
	if target then
		lifted[target] = nil
		RagdollService.Release(target)
	end
end

-- ends a cast that never reached the strike
local function abortCast(player, session, cooldown)
	if sessions[player] ~= session then return end
	sessions[player] = nil
	cooldownUntil[player] = os.clock() + cooldown

	dropTarget(session)

	local char = session.char
	if char and char.Parent then
		char:SetAttribute("Charging", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetAttribute("Charge", 0) end
	end
	WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled: clients end every visual now
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, WEAVE)
end

RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	local session = player and sessions[player]
	if session and session.char == char then
		abortCast(player, session, Dictionary[WEAVE].DebounceDuration)
	end
end)

-- is this model something the caster may grab right now? returns its humanoid, root and head
local function validateTarget(char, humRP, target, range)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or target == char then return end
	if not target:IsDescendantOf(workspace) or lifted[target] then return end

	local tHum = target:FindFirstChildOfClass("Humanoid")
	local tRoot = target:FindFirstChild("HumanoidRootPart")
	local tHead = target:FindFirstChild("Head")
	if not tHum or not tRoot or not tHead or tHum.Health <= 0 then return end
	if (tRoot.Position - humRP.Position).Magnitude > range + RANGE_SLACK then return end

	return tHum, tRoot, tHead
end

-- 1. E PRESSED: open a cast
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < 30 then return end -- already casting
	if os.clock() < (cooldownUntil[player] or 0) then return end                    -- on cooldown

	sessions[player] = { startedAt = os.clock(), level = getLevel(player), char = char }

	-- the hand visuals
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)

-- 2. TARGET CHOSEN (the client sends this right after the press)
WeavingInstantEvent.OnServerEvent:Connect(function(player: Player, weaveName, mouseTarget)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session or session.target or session.targeted then return end -- no open cast, or already locked on
	session.targeted = true

	local weaveData = Dictionary[WEAVE]
	local failCooldown = weaveData.FizzleCooldown or 1

	local char, hum, humRP = getAlive(player)
	if not char or char ~= session.char or (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then
		return abortCast(player, session, failCooldown)
	end

	local range = weaveData.CastRange + session.level -- same formula the client uses
	local tHum, tRoot, tHead = validateTarget(char, humRP, mouseTarget, range)
	if not tHum then
		return abortCast(player, session, failCooldown) -- nothing valid to grab
	end

	-- no Source, no cast
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
		return abortCast(player, session, failCooldown)
	end

	session.target = mouseTarget
	session.damage = weaveData.Damage + (session.level / 75)
	session.force = math.random(8000, 9000)
	lifted[mouseTarget] = true

	-- hold the target helpless
	local maxHold = weaveData.MaxHold or DEFAULT_MAX_HOLD
	RagdollService.Ragdoll(mouseTarget, maxHold + 1)

	-- the lift itself (server side, real physics)
	local folder = Instance.new("Folder")
	folder.Name = "TelekineticCrashServerFolder"
	folder.Parent = hum
	session.folder = folder

	local newLevitator = Levitator:Clone()
	newLevitator.CFrame = tRoot.CFrame + Vector3.new(0, 10, 0)
	newLevitator.Parent = folder

	local attachment = tHead:FindFirstChild("TelekineticAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "TelekineticAttachment"
		attachment.Parent = tHead
	end
	local align = newLevitator:FindFirstChildOfClass("AlignPosition")
	if align then align.Attachment0 = attachment end

	-- the replicators draw the lock-on
	WeavingInstantEvent:FireAllClients(char, hum, humRP, WEAVE, mouseTarget, session.damage, session.force)

	-- caster never lets go: drop the target after MaxHold
	task.delay(maxHold, function()
		if sessions[player] == session then
			abortCast(player, session, weaveData.DebounceDuration)
		end
	end)
end)

-- 3. E RELEASED: the strike
WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char = getAlive(player)
	if not session.target or not char or char ~= session.char or (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then
		return abortCast(player, session, weaveData.FizzleCooldown or 1)
	end

	sessions[player] = nil
	cooldownUntil[player] = os.clock() + weaveData.DebounceDuration

	-- clients play the release sound and start tidying up
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, WEAVE)

	local target = session.target
	task.delay(weaveData.CastDelay or DEFAULT_CAST_DELAY, function()
		-- let the target go first, whatever happens next
		stopLevitation(session)
		lifted[target] = nil
		RagdollService.Release(target)

		local c, hum, root = getAlive(player)
		local tHum = target:FindFirstChildOfClass("Humanoid")
		if not c or c ~= char or (RagdollService.IsRagdolled(c) or not MovementService.CanCast(c)) then return end -- caster died or got ragdolled first
		if not tHum or tHum.Health <= 0 then return end

		tHum:TakeDamage(session.damage)
		tHum:SetAttribute("LastAttacker", player.UserId)
		tHum:SetAttribute("LastDamage", session.damage)

		if tHum.Health > 0 then
			RagdollService.Ragdoll(target, KNOCKBACK_TIME)
			task.spawn(DebuffHandler.Knockback, root, target, KNOCKBACK_TIME, session.force, 2.5, 5)
		end

		-- the replicators play the impact (camera shake, particles off)
		WeavingEvent:FireAllClients(c, hum, root, WEAVE, target)
	end)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if weaveName ~= WEAVE then return end
	WeavingFxClear:FireAllClients(player.UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName, phase)
	if weaveName ~= WEAVE or typeof(phase) ~= "string" then return end
	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- visuals only; the server no longer waits on this
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		dropTarget(session) -- never leave somebody hanging in the air
	end
	cooldownUntil[player] = nil
end)
