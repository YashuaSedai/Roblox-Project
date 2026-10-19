-- ReplicatedFirst > Weaves > Effects > Air > LightningStrike > WeatherLightningEffect   (LocalScript)
--
-- Plays the lightning visuals for strikes that come from the WEATHER (no caster involved).
-- Same VFX asset as the Lightning Strike weave; LightningStrikeEffect is left untouched.

-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- MODULES
local Effects = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))

-- REMOTE (created by the WeatherLightning server script)
local WeatherLightningEvent = ReplicatedStorage:WaitForChild("WeatherLightningEvent")

-- VFX
local LightningStrike = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("VFX"):WaitForChild("LightningStrike")

-- SETTINGS
local PEAK_HEIGHT = 250
local SHAKE_RANGE = 150       -- the camera shakes if you are closer than this to the strike
local SHAKE_MAGNITUDE = 6.5   -- shake strength at point blank (fades out with distance)

local player = Players.LocalPlayer

local function R(x, y)
	return math.random(x, y)
end

WeatherLightningEvent.OnClientEvent:Connect(function(position: Vector3)
	if typeof(position) ~= "Vector3" then return end

	local newLightning = LightningStrike:Clone()
	newLightning.Parent = workspace

	-- the bolt: a jagged line from the ground up to the sky
	for i = 0, 5 do
		local joint = newLightning.Lightning[tostring(i)]
		local height = PEAK_HEIGHT * (i / 5)

		local x, z = 0, 0
		if i ~= 0 and i ~= 5 then
			x = R(-15, 15)
			z = R(-15, 15)
		end

		joint.Position = position + Vector3.new(x, height, z)
	end

	newLightning.Emitters.Emitters.CFrame = CFrame.new(position)

	-- put the ground mark on the floor
	local result = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -1000, 0))
	if result then
		newLightning.Emitters.Emitters.Mark.WorldPosition = result.Position + Vector3.new(0, 0.05, 0)
	end

	for _, v in newLightning.Emitters:GetDescendants() do
		if v:IsA("ParticleEmitter") and v:GetAttribute("EmitCount") then
			v:Emit(v:GetAttribute("EmitCount"))
		end

		if v:IsA("Sound") then
			v:Play()
		end
	end

	-- shake the camera, weaker the farther away you are
	local camera = workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - position).Magnitude
		if distance < SHAKE_RANGE then
			local magnitude = SHAKE_MAGNITUDE * (1 - distance / SHAKE_RANGE)
			Effects.ShakeCamera(player.UserId, true, nil, magnitude, 7, 0.25, 0.25)
		end
	end

	-- the bolt disappears from the top down
	task.spawn(function()
		for i = 5, 0, -1 do
			local joint = newLightning.Lightning:FindFirstChild(tostring(i))
			if joint then
				joint:Destroy()
			end
			task.wait(0.05)
		end
	end)

	-- the flash fades out
	task.spawn(function()
		local light = newLightning.Emitters.Emitters:FindFirstChild("PointLight")
		if light then
			Effects.NumberValueTweenObj(light, "PointLight", "Brightness", light.Brightness, 0.25, 0, 60)
		end
	end)

	task.delay(5, function()
		if newLightning then
			newLightning:Destroy()
		end
	end)
end)
