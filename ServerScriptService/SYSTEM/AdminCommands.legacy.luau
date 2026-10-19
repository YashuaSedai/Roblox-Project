-- AdminCommands   (Script, server)   ServerScriptService > SYSTEM > AdminCommands
--
-- Chat commands for admins. For now:
--     !add level, playername, amount
--     !add exp, playername, amount
-- The commas are optional ("!add level Bob 5" works too). The name can be a username, a display name, the start of either
-- (as long as only one player matches), or "me".
--
--   level  adds that many levels (a negative amount takes them away, but never below level 1)
--   exp    adds exp the normal way, so it levels the player up when they reach the amount needed
--
-- WHO CAN USE IT: only the user ids in ADMIN_USER_IDS below, and the owner of the game (if a user owns it).
-- In Studio everybody can, so you can test. Everyone else is ignored without a word.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Modules = RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local ExpHandler = require(Modules:WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))
local GuiRelatedThings = require(Modules:WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))

-- WHO CAN USE THE COMMANDS: put your user id here (and anybody else you trust)
local ADMIN_USER_IDS = {
	[201872807] = true,
}

-- SAFETY LIMITS for one command
local MAX_LEVELS = 500
local MAX_EXP = 1000000

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then return true end
	if ADMIN_USER_IDS[player.UserId] then return true end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- username / display name / start of either; nil if nobody (or more than one player) matches
local function findPlayer(speaker: Player, text: string): Player?
	text = text:lower()
	if text == "me" then return speaker end

	local prefixMatch, prefixCount = nil, 0
	for _, player in Players:GetPlayers() do
		local name, display = player.Name:lower(), player.DisplayName:lower()
		if name == text or display == text then
			return player -- an exact match wins straight away
		end
		if name:sub(1, #text) == text or display:sub(1, #text) == text then
			prefixMatch, prefixCount = player, prefixCount + 1
		end
	end
	if prefixCount == 1 then return prefixMatch end
	return nil
end

local function reply(admin: Player, message: string)
	print(`[Admin] {message}`)
	GuiRelatedThings.ErrorMessage(admin, message) -- shown in your error box
end

local function handleCommand(admin: Player, message: string)
	if message:lower():match("^!add%s") == nil then return end
	if not isAdmin(admin) then return end

	local body = message:match("^!%a+%s+(.+)$")
	local parts = {}
	for token in body:gmatch("[^,%s]+") do
		table.insert(parts, token)
	end
	if #parts ~= 3 then
		return reply(admin, "Use: !add level, playername, amount   or   !add exp, playername, amount")
	end

	local stat, playerText, amountText = parts[1]:lower(), parts[2], parts[3]
	local amount = tonumber(amountText)
	if not amount or amount ~= amount then
		return reply(admin, `"{amountText}" isn't a number`)
	end

	local target = findPlayer(admin, playerText)
	if not target then
		return reply(admin, `No single player matches "{playerText}"`)
	end

	local stats = target:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	local exp = stats and stats:FindFirstChild("Exp")
	if not (level and exp) then
		return reply(admin, `{target.Name} has no stats yet`)
	end
	if target:GetAttribute("hasLoaded") ~= true and not RunService:IsStudio() then
		return reply(admin, `{target.Name}'s data hasn't loaded yet, so it wouldn't be saved`)
	end

	if stat == "level" or stat == "levels" then
		amount = math.clamp(math.floor(amount), -MAX_LEVELS, MAX_LEVELS)
		local before = level.Value
		level.Value = math.max(1, before + amount) -- (the leaderboard script saves a few seconds after any level change)
		reply(admin, `{target.Name}: level {before} -> {level.Value}`)

	elseif stat == "exp" then
		amount = math.clamp(amount, -MAX_EXP, MAX_EXP)
		if amount >= 0 then
			ExpHandler.AwardExp(target, amount, false) -- levels them up when it's enough
		else
			exp.Value = math.max(0, exp.Value + amount)
		end
		reply(admin, `{target.Name}: {amount >= 0 and "gave" or "took"} {math.abs(amount)} exp (now level {level.Value}, {math.floor(exp.Value)} exp)`)

	else
		reply(admin, `Unknown stat "{parts[1]}". Use level or exp`)
	end
end

local function watch(player: Player)
	player.Chatted:Connect(function(message)
		handleCommand(player, message)
	end)
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
