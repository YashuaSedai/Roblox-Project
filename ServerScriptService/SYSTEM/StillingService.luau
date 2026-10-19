-- StillingService   (ModuleScript, SERVER ONLY)
-- Owns the STILLED state: a weaver stripped of the Power.
--
-- WHAT STILLED DOES
--   * player attribute  Stilled = true   (SourceSetup / BurnOutSetup / ElementAssignment / ShieldingScript read it)
--   * character attribute Stilled = true (re-applied on every respawn; the client reads it to block drawing)
--   * player attribute  StilledUntil = os.time() expiry (handy for a UI timer)
--   * MovementService status "Stilled": can't cast (this also means they can't START a shield or any weave)
--   * walk speed multiplied by STILLED_SPEED (a "Stilled" slow source in MovementService)
--   * draw slots wiped, drawn-element FX removed
--   * Source is held at 0 and Burn at 0 (SourceSetup / BurnOutSetup watch the Stilled player attribute). The values are
--     NOT destroyed, so the Source / Burn bars stay bound. When it expires Source comes back full.
--   * can't be shielded (ShieldingScript refuses a Stilled target at lock-on)
--
-- PERSISTENCE: the EXPIRY TIME (os.time() + 300) is saved in a DataStore, so the 5 minutes keep counting while the
--   player is offline and survive respawns / rejoins / server hops. (Studio needs "Enable Studio Access to API Services".)
--
-- API:  StillingService.Init()   StillingService.Apply(player, seconds?)   StillingService.Clear(player)
--       StillingService.IsStilled(playerOrCharacter)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Modules = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local MovementService = require(Modules:WaitForChild("MovementService"))
local Dictionary = require(Modules:WaitForChild("WeavingModule"):WaitForChild("Dictionary"))

local DEFAULT_SECONDS = 300
local STORE_NAME = "StillingData"
local SLOW_SOURCE = "Stilled"

local StillingService = {}

local store = nil
do
	local ok, result = pcall(function() return DataStoreService:GetDataStore(STORE_NAME) end)
	if ok then store = result else warn("[StillingService] DataStore unavailable: " .. tostring(result)) end
end

local token = {} -- [player] = number, so an old expiry timer can't clear a newer Stilled
local started = false

local function speedMult()
	local data = Dictionary.Stilling
	return data and data.StilledSpeedMult or 0.6
end

local function saveExpiry(player, expiry)
	if not store then return end
	task.spawn(function()
		local ok, err = pcall(function()
			if expiry then
				store:SetAsync(tostring(player.UserId), expiry)
			else
				store:RemoveAsync(tostring(player.UserId))
			end
		end)
		if not ok then warn("[StillingService] save failed: " .. tostring(err)) end
	end)
end

-- wipes the five draw slots exactly the way ElementAssignment does
local function clearSlots(player, char)
	for i = 1, 5 do
		char:SetAttribute("Slot" .. i, "Default")
	end
	char:SetAttribute("IsWeaving", false)
	local head = char:FindFirstChild("Head")
	local slotsUI = head and head:FindFirstChild("SlotsUI")
	local billboard = slotsUI and slotsUI:FindFirstChild("BillboardGui")
	if billboard then
		for i = 1, 5 do
			local slot = billboard:FindFirstChild("Slot" .. i)
			if slot then
				for _, icon in slot:GetChildren() do
					if icon:IsA("GuiObject") and icon.Name ~= "Default"
						and (icon.Name == "Fire" or icon.Name == "Water" or icon.Name == "Earth" or icon.Name == "Air" or icon.Name == "Spirit") then
						icon.Visible = false
					end
				end
			end
		end
	end
	local drawing = ReplicatedStorage:FindFirstChild("ElementalMixing")
	drawing = drawing and drawing:FindFirstChild("Drawing")
	local removeEvent = drawing and drawing:FindFirstChild("Remove")
	if removeEvent then removeEvent:FireAllClients(player.Name) end -- clears the drawn element FX
end

local function applyToCharacter(player, char)
	if not char or not char.Parent then return end
	char:SetAttribute("Stilled", true)
	clearSlots(player, char)
	MovementService.SetSlow(char, SLOW_SOURCE, speedMult())
end

local function expire(player, myToken)
	if token[player] ~= myToken then return end
	StillingService.Clear(player)
end

function StillingService.IsStilled(subject)
	if typeof(subject) ~= "Instance" then return false end
	if subject:IsA("Player") then
		return subject:GetAttribute("Stilled") == true
	end
	return subject:GetAttribute("Stilled") == true
end

-- strips a player. seconds = how long from now (default 300). Also used when loading a saved expiry.
function StillingService.Apply(player: Player, seconds: number?, absoluteExpiry: number?)
	if not player or not player.Parent then return end
	local expiry = absoluteExpiry or (os.time() + (seconds or DEFAULT_SECONDS))
	local remaining = expiry - os.time()
	if remaining <= 0 then return end

	token[player] = (token[player] or 0) + 1
	local myToken = token[player]

	player:SetAttribute("StilledUntil", expiry)
	player:SetAttribute("Stilled", true) -- SourceSetup / BurnOutSetup react to this
	if not absoluteExpiry then saveExpiry(player, expiry) end

	applyToCharacter(player, player.Character)

	task.delay(remaining, function() expire(player, myToken) end)
end

function StillingService.Clear(player: Player)
	if not player then return end
	token[player] = (token[player] or 0) + 1 -- cancels any running expiry timer
	player:SetAttribute("Stilled", nil)
	player:SetAttribute("StilledUntil", nil)
	local char = player.Character
	if char then
		char:SetAttribute("Stilled", nil)
		MovementService.ClearSlow(char, SLOW_SOURCE)
	end
	if player.Parent then saveExpiry(player, nil) end
end

local function load(player)
	if not store then return end
	local ok, expiry = pcall(function() return store:GetAsync(tostring(player.UserId)) end)
	if not ok then
		warn("[StillingService] load failed: " .. tostring(expiry))
		return
	end
	if typeof(expiry) == "number" and expiry > os.time() then
		StillingService.Apply(player, nil, expiry)
	elseif expiry ~= nil then
		saveExpiry(player, nil) -- it ran out while they were away
	end
end

local function watch(player)
	player.CharacterAdded:Connect(function(char)
		if player:GetAttribute("Stilled") == true then
			char:WaitForChild("Humanoid", 10)
			applyToCharacter(player, char) -- still Stilled after a respawn
		end
	end)
	task.spawn(load, player)
end

function StillingService.Init()
	if started then return end
	started = true
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		task.spawn(watch, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		token[player] = nil -- the expiry timestamp is already saved; it keeps counting while they're offline
	end)
end

return StillingService
