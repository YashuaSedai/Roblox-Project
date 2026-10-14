-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local EffectsSFX = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("SFX"))
local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))

-- REMOTE
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- VFX
local EffectsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("BrambleSnare")

local BrambleSnareTable = {}

WeavingInstantEvent.OnClientEvent:Connect(function(char, hum, humRP, weaveName, mousePos, DAMAGE, AREA, CAST_RANGE)
	if weaveName ~= "BrambleSnare" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local userId = player.UserId
	local element_0 = "Earth"
	local element_1 = "Water"

	if not BrambleSnareTable[userId] then 
		BrambleSnareTable[userId] = {}
	end

	-- *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* MAIN CHECKER *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*
	local flag = false
	local startTime = tick()  -- Start measuring time

	BrambleSnareTable[userId].AnimationConnection = AnimationSignal.OnClientEvent:Connect(function(weaveName: string, phase: string, userId)
		if weaveName ~= "BrambleSnare" then warn("WeaveName isn't BrambleSnare, returning from Replicator AnimationConnection") return end
		if phase ~= "Channel" then warn("Phase isn't Channel in BrambleSnare, returning from Replicator AnimationConnection") return end
		if player.UserId ~= userId then return end

		flag = true
	end)

	-- Standard repeat-until loop
	repeat
		-- Delay before the next loop iteration
		task.wait(1)  -- Waits for 1 second
	until flag == true or tick() - startTime >= 3.5  -- Waits for flag to be true or 3 seconds to pass

	-- Code to execute after the loop finishes
	if flag then
		BrambleSnareTable[userId].AnimationConnection:Disconnect()
	else
		--warn("BrambleSnareReplicator did not receive the animation signal")
		BrambleSnareTable[userId].AnimationConnection:Disconnect()
		return -- RETURN THE SCRIPT IMMEDIATELY TO AVOID CONNECTING UNNECESSARY STUFF FURTHER
	end
	
	-- *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* MAIN CODE *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*
	-- Prepare Folder for easier cleanup
	local Folder = Instance.new("Folder")
	Folder.Parent = hum
	Folder.Name = "BrambleSnareReplicatorFx"

	local EnemiesTable = {}

	-- Play Sound immediately
	local newExplosion = SFX:FindFirstChild("Earthquake Explosion 1 (SFX)"):Clone()
	newExplosion.Parent = Folder
	newExplosion:Play()

	-- Store Enemies in a table
	for _, part in workspace:GetChildren() do -- Look for instances in the workspace
		if part:IsA("Model") and part:FindFirstChild("Humanoid") and part.Name ~= player.Name then -- confirm the model if the instance has a Humanoid child
			local char = part -- The part is a character if it has a humanoid child
			local humanoidRootPart = char:FindFirstChild("HumanoidRootPart") -- Locate the root part of every character found
			if humanoidRootPart then
				local mag = (humanoidRootPart.Position - mousePos).magnitude -- Calculate the distance between the position of the mouse and every hrp found

				if mag < AREA and char.Name ~= player.Name then -- if the magnitude is less than (or inside) the AREA
					-- TODO: Setup barriers
					table.insert(EnemiesTable, char) -- Add the enemy in the table

				end
			end	
		end
	end
	
	if not BrambleSnareTable[userId].ChosenAnimations then
		BrambleSnareTable[userId].ChosenAnimations = {}
	end
	
	-- Handle enemy position Animation
	for _, Enemies in EnemiesTable do
		local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
		local ChosenAnimation = math.random(1, 2) == 1 and "RootedVine" or "RootedVine2" -- Randomly select animation

		-- Store animation name in the table
		table.insert(BrambleSnareTable[userId].ChosenAnimations, {Enemy = Enemies, Animation = ChosenAnimation})

		-- Play animation
		AnimationHandler.PlayAnimation(Enemies, ChosenAnimation, 1, Enum.AnimationPriority.Action4, true, 0)
	end

	-- Handle the damage
	BrambleSnareTable[userId].TaskLoop = task.spawn(function()
		
		-- Root Enemies
		for _, Enemies in EnemiesTable do
			DebuffHandler.FireRoot(player, userId, Enemies, true)
		end
		
		while EnemiesTable and BrambleSnareTable[userId] do
			-- Loop through EnemiesTable
			for _, Enemies in EnemiesTable do
				-- Locate important parts
				local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")

				-- Handle Damage
				DebuffHandler.FireDamage(player, player.UserId, EnemyHumanoid, DAMAGE)
				
			end
			task.wait(1)
		end
	end)
	
	-- Do effects
	BrambleSnareTable[userId].TaskEffect = task.spawn(function()
		if BrambleSnareTable[userId] then
			-- Loop through EnemiesTable
			for _, Enemies in EnemiesTable do
				-- Locate important parts
				local EnemyRP = Enemies:FindFirstChild("HumanoidRootPart")

				-- Clone Effects
				local newBlast = EffectsFolder.Blast:Clone(); newBlast.Parent = Folder
				local newVine = EffectsFolder.Vine:Clone(); newVine. Parent = Folder

				newBlast.CFrame = EnemyRP.CFrame * CFrame.new(0,-2,0) -- Ensuring that the blast originates on or below the ground
				newVine.CFrame = EnemyRP.CFrame * CFrame.new(0,-1,0)
				newVine["Rope Tight"]:Play()

				-- Disable the blast
				task.delay(0.75, function()
					for _, emitters in newBlast:GetDescendants() do
						if emitters and emitters:IsA("ParticleEmitter") then
							emitters.Enabled = false
						end
					end
				end)
			end

			-- Handle effects that does not require enemy parts or doesn't need cloning
			local newCrack = EffectsFolder.Crack:Clone()
			newCrack.CFrame = CFrame.new(mousePos);newCrack.Parent = Folder
			local sizePercentage =  (math.clamp(AREA * 10, 0, 100) / 100) + 1.25
			Effects.SmoothAdjustParticleSize(newCrack.Emitters.Crack1, sizePercentage, 1, 0)
			Effects.SmoothAdjustParticleSize(newCrack.Emitters.Crack2, sizePercentage, 1, 0)
			newCrack.Emitters.Crack1:Emit(1)
			newCrack.Emitters.Crack2:Emit(1)

		end

	end)


	-- Cleanup Function
	local function CleanUp()

		-- Tween the vines
		task.spawn(function()
			for _, vines in Folder:GetDescendants() do
				if vines.Parent and vines:IsA("Part") and vines:FindFirstChildOfClass("MeshPart") and vines.Name == "Vine" then

					-- Create tween
					local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					local goal = {Size = Vector3.new(0, 0, 0)}
					local tween = TweenService:Create(vines:FindFirstChildOfClass("MeshPart"), tweenInfo, goal)

					task.spawn(function() tween:Play() end)

					EffectsSFX.FadeSound(vines:FindFirstChild("Rope Tight"), 0, 2, 20)
				end
			end
			-- Clear Folder when tween finishes
			task.wait(3)
			Folder:Destroy()
		end)
		
		-- Stop animations
		for _, data in ipairs(BrambleSnareTable[userId].ChosenAnimations) do
			local Enemy = data.Enemy
			local Animation = data.Animation

			AnimationHandler.StopAnimation(Enemy, Animation)
		end

		-- Unroot Enemies and Stop Animation
		for _, Enemies in EnemiesTable do
			-- Locate important parts
			local EnemyHumanoid = Enemies:FindFirstChild("Humanoid")
			DebuffHandler.FireRoot(player, player.UserId, Enemies, false)
		end
		
		task.wait(2)
		
		-- Clear Enemies Table
		if EnemiesTable then EnemiesTable = {} end
		if BrambleSnareTable[userId] and BrambleSnareTable[userId].ChosenAnimations then BrambleSnareTable[userId].ChosenAnimations = nil end

		-- Disconnect Connections, Cancel Tasks, Clear BrambleSnareTable
		if BrambleSnareTable[userId] then
			if BrambleSnareTable[userId].AnimationConnection then BrambleSnareTable[userId].AnimationConnection:Disconnect() end
			if BrambleSnareTable[userId].TaskLoop and coroutine.status(BrambleSnareTable[userId].TaskLoop) ~= "dead" then task.cancel(BrambleSnareTable[userId].TaskLoop); end
			if BrambleSnareTable[userId].TaskEffect and coroutine.status(BrambleSnareTable[userId].TaskEffect) ~= "dead" then task.cancel(BrambleSnareTable[userId].TaskEffect) end
			if BrambleSnareTable[userId].HumanoidDeath then BrambleSnareTable[userId].HumanoidDeath:Disconnect() end
			if BrambleSnareTable[userId].PlayerLeaving then BrambleSnareTable[userId].PlayerLeaving:Disconnect() end
			if BrambleSnareTable[userId].WeavingInstantRelease then BrambleSnareTable[userId].WeavingInstantRelease:Disconnect() end

			BrambleSnareTable[userId] = nil
		end

	end

	-- Cleanup Listeners
	BrambleSnareTable[userId].HumanoidDeath = hum.Died:Connect(CleanUp)
	BrambleSnareTable[userId].PlayerLeaving = Players.PlayerRemoving:Connect(function(plr)
		if plr.UserId == userId then
			CleanUp()
		end
	end)

	BrambleSnareTable[userId].WeavingInstantRelease = WeavingInstantReleaseEvent.OnClientEvent:Connect(function(UID, weaveName)
		if UID ~= player.UserId then return end
		if BrambleSnareTable[UID] then
			CleanUp()
		end
	end)

end)