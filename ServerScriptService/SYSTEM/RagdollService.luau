local Players = game:GetService("Players")

local MAX_DURATION = 10

local RagdollService = {}
local active = {} -- [character] = { endsAt = number, parts = { {joint, socket, att0, att1}, ... } }

local ragdolledEvent = Instance.new("BindableEvent")       -- NEW
RagdollService.Ragdolled = ragdolledEvent.Event            -- NEW

local function ragdollJoints(char)
	local list = {}
	for _, joint in char:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Enabled and joint.Part0 and joint.Part1 then
			local att0 = Instance.new("Attachment")
			att0.Name = "RagdollAtt0"
			att0.CFrame = joint.C0
			att0.Parent = joint.Part0

			local att1 = Instance.new("Attachment")
			att1.Name = "RagdollAtt1"
			att1.CFrame = joint.C1
			att1.Parent = joint.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollSocket"
			socket.Attachment0 = att0
			socket.Attachment1 = att1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.Parent = joint.Parent

			joint.Enabled = false
			table.insert(list, { joint = joint, socket = socket, att0 = att0, att1 = att1 })
		end
	end
	return list
end

function RagdollService.IsRagdolled(char)
	return active[char] ~= nil
end

function RagdollService.Release(char)
	local state = active[char]
	if not state then return end
	active[char] = nil

	for _, p in state.parts do
		if p.joint.Parent then p.joint.Enabled = true end
		p.socket:Destroy()
		p.att0:Destroy()
		p.att1:Destroy()
	end

	if char.Parent then
		char:SetAttribute("Ragdolled", false)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

function RagdollService.Ragdoll(char, duration)
	if typeof(char) ~= "Instance" or not char:IsA("Model") then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if typeof(duration) ~= "number" or duration ~= duration or duration <= 0 then return end
	duration = math.min(duration, MAX_DURATION)

	local endsAt = os.clock() + duration
	local state = active[char]
	if state then
		state.endsAt = math.max(state.endsAt, endsAt) -- hit again: refresh the timer, don't stack
		return
	end

	state = { endsAt = endsAt, parts = ragdollJoints(char) }
	active[char] = state
	char:SetAttribute("Ragdolled", true)
	ragdolledEvent:Fire(char)             

	-- a player's own client simulates their character and reacts to the attribute (DebuffHandler.local);
	-- NPCs are simulated by the server, so switch their state here
	if not Players:GetPlayerFromCharacter(char) then
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end

	task.spawn(function()
		while active[char] == state do
			local remaining = state.endsAt - os.clock()
			if remaining <= 0 or hum.Health <= 0 or not char.Parent then break end
			task.wait(math.min(remaining, 0.25))
		end
		if active[char] == state then
			RagdollService.Release(char)
		end
	end)
end

return RagdollService