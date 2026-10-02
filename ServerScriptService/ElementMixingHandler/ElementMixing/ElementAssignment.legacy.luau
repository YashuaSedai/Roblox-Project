-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local Assign = ElementalMixing:WaitForChild("Assign")

Assign.OnServerEvent:Connect(function(plr, SlotName, Element)
	if plr then
		local Character = plr.Character
		
		if Character then
			if SlotName and Element then
				Character:SetAttribute(SlotName, Element)
			end
			
			local Head = Character:FindFirstChild("Head")
			
			if Head then
				local SlotsUI = Head:FindFirstChild("SlotsUI")
				
				if SlotsUI then
					
					if Element ~= "Default" then
						local MatchingSlot = SlotsUI:FindFirstChild("BillboardGui"):FindFirstChild(SlotName)
						local MatchingElement = MatchingSlot:FindFirstChild(Element)

						for _, element in pairs(MatchingSlot:GetChildren()) do

							if element.Name == "Fire"
								or element.Name == "Water"
								or element.Name == "Earth"
								or element.Name == "Air"
								or element.Name == "Spirit" then
								element.Visible = false
							end

						end

						MatchingElement.Visible = true
						
					else
				
						local MatchingSlot = SlotsUI:FindFirstChild("BillboardGui"):FindFirstChild(SlotName)
						local MatchingElement = MatchingSlot:FindFirstChild(Element)

						for _, element in pairs(MatchingSlot:GetChildren()) do

							if element.Name == "Fire"
								or element.Name == "Water"
								or element.Name == "Earth"
								or element.Name == "Air"
								or element.Name == "Spirit" then
								element.Visible = false
							end

						end
					end
					
				end
			end
		end
	end
end)