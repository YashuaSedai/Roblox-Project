local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weaver = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("RoleGiver"):WaitForChild("Weaver")

Players.PlayerAdded:Connect(function(plr)
	Weaver.OnServerEvent:Connect(function(passedPlayer)
		if passedPlayer == plr then
			local char = plr.Character or plr.CharacterAdded:Wait()

			-- Set default attributes if they don't exist
			if not char:GetAttribute("Slot1") then
				char:SetAttribute("Slot1", "Default")
			end

			if not char:GetAttribute("Slot2") then
				char:SetAttribute("Slot2", "Default")
			end

			if not char:GetAttribute("Slot3") then
				char:SetAttribute("Slot3", "Default")
			end

			if not char:GetAttribute("Slot4") then
				char:SetAttribute("Slot4", "Default")
			end

			if not char:GetAttribute("Slot5") then
				char:SetAttribute("Slot5", "Default")
			end
			
			if not char:GetAttribute("IsWeaving") or char:GetAttribute("IsWeaving") == true then
				char:SetAttribute("IsWeaving", false)
			end
			
			if not char:GetAttribute("WeavingDB") or char:GetAttribute("WeavingDB") == true then
				char:SetAttribute("WeavingDB", false)
			end
		end
	end)
	plr.CharacterAdded:Connect(function(char)
		if char then
		plr:SetAttribute("Role", "Default")
			
			if not char:GetAttribute("GlobalCD") or char:GetAttribute("GlobalCD") == true then
				char:SetAttribute("GlobalCD", false)
			end

			if not char:GetAttribute("Shielded") or char:GetAttribute("Shielded") == true then
				char:SetAttribute("Shielded", false)
			end

			if not char:GetAttribute("ShieldApplication") or char:GetAttribute("ShieldApplication") == true then
				char:SetAttribute("ShieldApplication", false)
			end

			if not char:GetAttribute("Concealed") then
				char:SetAttribute("Concealed", false)
			end

			if not char:GetAttribute("Immobilized") then
				char:SetAttribute("Immobilized", false)
			end

			if not char:GetAttribute("Stunned") then
				char:SetAttribute("Stunned", false)
			end
			
			if not char:GetAttribute("Frozen") then
				char:SetAttribute("Frozen", false)
			end

			if not char:GetAttribute("Rooted") then
				char:SetAttribute("Rooted", false)
			end
			
			if not char:GetAttribute("KnockedBack") then
				char:SetAttribute("KnockedBack", false)
			end
			
			if not char:GetAttribute("Ragdolled") then
				char:SetAttribute("Ragdolled", false)
			end

			if not char:GetAttribute("Linked") and plr:GetAttribute("Role") == "Weaver" then
				char:SetAttribute("Linked", false)
			end

			if not char:GetAttribute("Rendered") then
				char:SetAttribute("Rendered", false)
			end
		end
		
	end)
end)