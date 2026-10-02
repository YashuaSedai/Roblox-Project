-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- GENERIC
local Assets = ReplicatedStorage:WaitForChild("Assets")
local Elements = Assets:WaitForChild("Elements")
local SlotsUI = Elements:WaitForChild("SlotsUI")
local Sounds = Elements:WaitForChild("Sounds")
local Weaver = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("RoleGiver"):WaitForChild("Weaver")

Weaver.OnServerEvent:Connect(function(player)
	if player then
		local char = player.Character
		if char then
			local Head = char:WaitForChild("Head")
			local HumanoidRootPart = char:WaitForChild("HumanoidRootPart")

			if Head and not Head:FindFirstChild("SlotsUI") then
				local newSlot = SlotsUI:Clone()
				newSlot.Parent = Head
				for _, gui in pairs(newSlot:GetChildren()) do
					if gui:IsA("BillboardGui") then
						gui.Adornee = Head 
					end
				end
			end

			if HumanoidRootPart then
				local newSounds = Sounds:Clone()
				newSounds.Parent = HumanoidRootPart
			end
		end
	end
end)
		