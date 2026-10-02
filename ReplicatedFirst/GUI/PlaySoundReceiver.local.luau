-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- VARIABLES
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local PlaySoundRemote = RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("PlaySound")

-- Function to recursively search for a sound inside PlayerGui
local function FindSound(parent, soundName)
	for _, child in pairs(parent:GetChildren()) do
		if child:IsA("Sound") and child.Name == soundName then
			return child
		elseif child:IsA("Folder") or child:IsA("ScreenGui") or child:IsA("Frame") then
			local found = FindSound(child, soundName)
			if found then
				return found
			end
		end
	end
	return nil
end

PlaySoundRemote.OnClientEvent:Connect(function(soundName)
	if soundName then
		local sound = FindSound(PlayerGui, soundName)
		if sound then
			task.spawn(function()
				sound:Play()
			end)
		else
			warn("Sound not found in PlayerGui: " .. soundName)
		end
	end
end)
