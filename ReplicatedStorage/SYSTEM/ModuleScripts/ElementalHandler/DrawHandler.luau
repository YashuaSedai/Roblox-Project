-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
local RemoveEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Remove")

-- BEZIER MODULE
local Bezier = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))

-- ASSETS
local Assets = ReplicatedStorage:WaitForChild("Assets")
local ElementalFolder = Assets:WaitForChild("Elements")
-- BEAMS
local Beams = ElementalFolder:WaitForChild("Beams")
-- PARTICLES
local Particles = ElementalFolder:WaitForChild("Particles")
-- TRAILS
local Trails = ElementalFolder:WaitForChild("Trails")

local DrawHandler = {}
DrawHandler.PlayerFx = {}

-- SETUPS PLAYER FX FOLDER
function DrawHandler.SetUpPlayerFxFolder (name: string)

	DrawHandler.PlayerFx[name] = {
		Slots = {
			Slot1 = {},
			Slot2 = {},
			Slot3 = {},
			Slot4 = {},
			Slot5 = {}
		}
	}
end

-- CLEARS ALL THE ELEMENTAL FX FROM THE PLAYER FX FOLDER
function DrawHandler.ClearElementalFx(name: string)
	if name == nil or type(name) ~= "string" then warn("Name is nil or isn't a string") return end

	if DrawHandler.PlayerFx[name] then
		for i = 1, 5 do
			local Slotname = "Slot"..i
			local Slot = DrawHandler.PlayerFx[name].Slots[Slotname]
			if Slot then
				if DrawHandler.PlayerFx[name].Slots[Slotname].newParticle then
					for _, emitters in pairs (DrawHandler.PlayerFx[name].Slots[Slotname].newParticle:GetDescendants()) do
						if emitters:IsA("ParticleEmitter") then
							emitters.Enabled = false
						end
					end
					DrawHandler.PlayerFx[name].Slots[Slotname].TempTask1 = task.delay(2,function()
						if not DrawHandler.PlayerFx[name].Slots[Slotname].newParticle then return end
						DrawHandler.PlayerFx[name].Slots[Slotname].newParticle:Destroy()
						DrawHandler.PlayerFx[name].Slots[Slotname].newParticle = nil
					end)
				end

				if DrawHandler.PlayerFx[name].Slots[Slotname].newTrail then
					for _, trails in pairs (DrawHandler.PlayerFx[name].Slots[Slotname].newTrail:GetDescendants()) do
						if trails:IsA("Trail") then
							trails.Enabled = false
						end
					end
					DrawHandler.PlayerFx[name].Slots[Slotname].TempTask2 = task.delay(2,function()
						if not DrawHandler.PlayerFx[name].Slots[Slotname].newTrail then return end
						DrawHandler.PlayerFx[name].Slots[Slotname].newTrail:Destroy()
						DrawHandler.PlayerFx[name].Slots[Slotname].newTrail = nil
					end)
				end

				for taskIndex = 1, 4 do
					local taskKey = "Task" .. taskIndex
					if DrawHandler.PlayerFx[name].Slots[Slotname][taskKey] then
						task.cancel(DrawHandler.PlayerFx[name].Slots[Slotname][taskKey])
						DrawHandler.PlayerFx[name].Slots[Slotname][taskKey] = nil
					end
				end

				if DrawHandler.PlayerFx[name].Slots[Slotname].Connection then
					DrawHandler.PlayerFx[name].Slots[Slotname].Connection:Disconnect()
					DrawHandler.PlayerFx[name].Slots[Slotname].Connection = nil
				end

				if DrawHandler.PlayerFx[name].Slots[Slotname].NewBezier then
					DrawHandler.PlayerFx[name].Slots[Slotname].NewBezier = nil
				end
			end
		end
	end

end

-- CLEANS ALL EFFECTS IMMEDIATELY
function DrawHandler.InstantlyCleanElementalFx(name: string, userId:number, slot)
	if name == nil or type(name) ~= "string" then warn("Name is nil or isn't a string") return end
	if userId == nil or type(userId) ~= "number" then warn("UserId is nil or isn't a string") return end

	local Slot = DrawHandler.PlayerFx[name].Slots[slot]
	if Slot then

		if DrawHandler.PlayerFx[name].Slots[slot].newParticle then
			DrawHandler.PlayerFx[name].Slots[slot].newParticle:Destroy()
			DrawHandler.PlayerFx[name].Slots[slot].newParticle = nil
		end

		if DrawHandler.PlayerFx[name].Slots[slot].newTrail then
			DrawHandler.PlayerFx[name].Slots[slot].newTrail:Destroy()
			DrawHandler.PlayerFx[name].Slots[slot].newTrail = nil
		end

		for taskIndex = 1, 4 do
			local taskKey = "Task" .. taskIndex
			if DrawHandler.PlayerFx[name].Slots[slot][taskKey] then
				task.cancel(DrawHandler.PlayerFx[name].Slots[slot][taskKey])
				DrawHandler.PlayerFx[name].Slots[slot][taskKey] = nil
			end
		end

		if DrawHandler.PlayerFx[name].Slots[slot].Connection then
			DrawHandler.PlayerFx[name].Slots[slot].Connection:Disconnect()
			DrawHandler.PlayerFx[name].Slots[slot].Connection = nil
		end
		
		if DrawHandler.PlayerFx[name].Slots[slot].TempTask1 then
			task.cancel(DrawHandler.PlayerFx[name].Slots[slot].TempTask1)
		end
		
		if DrawHandler.PlayerFx[name].Slots[slot].TempTask2 then
			task.cancel(DrawHandler.PlayerFx[name].Slots[slot].TempTask2)
		end

		if DrawHandler.PlayerFx[name].Slots[slot].NewBezier then
			DrawHandler.PlayerFx[name].Slots[slot].NewBezier = nil
		end
	end

end


-- REMOVES AN ELEMENTAL EFFECT FROM A SLOT
function DrawHandler.RemoveElementalFx(name: string, userId:number, slot)
	if name == nil or type(name) ~= "string" then warn("Name is nil or isn't a string") return end
	if userId == nil or type(userId) ~= "number" then warn("UserId is nil or isn't a string") return end

	local Slot = DrawHandler.PlayerFx[name].Slots[slot]
	if Slot then

		if DrawHandler.PlayerFx[name].Slots[slot].newParticle then
			for _, emitters in pairs (DrawHandler.PlayerFx[name].Slots[slot].newParticle:GetDescendants()) do
				if emitters:IsA("ParticleEmitter") then
					emitters.Enabled = false
				end
			end
			task.delay(2,function()
				DrawHandler.PlayerFx[name].Slots[slot].newParticle:Destroy()
				DrawHandler.PlayerFx[name].Slots[slot].newParticle = nil
			end)
		end

		if DrawHandler.PlayerFx[name].Slots[slot].newTrail then
			for _, trails in pairs (DrawHandler.PlayerFx[name].Slots[slot].newTrail:GetDescendants()) do
				if trails:IsA("Trail") then
					trails.Enabled = false
				end
			end
			task.delay(2,function()
				DrawHandler.PlayerFx[name].Slots[slot].newTrail:Destroy()
				DrawHandler.PlayerFx[name].Slots[slot].newTrail = nil
			end)
		end

		for taskIndex = 1, 4 do
			local taskKey = "Task" .. taskIndex
			if DrawHandler.PlayerFx[name].Slots[slot][taskKey] then
				task.cancel(DrawHandler.PlayerFx[name].Slots[slot][taskKey])
				DrawHandler.PlayerFx[name].Slots[slot][taskKey] = nil
			end
		end

		if DrawHandler.PlayerFx[name].Slots[slot].Connection then
			DrawHandler.PlayerFx[name].Slots[slot].Connection:Disconnect()
			DrawHandler.PlayerFx[name].Slots[slot].Connection = nil
		end

		if DrawHandler.PlayerFx[name].Slots[slot].NewBezier then
			DrawHandler.PlayerFx[name].Slots[slot].NewBezier = nil
		end
	end
end


-- SIMULATES A TWEEN TO NUMBERVALUES
function DrawHandler.NumberValueTween(obj, kind, initialT: number, duration: number, finalT: number, steps: number)

	local increment = (finalT - initialT) / steps
	local interval = duration / steps
	local value = initialT

	for i = 1, steps do
		value = value + increment

		for _, valuesToTween in obj:GetDescendants() do
			if valuesToTween:IsA(kind) then
				local transparency = valuesToTween.Transparency
				transparency = NumberSequence.new(value)
				valuesToTween.Transparency = transparency
			end
		end

		task.wait(interval)
	end

end

-- SETS UP A BEZIER
function DrawHandler.BezierSetup(PointsTable, toTween: boolean, object: Instance, info: TweenInfo)
	-- Convert PointsTable to a numerically indexed array
	local function ConvertToArray(dictionary)
		local array = {}

		-- Extract keys and sort them
		local keys = {}
		for name in pairs(dictionary) do
			table.insert(keys, name)
		end
		table.sort(keys, function(a, b)
			local numA = tonumber(a:match("%d+")) or 0
			local numB = tonumber(b:match("%d+")) or 0
			return numA < numB
		end)

		-- Insert in correct order
		for _, key in ipairs(keys) do
			table.insert(array, dictionary[key])
		end

		return array
	end

	local PointsArray = ConvertToArray(PointsTable)

	-- Debug: Print types and values of all points
	for i, point in ipairs(PointsArray) do
		if typeof(point) ~= "Vector3" then
			warn("Invalid point in PointsArray at index", i, ":", point)
			return
		end
	end

	-- Use unpack() to pass individual points to Bezier.new
	local newBezier = Bezier.new(unpack(PointsArray)) -- <== FIX: unpack the array
	local Tween = nil

	-- Optional tween setup
	if toTween == true then
		if object == nil then
			warn("No Object Provided, tween failed")
			return
		end
		Tween = newBezier:CreateCFrameTween(object, {"CFrame"}, info)
	end

	if Tween then
		return newBezier, Tween
	else
		return newBezier, nil
	end
end

-- SHAKES THE ALIGN POSITION by extension the PARTICLE
function DrawHandler.ShakeAP(alignPosition: AlignPosition, basePos: CFrame, offset: Vector3, duration: number)
	local worldPosition = basePos * offset
	task.wait(duration)
	return worldPosition
end

-- SETUPS THE MAIN FUNCTION FOR HANDLING ELEMENTS
function DrawHandler.SetupElementalFx (char: Model, name: string, element: string, slot: string, slotNo: number?)
	if not char or char == nil then warn("Char not given") return end
	if not name or name == nil then warn("Name not given") return end
	if not element or element == nil then warn("Element not given") return end
	if not slot or slot == nil then warn("Slot Name not given") return end

	local originalPlayer: Player = Players:GetPlayerFromCharacter(char)
	local HumanoidRP = char:FindFirstChild("HumanoidRootPart")
	local Uppertorso = char:FindFirstChild("UpperTorso")
	local userId = originalPlayer.UserId

	-- Setup PlayerFx Folder
	if not DrawHandler.PlayerFx[name] then
		DrawHandler.SetUpPlayerFxFolder(name)
	end

	-- Reference the PlayerFx Folder's slots
	local SelectedSlot = DrawHandler.PlayerFx[name].Slots[slot]
	DrawHandler.InstantlyCleanElementalFx(name, userId, slot)

	-- If passed element is "Default", the slot's element should be cleaned and exit
	if element == "Default" then
		DrawHandler.RemoveElementalFx(name, userId, slot)
		--DrawHandler.PlayerFx[name].Slots[slot] = nil
		return
	end

	-- Returns true or false which determines the origin of the elemental effects
	SelectedSlot.SlotNo = slotNo and (slotNo % 2 == 0 and true or false)
	local SlotBoolean = SelectedSlot.SlotNo

	-- Creates the Particle of the element in the slot
	local particleCFrame = Uppertorso.CFrame * CFrame.new(0, 0, -2)
	local newParticle = SelectedSlot.newParticle
	local Emitters
	newParticle, Emitters = Effects.CreateParticle(element, particleCFrame, HumanoidRP, false, nil, nil, nil, nil, true)

	local alignPos = newParticle:FindFirstChild("AlignPosition")

	-- Causes the Particle to have randomized movement as a visual effect
	SelectedSlot.Task1 = task.spawn(function()
		while newParticle do
			local BasePosition = Uppertorso.CFrame * CFrame.new(0 , 1, -2)
			local localOffSet = Vector3.new(math.random(-0.5, 0.5), math.random(-0.5, 0.5), math.random(-0.5, 0.5))
			alignPos.Position = DrawHandler.ShakeAP(alignPos, BasePosition, localOffSet, 0.1)
		end
	end)

	local basePosition = HumanoidRP.Position
	local directionOffset = Vector3.new(0, 0, 0)  -- Default (forward)
	local newTrail = SelectedSlot.newTrail 
	newTrail, directionOffset = Effects.CreateTrail(element, workspace, newParticle:FindFirstChild("AP"), basePosition, SlotBoolean, char)

	-- Position adjustments based on the direction for Bezier
	SelectedSlot.Point1 = directionOffset
	SelectedSlot.Point2 = directionOffset + Vector3.new(math.random(10, 20), math.random(-5, 10), math.random(-10, 10))
	SelectedSlot.Point3 = directionOffset + Vector3.new(math.random(0, 10), math.random(-5, 10), math.random(-10, 10))
	SelectedSlot.Point4 = newParticle.Position

	local PointsTable = {
		Point1 = SelectedSlot.Point1,
		Point2 = SelectedSlot.Point2,
		Point3 = SelectedSlot.Point3,
		Point4 = SelectedSlot.Point4,
	}

	-- Setup the Bezier and Do something to it
	local tweenInfo = TweenInfo.new(1, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut, 0, false, 0)
	local newBezier = DrawHandler.newBezier 
	local tween
	newBezier, tween = DrawHandler.BezierSetup(PointsTable, true, newTrail, tweenInfo)

	SelectedSlot.Task2 = task.spawn(function()
		if tween then 
			tween:Play()
		end
	end)

	SelectedSlot.Connection = tween.Completed:Connect(function()
		SelectedSlot.Task3 = task.delay(2, function()
			DrawHandler.NumberValueTween(newTrail, "Trail", 0.5, 2, 1, 20)

			newTrail:Destroy()
			SelectedSlot.newTrail = nil
		end)

		for _, emitters in Emitters:GetChildren() do
			if emitters and emitters:IsA("ParticleEmitter") then
				emitters.Enabled = true
			end
		end
	end)

	-- Reinstate the important Variables to the actual table
	DrawHandler.PlayerFx[name].Slots[slot].newParticle = newParticle
	DrawHandler.PlayerFx[name].Slots[slot].newTrail = newTrail
	DrawHandler.PlayerFx[name].Slots[slot].newBezier = newBezier
end

return DrawHandler
