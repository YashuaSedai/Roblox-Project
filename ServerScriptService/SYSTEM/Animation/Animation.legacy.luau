-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- MODULES
local AnimationHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))

-- REMOTE
local PlayAnim = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("PlayAnim")

-- Setup Animations Once for existing characters
for _, character in pairs(workspace:GetChildren()) do
	if character:IsA("Model") and character:FindFirstChild("Humanoid") then
		AnimationHandler.LoadAllAnimations(character)
	end
end

-- Load animations for incoming players or characters
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child:FindFirstChild("Humanoid") then
		AnimationHandler.LoadAllAnimations(child)
	end
end)


-- Handles animation requests
PlayAnim.OnServerEvent:Connect(function(player: Player, action: string, char:Model, hum: Humanoid, animId: string, speed: number, priority: Enum.AnimationPriority, looped: boolean, fadeTime: number)
	if action == "Play" then
		AnimationHandler.PlayAnimation2(char, hum, animId, speed, priority, looped, fadeTime)
	elseif action == "Stop" then
		print(`Stopping animation for {char} from {player.Name}`)
		AnimationHandler.StopAnimation2(char)
	end
end)