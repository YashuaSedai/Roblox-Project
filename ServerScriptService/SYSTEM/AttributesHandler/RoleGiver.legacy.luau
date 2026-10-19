local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- WHICH ROLES CAN BE PICKED. Warder is switched off for now (the menu button says COMING SOON).
-- The SERVER enforces this, so a client that still fires the Warder remote gets nothing. Set it to true to turn the role back on.
local ROLE_ENABLED = { Weaver = true, Warder = false }

-- WHERE PLAY SENDS YOU. Tag any part with "GameSpawn" (CollectionService) to make it a spawn point, one is picked at random.
-- Without any tagged part it falls back to workspace.SpawnLocation, so the same scripts work on a map-less test place.
local SPAWN_TAG = "GameSpawn"
local function pickSpawn(): BasePart?
	local tagged = CollectionService:GetTagged(SPAWN_TAG)
	if #tagged > 0 then
		return tagged[math.random(1, #tagged)]
	end
	return workspace:FindFirstChild("SpawnLocation")
end

local RoleGiver = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("RoleGiver")
local Weaver = RoleGiver:WaitForChild("Weaver")
local Warder = RoleGiver:WaitForChild("Warder")
local PlayClicked = RoleGiver:WaitForChild("PlayClicked")

local TableOfScripts = { "ElementalSetting", "WeaverManual" }
local locked = {} -- [player] = true once Play was clicked this life: the role can't change anymore

local function hook(plr)
	plr.CharacterAdded:Connect(function() locked[plr] = nil end)
end
Players.PlayerAdded:Connect(hook)
for _, plr in Players:GetPlayers() do hook(plr) end
Players.PlayerRemoving:Connect(function(plr) locked[plr] = nil end)

Weaver.OnServerEvent:Connect(function(plr)
	if locked[plr] or not ROLE_ENABLED.Weaver then return end
	plr:SetAttribute("Role", "Weaver")
end)

Warder.OnServerEvent:Connect(function(plr)
	if locked[plr] or not ROLE_ENABLED.Warder then return end -- COMING SOON
	plr:SetAttribute("Role", "Warder")
end)

PlayClicked.OnServerEvent:Connect(function(plr)
	if locked[plr] then return end
	local role = plr:GetAttribute("Role")
	if not ROLE_ENABLED[role] then return end -- no role picked yet, or a role that is switched off
	locked[plr] = true

	local char = plr.Character
	if not char then return end

	-- THE SPAWN IS DONE HERE, BY THE SERVER, ONCE PER LIFE. It used to be a separate "ChangePos" remote that teleported
	-- whoever fired it, whenever they fired it (any client could teleport itself to the spawn in the middle of a fight).
	-- Now the only way to get moved is a valid Play click: a role is picked and `locked` is still false for this life.
	local spawnPart = pickSpawn()
	if spawnPart then
		char:PivotTo(spawnPart.CFrame * CFrame.new(0, 5, 0))
	else
		warn("RoleGiver: no spawn found (tag a part \"" .. SPAWN_TAG .. "\" or add workspace.SpawnLocation)")
	end

	-- spawn protection ends when you start playing
	local ff = char:FindFirstChildOfClass("ForceField")
	if ff then ff:Destroy() end

	local weaverFolder = char:WaitForChild("Weaver", 5)
	if role == "Weaver" then
		if weaverFolder then
			for _, scripts in weaverFolder:GetDescendants() do
				if scripts:IsA("LocalScript") and table.find(TableOfScripts, scripts.Name) then
					scripts.Enabled = true
				end
			end
		end
	else -- Warder
		for i = 1, 5 do
			char:SetAttribute("Slot" .. i, nil)
		end
		local head = char:WaitForChild("Head", 5)
		local slotsUI = head and head:FindFirstChild("SlotsUI")
		if slotsUI then slotsUI:Destroy() end
		if weaverFolder then
			for _, scripts in weaverFolder:GetDescendants() do
				if scripts:IsA("LocalScript") then scripts.Enabled = false end
			end
		end
	end
end)