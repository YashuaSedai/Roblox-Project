-- SERVICE
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- VARIABLE
local StatsFolder = RS:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Stats"):WaitForChild("StatsBar")
local UpdateVisibility = RS:WaitForChild("SYSTEM"):WaitForChild("Attributes"):WaitForChild("Stats"):WaitForChild("UpdateVisibility")

UpdateVisibility.OnServerEvent:Connect(function(player)
	local char = player.Character
	local hum: Humanoid = char and char:WaitForChild("Humanoid")
	local head = char and char:WaitForChild("Head")
	
	local newStats = StatsFolder:Clone()
	newStats.Parent = head
	
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	
	if player:GetAttribute("Role") == nil or player:GetAttribute("Role") == "Default" then  return end

	if player and player:GetAttribute("Role") == "Weaver" then
		for _, billboard in newStats:GetChildren() do
			if billboard:IsA("BillboardGui") then
				billboard.Adornee = head
			end
		end
		
	end

	if player and player:GetAttribute("Role") == "Warder" then
		for _, billboard in newStats:GetChildren() do
			if billboard:IsA("BillboardGui") then
				billboard.Adornee = head

				if billboard.Name == "Source" then
					billboard:Destroy()
				end
			end
		end
	end

end)