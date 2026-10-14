-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULES
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))

-- REMOTES
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

WeavingEvent.OnServerEvent:Connect(function(player: Player, weaveName, charge: number, mouseTarget: Instance?, mousePos: Vector3?, Level)
	if not player then return warn("Frostbound didn't receive a player") end
	if weaveName ~= "Frostbound" then return end

	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end
	
	local DB_DURATION = weaveData.DebounceDuration
	local DAMAGE = weaveData.Damage
	local DURATION = weaveData.Duration
	local PROJECTILE_SPEED = weaveData.ProjectileSpeed
	local LIFETIME = weaveData.Lifetime
	local AREA = weaveData.Area
	
	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end

	-- Handle Charge
	if charge > weaveData.MaxCharge then
		charge = weaveData.MaxCharge
	end
	
	-- Recalculate important values here 
	DURATION = (DURATION + (charge / 75)) 
	LIFETIME = (LIFETIME + (Level / 50))
	AREA = AREA + ((Level * charge) / 100)
	DAMAGE = DAMAGE + ((Level * charge)/ 150)
	PROJECTILE_SPEED = (PROJECTILE_SPEED + ((Level * charge)) / 200)
	
	-- Fire the weaving event (The local scripts will assess via WeaveName whether they will process the weave)
	WeavingEvent:FireAllClients(char, hum, humRP, weaveName, mousePos, DAMAGE, DURATION, charge, LIFETIME, AREA, PROJECTILE_SPEED)
	
end)


WeavingFxEvent.OnServerEvent:Connect(function(player: Player, weaveName, mousePos: Vector3?, level)
	if not player then return warn("Frostbound fx didn't receive a player") end
	if weaveName ~= "Frostbound" then return end

	-- Set up some references
	local char: Model?= player and player.Character
	local hum: Humanoid = char and char:FindFirstChild("Humanoid")
	local humRP = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or not humRP then return warn("Cannot find Char or Hum") end
	
	-- Retrieve the required data from the dictionary
	local weaveData = Dictionary[weaveName]
	if not weaveData then return warn("Weave data not found for " .. weaveName) end

	-- Fire effects, effects are assessed via the weaveName
	WeavingFxEvent:FireAllClients(char, hum, humRP, weaveName)
end)

WeavingFxClear.OnServerEvent:Connect(function(player, weaveName)
	if not player then return warn("Frostbound fx cleaner didn't receive a player") end
	if weaveName ~= "Frostbound" then return end

	local UserId = player.UserId
	WeavingFxClear:FireAllClients(UserId, weaveName)
end)

AnimationSignal.OnServerEvent:Connect(function(player: Player, weaveName: string, phase)
	if not player then warn(`No player received in Animation Signal server`) return end
	if not weaveName then warn(`No weaveName received in Animation Signal server`) return end
	
	if weaveName ~= "Frostbound" then return end
	
	AnimationSignal:FireAllClients(weaveName, phase, player.UserId) -- notifies a specific weave about an animation signal
	
end)