-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULES
local WeavingFolder = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule")
local WeavingModule = require(WeavingFolder:WaitForChild("WeavingModule"))
local Dictionary = require(WeavingFolder:WaitForChild("Dictionary"))

-- REMOTES
local WeavingEvent = WeavingFolder:WaitForChild("WeavingEvent")
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local WEAVE = "Fireball"

-- STATE THE SERVER OWNS (clients can't touch these)
local sessions = {}       -- [player] = { startedAt, level, char } while a cast is being channeled
local cooldownUntil = {}  -- [player] = os.clock() time when the weave is ready again

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

-- START OF CAST (client fires this when E is pressed)
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[weaveName]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end

	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < 30 then return end -- already channeling
	if os.clock() < (cooldownUntil[player] or 0) then return end                   -- on cooldown

	-- no Source, no cast
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then return end

	local session = { startedAt = os.clock(), level = getLevel(player), char = char }
	sessions[player] = session

	-- while charging, keep paying Source (this used to be the client's job)
	if weaveData.Charging and weaveData.Interval > 0 then
		local maxTime = weaveData.MaxCharge * WeavingModule.ChargeInterval(session.level)
		task.spawn(function()
			while sessions[player] == session and hum.Health > 0 and os.clock() - session.startedAt < maxTime do
				task.wait(weaveData.Interval)
				if sessions[player] ~= session then break end
				if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then break end
			end
		end)
	end

	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)

-- RELEASE (client fires this when E is released)
WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, _charge, _mouseTarget, mousePos, _level)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end -- not casting: ignore (also stops double releases)
	sessions[player] = nil

	local char, hum, humRP = getAlive(player)
	if not char or session.char ~= char then return end
	if typeof(mousePos) ~= "Vector3" or not (mousePos.Magnitude < 1e5) then return end

	local weaveData = Dictionary[weaveName]
	if not weaveData then return end
	cooldownUntil[player] = os.clock() + weaveData.DebounceDuration

	-- the server's own numbers, never the client's
	local level = session.level
	local charge = 0
	if weaveData.Charging then
		local interval = WeavingModule.ChargeInterval(level)
		charge = math.clamp(math.floor((os.clock() - session.startedAt) / interval) + 1, 0, weaveData.MaxCharge)
	end

	local DAMAGE = weaveData.Damage
	local DOT = weaveData.DamageOverTime
	local DURATION = weaveData.Duration
	local PROJECTILE_SPEED = weaveData.ProjectileSpeed
	local LIFETIME = weaveData.Lifetime
	local AREA = weaveData.Area

	DOT = DOT + (DOT * (charge / 5))
	DURATION = DURATION + (DURATION * (charge / 100))
	LIFETIME = LIFETIME + (level / 50)
	AREA = AREA + ((level * charge) / 50)
	PROJECTILE_SPEED = PROJECTILE_SPEED + ((level * charge) / 200)
	local force = (charge * 100) + 2500

	WeavingEvent:FireAllClients(char, hum, humRP, weaveName, mousePos, DAMAGE, DURATION, charge, LIFETIME, AREA, PROJECTILE_SPEED, DOT, force)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if weaveName ~= WEAVE then return end
	WeavingFxClear:FireAllClients(player.UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName, phase)
	if weaveName ~= WEAVE or typeof(phase) ~= "string" then return end
	AnimationSignal:FireAllClients(weaveName, phase, player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	cooldownUntil[player] = nil
end)

---- SERVICES
--local Players = game:GetService("Players")
--local ReplicatedStorage = game:GetService("ReplicatedStorage")

---- MODULES
--local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))
--local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
--local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
--local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))

---- REMOTES
--local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
--local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
--local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
--local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")


--WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, charge: number, mouseTarget: Instance?, mousePos: Vector3?, Level)
--	if not player then return warn("Fireball didn't receive a player") end
--	if weaveName ~= "Fireball" then return end

--	-- Retrieve the required data from the dictionary
--	local weaveData = Dictionary[weaveName]
--	if not weaveData then return warn("Weave data not found for " .. weaveName) end

--	local DB_DURATION = weaveData.DebounceDuration
--	local DAMAGE = weaveData.Damage
--	local DOT = weaveData.DamageOverTime
--	local DURATION = weaveData.Duration
--	local PROJECTILE_SPEED = weaveData.ProjectileSpeed
--	local LIFETIME = weaveData.Lifetime
--	local AREA = weaveData.Area

--	-- Set up some references
--	local char: Model? = player and player.Character
--	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
--	local humRP = char and char:FindFirstChild("HumanoidRootPart")
--	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end

--	-- Handle Charge
--	if charge and charge > weaveData.MaxCharge then
--		charge = weaveData.MaxCharge
--	end

--	-- Recalculate important values here 
--	DOT = DOT + (DOT * (charge / 5))
--	DURATION = DURATION + (DURATION * (charge / 100))
--	LIFETIME = (LIFETIME + (Level / 50))
--	AREA = (AREA + ((Level * charge) / 50))
--	PROJECTILE_SPEED = (PROJECTILE_SPEED + ((Level * charge)) / 200)
--	local force = (charge * 100) + 2500
--	-- Fire the weaving event (The local scripts will assess via WeaveName whether they will process the weave)
--	WeavingEvent:FireAllClients(char, hum, humRP, weaveName, mousePos, DAMAGE, DURATION, charge, LIFETIME, AREA, PROJECTILE_SPEED, DOT, force)

--end)


--WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
--	if not player then return warn("Fireball fx didn't receive a player") end
--	if weaveName ~= "Fireball" then return end

--	-- Set up some references
--	local char: Model?= player and player.Character
--	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
--	local humRP = char and char:FindFirstChild("HumanoidRootPart")
--	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end

--	-- Retrieve the required data from the dictionary
--	local weaveData = Dictionary[weaveName]
--	if not weaveData then return warn("Weave data not found for " .. weaveName) end

--	-- Fire effects, effects are assessed via the weaveName
--	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
--end)

--WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
--	if not player then return warn("Fireball fx cleaner didn't receive a player") end
--	if weaveName ~= "Fireball" then return end

--	local UserId = player.UserId
--	WeavingFxClear:FireAllClients(UserId, weaveName)
--end)

--AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName: string, phase)
--	if not player then warn(`No player received in Animation Signal server`) return end
--	if not weaveName then warn(`No weaveName received in Animation Signal server`) return end

--	if weaveName ~= "Fireball" then return end

--	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- notifies a specific weave about an animation signal

--end)