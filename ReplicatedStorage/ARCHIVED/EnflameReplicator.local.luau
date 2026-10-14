-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local DebuffHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler"):WaitForChild("DebuffHandler"))
local BezierModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))
local DrawHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))

-- REMOTE
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")

-- SOUNDS
local SFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("SFX")

-- EFFECT
local VFX = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("Enflame")

local EnflameFx = {}

WeavingEvent.OnClientEvent:Connect(function(char: Model?, hum: Humanoid, humRP, weaveName, target: Model?, DAMAGE_OVER_TIME, DURATION)
	if not char then warn("Character not found") return end  
	if not hum then warn("Humanoid not found") return end  
	if not humRP then warn("HumanoidRootPart not found") return end  
	if not weaveName then warn("WeaveName is missing") return end  
	if not target then warn("No Target found") return end

	if weaveName ~= "Enflame" then return end

	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end -- Safety check

	local uniqueId = tostring(player.UserId) .. "_" .. tostring(math.random(1000, 9999))
	local element = "Fire"

	local targetHum = target:FindFirstChild("Humanoid")
	local targetRP = target:FindFirstChild("HumanoidRootPart")
	local RightHand = char:FindFirstChild("RightHand")

	if not EnflameFx[uniqueId] then 
		EnflameFx[uniqueId] = {}
	end

	-- Setup Easy cleanup
	local Folder = Instance.new("Folder")
	Folder.Name = "EnflameFx2"
	Folder.Parent = targetHum
	
	-- Create a trail or create a custom trail. 
	-- Create Locking Trail
	local LockingTrail = Effects.CreateTrail2(element, Folder, false, nil, nil, nil, RightHand.CFrame)
	LockingTrail.Anchored = true
	LockingTrail.Parent = Folder
	
	-- Set attribute Locking to true
	LockingTrail:SetAttribute("Locking", true)
	-- Set attribute WeaveName to weaveName
	
	LockingTrail:SetAttribute("WeaveName", weaveName)
	
	-- Set a Tag
	CollectionService:AddTag(LockingTrail, "Locking")
	
	-- Set trail position away from target character within 30 studs (Technically yes)
	
	-- Create tween info and goal
	local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	
	-- Setup Bezier Points
	local Base = RightHand.Position
	local Point1 = Base
	local Point2 = Base + Vector3.new(math.random(-20, 10), math.random(-10, 10), math.random(0, 10))
	local Point3 = Base + Vector3.new(math.random(10, 20), math.random(0, 10), math.random(0, 10))
	local Point4 = targetRP.Position
	
	-- Set them up in a table
	local PointsTable = {
		Point1 = Point1,
		Point2 = Point2,
		Point3 = Point3,
		Point4 = Point4
	}
	
	-- Create Bezier
	local NewBezier = BezierModule.new(Point1, Point2, Point3, Point4)

	-- Tween trail position towards target position
	local Tween = NewBezier:CreateCFrameTween(LockingTrail, {"CFrame"}, tweenInfo)
	
	-- Acquire Target character's attribute LockedWeave then set it to the taget's name + weave name
	target:SetAttribute("LockedWeave" .. weaveName, (target:GetAttribute("LockedWeave" .. weaveName) or 0) + 1)
	
	-- Play the tween
	Tween:Play()
	
	-- Set up a listener for when LockedWeave attribute changes to Zero, if Zero then proceed to clean up code immediately
	local flag = false
	EnflameFx[uniqueId].LockedWeaveListener = target:GetAttributeChangedSignal("LockedWeave" .. weaveName):Connect(function()
		if target:GetAttribute("LockedWeave" .. weaveName) == 0 then
			
			-- Set Flag
			flag = true
			
			task.delay(1, function()
				-- Cancel Tween
				Tween:Cancel()

				-- Anchor Trail
				LockingTrail.Anchored = true
			end)
			
			-- Clean any previous code
			Effects.NumberValueTweenObj(LockingTrail, "Trail", "Transparency", 0, 1, 1, 10)
			task.wait(2)
			if not EnflameFx[uniqueId] then return end
			
			if Folder then Folder:Destroy() end
			if EnflameFx[uniqueId].LockedWeaveListener then EnflameFx[uniqueId].LockedWeaveListener:Disconnect(); EnflameFx[uniqueId].LockedWeaveListener = nil end
			
			return -- Cancel the code
		end
	end)
	
	Tween.Completed:Wait()
	if flag then warn("Flag is true, canceling script") return end
	
	-- If Tween manages to finish without the LockedWeave attribute changing, immediately disconnect the listener and subtract the LockedWeave
	if EnflameFx[uniqueId].LockedWeaveListener then EnflameFx[uniqueId].LockedWeaveListener:Disconnect(); EnflameFx[uniqueId].LockedWeaveListener = nil end
	if target:GetAttribute("LockedWeave"..weaveName) ~= 0 then
		target:SetAttribute("LockedWeave" .. weaveName, (target:GetAttribute("LockedWeave" .. weaveName)) - 1)
	end
	
	
	-- Proceed code normally with damage, effects, and regular cleanup
	-- Create effects
	local Rotator = Effects.CreatePart(Vector3.new(1,1,1), 1, "EnflameRotator", targetRP.CFrame, Folder, true)
	local Trail = Effects.CreateTrail2(element, Folder, false, nil, true, Rotator, Rotator.CFrame * CFrame.new(0, 0, 2.5))

	-- Create sound effects
	local FireCrackingSFX = SFX["Fireplace Constant Burning Flame 4 (SFX)"]:Clone()
	FireCrackingSFX.Parent = Folder
	local FlameLoopSFX = SFX["Flamethrower Loop"]:Clone()
	FlameLoopSFX.Parent = Folder
	local WhooshSFX = SFX["Magic Whooshes Growly Magic Whooshes Airy Gu (SFX)"]:Clone()
	WhooshSFX.Parent = Folder

	-- Play Sounds
	FireCrackingSFX:Play()
	FlameLoopSFX:Play()
	WhooshSFX:Play()

	-- Create Burning effect to target
	local newEffect = VFX.EnflameEffect:Clone()
	newEffect.Parent = Folder
	newEffect.CFrame = targetRP.CFrame
	newEffect.WeldConstraint.Part0 = targetRP

	-- Setup animation for the rotator
	local rotationAngle = 0
	local isAdding = true

	EnflameFx[uniqueId].Connection = RunService.Heartbeat:Connect(function()
		local rootPosition = target.HumanoidRootPart.Position
		local yOffset = isAdding and 0.05 or -0.05
		local currentY = Rotator.Position.Y
		local targetY = currentY + yOffset

		if targetY >= 5 then
			isAdding = false
		elseif targetY <= 0 then
			isAdding = true
		end

		rotationAngle = rotationAngle + math.rad(5)
		local newPosition = Vector3.new(rootPosition.X, targetY, rootPosition.Z)
		local newRotation = CFrame.Angles(0, rotationAngle, 0)
		Rotator.CFrame = CFrame.new(newPosition) * newRotation
	end)

	DebuffHandler.FireDoT(player, player.UserId, targetHum, DAMAGE_OVER_TIME, DURATION, 0.1)

	--**CLEANUP HANDLER**
	local function cleanup()
		if not EnflameFx[uniqueId] then return end

		for _, emitters in Folder:GetDescendants() do
			if emitters:IsA("ParticleEmitter") then
				emitters.Enabled = false
			end
		end

		Trail.Anchored = true
		Effects.NumberValueTween(Trail, "Trail", "Transparency", 0, 2, 1, 20)

		Folder:Destroy()

		if EnflameFx[uniqueId].Connection then 
			EnflameFx[uniqueId].Connection:Disconnect() 
		end
		EnflameFx[uniqueId] = nil
	end

	-- Cleanup on character death
	local deathConnection
	if hum then
		deathConnection = hum.Died:Connect(cleanup)
	end

	-- Cleanup on player leaving
	local leaveConnection
	leaveConnection = Players.PlayerRemoving:Connect(function(playerLeaving)
		if playerLeaving == player then
			cleanup()
			leaveConnection:Disconnect()
		end
	end)

	-- Cleanup after spell duration ends
	task.wait(DURATION)
	cleanup()

	-- Disconnect cleanup connections
	if deathConnection then deathConnection:Disconnect() end
	if leaveConnection then leaveConnection:Disconnect() end
end)
