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
		task.wait(2)
		AnimationHandler.LoadAllAnimations(child)
	end
end)