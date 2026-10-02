-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Utilities = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		local hum: Humanoid = char:WaitForChild("Humanoid")

		-- Create attributes if not already set
		if not player:GetAttribute("Role") then
			player:SetAttribute("Role", "Default")
		end
		
		local leaderstats = player:WaitForChild("leaderstats")
		local level = leaderstats:WaitForChild("Level")
		local multiplier = 4

		-- Create MaxSource and Source values
		local maxSource = hum:FindFirstChild("MaxSource") or Instance.new("NumberValue")
		maxSource.Name = "MaxSource"
		maxSource.Parent = hum
		maxSource.Value = 100 + (level.Value * multiplier)

		local source = hum:FindFirstChild("Source") or Instance.new("NumberValue")
		source.Name = "Source"
		source.Parent = hum
		source.Value = maxSource.Value

		-- Define the regeneration rate
		local sourceRegen = 1 + ((multiplier/1000) * level.Value)

		-- Function to clean up source-related logic
		local function CleanupSource()
			if hum:FindFirstChild("MaxSource") then
				hum.MaxSource:Destroy()
			end
			if hum:FindFirstChild("Source") then
				hum.Source:Destroy()
			end
		end

		-- Function to set up source-related logic
		local function SetupSource()
			if not hum:FindFirstChild("MaxSource") then
				local newMaxSource = Instance.new("NumberValue")
				newMaxSource.Name = "MaxSource"
				newMaxSource.Parent = hum
				newMaxSource.Value = 100
			end
			if not hum:FindFirstChild("Source") then
				local newSource = Instance.new("NumberValue")
				newSource.Name = "Source"
				newSource.Parent = hum
				newSource.Value = hum.MaxSource.Value
			end

			-- Regenerate source logic
			if source and maxSource then
				task.spawn(function()
					while hum.Parent and hum:FindFirstChild("Source") and hum:FindFirstChild("MaxSource") do
						if source.Value > maxSource.Value then
							source.Value = maxSource.Value
						end

						-- Regenerate source if below max and passes the Checker
						if source.Value < maxSource.Value and not char:GetAttribute("GlobalCD") 
							and not char:GetAttribute("Shielded") 
							and not char:GetAttribute("ShieldApplication") then
							source.Value = math.min(source.Value + sourceRegen, maxSource.Value)
						end

						task.wait(0.1)
					end
				end)
			end
		end

		-- Listen for changes to the "Role" attribute
		player:GetAttributeChangedSignal("Role"):Connect(function()
			local role = player:GetAttribute("Role")
			if role == "Weaver" then
				SetupSource()
			elseif role == "Warder" then
				CleanupSource()
			end
		end)

		-- Initial role setup
		if player:GetAttribute("Role") == "Weaver" then
			SetupSource()
		elseif player:GetAttribute("Role") == "Warder" then
			CleanupSource()
		end
	end)
end)
