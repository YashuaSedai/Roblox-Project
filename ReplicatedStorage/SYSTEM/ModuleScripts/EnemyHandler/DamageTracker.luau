local DamageTracker = {}

-- CREATES A TRACKER
function DamageTracker.CreateTracker(key)
	
	if not DamageTracker[key] then
		DamageTracker[key] = {}
	end
	
	return DamageTracker[key]
end



return DamageTracker
