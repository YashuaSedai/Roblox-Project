-- SERVICES
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- LISTENS FOR THE PLAYER JOINING
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local humanoid = char:WaitForChild("Humanoid")
		local leaderstats = player:WaitForChild("leaderstats")
		local level = leaderstats:WaitForChild("Level")
		
		local function SetPlayerStats()
			-- Set PlayerHealth and PlayerSource

			local multiplier = 2.5
			humanoid.MaxHealth = humanoid.MaxHealth + (level.Value * multiplier)
			
			humanoid.Health = humanoid.MaxHealth
		end

		level.Changed:Connect(function()
			SetPlayerStats()
		end)
		
		SetPlayerStats()
	end)
end)
