-- StarterCharacterScripts > Weaver > DebuffHandler   (LocalScript)   REPLACES the old 14-line version
--
-- The CLIENT half of the status effects. Two jobs, and neither one DECIDES anything (the server does):
--   1. RAGDOLL: keep the humanoid in the Physics state for as long as the server says "Ragdolled".
--      The old version only reacted to the attribute CHANGING once. If anything knocked the humanoid out of
--      Physics afterwards (a state change, a respawn race, the controls turning back on) the player simply
--      stood back up while the server still thought they were ragdolled = "sometimes doesn't get ragdolled".
--   2. MOVEMENT GUARD: the player simulates their own character, so a local write to WalkSpeed / JumpPower
--      (the old ElementalSetting did exactly that) would beat the server's value. If the server says the
--      character can't move / jump, any local change back to a non-zero value is undone straight away.

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- PLAYER
local Player = Players.LocalPlayer
local Char = Player.Character or Player.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")

-- 1. RAGDOLL --------------------------------------------------------------------------------------------
local function isRagdolled()
	return Char:GetAttribute("Ragdolled") == true
end

local function applyRagdoll()
	if Hum.Health <= 0 then return end
	if Hum:GetState() ~= Enum.HumanoidStateType.Physics then
		Hum:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

Char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
	if isRagdolled() then
		applyRagdoll()
	elseif Hum.Health > 0 then
		Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)

-- still ragdolled but the humanoid left the Physics state? put it back
Hum.StateChanged:Connect(function(_, newState)
	if isRagdolled() and newState ~= Enum.HumanoidStateType.Physics and newState ~= Enum.HumanoidStateType.Dead then
		task.defer(applyRagdoll)
	end
end)

if isRagdolled() then applyRagdoll() end -- the attribute was already true when this script started

-- 2. MOVEMENT GUARD -------------------------------------------------------------------------------------
local function guardWalkSpeed()
	if Char:GetAttribute("CanMove") == false and Hum.WalkSpeed ~= 0 then
		Hum.WalkSpeed = 0
	end
end

local function guardJump()
	if Char:GetAttribute("CanJump") == false then
		if Hum.JumpPower ~= 0 then Hum.JumpPower = 0 end
		if Hum.JumpHeight ~= 0 then Hum.JumpHeight = 0 end
	end
end

Hum:GetPropertyChangedSignal("WalkSpeed"):Connect(guardWalkSpeed)
Hum:GetPropertyChangedSignal("JumpPower"):Connect(guardJump)
Hum:GetPropertyChangedSignal("JumpHeight"):Connect(guardJump)

-- the server's attributes can arrive a moment before / after the property, so check when they change too
Char:GetAttributeChangedSignal("CanMove"):Connect(guardWalkSpeed)
Char:GetAttributeChangedSignal("CanJump"):Connect(guardJump)

-- a shielded / frozen / stunned player can never hold a jump input down into the next state
RunService.Heartbeat:Connect(function()
	if Char:GetAttribute("CanJump") == false and Hum.Jump then
		Hum.Jump = false
	end
end)
