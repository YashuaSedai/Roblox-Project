-- Linking   (Script, server)
--
-- THE LINK, step by step
--   1. E pressed ......... the cast opens                                                  -> CLIENT HOOK 1
--   2. target locked ..... range / validity checked, then the caster LINKS to the target.  -> CLIENT HOOK 2
--                          If the target is already linked to somebody, the caster joins THAT chain: the END weaver of the
--                          chain is the leader and collects everybody (LinkService.Add does the bookkeeping).
--   3. the caster HOLDS E. The link lives as long as the caster keeps holding it. It breaks (END) when they release,
--      are interrupted, die, walk out of range of the weaver they linked to, or cast another weave.
--      Whoever was linked to THEM stays linked to them (a broken chain splits in two).
--
-- WHAT A LINK DOES is NOT done here. This script only builds and breaks the link; LinkService writes the attributes
-- (Link / Linked / LinkLeader / ...), and Source, Burn and Shielding read them. See LinkData for the list.
--
--   sessions[player] = one caster's link attempt. Created on press, deleted ONLY inside finish().
--   Every loop re-checks  sessions[player] == session  so a stale one can never touch a newer cast.

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
local MovementService = require(Modules:WaitForChild("MovementService"))
local LinkService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("LinkService"))

-- REMOTES
local WeavingInstantEvent = WeavingFolder:WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local WEAVE = "Linking"

-- TUNING
local DEFAULT_MAX_HOLD = 300  -- or set MaxHold in the Dictionary
local RANGE_SLACK = 6         -- the client already checked range; allow a little movement since
local TARGET_TIMEOUT = 2      -- the client sends the target right after the press; no target by then = the cast fizzles
local DEBUG = false       -- prints WHY every link ended or fizzled in the Output window. Set to false when you're done testing.
local MIN_INTERVAL = 0.1      -- the Dictionary's Interval is 0, which would spin the loop; never check faster than this

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}      -- [caster player] = that caster's link attempt
local cooldownUntil = {} -- [caster player] = os.clock() time when the weave is ready again (outlives the session)

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

-- a valid target is another WEAVER (a player) who is alive and has Source (the leader's Source is what links boost)
local function getTargetParts(target)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then return end
	if not Players:GetPlayerFromCharacter(target) then return end
	local tHum = target:FindFirstChildOfClass("Humanoid")
	local tRoot = target:FindFirstChild("HumanoidRootPart")
	if not tHum or not tRoot or tHum.Health <= 0 then return end
	local source = tHum:FindFirstChild("Source")
	local maxSource = tHum:FindFirstChild("MaxSource")
	if not source or not maxSource then return end
	return tHum, tRoot
end

-- THE ONE PLACE A CAST ENDS. The caster's link breaks (anyone linked to THEM stays linked to them).
local function finish(player, session, cooldown, notifyClear, reason)
	if sessions[player] ~= session then return end -- already ended
	if DEBUG then
		print(`[Linking] {player.Name}: link ended. Reason: {reason or "unspecified"}`)
	end
	sessions[player] = nil
	cooldownUntil[player] = os.clock() + cooldown

	local char = session.char
	if session.linked then
		LinkService.Remove(char)
	end

	-- The linker can't move while holding the link (Dictionary: Controls = false, applied by MovementServer under the source "Cast").
	-- MovementServer only hears the CLIENT letting go, so when the SERVER ends the link (target out of range, status effect, a
	-- fizzle...) the lock is lifted here, or they would stay rooted for as long as they keep holding E.
	if char then
		MovementService.ClearSource(char, "Cast")
	end

	if char and char.Parent then
		char:SetAttribute("Charging", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:SetAttribute("Charge", 0) end
	end

	-- END (for THIS caster): the beam to the weaver they linked to can stop
	if notifyClear then
		WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = cancelled
	end
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, WEAVE, session.target)
end

-- THE CHANNEL: one loop per caster, keeps the link alive
local function runChannel(player, session)
	local weaveData = Dictionary[WEAVE]
	local target = session.target
	local interval = math.max(weaveData.Interval or 0, MIN_INTERVAL)
	local range = weaveData.CastRange + session.level + RANGE_SLACK
	local holdUntil = session.startedAt + (weaveData.MaxHold or DEFAULT_MAX_HOLD)
	local endCooldown = weaveData.DebounceDuration

	task.spawn(function()
		while sessions[player] == session do
			task.wait(interval)
			if sessions[player] ~= session then return end -- it ended while we were waiting

			-- THIS CASTER: dead, ragdolled, frozen, rooted, stunned or shielded = the link breaks
			local char, hum, humRP = getAlive(player)
			if not char or char ~= session.char or not DebuffHandler.CheckStatus(char) then
				return finish(player, session, endCooldown, true, "you died, or a status effect (Frozen / Shielded / Rooted / Stunned / Ragdolled) landed on you")
			end
			if os.clock() > holdUntil then
				return finish(player, session, endCooldown, true, "held for the maximum time")
			end

			-- the link was cut from outside (the weaver they linked to died or left)
			if LinkService.GetParent(char) ~= target then
				return finish(player, session, endCooldown, true, "the link was cut from outside (the weaver you linked to died or left)")
			end

			-- THE WEAVER THEY LINKED TO: gone, dead, or out of range = the link breaks
			local tHum, tRoot = getTargetParts(target)
			if not tHum or not target:IsDescendantOf(workspace) or (tRoot.Position - humRP.Position).Magnitude > range then
				return finish(player, session, endCooldown, true, "the weaver you linked to is gone, dead, or out of range")
			end

			-- the cast gate (also what ends the link the moment a status effect lands). SourceCost is 0 in the Dictionary.
			if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
				return finish(player, session, endCooldown, true, "the cast gate refused (a status effect, or not enough Source)")
			end
		end
	end)
end

-- 1. E PRESSED: the cast opens
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	-- casting ANY OTHER weave breaks the link this caster is holding
	if weaveName ~= WEAVE then
		local session = sessions[player]
		if session then
			finish(player, session, Dictionary[WEAVE].DebounceDuration, true, "you cast another weave")
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
		target = nil,      -- the weaver this caster linked to (step 2)
		linked = false,    -- true once LinkService has the link
		targeted = false,
	}
	sessions[player] = session

	-- the target should arrive any moment; if it never does, don't leave a half-open cast behind
	task.delay(TARGET_TIMEOUT, function()
		if sessions[player] == session and not session.targeted then
			finish(player, session, weaveData.FizzleCooldown or 1, true, "no target arrived in time (the client never sent one)")
		end
	end)

	-- CLIENT HOOK 1: the caster tries to link. Hand VFX etc. start here.
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
		return finish(player, session, failCooldown, true, "your character isn't alive")
	end

	-- is it somebody who can be linked to?
	local tHum, tRoot = getTargetParts(mouseTarget)
	if not tHum or mouseTarget == char then
		return finish(player, session, failCooldown, true, "that target can't be linked: it must be another PLAYER's character, alive, with Source (an NPC dummy won't work)")
	end

	-- CHECK THE RANGE (the same formula the client uses)
	local range = weaveData.CastRange + session.level
	if (tRoot.Position - humRP.Position).Magnitude > range + RANGE_SLACK then
		return finish(player, session, failCooldown, true, "that target is out of range")
	end

	-- THE LINK. Fails if the caster is already linked to somebody, or if it would make a loop.
	local ok, why = LinkService.Add(char, mouseTarget)
	if not ok then
		return finish(player, session, failCooldown, true, "LinkService refused: " .. tostring(why))
	end
	session.target = mouseTarget
	session.linked = true

	-- The linker can't move while the link exists. MovementServer already applies this from the Dictionary (Controls = false)
	-- when E is pressed; doing it here too ties the lock to the link itself. finish() lifts it.
	MovementService.SetLock(char, "Cast", MovementService.Locks.Channel)
	if DEBUG then
		print(`[Linking] {player.Name} linked to {mouseTarget.Name}. Linkers on the leader: {LinkService.GetLeader(char):GetAttribute("Link")}`)
	end

	-- CLIENT HOOK 2: the link is made. A beam from the caster to the weaver they linked to starts here.
	-- The last argument is the LEADER of the chain (the end weaver). Link attributes are already up to date on every character.
	WeavingInstantEvent:FireAllClients(char, hum, humRP, WEAVE, mouseTarget, LinkService.GetLeader(char))

	runChannel(player, session)
end)

-- 3. E RELEASED: this caster lets go, so their link breaks
WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	if session.linked then
		finish(player, session, weaveData.DebounceDuration, false, "you released the key (link was up)")
	else
		finish(player, session, weaveData.FizzleCooldown or 1, false, "you released the key before the link was made") -- let go before the link was made
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
		finish(player, session, 0, true, "you left the game") -- never leave a dangling link
	end
	cooldownUntil[player] = nil
end)
