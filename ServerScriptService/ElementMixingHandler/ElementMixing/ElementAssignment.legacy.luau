local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assign = ReplicatedStorage:WaitForChild("ElementalMixing"):WaitForChild("Assign")

local ELEMENTS = { Fire = true, Water = true, Earth = true, Air = true, Spirit = true, Default = true }
local SLOTS = { Slot1 = true, Slot2 = true, Slot3 = true, Slot4 = true, Slot5 = true }

Assign.OnServerEvent:Connect(function(plr, SlotName, Element)
	if typeof(SlotName) ~= "string" or not SLOTS[SlotName] then return end
	if typeof(Element) ~= "string" or not ELEMENTS[Element] then return end

	local Character = plr.Character
	if not Character then return end

	-- held by a Stilling, or Stilled: they can't draw (clearing a slot is still allowed)
	if Element ~= "Default" and (Character:GetAttribute("Stilling") or Character:GetAttribute("Stilled") or plr:GetAttribute("Stilled")) then return end

	Character:SetAttribute(SlotName, Element)

	local Head = Character:FindFirstChild("Head")
	local SlotsUI = Head and Head:FindFirstChild("SlotsUI")
	local Billboard = SlotsUI and SlotsUI:FindFirstChild("BillboardGui")
	local MatchingSlot = Billboard and Billboard:FindFirstChild(SlotName)
	if not MatchingSlot then return end

	-- hide every element icon in the slot, then show the chosen one
	for _, icon in MatchingSlot:GetChildren() do
		if icon:IsA("GuiObject") and ELEMENTS[icon.Name] and icon.Name ~= "Default" then
			icon.Visible = false
		end
	end
	if Element ~= "Default" then
		local chosen = MatchingSlot:FindFirstChild(Element)
		if chosen then chosen.Visible = true end
	end
end)