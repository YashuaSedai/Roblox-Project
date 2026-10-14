-- ServerScriptService > SYSTEM > MovementServer   (Script, server)   NEW
--
-- The server half of MovementService.
--   1. Every character is tracked, so a status effect (Frozen, Shielded, Ragdolled...) changes WalkSpeed / Jump
--      the moment it lands. Nothing else in the project writes WalkSpeed / JumpPower any more.
--   2. WHILE A WEAVE IS BEING CHANNELED its Dictionary rule applies, decided HERE and not on the client:
--          Controls == false  -> the caster can't move (a Channel lock)
--          Controls == true   -> the caster is slowed to SlowPercentage (a speed multiplier)
--      The rule lasts until the weave is released / cleared, the caster dies, a status effect lands,
--      or a failsafe timer runs out (so a lost "release" message can never leave anybody stuck).

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local MovementService = require(Modules:WaitForChild("MovementService"))
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local Dictionary = require(WeavingFolder:WaitForChild("Dictionary"))

-- REMOTES (only listened to, the weave scripts still own them)
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")             -- E pressed
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")             -- the client's clean up
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")                 -- E released
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")

local SOURCE = "Cast"
local DEFAULT_FAILSAFE = 30 -- seconds, or the weave's MaxHold (+5) when it has one

local castStamp = {} -- [player] = number, so an old failsafe timer can never end a newer cast

local function getChar(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		return char
	end
	return nil
end

local function endCast(player)
	castStamp[player] = nil
	local char = player.Character
	if char then
		MovementService.ClearSource(char, SOURCE)
	end
end

-- 1. EVERY CHARACTER IS TRACKED
local function onCharacter(char)
	MovementService.Track(char)
	MovementService.Refresh(char)
end

local function onPlayer(player)
	if player.Character then onCharacter(player.Character) end
	player.CharacterAdded:Connect(onCharacter)
end

for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
Players.PlayerAdded:Connect(onPlayer)

-- 2. A WEAVE STARTS: apply its movement rule
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	local weaveData = typeof(weaveName) == "string" and Dictionary[weaveName]
	if not weaveData then return end

	local char = getChar(player)
	if not char or not MovementService.CanCast(char) then return end -- can't cast, so no cast rule either

	if weaveData.Controls == false then
		MovementService.SetLock(char, SOURCE, MovementService.Locks.Channel)
	elseif weaveData.Controls == true and weaveData.SlowPercentage then
		MovementService.SetSlow(char, SOURCE, weaveData.SlowPercentage)
	else
		return
	end

	-- failsafe
	local stamp = os.clock()
	castStamp[player] = stamp
	task.delay((weaveData.MaxHold or DEFAULT_FAILSAFE) + 5, function()
		if castStamp[player] == stamp then
			endCast(player)
		end
	end)
end)

-- 3. A WEAVE ENDS (the client always fires these from its clean up, whatever the reason)
WeavingFxClear.OnServerEvent:Connect(endCast)
WeavingEvent.OnServerEvent:Connect(endCast)
WeavingInstantReleaseEvent.OnServerEvent:Connect(endCast)

Players.PlayerRemoving:Connect(function(player)
	castStamp[player] = nil
end)
