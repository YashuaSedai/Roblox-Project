-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULE
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))

-- GENERIC
local ChargeEvent = ReplicatedStorage:WaitForChild("ElementalMixing"):WaitForChild("Charging"):WaitForChild("Charge")

--ChargeEvent.OnServerEvent:Connect(function(player: Player, boolean, max, level)
	
--	local char: Model? = player and player.Character
--	local hum: Humanoid? = char and char:FindFirstChild("Humanoid")
	
--	char:SetAttribute("Charging", boolean)
	
--	if boolean == true then
--		WeavingModule.Charge(char, max, level)
--	elseif boolean == false then
--		hum:SetAttribute("Charge", 0)
--	end
	
	
--end)

ChargeEvent.OnServerEvent:Connect(function(player: Player, enable, max)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then return end

	if enable == true then
		if char:GetAttribute("Charging") then return end -- don't stack loops
		local stats = player:FindFirstChild("leaderstats")
		local lvl = stats and stats:FindFirstChild("Level")
		max = typeof(max) == "number" and math.clamp(max, 0, 100) or 0 -- 100 = your highest MaxCharge
		char:SetAttribute("Charging", true)
		WeavingModule.Charge(char, max, lvl and lvl.Value or 1)
	elseif enable == false then
		char:SetAttribute("Charging", false)
		hum:SetAttribute("Charge", 0)
	end
end)