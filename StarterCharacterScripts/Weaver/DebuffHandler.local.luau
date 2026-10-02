-- SERVICES
local Players = game:GetService("Players")

-- PLAYER
local Player = Players.LocalPlayer
local Char = Player.Character
local Hum = Char.Humanoid

Char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
	if Char:GetAttribute("Ragdolled") == true then
		Hum:ChangeState(Enum.HumanoidStateType.Physics)
	else
		Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)