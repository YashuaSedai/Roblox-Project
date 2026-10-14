-- SERVICE
local RS = game:GetService("ReplicatedStorage")

-- REMOTES
local DebuffHandlerFolder = RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler")
local DoTRemote = DebuffHandlerFolder:WaitForChild("DoT")
local DamageRemote = DebuffHandlerFolder:WaitForChild("Damage")
local StunRemote = DebuffHandlerFolder:WaitForChild("Stun")
local FreezeRemote = DebuffHandlerFolder:WaitForChild("Freeze")
local RootRemote = DebuffHandlerFolder:WaitForChild("Root")
local KnockbackRemote = DebuffHandlerFolder:WaitForChild("Knockback")

-- MODULES
local DebuffHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))

DoTRemote.OnServerEvent:Connect(function(player: Player, userId: number, targetHumanoid: Humanoid, damage: number, duration: number, perTick: number)
	
	DebuffHandler.DoT(player, userId, targetHumanoid, damage, duration, perTick)
	
end)

DamageRemote.OnServerEvent:Connect(function(player: Player, userId: number, targetHumanoid: Humanoid, damage: number)
	
	DebuffHandler.Damage(player, userId, targetHumanoid, damage)
	
end)

FreezeRemote.OnServerEvent:Connect(function(player: Player, targetCharacter: Model?, duration: number)
	
	DebuffHandler.Freeze(player, targetCharacter, duration)
	
end)

RootRemote.OnServerEvent:Connect(function(player: Player, targetCharacter: Model?, duration: number | boolean)

	DebuffHandler.Root(player, targetCharacter, duration)
	
end)

KnockbackRemote.OnServerEvent:Connect(function(player: Player, obj: Instance, targetCharacter: Model?, duration: number, forceValue: number, upwardForce: number, rotationvalue: number)

	DebuffHandler.Ragdoll(player, targetCharacter, duration)
	task.wait()
	DebuffHandler.Knockback(obj, targetCharacter, duration, forceValue, upwardForce, rotationvalue)
	
end)

StunRemote.OnServerEvent:Connect(function(player, targetCharacter, duration)
	
	DebuffHandler.Ragdoll(player, targetCharacter, duration)
	
end)
