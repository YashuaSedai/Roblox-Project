-- LeaderboardScript   (Script, server)
-- Creates leaderstats (Level / Marks / Exp) and loads and saves them.
--
-- WHAT CHANGED FROM THE OLD VERSION
--   * ONE record per player ("PlayerData_v1") instead of three separate stores. It's written in one request, so level, exp and
--     marks can never be saved out of step with each other.
--   * Existing players keep their progress: the first time someone joins without a new record, their level / exp / marks are read
--     from the three OLD stores and carried over.
--   * Every DataStore call retries with a growing wait, instead of failing on the first hiccup.
--   * A failed load never lets you play on as level 1 and then overwrite your real data: you're kicked with a message
--     (in Studio you just play without saving).
--   * Saves happen: every AUTOSAVE_INTERVAL seconds, shortly after every LEVEL-UP, when you leave, and when the server shuts
--     down (BindToClose). The old version only saved on leaving, so a crash or shutdown lost everything.
--   * SESSION LOCK. The record remembers which server has the player. If you rejoin while the old server is still saving, the new
--     server waits for it. A server that doesn't have the lock can never overwrite the data. A lock older than LOCK_TIMEOUT is
--     assumed to belong to a crashed server and is taken over.

-- SERVICES
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

-- MODULES
local ExpHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))

-- DATASTORES
local store = DataStoreService:GetDataStore("PlayerData_v1")
local legacyLevelStore = DataStoreService:GetDataStore("PlayerLevelData") -- the old stores: only READ, once, to migrate
local legacyMarksStore = DataStoreService:GetDataStore("PlayerMarksData")
local legacyExpStore = DataStoreService:GetDataStore("PlayerExpData")

-- TUNING
local KEY_PREFIX = "Player_"
local AUTOSAVE_INTERVAL = 60   -- seconds between autosaves (this also refreshes the session lock)
local LEVEL_SAVE_DELAY = 3     -- after a level-up, wait this long (so a burst of level-ups is one save), then save
local MAX_ATTEMPTS = 5         -- tries per DataStore call
local LOCK_TIMEOUT = 180       -- seconds before another server's lock is assumed dead
local LOCK_WAIT_ATTEMPTS = 6   -- how many times to wait for the old server to let go...
local LOCK_WAIT_SECONDS = 3    -- ...and how long between those waits
local KICK_ON_LOAD_FAIL = true -- true: kick if data can't be loaded (outside Studio). false: play without saving.

local loaded = {}         -- [player] = true once their data is live (only loaded players are ever saved)
local saving = {}         -- [player] = true while a save is in flight
local levelSaveQueued = {} -- [player] = true while a post-level-up save is waiting

-- calls fn until it works, waiting 1, 2, 4, 8, 8 seconds between tries. Returns ok, result
local function withRetry(fn)
	local lastErr
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		if tostring(result):find("StudioAccessToApisNotAllowed") then break end -- no point retrying, API access is off
		if attempt < MAX_ATTEMPTS then
			task.wait(math.min(2 ^ (attempt - 1), 8))
		end
	end
	return false, lastErr
end

-- READ the player's record and take the session lock, in ONE atomic request. Returns record or nil, errorText
local function loadRecord(userId)
	local key = KEY_PREFIX .. userId
	for _ = 1, LOCK_WAIT_ATTEMPTS do
		local lockedByOther = false
		local ok, record = withRetry(function()
			return store:UpdateAsync(key, function(old)
				lockedByOther = false -- (reset: the function can run more than once)
				old = old or {}
				local lock = old.Lock
				if lock and lock.JobId ~= game.JobId and os.time() - lock.Time < LOCK_TIMEOUT then
					lockedByOther = true
					return nil -- cancel: somebody else has this player right now
				end
				old.Lock = { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if not ok then return nil, record end
		if not lockedByOther then return record end
		task.wait(LOCK_WAIT_SECONDS)
	end
	return nil, "this player is still active on another server"
end

-- a player with no new record yet: bring their level / exp / marks over from the three old stores
local function readLegacy(userId)
	local function read(legacyStore)
		local ok, value = withRetry(function() return legacyStore:GetAsync(userId) end)
		if not ok then return false, value end
		return true, tonumber(value) -- (nothing saved, or "", gives nil)
	end
	local okL, level = read(legacyLevelStore)
	if not okL then return nil, level end
	local okE, exp = read(legacyExpStore)
	if not okE then return nil, exp end
	local okM, marks = read(legacyMarksStore)
	if not okM then return nil, marks end
	return { Level = level or 1, Exp = exp or 0, Marks = marks or 0 }
end

-- WRITE the record. releaseLock = true when the player is leaving. Returns true when it was saved
local function savePlayer(player, releaseLock)
	if not loaded[player] then return false end
	if saving[player] then
		if not releaseLock then return false end -- an autosave can simply skip a turn
		while saving[player] do task.wait(0.1) end -- the final save waits its turn
		if not loaded[player] then return true end -- (somebody else already did the final save)
	end

	local stats = player:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	local exp = stats and stats:FindFirstChild("Exp")
	local marks = stats and stats:FindFirstChild("Marks")
	if not (level and exp and marks) then return false end
	local levelValue, expValue, marksValue = level.Value, exp.Value, marks.Value

	saving[player] = true
	local lostLock = false
	local ok, err = withRetry(function()
		store:UpdateAsync(KEY_PREFIX .. player.UserId, function(old)
			old = old or {}
			if old.Lock and old.Lock.JobId ~= game.JobId then
				lostLock = true
				return nil -- another server owns this player now: never overwrite their data
			end
			lostLock = false
			old.Version = 1
			old.Level, old.Exp, old.Marks = levelValue, expValue, marksValue
			old.Lock = if releaseLock then nil else { JobId = game.JobId, Time = os.time() }
			return old
		end)
	end)
	saving[player] = nil

	if not ok then
		warn(`[Leaderboard] could not save {player.Name}: {err}`)
		return false
	end
	if lostLock then
		warn(`[Leaderboard] {player.Name} is locked by another server, nothing saved`)
		return false
	end
	if releaseLock then loaded[player] = nil end
	return true
end

-- a player who left while we were still loading: hand the lock back
local function releaseLock(userId)
	pcall(function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(old)
			if old and old.Lock and old.Lock.JobId == game.JobId then
				old.Lock = nil
				return old
			end
			return nil
		end)
	end)
end

local function onPlayerAdded(player: Player)
	-- the storage for our stats. They exist from the start (so nothing else breaks) and are filled in once the data has loaded.
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local level = Instance.new("NumberValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = leaderstats

	local marks = Instance.new("NumberValue")
	marks.Name = "Marks"
	marks.Parent = leaderstats

	local exp = Instance.new("NumberValue")
	exp.Name = "Exp"
	exp.Parent = leaderstats

	-- true only once the data really loaded. Other scripts can read it.
	player:SetAttribute("hasLoaded", false)
	player:SetAttribute("Level", 1)
	player:SetAttribute("Marks", 0)
	player:SetAttribute("Exp", 0)

	local record, err = loadRecord(player.UserId)

	if record and record.Level == nil then -- no new-style record yet: a brand new player, or one from the old system
		local legacy, legacyErr = readLegacy(player.UserId)
		if legacy then
			record.Level, record.Exp, record.Marks = legacy.Level, legacy.Exp, legacy.Marks
		else
			record, err = nil, legacyErr
			releaseLock(player.UserId)
		end
	end

	if not player.Parent then -- they left while this was loading
		if record then releaseLock(player.UserId) end
		return
	end

	if not record then
		warn(`[Leaderboard] data for {player.Name} did not load: {err}`)
		if KICK_ON_LOAD_FAIL and not RunService:IsStudio() then
			player:Kick("Your data could not be loaded, so you were removed to protect your progress. Please rejoin.")
		end
		return -- (in Studio you keep playing at level 1, and nothing is saved because loaded[player] stays unset)
	end

	-- APPLY THE DATA (before the change handlers below are connected, so loading doesn't trigger a level-up check or a save)
	level.Value = math.max(1, math.floor(tonumber(record.Level) or 1))
	exp.Value = math.max(0, tonumber(record.Exp) or 0)
	marks.Value = math.max(0, tonumber(record.Marks) or 0)
	player:SetAttribute("Level", level.Value)
	player:SetAttribute("Marks", marks.Value)
	player:SetAttribute("Exp", exp.Value)

	loaded[player] = true
	player:SetAttribute("hasLoaded", true)

	level.Changed:Connect(function()
		player:SetAttribute("Level", level.Value)
		-- a level is the thing a player hates losing most: save soon after every level-up
		if level.Value > 1 and not levelSaveQueued[player] then
			levelSaveQueued[player] = true
			task.delay(LEVEL_SAVE_DELAY, function()
				levelSaveQueued[player] = nil
				if player.Parent then savePlayer(player, false) end
			end)
		end
	end)

	marks.Changed:Connect(function()
		player:SetAttribute("Marks", marks.Value)
	end)

	exp.Changed:Connect(function()
		player:SetAttribute("Exp", exp.Value)
		ExpHandler.CheckExp(player)
	end)
end

-- LEAVING: save and hand the lock back
Players.PlayerRemoving:Connect(function(player)
	savePlayer(player, true)
	loaded[player] = nil
	saving[player] = nil
	levelSaveQueued[player] = nil
end)

-- SERVER SHUTTING DOWN: save everybody at once, then let the server close
game:BindToClose(function()
	local pending = 0
	for _, player in Players:GetPlayers() do
		if loaded[player] then
			pending += 1
			task.spawn(function()
				savePlayer(player, true)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

-- AUTOSAVE
task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in Players:GetPlayers() do
			if loaded[player] then
				task.spawn(savePlayer, player, false)
				task.wait(0.2) -- spread the requests out
			end
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do -- (players who joined before this script started)
	task.spawn(onPlayerAdded, player)
end
