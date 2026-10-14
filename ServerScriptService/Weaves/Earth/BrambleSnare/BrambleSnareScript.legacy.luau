-- ServerScriptService > Weaves > Earth > BrambleSnare > BrambleSnareScript   (Script)
-- Replaces the whole old file.
--
-- The client asks ("I'm casting here", "I let go"). The server decides everything else:
-- cooldown, Source (drained while you hold E), range, who is inside the snare, the roots and the damage.
--
-- Flow:
--   1. E pressed   (WeavingFxEvent)             -> checks, Source starts draining, hand visuals appear
--   2. ReadyTime later (server timer)           -> the snare LANDS: everyone inside the area is rooted and starts taking damage
--   3. E released  (WeavingInstantReleaseEvent) -> everyone is freed and the weave goes on cooldown
--      (released BEFORE it landed = it fizzles: nothing is rooted, short FizzleCooldown)
--   The snare also ends by itself if the caster is ragdolled, dies, leaves, runs out of Source, or holds too long.
--
-- Dictionary: set ReadyTime to when the Channel animation's "Signal" marker fires (that is when the old version landed),
-- and add RequiresReady = true / FizzleCooldown = 1 the same way as Boulder and Frostbound.

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
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local WEAVE = "BrambleSnare"
local DEFAULT_READY_TIME = 4   -- seconds from press to the snare landing; set ReadyTime in the Dictionary to match your Channel animation
local DEFAULT_MAX_HOLD = 60    -- safety cap: the snare never lasts longer than this; or set MaxHold in the Dictionary
local DAMAGE_TICK = 1          -- seconds between damage ticks (same as the old client script)
local RANGE_SLACK = 6          -- the client already checked range when you pressed; allow a little movement since

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}      -- [player] = { startedAt, level, char, mousePos, area, damage, landed, enemies, ... }
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

-- ENDS THE SNARE (whatever the reason): frees everyone, resets the caster, tells the clients to clean up
local function finish(player, session, cooldown, notifyClear)
	if sessions[player] ~= session then return end -- already ended
	sessions[player] = nil
	cooldownUntil[player] = os.clock() + cooldown

	if session.diedConn then session.diedConn:Disconnect() end

	-- free everyone this snare rooted (Root(false) waits a moment before unanchoring, so don't block on it)
	for _, enemy in session.enemies do
		if enemy.Parent then
			task.spawn(DebuffHandler.Root, player, enemy, false)
		end
	end
	session.enemies = {}

	local char = session.char
	if char and char.Parent then
		char:SetAttribute("Charging", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetAttribute("Charge", 0) end
	end

	if notifyClear then
		WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled: clients end the hand visuals now
	end
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, WEAVE) -- the replicators tidy up the vines
end

-- THE SNARE LANDS: pick who is inside, root them, start the damage ticks
local function land(player, session)
	if sessions[player] ~= session or session.landed then return end

	local weaveData = Dictionary[WEAVE]
	local char, hum, humRP = getAlive(player)
	if not char or char ~= session.char or (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then
		return finish(player, session, weaveData.DebounceDuration, true)
	end
	session.landed = true

	local position, area, damage = session.mousePos, session.area, session.damage

	local enemies, seen = {}, {}
	for _, part in workspace:GetPartBoundsInRadius(position, area) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] and model ~= char then
			seen[model] = true
			local tHum = model:FindFirstChildOfClass("Humanoid")
			local tRoot = model:FindFirstChild("HumanoidRootPart")
			if tHum and tRoot and tHum.Health > 0 and (tRoot.Position - position).Magnitude < area then
				table.insert(enemies, model)
			end
		end
	end
	session.enemies = enemies

	for _, enemy in enemies do
		DebuffHandler.Root(player, enemy, true) -- rooted until the snare ends
	end

	-- the replicators draw the vines on exactly the enemies the server picked
	WeavingInstantEvent:FireAllClients(char, hum, humRP, WEAVE, position, damage, area, session.castRange, enemies)

	-- damage ticks, applied by the server
	task.spawn(function()
		while sessions[player] == session do
			for _, enemy in enemies do
				local tHum = enemy.Parent and enemy:FindFirstChildOfClass("Humanoid")
				if tHum and tHum.Health > 0 then
					DebuffHandler.Damage(player, player.UserId, tHum, damage)
				end
			end
			task.wait(DAMAGE_TICK)
		end
	end)
end

-- the caster got ragdolled: end the snare
RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	local session = player and sessions[player]
	if session and session.char == char then
		finish(player, session, Dictionary[WEAVE].DebounceDuration, true)
	end
end)

-- 1. E PRESSED
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, _level)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < (weaveData.MaxHold or DEFAULT_MAX_HOLD) + 5 then return end -- already casting
	if os.clock() < (cooldownUntil[player] or 0) then return end                                                          -- on cooldown

	-- where is the snare going? it must be a real point within reach
	if typeof(mousePos) ~= "Vector3" or mousePos ~= mousePos or not (mousePos.Magnitude < 1e5) then return end
	local level = getLevel(player)
	local castRange = weaveData.CastRange + level -- same formula the client uses
	if (mousePos - humRP.Position).Magnitude > castRange + RANGE_SLACK then return end

	-- no Source, no cast
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

	local area = weaveData.Area + (level / 10)
	local session = {
		startedAt = os.clock(),
		level = level,
		char = char,
		mousePos = mousePos,
		castRange = castRange,
		area = area,
		damage = weaveData.Damage + (level / 75), -- damage PER TICK
		landed = false,
		enemies = {},
	}
	sessions[player] = session

	-- the caster dying ends it
	session.diedConn = hum.Died:Connect(function()
		finish(player, session, weaveData.DebounceDuration, true)
	end)

	-- keep draining Source while E is held (SourceCost every Interval, as the Dictionary describes). Out of Source = the snare ends.
	local interval = weaveData.Interval
	if weaveData.Charging and interval and interval > 0 then
		task.spawn(function()
			while sessions[player] == session do
				task.wait(interval)
				if sessions[player] ~= session then break end
				if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
					finish(player, session, weaveData.DebounceDuration, true)
					break
				end
			end
		end)
	end

	-- the snare lands after the wind-up
	task.delay(weaveData.ReadyTime or DEFAULT_READY_TIME, function()
		land(player, session)
	end)

	-- caster holds forever: end it
	task.delay(weaveData.MaxHold or DEFAULT_MAX_HOLD, function()
		finish(player, session, weaveData.DebounceDuration, true)
	end)

	-- the hand visuals
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName, area, mousePos)
end)

-- 2. E RELEASED
WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	if session.landed then
		finish(player, session, weaveData.DebounceDuration, false) -- normal end; the client already cleared its own visuals
	else
		finish(player, session, weaveData.FizzleCooldown or 1, false) -- released before it landed: it fizzles, nothing was rooted
	end
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
		finish(player, session, 0, false) -- never leave anyone rooted
	end
	cooldownUntil[player] = nil
end)
