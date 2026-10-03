-- UtilitiesModule.lua
local ReplicatedStorage =  game:GetService("ReplicatedStorage")
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Players = game:GetService('Players')
local camera = workspace.CurrentCamera
local uis = game:GetService("UserInputService")
local bezierModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Bezier"))

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

-- Finds the character from a given part
function Utilities.getCharacterFromPart(part)
	local model = part.Parent
	while model do
		if model:FindFirstChild("Humanoid") then
			return model
		end
		model = model.Parent
	end
	return nil
end

-- SETS UP A BEZIER
function Utilities.BezierSetup(PointsTable, toTween: boolean, object: Instance, info: TweenInfo, relativeToLength: boolean?)
	-- Convert a "Point1/Point2/..." dictionary (or array) into a sorted array
	local function ConvertToArray(dictionary)
		-- If already an array-like table (1..n), just return a shallow copy
		local function isArray(t)
			local n = 0
			for k in pairs(t) do
				if typeof(k) ~= "number" then return false end
				if k % 1 ~= 0 or k < 1 then return false end
				n = math.max(n, k)
			end
			-- allow sparse arrays but we treat as array
			return n > 0
		end

		if isArray(dictionary) then
			local arr = {}
			for i = 1, #dictionary do arr[i] = dictionary[i] end
			return arr
		end

		-- Otherwise, assume a dictionary with string keys like "Point1", "Point2", ...
		local keys = {}
		for name in pairs(dictionary) do
			table.insert(keys, name)
		end
		table.sort(keys, function(a, b)
			local na = tonumber(type(a) == "string" and a:match("%d+") or a) or math.huge
			local nb = tonumber(type(b) == "string" and b:match("%d+") or b) or math.huge
			-- Fallback to string compare if no numeric suffix
			if na == math.huge and nb == math.huge then
				return tostring(a) < tostring(b)
			end
			return na < nb
		end)

		local array = {}
		for _, key in ipairs(keys) do
			table.insert(array, dictionary[key])
		end
		return array
	end

	-- Validate / coerce a single point into Vector3 or BasePart
	local function normalizePoint(p, idx)
		local t = typeof(p)
		if t == "Vector3" then
			return p -- static
		elseif t == "Instance" then
			if p:IsA("BasePart") then
				return p -- dynamic (best for moving targets)
			elseif p:IsA("Attachment") then
				warn(("BezierSetup: Point %d is an Attachment; using WorldPosition snapshot (static). Consider passing the parent BasePart for dynamic behavior."):format(idx))
				return p.WorldPosition
			else
				warn(("BezierSetup: Point %d is an Instance (%s) not supported; ignoring."):format(idx, p.ClassName))
				return nil
			end
		elseif t == "CFrame" then
			warn(("BezierSetup: Point %d is a CFrame; using .Position snapshot (static)."):format(idx))
			return p.Position
		else
			warn(("BezierSetup: Point %d has unsupported type %s; ignoring."):format(idx, t))
			return nil
		end
	end

	local PointsArray = ConvertToArray(PointsTable)

	-- Build a sanitized array of points the Bezier module accepts
	local sanitized = {}
	for i, point in ipairs(PointsArray) do
		local okPoint = normalizePoint(point, i)
		if okPoint ~= nil then
			table.insert(sanitized, okPoint)
		else
			-- stop early if anything critical is bad
			warn("BezierSetup: Aborting due to invalid point at index", i)
			return nil, nil
		end
	end

	if #sanitized == 0 then
		warn("BezierSetup: No valid points provided.")
		return nil, nil
	end

	-- Construct the Bezier (pass Vector3s and/or BaseParts directly)
	local newBezier = bezierModule.new(unpack(sanitized))

	-- Optional tween creation
	local Tween = nil
	if toTween == true then
		if object == nil then
			warn("BezierSetup: No object provided; cannot create tween.")
			return newBezier, nil
		end
		if #sanitized <= 1 then
			warn("BezierSetup: Need at least 2 points to create a CFrame tween (for direction).")
			return newBezier, nil
		end

		-- CFrame tween follows curve tangent; set relativeToLength=true to move by distance instead of param t
		Tween = newBezier:CreateCFrameTween(object, {"CFrame"}, info, relativeToLength == true)
	end

	return newBezier, Tween
end

function Utilities.PlaceAtFeet(characterOrPosition, object)
	local position

	-- Get position source
	if typeof(characterOrPosition) == "Instance" then
		local hrp = characterOrPosition:FindFirstChild("HumanoidRootPart")
		if hrp then
			position = hrp.Position
		elseif characterOrPosition:IsA("BasePart") then
			position = characterOrPosition.Position
		end
	elseif typeof(characterOrPosition) == "Vector3" then
		position = characterOrPosition
	end

	if not position then return end

	-- Raycast
	local rayParams = RaycastParams.new()
	if typeof(characterOrPosition) == "Instance" then
		rayParams.FilterDescendantsInstances = {characterOrPosition}
	end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(position, Vector3.new(0, -50, 0), rayParams)
	if not result then return end

	local groundPos = result.Position + Vector3.new(0, 0.15, 0)

	-- BASEPART
	if object:IsA("BasePart") then
		object.CFrame = CFrame.new(groundPos + Vector3.new(0, object.Size.Y/2, 0))

		-- MODEL
	elseif object:IsA("Model") and object.PrimaryPart then
		object:PivotTo(CFrame.new(groundPos))

		-- ATTACHMENT ✅
	elseif object:IsA("Attachment") and object.Parent:IsA("BasePart") then
		local parentPart = object.Parent

		-- Convert world position to parent local space
		local localPos = parentPart.CFrame:PointToObjectSpace(groundPos)

		object.CFrame = CFrame.new(localPos)
	end
end


function Utilities.PlaceAtFeet2(character, object)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Raycast setup
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {character}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Cast ray downwards
	local result = workspace:Raycast(hrp.Position, Vector3.new(0, -50, 0), rayParams)

	if result then
		-- Position object on ground using Position only
		if object:IsA("BasePart") then
			object.Position = result.Position + Vector3.new(0, object.Size.Y/2, 0) + Vector3.new(0, 0.15, 0) -- Test
		elseif object:IsA("Model") and object.PrimaryPart then
			object.PrimaryPart.Position = result.Position + Vector3.new(0, 0.15, 0) -- Test
		end
	end
end

function Utilities.ScaleModel(model: Model, targetScale, duration)
	if not model:IsA(`Model`) then return end
	task.spawn(function()
		local start = model:GetScale()
		local change = targetScale - start
		local steps = 60 -- how many increments (60 = ~1 second at 60fps)
		local stepTime = duration / steps

		for i = 1, steps do
			if not model then return end
			local alpha = i / steps
			local newScale = start + (change * alpha)

			-- clamp to positive non-zero values
			if newScale <= 0.05 then
				newScale = 0.05
			end

			model:ScaleTo(newScale)
			task.wait(stepTime)
		end

		-- snap to final target safely
		model:ScaleTo(targetScale)
	end)
end

function Utilities.getMouseTarget(player)
	-- screen position of mouse
	local mousePos = uis:GetMouseLocation()

	-- ray from camera through the mouse
	local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)

	-- configure raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {} -- include everything
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude 
	raycastParams.IgnoreWater = true

	-- raise origin by 2 studs upward
	local raisedOrigin = ray.Origin + Vector3.new(0, 2, 0)

	-- cast the ray
	local result = workspace:Raycast(raisedOrigin, ray.Direction * 500, raycastParams)

	-- calculate endpoint (hit position or max)
	local endPos = result and result.Position or (raisedOrigin + ray.Direction * 500)

	if result then
		print("Hit:", result.Instance:GetFullName())

		-- check if it's a player
		local character = result.Instance:FindFirstAncestorWhichIsA("Model")
		if character and Players:GetPlayerFromCharacter(character) then
			print("Hit player:", Players:GetPlayerFromCharacter(character).Name)
			return character
		end
	else
		print("Hit nothing")
		return nil
	end
end

function Utilities.getDirection(moveDir: Vector3)
	if moveDir.Magnitude < 0.1 then
		return "Idle"
	end

	-- Only care about XZ plane
	local angle = math.atan2(moveDir.X, moveDir.Z) -- radians

	-- Convert radians → degrees (0 = forward/north, clockwise rotation)
	local deg = math.deg(angle)
	if deg < 0 then
		deg = deg + 360
	end

	-- Each sector covers 45° (N, NE, E, SE, S, SW, W, NW)
	if deg >= 337.5 or deg < 22.5 then
		return "North"
	elseif deg < 67.5 then
		return "NorthEast"
	elseif deg < 112.5 then
		return "East"
	elseif deg < 157.5 then
		return "SouthEast"
	elseif deg < 202.5 then
		return "South"
	elseif deg < 247.5 then
		return "SouthWest"
	elseif deg < 292.5 then
		return "West"
	elseif deg < 337.5 then
		return "NorthWest"
	end
end

function Utilities.GetGroundedTarget(target, source, maxDistance, rayLength)
	-- Defaults
	maxDistance = maxDistance or 30
	rayLength = rayLength or 100

	-- Get source position (part/model/vector3)
	local sourcePos
	if typeof(source) == "Vector3" then
		sourcePos = source
	elseif typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			sourcePos = source.Position
		elseif source:IsA("Model") then
			local primary = source.PrimaryPart or source:FindFirstChildWhichIsA("BasePart")
			assert(primary, "Model has no PrimaryPart or BasePart")
			sourcePos = primary.Position
		else
			error("Unsupported source type: " .. source.ClassName)
		end
	else
		error("Source must be a Vector3, BasePart, or Model")
	end

	-- Get target position (part/model/vector3)
	local targetPos
	if typeof(target) == "Vector3" then
		targetPos = target
	elseif typeof(target) == "Instance" then
		if target:IsA("BasePart") then
			targetPos = target.Position
		elseif target:IsA("Model") then
			local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
			assert(primary, "Model has no PrimaryPart or BasePart")
			targetPos = primary.Position
		else
			error("Unsupported target type: " .. target.ClassName)
		end
	else
		error("Target must be a Vector3, BasePart, or Model")
	end

	-- Step 1: Clamp distance
	local direction = targetPos - sourcePos
	local distance = direction.Magnitude
	if distance > maxDistance then
		direction = direction.Unit * maxDistance
	end
	local clampedPos = sourcePos + direction

	-- Step 2: Raycast downward
	local rayOrigin = clampedPos + Vector3.new(0, 2, 0) -- raise ray start 2 studs higher
	local rayDirection = Vector3.new(0, -rayLength, 0)

	local raycastParams = RaycastParams.new()
	if typeof(source) == "Instance" then
		raycastParams.FilterDescendantsInstances = {source}
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	end

	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if result then
		return result.Position
	else
		return clampedPos + Vector3.new(0, 0.15, 0)
	end
end

-- Function to return an instance from a given directory
function Utilities.GetFromDirectory(directory)
	local children = directory:GetChildren()

	if #children == 0 then
		return nil
	end

	return children[math.random(#children)]
end

function Utilities.GetDifferentFromDirectory(directory, excludedSounds)
	local children = directory:GetChildren()
	if #children == 0 then
		return nil
	end

	-- Build exclusion set by SoundId
	local excluded = {}
	for _, sound in pairs(excludedSounds or {}) do
		if sound and sound.SoundId then
			excluded[sound.SoundId] = true
		end
	end

	-- Collect valid candidates
	local candidates = {}
	for _, child in ipairs(children) do
		if child:IsA("Sound") and not excluded[child.SoundId] then
			table.insert(candidates, child)
		end
	end

	-- Fallback if everything is excluded
	if #candidates == 0 then
		candidates = children
	end

	return candidates[math.random(#candidates)]
end

return Utilities
