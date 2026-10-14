-- CustomShiftLock.lua (LocalScript, put in StarterPlayer > StarterPlayerScripts)

-- SERVICES
local UIS = game:GetService("UserInputService")
local Run = game:GetService("RunService")
local Players = game:GetService("Players")

-- SETTINGS
local TOGGLE_KEY = Enum.KeyCode.LeftShift
local PAUSE_KEY = Enum.KeyCode.LeftAlt          -- hold to free the cursor for UI
local SHIFTLOCK_OFFSET = Vector3.new(4, 1.5, 1)   -- camera offset while locked
local OFFSET_SPEED = 15                         -- how fast the camera slides in/out of the offset

-- STATE
local plr = Players.LocalPlayer
local camera = workspace.CurrentCamera

local hrp, hum
local enabled = false       -- shift lock toggled on
local paused = false        -- PAUSE_KEY held (cursor free for UI)
local currentOffset = Vector3.zero

local function applyState()
	local active = enabled and not paused

	if hum then
		hum.AutoRotate = not active
	end

	plr.CameraMaxZoomDistance = 16
	plr.CameraMinZoomDistance = enabled and 4 or 0

	UIS.MouseBehavior = active and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
end

local function update(dt)
	if not (hrp and hum and hrp.Parent) then return end

	-- Smoothly slide the camera offset instead of snapping
	local target = enabled and SHIFTLOCK_OFFSET or Vector3.zero
	currentOffset = currentOffset:Lerp(target, 1 - math.exp(-OFFSET_SPEED * dt))

	-- Height goes through the Humanoid (it doesn't depend on which way you face).
	-- Sideways/depth is applied in camera space right after the camera updates, so it
	-- can never trail behind the camera during fast mouse turns.
	hum.CameraOffset = Vector3.new(0, currentOffset.Y, 0)
	camera.CFrame = camera.CFrame * CFrame.new(currentOffset.X, 0, currentOffset.Z)

	if enabled and not paused then
		-- Re-assert the lock in case something else released it
		if UIS.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		end

		-- Face the camera's horizontal direction
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			local pos = hrp.Position
			hrp.CFrame = CFrame.lookAt(pos, pos + flat)
		end
	end
end

-- Run right AFTER the camera updates so the character never lags a frame behind it
Run:BindToRenderStep("CustomShiftLock", Enum.RenderPriority.Camera.Value + 1, update)

-- CHARACTER (handles respawns)
local function onCharacter(char)
	hrp = char:WaitForChild("HumanoidRootPart")
	hum = char:WaitForChild("Humanoid")
	currentOffset = Vector3.zero
	applyState()
end

plr.CharacterAdded:Connect(onCharacter)
if plr.Character then
	task.spawn(onCharacter, plr.Character)
end

-- INPUT
UIS.InputBegan:Connect(function(input, gpe)
	if input.KeyCode == PAUSE_KEY then
		paused = true
		applyState()
	elseif input.KeyCode == TOGGLE_KEY and not gpe then
		enabled = not enabled
		applyState()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == PAUSE_KEY and paused then
		paused = false
		applyState()
	end
end)

-- If the window loses focus while Alt is held (e.g. Alt-Tab), the release never arrives
UIS.WindowFocused:Connect(function()
	paused = false
	applyState()
end)
