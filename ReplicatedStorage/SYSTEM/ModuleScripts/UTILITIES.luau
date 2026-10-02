-- UtilitiesModule.lua
local ReplicatedStorage =  game:GetService("ReplicatedStorage")
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Utilities = {}

-- Finds the humanoid's parent within the specified range
function Utilities.findCharacter(targetPart, detectionRange, player)
    local parent = targetPart
    while parent do
        if parent:FindFirstChild("Humanoid") then
            local distance = (parent.PrimaryPart.Position - player.Character.HumanoidRootPart.Position).magnitude
            if distance <= detectionRange then
                return parent
			else
				task.spawn(function()
					GuiRelatedThings.ErrorMessage(player, "Target is out of Range")
				end)
                
                return nil
            end
        end
        parent = parent.Parent
    end
    return nil
end


-- Waits until the specified attribute is present on the instance
function Utilities.WaitforAttribute(instance, attributeName)
	repeat
		wait(0.1)
	until instance:GetAttribute(attributeName) ~= nil
	return instance:GetAttribute(attributeName)
end

return Utilities
