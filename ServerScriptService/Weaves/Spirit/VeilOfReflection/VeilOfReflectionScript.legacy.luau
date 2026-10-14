-- ServerScriptService > Weaves > Spirit > VeilOfReflection > VeilOfReflectionScript   (Script)
-- Replaces the whole old file.
--
-- The barrier is a real object that the SERVER builds, moves, heals and breaks. It replicates to every
-- client (with its particles and sounds), so no client script is needed. That also means the server can
-- finally SEE it, so projectiles can bounce off it (see ProjectileService.RegisterBarrier).
--
-- Flow (same shape as TelekineticCrash):
--   press E      -> WeavingFxEvent             -> session starts, the barrier appears after ReadyTime
--   release E    -> WeavingInstantReleaseEvent -> barrier breaks, cooldown starts
--   Health <= 0  -> barrier breaks by itself
--
-- SMOOTHNESS: the server does NOT use physics for the barrier (no AlignPosition). The barrier is anchored and
-- the server just places it where the caster is, so hit detection stays server-side. The barrier is only
-- replicated ~20 times a second, which looks choppy when you turn, so every CLIENT re-poses it locally every
-- frame from the caster's own (smooth) character. That is VeilOfReflectionFollow (LocalScript) - it needs the
-- tag this script puts on the barrier, and its HOLD_OFFSET / FACING must match the ones below.
--
-- Dictionary (VeilOfReflection) extra fields:  ReadyTime = 1.2,  MaxHold = 60,  FizzleCooldown = 1
-- (ReadyTime = when the Channel animation's "Signal" marker fires, minus a little slack)

-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- MODULES
local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local WeavingFolder = Modules:WaitForChild("WeavingModule")
local WeavingModule = require(WeavingFolder:WaitForChild("WeavingModule"))
local Dictionary = require(WeavingFolder:WaitForChild("Dictionary"))
local Effects = require(Modules:WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local RagdollService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("RagdollService"))
local MovementService = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("MovementService"))
local ProjectileService = require(ServerScriptService:WaitForChild("SYSTEM"):WaitForChild("ProjectileService"))

-- REMOTES
local WeavingFxEvent = WeavingFolder:WaitForChild("WeavingFxEvent")
local WeavingFxClear = WeavingFolder:WaitForChild("WeavingFxClear")
local WeavingInstantReleaseEvent = WeavingFolder:WaitForChild("WeavingInstantReleaseEvent")
local AnimationSignal = Modules:WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- ASSET (a Model whose main part is called VeilOfReflectionEffect)
local AssetFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("VeilOfReflection")
local Template = AssetFolder:FindFirstChild("VeilOfReflection") or AssetFolder:WaitForChild("VeilofReflection")

local WEAVE = "VeilOfReflection"
local BARRIER_TAG = "VeilOfReflectionBarrier" -- the client follow script finds barriers by this tag
local DEFAULT_READY_TIME = 1.2
local DEFAULT_MAX_HOLD = 60
local HOLD_OFFSET = CFrame.new(0, 1.5, -4)         -- where the barrier floats, relative to the caster
local FACING = CFrame.Angles(0, math.rad(90), 0)   -- the asset faces sideways, so turn it to face forward

-- SIZE: the barrier is 1x at 50 Health and gains GROWTH_PER_HEALTH for every point of Health above that
-- (0.005 = the old client version: 200 Health -> 1.75x). Raise it to make the growth easier to see.
local GROWTH_BASE_HEALTH = 50
local GROWTH_PER_HEALTH = 0.005
local GROWTH_STEP = 0.005 -- only rescale when the size changed by at least this much

-- STATE THE SERVER OWNS
local sessions = {}      -- [player] = { startedAt, level, char, barrier = {...} or nil, diedConn }
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

local function getBarrierFolder()
	local barriers = workspace:FindFirstChild("Barriers")
	if not barriers then
		barriers = Instance.new("Folder")
		barriers.Name = "Barriers"
		barriers.Parent = workspace
	end
	local folder = barriers:FindFirstChild("VeilOfReflection")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "VeilOfReflection"
		folder.Parent = barriers
	end
	return folder
end

local function getNumberValue(part, name)
	local value = part:FindFirstChild(name)
	if value and not value:IsA("NumberValue") then
		value:Destroy() -- e.g. an IntValue would round every small regen tick away
		value = nil
	end
	if not value then
		value = Instance.new("NumberValue")
		value.Name = name
		value.Parent = part
	end
	return value
end

-- THE BARRIER BREAKS: stop it, fade it, remove it
local function breakBarrier(session)
	local barrier = session.barrier
	if not barrier then return end
	session.barrier = nil

	if barrier.followConnection then barrier.followConnection:Disconnect() end
	if barrier.healthConnection then barrier.healthConnection:Disconnect() end

	local part = barrier.part
	ProjectileService.UnregisterBarrier(part)

	barrier.model:SetAttribute("Broken", true) -- clients stop re-posing it; it stays where it broke
	part.CanQuery = false

	local died = part:FindFirstChild("Died")
	if died and died:IsA("Sound") then died:Play() end

	for _, descendant in part:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
			Effects.NumberValueTweenObj(descendant, "ParticleEmitter", "Transparency", 0, 0.5, 1, 20)
		elseif descendant:IsA("Beam") then
			Effects.NumberValueTweenObj(descendant, "Beam", "Transparency", 0, 0.5, 1, 20)
		end
	end

	task.delay(2, function()
		barrier.model:Destroy()
	end)
end

-- THE CAST ENDS (release, death, ragdoll, leaving, or the barrier ran out of health)
local function finish(player, session, cooldown, tellClients)
	if sessions[player] ~= session then return end
	sessions[player] = nil

	cooldownUntil[player] = os.clock() + cooldown
	if session.diedConnection then session.diedConnection:Disconnect() end
	breakBarrier(session)

	if tellClients then
		WeavingFxClear:FireAllClients(player.UserId, WEAVE, true) -- ends the caster's hand effects
	end
	WeavingInstantReleaseEvent:FireAllClients(player.UserId, WEAVE)
end

-- THE BARRIER APPEARS (ReadyTime after the press, if the caster is still holding)
local function createBarrier(player, session)
	local weaveData = Dictionary[WEAVE]
	local char, _, humRP = getAlive(player)
	if not char or char ~= session.char or (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	-- the server's own numbers, never the client's
	local level = session.level
	local health = weaveData.Health + (level * 0.01)
	local maxHealth = weaveData.MaxHealth + level
	local regen = weaveData.RegenRate + (level * 0.01)
	local interval = weaveData.Interval or 0.1

	local model = Template:Clone()
	model.Name = "VeilOfReflection_" .. player.UserId

	local part = model:FindFirstChild("VeilOfReflectionEffect", true)
	if not part then
		model:Destroy()
		warn("[VeilOfReflection] the asset has no part called VeilOfReflectionEffect")
		return
	end

	-- placed where it belongs BEFORE it enters the world, so it never "flies in"
	local hold = humRP.CFrame * HOLD_OFFSET * FACING
	model:PivotTo(hold)

	-- only the main part can be hit, so every hit lands on the part that has Health and Owner.
	-- Everything is anchored: the barrier is moved by hand, not by physics.
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = (descendant == part)
		elseif descendant:IsA("AlignPosition") or descendant:IsA("AlignOrientation") or descendant:IsA("LinearVelocity") then
			descendant:Destroy() -- leftovers from the old physics version would fight the placement
		end
	end
	part:SetAttribute("Owner", player.Name)
	model:SetAttribute("Owner", player.Name)

	local healthValue = getNumberValue(part, "Health")
	local maxHealthValue = getNumberValue(part, "MaxHealth")
	maxHealthValue.Value = maxHealth
	healthValue.Value = health

	-- the real numbers live in the NumberValues "Health" / "MaxHealth" inside the barrier part.
	-- They are mirrored onto attributes as well, so the live values also show in the Attributes section.
	part:SetAttribute("MaxHealth", maxHealth)
	part:SetAttribute("Health", health)

	-- start at the size that matches the starting Health
	local baseScale = model:GetScale()
	local startScale = 1 + math.max(0, health - GROWTH_BASE_HEALTH) * GROWTH_PER_HEALTH
	model:ScaleTo(baseScale * startScale)

	local attachment = part:FindFirstChild("Effects1")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "Effects1"
		attachment.Parent = part
	end

	CollectionService:AddTag(model, BARRIER_TAG)
	model.Parent = getBarrierFolder()

	local barrier = {
		model = model, part = part, health = healthValue,
	}
	session.barrier = barrier
	ProjectileService.RegisterBarrier(part)

	-- the SERVER copy keeps following the caster so hit detection is right.
	-- (clients re-pose it themselves every frame for smoothness: VeilOfReflectionFollow)
	local lastPlaced = hold
	barrier.followConnection = RunService.Heartbeat:Connect(function()
		local c, _, root = getAlive(player)
		if not c or c ~= session.char then return end -- finish() deals with death; just stop updating
		local target = root.CFrame * HOLD_OFFSET * FACING
		if (target.Position - lastPlaced.Position).Magnitude > 0.02 or target.LookVector:Dot(lastPlaced.LookVector) < 0.99995 then
			lastPlaced = target
			model:PivotTo(target)
		end
	end)

	-- regenerate health
	task.spawn(function()
		while session.barrier == barrier do
			if healthValue.Value < maxHealthValue.Value then
				healthValue.Value = math.min(healthValue.Value + regen, maxHealthValue.Value)
			end
			task.wait(interval)
		end
	end)

	-- react to health changes: break at 0, grow with health, flash when hit
	local lastHealth = healthValue.Value
	local lastScale = startScale
	barrier.healthConnection = healthValue.Changed:Connect(function(value)
		if session.barrier ~= barrier then return end
		part:SetAttribute("Health", value)

		if value <= 0 then
			finish(player, session, weaveData.DebounceDuration, true)
			return
		end

		local scale = 1 + (math.max(0, value - GROWTH_BASE_HEALTH) * GROWTH_PER_HEALTH)
		if math.abs(scale - lastScale) >= GROWTH_STEP then -- not on every tiny regen tick
			lastScale = scale
			model:ScaleTo(baseScale * scale)
		end

		if value < lastHealth then
			local emitter = attachment:FindFirstChild("Emitter")
			if emitter then emitter:Emit(1) end

			local hit = part:FindFirstChild("Hit")
			if hit and hit:IsA("Sound") then
				local pitch = hit:FindFirstChildOfClass("PitchShiftSoundEffect")
				if pitch then pitch.Octave = 0.75 + math.random() * 0.5 end
				hit:Play()
			end
		end
		lastHealth = value
	end)
end

-- a caster who gets ragdolled loses the cast
RagdollService.Ragdolled:Connect(function(char)
	local player = Players:GetPlayerFromCharacter(char)
	local session = player and sessions[player]
	if session then
		finish(player, session, Dictionary[WEAVE].DebounceDuration, true)
	end
end)

-- START OF CAST (client fires this when E is pressed)
WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local weaveData = Dictionary[WEAVE]
	if not weaveData then return end

	local char, hum, humRP = getAlive(player)
	if not char then return end
	if (RagdollService.IsRagdolled(char) or not MovementService.CanCast(char)) then return end

	local maxHold = weaveData.MaxHold or DEFAULT_MAX_HOLD
	local old = sessions[player]
	if old and old.char == char and os.clock() - old.startedAt < maxHold + 5 then return end -- already casting
	if os.clock() < (cooldownUntil[player] or 0) then return end                             -- on cooldown

	if (weaveData.SourceCost or 0) > 0 and not WeavingModule.DeductSource(player, hum, weaveData.SourceCost) then
		return
	end

	local session = { startedAt = os.clock(), level = getLevel(player), char = char }
	sessions[player] = session

	session.diedConnection = hum.Died:Connect(function()
		finish(player, session, weaveData.DebounceDuration, true)
	end)

	-- keep draining Source while E is held: SourceCost every Interval (the Dictionary has Charging = true, Interval = 0.1).
	-- Out of Source = the barrier breaks.
	local interval = weaveData.Interval
	if weaveData.Charging and interval and interval > 0 and (weaveData.SourceCost or 0) > 0 then
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

	-- the barrier appears once the spell is ready
	task.delay(weaveData.ReadyTime or DEFAULT_READY_TIME, function()
		if sessions[player] == session and not session.barrier then
			createBarrier(player, session)
		end
	end)

	-- nobody holds it forever
	task.delay(maxHold, function()
		finish(player, session, weaveData.DebounceDuration, true)
	end)

	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)

-- RELEASE (client fires this when E is released)
WeavingInstantReleaseEvent.OnServerEvent:Connect(function(player: Player, weaveName)
	if weaveName ~= WEAVE then return end

	local session = sessions[player]
	if not session then return end

	local weaveData = Dictionary[WEAVE]
	if session.barrier then
		finish(player, session, weaveData.DebounceDuration, false)       -- normal end
	else
		finish(player, session, weaveData.FizzleCooldown or 1, false)    -- released before it was ready
	end
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
	local session = sessions[player]
	if session then
		finish(player, session, 0, false)
	end
	sessions[player] = nil
	cooldownUntil[player] = nil
end)
