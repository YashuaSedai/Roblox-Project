local MarksHandler = {}

-- GIVE MARKS TO A PLAYER
function MarksHandler.GiveMarks(player:Player, value: number, hasDoubleMarks)
	
	local leaderstats = player:FindFirstChild("leaderstats") -- First we'll have to find the leaderstats folder
	if leaderstats then -- We check if it exists
		
		local marks = leaderstats:FindFirstChild("Marks")
		
		if marks then
			
			if hasDoubleMarks then
				value = value * 2
			end
		
			marks.Value = marks.Value + value
		end
	end
	
end

-- REMOVE MARKS FROM A PLAYER
function MarksHandler.RemoveMarks(player:Player, value: number)
	
	local leaderstats = player:FindFirstChild("leaderstats") -- First we'll have to find the leaderstats folder
	if leaderstats then -- We check if it exists

		local marks = leaderstats:FindFirstChild("Marks")

		if marks then
			marks.Value = marks.Value - value
		end
	end
	
end


return MarksHandler
