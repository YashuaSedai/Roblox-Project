-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- GENERIC
local SYSTEM = ReplicatedStorage:WaitForChild("SYSTEM")
local Menu = SYSTEM:WaitForChild("Menu")
local RigFolder = Menu:WaitForChild("Rig")
local CloneRig = RigFolder:WaitForChild("CloneRig")
local ChangePos = RigFolder:WaitForChild("ChangePos")

-- workspace.Menu.TemporarySpawn is optional: a map without it must not freeze this script (it used to WaitForChild forever,
-- so no player ever got the rig or the teleport)
local function getTemporarySpawn()
	local menu = workspace:WaitForChild("Menu", 5)
	return menu and menu:WaitForChild("TemporarySpawn", 5)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid") -- Wait for Humanoid to load as a key indicator
		local HumanoidRP = char:WaitForChild("HumanoidRootPart") -- Critical part of the rig

		CloneRig:FireClient(player)
		local temporarySpawn = getTemporarySpawn()
		if temporarySpawn then
			HumanoidRP.CFrame = temporarySpawn.CFrame * CFrame.new(0,10,0)
		else
			warn("RigHandler: workspace.Menu.TemporarySpawn not found, the player stays where they spawned")
		end
	end)
end)

-- RETIRED: ChangePos used to teleport whoever fired it to the spawn, which any exploiter could do at any time.
-- The spawn now happens on the server inside RoleGiver (PlayClicked). The remote is kept so an old client script
-- that still fires it doesn't error, but it deliberately does nothing.
ChangePos.OnServerEvent:Connect(function() end)