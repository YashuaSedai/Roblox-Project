local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weaver = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("RoleGiver"):WaitForChild("Weaver")
local Warder = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("RoleGiver"):WaitForChild("Warder")
local PlayClicked = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("Menu"):WaitForChild("RoleGiver"):WaitForChild("PlayClicked")

Weaver.OnServerEvent:Connect(function(plr)
	if plr then
		plr:SetAttribute("Role", "Weaver")
	end
end)

Warder.OnServerEvent:Connect(function(plr)
	if plr then
		plr:SetAttribute("Role", "Warder")
	end
end)

PlayClicked.OnServerEvent:Connect(function(plr)
	if plr:GetAttribute("Role") == "Weaver" then
		local char = plr.Character
		local TableOfScripts = {"ElementalSetting", "WeaverManual"}
		if char then
			local Weaver = char:FindFirstChild("Weaver")
			if Weaver then
				for _, scripts in pairs(Weaver:GetDescendants()) do
					if script:IsA("LocalScript") and table.find(TableOfScripts, script.Name) then
						script.Enabled = true
					end
				end
			end
		end
		
	elseif plr:GetAttribute("Role") == "Warder" then
		local char = plr.Character

		if char then
			for i = 1, 5 do
				local Slotname = "Slot"..i
				if Slotname then
					char:SetAttribute(Slotname, nil)
				end
			end

			local head = char:WaitForChild("Head")

			if head and head:FindFirstChild("SlotsUI") then
				local SlotsUI = head:FindFirstChild("SlotsUI")
				SlotsUI:Destroy()
				warn ("Slots were destroyed")
			end

			local Weaver = char:WaitForChild("Weaver")
			if Weaver then
				for _, scripts in pairs(Weaver:GetDescendants()) do
					if scripts:IsA("LocalScript") then
						scripts.Enabled = false
					end
				end
			end
		end
	end

end)