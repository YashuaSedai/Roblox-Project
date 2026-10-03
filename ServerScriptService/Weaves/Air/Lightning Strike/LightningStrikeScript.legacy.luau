-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- MODULES
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))
local RagdollService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("RagdollService"))

-- REMOTES
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

local sessions = {}
local cooldownUntil = {}
local castCounters = {}

local WEAVE = "LightningStrike"

local function getLevel(player)
	local stats = player:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	return level and level.Value or 1
end

local function cancelCast(player, char)
	if not sessions[player] then return end
	sessions[player] = nil

	cooldownUntil[player] = os.clock() + Dictionary[WEAVE].DebounceDuration -- delete this line if you don't want a cooldown on interruption

	-- reset the charging state the client would normally reset on release
	char:SetAttribute("Charging", false)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum:SetAttribute("Charge", 0) end

	WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- true = "cancelled", so clients end the visuals now
end

WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, _charge, _mouseTarget, mousePos, _level)
	if weaveName ~= "LightningStrike" then return end

	local session = sessions[player]
	if not session then return end
	sessions[player] = nil

	local weaveData = Dictionary[weaveName]
	if not weaveData then return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or char ~= session.char or not hum or not humRP or hum.Health <= 0 then return end
	if typeof(mousePos) ~= "Vector3" then return end
	
	if RagdollService.IsRagdolled(char) then return end

	cooldownUntil[player] = os.clock() + weaveData.DebounceDuration

	-- the server's own numbers
	local level = session.level
	local charge = math.clamp(session.charge, 1, weaveData.MaxCharge)
	local castRange = weaveData.CastRange + (level * charge / 10)
	local damage = weaveData.Damage + (level * charge) / 100   -- your formula (+0.05 at level 1, check that's intended)
	local area = weaveData.Area

	-- clamp the strike point to max range
	local offset = mousePos - humRP.Position
	if not (offset.Magnitude < math.huge) then return end
	if offset.Magnitude > castRange then
		mousePos = humRP.Position + offset.Unit * castRange
	end
	
	-- raycast to the ground
	local rayOrigin = mousePos
	local rayDirection = Vector3.new(0, -1000, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(mousePos + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), raycastParams)
	if result then
		mousePos = result.Position + Vector3.new(0, 1, 0)
	end

	-- clients only get the visuals
	WeavingEvent:FireAllClients(char, hum, humRP, weaveName, mousePos, damage, area, castRange, weaveData.MaxCharge)

	-- the server picks who gets hit, after the wind-up
	task.delay(0.25, function()
		for _, model in workspace:GetChildren() do
			local targetHum = model:IsA("Model") and model ~= char and model:FindFirstChildOfClass("Humanoid")
			local targetRoot = targetHum and model:FindFirstChild("HumanoidRootPart")
			if targetRoot and targetHum.Health > 0 and (targetRoot.Position - mousePos).Magnitude <= area then
				targetHum:TakeDamage(damage)
				targetHum:SetAttribute("LastAttacker", player.UserId)
				targetHum:SetAttribute("LastDamage", damage)
				if weaveData.RagdollDuration then
					RagdollService.Ragdoll(model, weaveData.RagdollDuration)
				end
			end
		end
	end)
end)


WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
	if weaveName ~= "LightningStrike" then return end

	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end
	if RagdollService.IsRagdolled(char) then return end

	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end
	
	local old = sessions[player]

	if old and old.char == char and os.clock() - old.startedAt < 30 then
		return
	end

	if os.clock() < (cooldownUntil[player] or 0) then
		return
	end
	
	if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
		return
	end
	
	castCounters[player] = (castCounters[player] or 0) + 1
	local castId = castCounters[player]
	
	local session = {
		startedAt = os.clock(),
		level = getLevel(player),
		char = char,
		charge = 0,          -- what the player has actually paid for
	}

	sessions[player] = session
	
	local chargeInterval = WeavingModule.ChargeInterval(session.level)

	task.spawn(function()
		while sessions[player] == session and hum.Health > 0 and session.charge < weaveData.MaxCharge do
			task.wait(chargeInterval)

			if sessions[player] ~= session then
				break
			end

			if not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
				break
			end

			session.charge += 1
		end
	end)
	

	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName, castId)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName, phase)
	if weaveName ~= WEAVE or typeof(phase) ~= "string" then return end
	AnimationSignal:FireAllClients(weaveName, phase, player.UserId)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	cooldownUntil[player] = nil
	castCounters[player] = nil
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if weaveName ~= WEAVE then return end
	WeavingFxClear:FireAllClients(player.UserId, weaveName)
end)

RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		cancelCast(player, char)
	end
end)