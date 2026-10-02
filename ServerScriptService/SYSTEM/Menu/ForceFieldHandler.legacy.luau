-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- GENERIC
local Remove = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("ForceField"):WaitForChild("Remove")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		if char then
			local FF = Instance.new("ForceField")
			FF.Visible = false
			FF.Parent = char
		end
	end)
end)

Remove.OnServerEvent:Connect(function(plr)
	if plr then
		local char = plr.Character
		
		if char then
			local FF = char:FindFirstChildOfClass("ForceField")
			if FF then
				FF:Destroy()
			end
		end
	end
end)


	