-- DamageService   (ModuleScript, SERVER ONLY)   ServerScriptService > SYSTEM > DamageService
--
-- THE ONE PLACE DAMAGE HAPPENS. Weaves, damage over time and burnout all call into here instead of touching a Humanoid.
--
--   DamageService.Damage(target, amount, attacker, info?)  -> damage actually dealt
--       target    a Humanoid or a character Model
--       amount    how much to deal
--       attacker  the Player who gets the credit (or nil: environment, burnout, NPC...)
--       info      optional table, e.g. { Source = "Fireball" }.  { BypassForceField = true } skips ForceFields (burnout).
--   DamageService.DamageOverTime(target, total, duration, perTick, attacker, info?)
--   DamageService.Damaged   event  (humanoid, dealt, attackerPlayer, info)   fires on every hit that did damage
--   DamageService.Killed    event  (humanoid, killerPlayer, credits)         fires once when something dies
--
-- WHY EXP COMES FROM HERE. Only damage that really took health is recorded ("dealt"), per attacker, per victim.
-- When the victim dies, every attacker is paid for the damage THEY dealt:
--
--     exp   = victim's exp value  x  (damage you dealt / victim's max health)  x  EXP_MULTIPLIER
--     marks = victim's marks value x (damage you dealt / victim's max health)
--
--   * Deal all of a victim's health and you get its whole value. Deal a quarter of it and you get a quarter.
--   * Overkill doesn't count (only health that was really lost is credited), and neither does damage nobody dealt:
--     if the victim died to burnout or a fall, only the player damage is paid.
--   * Heal-and-hit farming can't pay out more than the victim's full value: the total is scaled down if it would.
--   * Victim value: an NPC uses its EnemyDictionary entry. A player is worth PlayerBaseInfo.exp + level * 3 (as before).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local ExpHandler = require(Modules:WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))
local MarksHandler = require(Modules:WaitForChild("MarksHandler"):WaitForChild("MarksHandler"))
local EnemyDictionary = require(Modules:WaitForChild("EnemyHandler"):WaitForChild("EnemyDictionary"))

-- TUNING
local EXP_MULTIPLIER = 1       -- scales ALL exp from kills (raise it to make leveling faster)
local PLAYER_EXP_PER_LEVEL = 3 -- a player victim is worth PlayerBaseInfo.exp + (their level * this)

local DamageService = {}

local damagedEvent = Instance.new("BindableEvent")
local killedEvent = Instance.new("BindableEvent")
DamageService.Damaged = damagedEvent.Event
DamageService.Killed = killedEvent.Event

-- records[humanoid] = { credits = { [userId] = damage dealt }, settled = bool }   (weak keys: gone with the humanoid)
local records = setmetatable({}, { __mode = "k" })

local function getRecord(hum)
	local record = records[hum]
	if not record or (record.settled and hum.Health > 0) then -- (a revived NPC starts a fresh record)
		record = { credits = {}, settled = false }
		records[hum] = record
	end
	return record
end

local function resolveHumanoid(target)
	if typeof(target) ~= "Instance" then return nil end
	if target:IsA("Humanoid") then return target end
	if target:IsA("Model") then return target:FindFirstChildOfClass("Humanoid") end
	return nil
end

local function resolvePlayer(attacker)
	if typeof(attacker) == "Instance" then
		if attacker:IsA("Player") then return attacker end
		if attacker:IsA("Model") then return Players:GetPlayerFromCharacter(attacker) end
	elseif type(attacker) == "number" then
		return Players:GetPlayerByUserId(attacker)
	end
	return nil
end

-- the victim died: pay everybody for the damage they dealt
local function settle(hum, record, killer)
	if record.settled then return end
	record.settled = true

	local char = hum.Parent
	local victimPlayer = char and Players:GetPlayerFromCharacter(char)
	local expValue, marksValue

	if victimPlayer then
		local base = EnemyDictionary.Information.PlayerBaseInfo
		local stats = victimPlayer:FindFirstChild("leaderstats")
		local level = stats and stats:FindFirstChild("Level")
		expValue = base.exp + (level and level.Value or 1) * PLAYER_EXP_PER_LEVEL
		marksValue = base.marks
	else
		local entry = char and EnemyDictionary.Information[char.Name]
		if entry then
			expValue, marksValue = entry.exp, entry.marks
		end
	end

	if expValue then
		local maxHealth = math.max(hum.MaxHealth, 1)
		local totalFraction = 0
		for _, damage in record.credits do
			totalFraction += damage / maxHealth
		end
		local scale = if totalFraction > 1 then 1 / totalFraction else 1

		for userId, damage in record.credits do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				local fraction = (damage / maxHealth) * scale
				ExpHandler.AwardExp(player, expValue * fraction * EXP_MULTIPLIER, player:GetAttribute("TripleExp") or false)
				MarksHandler.GiveMarks(player, (marksValue or 0) * fraction, player:GetAttribute("DoubleMarks") or false)
			end
		end
	end

	killedEvent:Fire(hum, killer, record.credits)
end

function DamageService.Damage(target, amount, attacker, info)
	local hum = resolveHumanoid(target)
	if not hum or hum.Health <= 0 then return 0 end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return 0 end
	info = info or {}

	local attackerPlayer = resolvePlayer(attacker)
	if attackerPlayer and attackerPlayer == Players:GetPlayerFromCharacter(hum.Parent) then
		attackerPlayer = nil -- hurting yourself earns nothing
	end

	local before = hum.Health

	-- the legacy attribution, set BEFORE the health changes so anything listening to HealthChanged already sees it
	if attackerPlayer then
		hum:SetAttribute("LastAttacker", attackerPlayer.UserId)
		hum:SetAttribute("LastDamage", amount)
	end

	if info.BypassForceField then
		hum.Health = math.max(before - amount, 0)
	else
		hum:TakeDamage(amount) -- (a ForceField makes this do nothing)
	end

	local dealt = before - hum.Health
	if dealt <= 0 then return 0 end

	local record = getRecord(hum)
	if attackerPlayer then
		record.credits[attackerPlayer.UserId] = (record.credits[attackerPlayer.UserId] or 0) + dealt
	end

	damagedEvent:Fire(hum, dealt, attackerPlayer, info)

	if hum.Health <= 0 then
		settle(hum, record, attackerPlayer)
	end
	return dealt
end

-- `total` damage spread evenly over `duration` seconds, one hit every `perTick` seconds
function DamageService.DamageOverTime(target, total, duration, perTick, attacker, info)
	local hum = resolveHumanoid(target)
	if not hum or type(duration) ~= "number" or type(perTick) ~= "number" or perTick <= 0 then return end
	local ticks = math.max(math.floor(duration / perTick + 0.5), 1)
	local each = total / ticks
	task.spawn(function()
		for _ = 1, ticks do
			if not hum.Parent or hum.Health <= 0 then return end
			DamageService.Damage(hum, each, attacker, info)
			task.wait(perTick)
		end
	end)
end

return DamageService
