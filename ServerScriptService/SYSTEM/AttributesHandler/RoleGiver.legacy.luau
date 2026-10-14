local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	if locked[plr] then return end
	plr:SetAttribute("Role", "Weaver")
end)

Warder.OnServerEvent:Connect(function(plr)
	if locked[plr] then return end
	plr:SetAttribute("Role", "Warder")
end)

PlayClicked.OnServerEvent:Connect(function(plr)
	if locked[plr] then return end
	local role = plr:GetAttribute("Role")
	if role ~= "Weaver" and role ~= "Warder" then return end
	locked[plr] = true

	local char = plr.Character
	if not char then return end

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