-- SERVICES
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- MODULES
local ModuleScripts = RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts")
local BezierModule = require(ModuleScripts:WaitForChild("Bezier"))
local Effects = require(ModuleScripts:WaitForChild("EffectsHandler"):WaitForChild("VFX"))
local SFX = require(ModuleScripts:WaitForChild("EffectsHandler"):WaitForChild("SFX"))
local DrawHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("DrawHandler"))

-- ASSETS
local Sounds = RS:WaitForChild("Assets"):WaitForChild("Elements"):WaitForChild("Sounds")

-- REMOTE
local InversingRemote = ModuleScripts:WaitForChild("WeavingModule"):WaitForChild("InversingRemote")

-- TABLE
local InversingTable = {}


-- IN THE ALL CLIENTS SCRIPT: (Visualizing)
InversingRemote.OnClientEvent:Connect(function(char, hum, humRP, InverseName, IncomingWeave, e1, e2, e3, e4, e5)
	-- Validate character
	if not char then warn(`Visualizer: Inversing Replicator did not receive a character for {InverseName}`) return end
	
	-- Set Character's LockedWeave to 0
	char:SetAttribute("LockedWeave" .. InverseName, 0)
	
	-- Validate the player (grab the player via getplayerfromcharacter())
	local player = Players:GetPlayerFromCharacter(char)
	local RightHand = char:FindFirstChild("RightHand")
	
	-- Assemble the elements (e1 to e5 contain strings of elements)
	local elements = {e1, e2, e3, e4, e5}
	
	-- Create a Folder
	local Folder = Instance.new("Folder")
	Folder.Name = "InverseWeave" .. InverseName
	Folder.Parent = char
	
	-- Only return if e1 is empty 
	if not e1 then warn(`Visualizer: Inversing Replicator e1 is empty for {InverseName}`) return end
	
	-- Create trails based on the passed elements, if the passed element is nil, or the corresponding element is nil, then simply not create a trail
	for _, element in ipairs(elements) do
		if element then
			local InverseTrail = Effects.CreateTrail2(element, Folder, false, nil, false, nil, humRP.CFrame * CFrame.new(0,0,-1))
			InverseTrail.Parent = Folder
			
			-- Trails are individualized but will have similar tween info and goal
			-- Create tween info and goal
			-- May try to use bezier curves
			-- Tween should only last 1 or half a second
			local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

			-- Setup Bezier Points
			local Base = RightHand.Position
			local Point1 = Base
			local Point2 = Base + Vector3.new(math.random(-20, 10), math.random(-10, 10), math.random(0, 10))
			local Point3 = Base + Vector3.new(math.random(10, 20), math.random(0, 10), math.random(0, 10))
			-- Goal is the incoming part/trail/weave
			local Point4 = IncomingWeave.Position

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
			local Tween = NewBezier:CreateCFrameTween(InverseTrail, {"CFrame"}, tweenInfo)
			
			Tween:Play()
			Tween.Completed:Wait()
			
			InverseTrail.Anchored = true
			task.wait(2)
			Folder:Destroy()
		end
	end
	
end)