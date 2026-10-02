-- SERVICES
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

-- DATASTORE
local levelDataStore = DataStoreService:GetDataStore("PlayerLevelData")
local marksDataStore = DataStoreService:GetDataStore("PlayerMarksData")
local expDataStore = DataStoreService:GetDataStore("PlayerExpData")

-- MODULES
local ExpHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ExpHandler"):WaitForChild("ExpHandler"))

-- LISTENS FOR THE PLAYER JOINING
Players.PlayerAdded:Connect(function(player)
	-- Create a leaderstat folder for the player, a storage for our precious stats like level, marks, and exp
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	-- We basically create a storage wherein our stats will be placed, since they are numbers, they are stored in NumberValue
	local level = Instance.new("NumberValue")
	level.Name = "Level"
	level.Parent = leaderstats
	
	local marks = Instance.new("NumberValue")
	marks.Name = "Marks"
	marks.Parent = leaderstats
	
	local exp = Instance.new("NumberValue")
	exp.Name = "Exp"
	exp.Parent = leaderstats
	
	-- Now we need a boolean value in order for us to determine if the player has loaded everything properly, this is important later ;)
	player:SetAttribute("hasLoaded", false)
	
	-- Then we can try to load the data from our DATASTORE using pcall
	local successLevel, levelData = pcall(function() -- successLevel is a boolean, it determines whether this function succeeds or not
		return levelDataStore:GetAsync(player.UserId) -- It is basically determined here whether it succeeds or not, we use player.UserId as a parameter to identify whose data we're retrieving
	end)
	
	if successLevel then -- Now we do something with it as the previous function is like us trying to ask the server if something exists or not (like the level)
		level.Value = (levelData and levelData ~= "") and levelData or 1 -- If there is "PlayerLevelData" then store the levelData (because we referenced it in the pcall) to our actual level.Value
		player:SetAttribute("Level", level.Value) -- We can also put it on the player itself as an attribute for ease of access
		player:SetAttribute("hasLoaded", true) -- We only set it true once here in the first stat we're checking, because if this one fails and is set to false, then it should stay that way for the rest
	else 
		player:SetAttribute("hasLoaded", false) -- We set the hasLoaded = false, therefore it won't try to save the data as nil or 0 in the DataStore later on
		level.Value = 1
		warn("Level for ".. player.Name .." did not successfully load, error msg:", levelData) -- levelData becomes an error message if false was returned to it
	end
	
	-- Then repeat the steps
	local successMarks, marksData = pcall(function()
		return marksDataStore:GetAsync(player.UserId)
	end)
	
	if successMarks then
		marks.Value = (marksData and marksData ~= "") and marksData or 0
		player:SetAttribute("Marks", marks.Value)
	else
		player:SetAttribute("hasLoaded", false)
		marks.Value = 0
		warn("Marks for ".. player.Name .." did not successfully load, error msg:", marksData)
	end
	
	local successExp, expData = pcall(function()
		return expDataStore:GetAsync(player.UserId	)
	end)
	
	if successExp then
		exp.Value = (expData and expData ~= "") and expData or 0
		player:SetAttribute("Exp", exp.Value)
	else
		player:SetAttribute("hasLoaded", false)
		exp.Value = 0
		warn("Exp for ".. player.Name .." did not successfully load, error msg:", expData)
	end

	level.Changed:Connect(function()
		if level.Value > player:GetAttribute("Level") then
			player:SetAttribute("Level", level.Value)
		end
	end)

	marks.Changed:Connect(function()
		if marks.Value > player:GetAttribute("Marks") then
			player:SetAttribute("Marks", marks.Value)
		end
	end)

	exp.Changed:Connect(function()
		if exp.Value > player:GetAttribute("Exp") then
			player:SetAttribute("Exp", exp.Value)
		end
		ExpHandler.CheckExp(player)
	end)
end)

-- SAVING DATA UPON PLAYER REMOVAL
Players.PlayerRemoving:Connect(function(player)
	
	-- Reference the important values from earlier
	local leaderstats: Folder = player:FindFirstChild("leaderstats")
	
	if not leaderstats then warn("UNABLE TO SAVE DATA, LEADERSTATS FOLDER MISSING FROM:", player.Name) return end
	
	local level: NumberValue? = leaderstats:FindFirstChild("Level")
	local marks: NumberValue? = leaderstats:FindFirstChild("Marks")
	local exp: NumberValue? = leaderstats:FindFirstChild("Exp")
	local hasLoaded: boolean = player:GetAttribute("hasLoaded")
	
	-- If the player successfully loaded data, or hasLoaded was never set to false then save the data
	if hasLoaded then
		
		local successLevel, levelErr = pcall(function()
			levelDataStore:SetAsync(player.UserId, level.Value) -- set the level for the player with the userId provided in their "PlayerLevelData"
		end)
		
		local successMarks, marksErr = pcall(function()
			marksDataStore:SetAsync(player.UserId, marks.Value)
		end)
		
		local successExp, expErr = pcall(function()
			expDataStore:SetAsync(player.UserId, exp.Value)
		end)
		
		-- Error messages for when SetAsync fails
		if not successLevel then
			warn("UNABLE TO SAVE LEVEL FOR", player.Name, "ERROR:", levelErr)
		end
		
		if not successMarks then
			warn("UNABLE TO SAVE MARKS FOR", player.Name, "ERROR:", marksErr)
		end
		
		if not successExp then
			warn("UNABLE TO SAVE EXP FOR", player.Name, "ERROR:", expErr)
		end
		
	end
	
end)
