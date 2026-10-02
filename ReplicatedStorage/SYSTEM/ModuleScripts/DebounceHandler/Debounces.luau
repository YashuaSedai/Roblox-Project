local DebounceHandler = {}

-- TOGGLES THE DEBOUNCE OF AN INSTANCE THEN REVERTS IT BASED ON THE GIVEN DURATION
function DebounceHandler.DebounceWait(player: Player, object: Instance, attributeName, duration: number?)
	if not player then warn("DebounceHandler cannot find the player to receive the debounce") return end
	if not object then warn("DebounceHandler cannot find the object to find the attribute from") return end
	if type(attributeName) ~= "string" then warn("DebounceHandler cannot find which attribute to toggle") return end
	if object:GetAttribute(attributeName) ~= nil then
		if object:GetAttribute(attributeName) ~= true and object:GetAttribute(attributeName) ~= false then warn("The given attribute is not a boolean value") return end
	end
	

	object:SetAttribute(attributeName, true) -- Always set to true for cooldown

	if duration == nil then return end
	task.delay(duration, function()
		object:SetAttribute(attributeName, false) -- Reset after delay
	end)
end

-- DEBOUNCE CHECKER THAT CREATES THE ATTRIBUTE IF NONE IS FOUND
function DebounceHandler.DebounceCheck(player: Player, object: Instance, attributeName)
	if not player then warn("DebounceCheck cannot find the player to check debounce for") return false end
	if not object then warn("DebounceCheck cannot find the object to check the debounce from") return false end
	if not attributeName then warn("DebounceCheck didn't receive the attribute to check") return false end

	local attr = object:GetAttribute(attributeName)

	if attr == true then
		return true -- Cooldown active
	elseif attr == nil then
		object:SetAttribute(attributeName, false) -- Initialize as available
		warn("Created an attribute called", attributeName, "for", player.Name)
		return false
	end

	return false
end

 -- DEBOUNCE CHECKER THAT DOESN'T CREATE THE ATTRIBUTE
function DebounceHandler.DebounceCheck2(player: Player, object: Instance, attributeName)
	if not player then warn("DebounceCheck cannot find the player to check debounce for") return false end
	if not object then warn("DebounceCheck cannot find the object to check the debounce from") return false end
	if not attributeName then warn("DebounceCheck didn't receive the attribute to check") return false end

	local attr = object:GetAttribute(attributeName)

	if attr == true then
		return true -- Cooldown active
	end

	return false
end

return DebounceHandler
