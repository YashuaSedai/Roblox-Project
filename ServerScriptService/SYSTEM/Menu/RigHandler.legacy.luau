-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- GENERIC
local SYSTEM = ReplicatedStorage:WaitForChild("SYSTEM")
local Menu = SYSTEM:WaitForChild("Menu")
local RigFolder = Menu:WaitForChild("Rig")
local CloneRig = RigFolder:WaitForChild("CloneRig")
local ChangePos = RigFolder:WaitForChild("ChangePos")
local TemporarySpawn = workspace:WaitForChild("Menu"):WaitForChild("TemporarySpawn")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid") -- Wait for Humanoid to load as a key indicator
		local HumanoidRP = char:WaitForChild("HumanoidRootPart") -- Critical part of the rig

		CloneRig:FireClient(player)
		HumanoidRP.CFrame = TemporarySpawn.CFrame * CFrame.new(0,10,0)
	end)
end)

ChangePos.OnServerEvent:Connect(function(player)
	if player and player.Character then
		local HumanoidRP = player.Character:WaitForChild("HumanoidRootPart")
		
		HumanoidRP.CFrame = game.Workspace:WaitForChild("SpawnLocation").CFrame * CFrame.new(0, 5, 0)
	end
end)