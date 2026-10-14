-- ReplicatedFirst > Weaves > Effects > Spirit > VeilOfReflection > VeilOfReflectionFollow   (LocalScript, NEW)
--
-- The server places the barrier (so hits are decided by the server), but it only replicates a few times a second,
-- which looks choppy when you turn. So every client re-poses each barrier here, every frame, from the caster's own
-- character (which is always smooth). Nothing here decides anything: it only changes where the barrier is DRAWN.
--
-- HOLD_OFFSET and FACING must match the ones in VeilOfReflectionScript (server).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TAG = "VeilOfReflectionBarrier" -- the server tags every barrier model with this
local HOLD_OFFSET = CFrame.new(0, 1.5, -4)
local FACING = CFrame.Angles(0, math.rad(90), 0)

local barriers = {} -- [model] = true

local function track(model)
	if model:IsA("Model") then
		barriers[model] = true
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(model)
	barriers[model] = nil
end)
for _, model in CollectionService:GetTagged(TAG) do
	track(model)
end

RunService.RenderStepped:Connect(function()
	for model in barriers do
		if not model.Parent then
			barriers[model] = nil
		elseif not model:GetAttribute("Broken") then -- a broken barrier stays where it broke while it fades
			local owner = Players:FindFirstChild(tostring(model:GetAttribute("Owner") or ""))
			local char = owner and owner.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				model:PivotTo(root.CFrame * HOLD_OFFSET * FACING)
			end
		end
	end
end)
