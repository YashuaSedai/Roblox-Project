-- ServerScriptService > Weaves > Fire > Enflame > EnflameScript   (Script)
-- Replaces the whole old file.
--
-- The client asks ("I'm casting", "release, my target is this model"). The server decides everything else:
-- cooldown, Source, whether the target is valid and in range, whether the target countered it (Inverse, F key),
-- and the burn itself.
--
-- NOTE: add  ServerPaid = true  to the Enflame entry in the Dictionary. The server charges the Source now,
-- and without that flag the client ALSO charges it, so every cast would cost double.

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
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local InversingRemote = WeavingFolder:WaitForChild("InversingRemote")

local WEAVE = "Enflame"
local TRAVEL_TIME = 2    -- seconds the flame trail takes to reach the target. MUST match tweenInfo in EnflameReplicator.
local INVERSE_GRACE = 0.3 -- extra time a counter is still accepted (the target reacts to what THEY see, which is a bit late)
local DOT_TICK = 0.1     -- same tick the old client script used
local RANGE_SLACK = 6    -- the client measured range a moment ago; the target may have moved since

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}      -- [player] = { startedAt, level, char }  between press and release
local cooldownUntil = {} -- [player] = os.clock() time when the weave is ready again
local incoming = {}      -- [target model] = { [lock] = true }  flames still travelling towards that target

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

-- a cast that's cancelled while the caster is still holding E (ragdolled)
local function cancelCast(player, char)
	if not sessions[player] then return end
	sessions[player] = nil

	cooldownUntil[player] = os.clock() + Dictionary[WEAVE].DebounceDuration

	char:SetAttribute("Charging", false)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum:SetAttribute("Charge", 0) end

	WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled, clients end the visuals now
end

RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		cancelCast(player, char)
	end
end)

-- 1. E PRESSED: open a cast (checks, Source, hand visuals)
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < 30 then return end -- already casting
	if os.clock() < (cooldownUntil[player] or 0) then return end                    -- on cooldown

	-- no Source, no cast
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

	sessions[player] = { startedAt = os.clock(), level = getLevel(player), char = char }
	
	if typeof(mousePos) ~= "Vector3" or mousePos ~= mousePos or not (mousePos.Magnitude < 1e5) then mousePos = nil end

	-- the hand visuals
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName, mousePos)
end)

-- 2. E RELEASED: the client says who it's aiming at, the server decides if that's allowed
WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, _charge, mouseTarget, _mousePos, _level)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)
	sessions[player] = nil

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char or char ~= session.char then return end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	local level = session.level
	local failCooldown = weaveData.FizzleCooldown or 1

	-- is the target something that can be burned?
	if typeof(mouseTarget) ~= "Instance" or not mouseTarget:IsA("Model") or mouseTarget == char or not mouseTarget:IsDescendantOf(workspace) then
		cooldownUntil[player] = os.clock() + failCooldown
		return
	end
	local target = mouseTarget
	local tHum = target:FindFirstChildOfClass("Humanoid")
	local tRoot = target:FindFirstChild("HumanoidRootPart")
	if not tHum or not tRoot or tHum.Health <= 0 then
		cooldownUntil[player] = os.clock() + failCooldown
		return
	end

	-- in range? (same formula the client uses: CastRange + level)
	local castRange = weaveData.CastRange + level
	if (tRoot.Position - humRP.Position).Magnitude > castRange + RANGE_SLACK then
		cooldownUntil[player] = os.clock() + failCooldown
		return
	end

	cooldownUntil[player] = os.clock() + weaveData.DebounceDuration

	-- the server's own numbers
	local totalDamage = weaveData.DamageOverTime * (1 + level / 100)
	local duration = weaveData.Duration

	-- the flame is now "in flight" towards the target: this is the window the target can counter it in
	local lock = { cancelled = false }
	incoming[target] = incoming[target] or {}
	incoming[target][lock] = true

	-- the replicators draw the trail travelling to the target, then the burn
	WeavingEvent:FireAllClients(char, hum, humRP, WEAVE, target, totalDamage, duration)

	task.delay(TRAVEL_TIME + INVERSE_GRACE, function()
		local locks = incoming[target]
		if locks then
			locks[lock] = nil
			if next(locks) == nil then incoming[target] = nil end
		end

		if lock.cancelled then return end -- the target countered it
		if not tHum.Parent or tHum.Health <= 0 then return end

		-- the burn: damage spread over the duration, applied by the server
		DebuffHandler.DoT(player, player.UserId, tHum, totalDamage, duration, DOT_TICK)
	end)
end)

-- COUNTER (Inverse): the target drew the opposite element and pressed F.
-- The server only believes it if a flame is genuinely on its way to that player.
InversingRemote.OnServerEvent:Connect(function(player: Player, inverseName, inverseKey, incomingWeave)
	if inverseName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData or typeof(inverseKey) ~= "string" or inverseKey ~= weaveData.InverseKey then return end
	if typeof(incomingWeave) ~= "CFrame" then return end -- only used for the visual

	local char, hum, humRP = getAlive(player)
	if not char then return end

	local locks = incoming[char]
	if not locks or next(locks) == nil then return end -- nothing is coming at this player: nothing to counter

	for lock in locks do
		lock.cancelled = true
	end
	incoming[char] = nil

	-- Decode the key into elements (e1..e5), then let every client draw the counter
	local e1, e2, e3, e4, e5 = WeavingModule.DecodeInverseKey(inverseKey)
	InversingRemote:FireAllClients(char, hum, humRP, inverseName, incomingWeave, e1, e2, e3, e4, e5)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if weaveName ~= WEAVE then return end
	WeavingFxClear:FireAllClients(player.UserId, weaveName)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	cooldownUntil[player] = nil
end)
