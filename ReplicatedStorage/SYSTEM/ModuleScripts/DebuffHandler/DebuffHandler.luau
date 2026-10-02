-- SERVICE
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- REMOTES
local DebuffHandlerFolder = RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebuffHandler")
local DoTRemote = DebuffHandlerFolder:WaitForChild("DoT")
local DamageRemote = DebuffHandlerFolder:WaitForChild("Damage")
local StunRemote = DebuffHandlerFolder:WaitForChild("Stun")
local KnockbackRemote = DebuffHandlerFolder:WaitForChild("Knockback")
local RootRemote = DebuffHandlerFolder:WaitForChild("Root")
local FreezeRemote = DebuffHandlerFolder:WaitForChild("Freeze")
local Ice = DebuffHandlerFolder:WaitForChild("DebuffVFX"):WaitForChild("Ice")
local AnimationHandler = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))

-- MODULES
local Effects = require(RS:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("EffectsHandler"):WaitForChild("VFX"))

local DebuffHandler = {
	FreezeVFX = {},
	StunVFX = {},
	RootVFX = {}
}

-- FIRING DOT TO SERVER
function DebuffHandler.FireDoT(player: Player, userId: number, targetHumanoid: Humanoid, damage: number, duration: number, perTick: number)
	
	if player == nil then warn("DoT did not receive a player, cannot fire to server") return end
	if userId == nil then warn("DoT did not receive a userId, cannot fire to server") return end
	if targetHumanoid == nil then warn("DoT did not receive a target humanoid, cannot fire to server") return end
	if damage == nil then warn("DoT did not receive a damage value, cannot fire to server") return end
	if duration == nil then warn("DoT did not receive a duration value, cannot fire to server") return end
	if perTick == nil then warn("DoT did not receive a perTick value, cannot fire to server") return end
	
	DoTRemote:FireServer(userId, targetHumanoid, damage, duration, perTick)
	
end

-- FUNCTION TO DEAL DAMAGE OVER TIME
function DebuffHandler.DoT(player: Player, userId: number, targetHumanoid: Humanoid, damage: number, duration: number, perTick: number)
	if player == nil then warn("DoT did not receive a player") return end
	if userId == nil then warn("DoT did not receive a userId") return end
	if targetHumanoid == nil then warn("DoT did not receive a target humanoid") return end
	if damage == nil then warn("DoT did not receive a damage value") return end
	if duration == nil then warn("DoT did not receive a duration value") return end
	if perTick == nil then warn("DoT did not receive a perTick value") return end

	if player.UserId == userId then
		local tickDamage = damage / (duration / perTick) -- Splitting total damage over time
		local elapsedTime = 0

		local function applyDoT()
			while elapsedTime < duration do
				if targetHumanoid and targetHumanoid.Health > 0 then
					targetHumanoid:TakeDamage(tickDamage)
					DebuffHandler.LastAttackerAndDamage(player, targetHumanoid, tickDamage)
				else
					break -- Stop if target is dead
				end
				elapsedTime += perTick
				task.wait(perTick)
			end
		end

		task.spawn(applyDoT) -- Runs the DoT in the background
	end
end

-- FIRING DAMAGE TO SERVER
function DebuffHandler.FireDamage(player: Player, userId: number, targetHumanoid: Humanoid, damage: number)

	if player == nil then warn("Damage did not receive a player, cannot fire to server") return end
	if userId == nil then warn("Damage did not receive a userId, cannot fire to server") return end
	if targetHumanoid == nil then warn("Damage did not receive a target humanoid, cannot fire to server") return end
	if damage == nil then warn("Damage did not receive a damage value, cannot fire to server") return end
	
	DamageRemote:FireServer(userId, targetHumanoid, damage)

end

-- FUNCTION TO DEAL DAMAGE ONCE
function DebuffHandler.Damage(player: Player, userId: number, targetHumanoid:Humanoid, damage: number)
	if player == nil then warn("Damage did not receive a player") return end
	if userId == nil then warn("Damage did not receive a userId") return end
	if targetHumanoid == nil then warn("Damage did not receive a target humanoid") return end
	if damage == nil then warn("Damage did not receive a damage value") return end
	
	if player.UserId == userId then
		targetHumanoid:TakeDamage(damage)
		DebuffHandler.LastAttackerAndDamage(player, targetHumanoid, damage)
	end
end

-- FIRING STUN TO SERVER
function DebuffHandler.FireStun(player: Player, userId: number, targetCharacter: Model?, duration: number)
	if player == nil then warn("Stun did not receive a player, cannot fire to server") return end
	if userId == nil then warn("Stun did not receive a userId, cannot fire to server") return end
	if targetCharacter == nil then warn("Stun did not receive a target character, cannot fire to server") return end
	if duration == nil then warn("Stun did not receive a damage value, cannot fire to server") return end
	
	StunRemote:FireServer(targetCharacter, duration)
	
end

-- FIRING KNOCKBACK TO SERVER
function DebuffHandler.FireKnockback(player: Player, obj: Instance, targetCharacter: Model?, duration: number, forceValue: number, upwardForce: number, rotationvalue: number)
	if player == nil then warn("Knockback did not receive a player, cannot fire to server") return end
	if targetCharacter == nil then warn("Knockback did not receive a target character, cannot fire to server") return end
	if duration == nil then warn("Knockback did not receive a damage value, cannot fire to server") return end

	KnockbackRemote:FireServer(obj, targetCharacter, duration, forceValue, upwardForce, rotationvalue)

end

-- FUNCTION TO KNOCKBACK A PLAYER
function DebuffHandler.Knockback(obj, targetCharacter: Model?, duration: number, forceValue: number, upwardForce: number?, rotationValue: number)
	local targetHumanoidRP = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not targetHumanoidRP then warn("Target Humanoid Root Part cannot be found, knockback failed") return end
	if not targetCharacter:GetAttribute("Ragdolled") then warn("Target isn't ragdolled yet at this point") end

	local targetplayer = Players:GetPlayerFromCharacter(targetCharacter)
	local targetMass = targetHumanoidRP:GetMass() -- Get the target's mass

	-- Ensure mass is reasonable (avoid division by zero)
	if targetMass <= 0 then targetMass = 1 end 

	-- Adjust force to maintain consistent acceleration
	local adjustedForce = forceValue * (1 / targetMass) -- Normalize force by mass
	local adjustedUpwardForce = (upwardForce or 0) * (1 / targetMass) -- Scale vertical force too

	-- IF PLAYER
	if targetplayer then
		warn (`{targetplayer.Name} got knocked back`)
		if obj and targetHumanoidRP then
			local direction = (targetHumanoidRP.Position - obj.Position).unit
			local att = Instance.new("Attachment", targetHumanoidRP)
			local force = Instance.new("VectorForce", targetHumanoidRP)
			force.Attachment0 = att	
			force.Force = (direction + Vector3.new(0, adjustedUpwardForce, 0)).Unit * adjustedForce
			force.RelativeTo = Enum.ActuatorRelativeTo.World

			local rotation = Instance.new("AngularVelocity", targetHumanoidRP)
			rotation.Attachment0 = att
			rotation.AngularVelocity = Vector3.new(1, 1, 1) * rotationValue
			rotation.MaxTorque = math.huge
			rotation.RelativeTo = Enum.ActuatorRelativeTo.Attachment0

			-- Cleanup after duration
			game.Debris:AddItem(force, 0.2)
			game.Debris:AddItem(rotation, 0.2)
			game.Debris:AddItem(att, 0.2)
		end
	else
		-- IF NOT PLAYER
		warn(`A non-player got knocked back`)
		--local LinearVelocity = Instance.new("LinearVelocity", targetHumanoidRP)
		--LinearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		--LinearVelocity.MaxForce = adjustedForce * 10 -- Ensure it can overcome resistance

		---- Calculate knockback direction
		--local knockbackDirection = (targetHumanoidRP.Position - obj.Position).unit
		--knockbackDirection = Vector3.new(knockbackDirection.X, math.abs(knockbackDirection.Y), knockbackDirection.Z)

		---- Scale upward force relative to knockback force
		--local verticalBoost = Vector3.new(0, adjustedUpwardForce, 0)

		---- Apply force
		--local finalVelocity = (knockbackDirection * adjustedForce) + verticalBoost

		---- Ensure Y-component is positive
		--if finalVelocity.Y < 0 then
		--	finalVelocity = Vector3.new(finalVelocity.X, math.abs(finalVelocity.Y), finalVelocity.Z)
		--end

		--LinearVelocity.VectorVelocity = finalVelocity

		---- Attachments
		--local Att = Instance.new("Attachment", targetHumanoidRP)
		--LinearVelocity.Attachment0 = Att

		---- Cleanup after duration
		--game.Debris:AddItem(LinearVelocity, 0.2)
		--game.Debris:AddItem(Att, 0.2)
		if obj and targetHumanoidRP then
			local direction = (targetHumanoidRP.Position - obj.Position).unit
			local att = Instance.new("Attachment", targetHumanoidRP)
			local force = Instance.new("VectorForce", targetHumanoidRP)
			force.Attachment0 = att	
			
			local rawForceDir = direction + Vector3.new(0, adjustedUpwardForce, 0)
			if rawForceDir.Magnitude == 0 then rawForceDir = Vector3.new(0, 1, 0) end
			force.Force = rawForceDir.Unit * adjustedForce
			
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			targetCharacter.Humanoid.PlatformStand = true

			local rotation = Instance.new("AngularVelocity", targetHumanoidRP)
			rotation.Attachment0 = att
			rotation.AngularVelocity = Vector3.new(1, 1, 1) * rotationValue
			rotation.MaxTorque = math.huge
			rotation.RelativeTo = Enum.ActuatorRelativeTo.Attachment0

			-- Cleanup after duration
			game.Debris:AddItem(force, 0.2)
			game.Debris:AddItem(rotation, 0.2)
			game.Debris:AddItem(att, 0.2)
			
			task.wait(duration)
			targetCharacter.Humanoid.PlatformStand = false
		end
	end
end

-- FUNCTION TO RAGDOLL A PLAYER
function DebuffHandler.Ragdoll(player: Player, targetCharacter: Model?, duration: number | boolean)
	if not player then 
		warn("Ragdoll did not receive a player") 
		return 
	end
	if not targetCharacter then 
		warn("Ragdoll did not receive a target character") 
		return 
	end
	if duration == nil then 
		warn("Ragdoll did not receive a duration") 
		return 
	end

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- For stacking, track total ragdoll duration and count
	local currentDuration = targetCharacter:GetAttribute("RagdollDuration") or 0
	local currentCount = targetCharacter:GetAttribute("RagdollCount") or 0

	if typeof(duration) == "number" then
		-- Increase duration and count
		targetCharacter:SetAttribute("RagdollDuration", currentDuration + duration)
		targetCharacter:SetAttribute("RagdollCount", currentCount + 1)
		targetCharacter:SetAttribute("Ragdolled", true)

		-- If the target is an NPC (not a player character), force physics mode
		local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
		if humanoid and not targetPlayer then
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end

		-- Apply the ragdoll effect if not already applied
		DebuffHandler.ApplyRagdoll(targetCharacter)

		-- Start a countdown to reduce the ragdoll duration
		task.spawn(function()
			while targetCharacter:GetAttribute("RagdollDuration") > 0 do
				task.wait(1)
				local newDuration = targetCharacter:GetAttribute("RagdollDuration") - 1
				targetCharacter:SetAttribute("RagdollDuration", math.max(newDuration, 0))
				-- When duration reaches zero, decrement the ragdoll count
				if targetCharacter:GetAttribute("RagdollDuration") == 0 then
					local newCount = targetCharacter:GetAttribute("RagdollCount") - 1
					targetCharacter:SetAttribute("RagdollCount", math.max(newCount, 0))
				end
			end

			-- Only unragdoll if all sources have expired
			if targetCharacter:GetAttribute("RagdollCount") == 0 then
				DebuffHandler.Unragdoll(targetCharacter)
			end
		end)

	elseif typeof(duration) == "boolean" then
		-- Boolean case: if true, force ragdoll indefinitely; if false, unragdoll immediately
		if duration then
			targetCharacter:SetAttribute("Ragdolled", true)
			targetCharacter:SetAttribute("RagdollCount", currentCount + 1)
			if humanoid then
				humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			end
			DebuffHandler.ApplyRagdoll(targetCharacter)
		else
			-- When duration is false, we reduce the count and unragdoll if no more sources remain
			local newCount = targetCharacter:GetAttribute("RagdollCount") - 1
			targetCharacter:SetAttribute("RagdollCount", math.max(newCount, 0))
			if targetCharacter:GetAttribute("RagdollCount") == 0 then
				DebuffHandler.Unragdoll(targetCharacter)
			end
		end
	end
end

------------------------------------------------------------
-- FUNCTION TO APPLY THE RAGDOLL EFFECT (Common code)
function DebuffHandler.ApplyRagdoll(targetCharacter: Model)
	-- Loop through all Motor6Ds to disable them and add BallSocketConstraints
	for _, joint in pairs(targetCharacter:GetDescendants()) do
		if joint:IsA("Motor6D") then
			-- Exclude the neck joint so the head doesn't dangle
		
				-- Only apply if not already ragdolled (check for existing constraint)
				if not joint:FindFirstChild("RagdollSocket") then
					local socket = Instance.new("BallSocketConstraint")
					socket.Name = "RagdollSocket"
					socket.Parent = joint.Parent

					local att0 = Instance.new("Attachment")
					att0.Parent = joint.Part0
					local att1 = Instance.new("Attachment")
					att1.Parent = joint.Part1

					att0.CFrame = joint.C0
					att1.CFrame = joint.C1

					socket.Attachment0 = att0
					socket.Attachment1 = att1
					socket.TwistLimitsEnabled = true
					socket.LimitsEnabled = true

					joint.Enabled = false
				end
			
		end
	end
end

------------------------------------------------------------
-- FUNCTION TO UNRAGDOLL A PLAYER
function DebuffHandler.Unragdoll(targetCharacter: Model)
	if not targetCharacter then 
		warn("Unragdoll did not receive a target character") 
		return 
	end

	targetCharacter:SetAttribute("Ragdolled", false)

	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Optional: Change state to GettingUp or another appropriate state
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	-- Restore joints by re-enabling them and removing constraints
	for _, joint in pairs(targetCharacter:GetDescendants()) do
		if joint:IsA("Motor6D") then
			joint.Enabled = true
		end

		if joint:IsA("BallSocketConstraint") and joint.Name == "RagdollSocket" then
			if joint.Attachment0 then joint.Attachment0:Destroy() end
			if joint.Attachment1 then joint.Attachment1:Destroy() end
			joint:Destroy()
		end
	end
end

-- FUNCTION TO STUN A PLAYER
function DebuffHandler.Stun(player: Player, targetCharacter: Model?, duration: number)
	
end

-- FIRING FREEZE TO SERVER
function DebuffHandler.FireFreeze(player: Player, userId: number, targetCharacter: Model?, duration: number)
	if player == nil then warn("Freeze did not receive a player, cannot fire to server") return end
	if userId == nil then warn("Freeze did not receive a userId, cannot fire to server") return end
	if targetCharacter == nil then warn("Freeze did not receive a target character, cannot fire to server") return end
	if duration == nil then warn("Freeze did not receive a duration number, cannot fire to server") return end

	FreezeRemote:FireServer(targetCharacter, duration)

end

-- FUNCTION TO FREEZE A PLAYER
function DebuffHandler.Freeze(player: Player, targetCharacter: Model?, duration: number)
	if not player then warn("Freeze did not receive a player") return end
	if not targetCharacter then warn("Freeze did not receive a target character") return end
	if not duration then warn("Freeze did not receive a duration") return end

	local humanoidRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
	local humanoid = targetCharacter:FindFirstChild("Humanoid")

	if not humanoidRootPart or not humanoid then
		warn(`Freeze failed: No HumanoidRootPart: {humanoidRootPart} or Humanoid: {humanoid} found`)
		return
	end

	-- Get current freeze duration and extend it
	local currentDuration = targetCharacter:GetAttribute("FrozenDuration") or 0
	targetCharacter:SetAttribute("FrozenDuration", currentDuration + duration)
	targetCharacter:SetAttribute("Frozen", true)
	
	-- If already frozen, do not start a new freeze process
	if currentDuration > 0 then
		return
	end
	
	-- Create Ice Vfx for player
	if not DebuffHandler.FreezeVFX[targetCharacter] then
		DebuffHandler.FreezeVFX[targetCharacter] = {}
	end

	local iceEffect = DebuffHandler.FreezeVisual(targetCharacter, player.Name)

	table.insert(DebuffHandler.FreezeVFX[targetCharacter], iceEffect)

	-- Store original anchored states
	local originalAnchors = {}

	-- Anchor all body parts
	for _, part in ipairs(targetCharacter:GetDescendants()) do
		if part:IsA("BasePart") and part ~= humanoidRootPart then -- Exclude root part for stability
			originalAnchors[part] = part.Anchored
			part.Anchored = true
		end
	end

	-- Disable movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0

	-- Continuously update FrozenDuration and unfreeze when it reaches 0
	task.spawn(function()
		while targetCharacter:GetAttribute("FrozenDuration") > 0 do
			task.wait(1)
			local newDuration = targetCharacter:GetAttribute("FrozenDuration") - 1
			targetCharacter:SetAttribute("FrozenDuration", math.max(newDuration, 0))
		end

		-- Unfreeze the character once the duration expires
		if targetCharacter and humanoid then
			
			-- Immediately Set Frozen Attribute to False
			targetCharacter:SetAttribute("Frozen", false)
			
			-- Check whether unanchoring is allowed
			local flag = DebuffHandler.CheckUnanchor(targetCharacter)
			local startTime = tick()  -- Start measuring time

			-- Standard repeat-until loop
			repeat
				flag = DebuffHandler.CheckUnanchor(targetCharacter)
				task.wait()  -- Waits for 1 second
			until flag == true or tick() - startTime >= 2  -- Waits for flag to be true or 2 seconds to pass

			if flag == false then return end
			
			-- Unanchor if unanchoring is allowed
			for part, wasAnchored in pairs(originalAnchors) do
				if part then
					part.Anchored = false
				end
			end
			
			-- Check status whether returning original walkspeed and jumppower is allowed
			if DebuffHandler.CheckStatus(targetCharacter) then
				humanoid.WalkSpeed = 16 -- Default WalkSpeed
				humanoid.JumpPower = 50 -- Default JumpPower
			end
			
			-- Clean up the ice
			if DebuffHandler.FreezeVFX[targetCharacter] then
				for _, ice in ipairs(DebuffHandler.FreezeVFX[targetCharacter]) do
					if ice then 
						ice:FindFirstChild("ice heavy impact"):Play()
						
						for _, weldconstraint in ice:GetChildren() do
							if weldconstraint and weldconstraint:IsA("WeldConstraint") then 
								weldconstraint:Destroy();
							end
						end
						
						for _, union in ice:GetChildren() do
							if union and union:IsA("UnionOperation") then
								union.CanCollide = true
							end
						end
						
						task.delay(2, function()
							
							if ice and ice.Smoke then 
								ice.Smoke.Enabled = false 
								Effects.NumberValueTweenObj(ice.Smoke, "ParticleEmitter", "Transparency", 0, 2, 1, 60)
							end
							
							-- Tween union size 
							for _, union in ice:GetChildren() do
								if union and union:IsA("UnionOperation") then
									-- Tween the Size to 0 before destruction
									local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) -- 1.5s duration
									local goal = {Size = Vector3.new(0.1, 0.1, 0.1)} -- Minimum size before destruction
									local tween = TweenService:Create(union, tweenInfo, goal)
									tween:Play()
									
								end
							end
							
							task.wait(2)
							ice:Destroy() 
						end)
					end
				end
				DebuffHandler.FreezeVFX[targetCharacter] = nil
			end
		end
	end)
end

-- FUNCTION TO CREATE ICE AROUND PLAYER
function DebuffHandler.FreezeVisual(targetCharacter: Model?, Name: string)
	
	local newIce = Ice:Clone()
	
	local humanoidRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
	newIce.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 3.25, 0)
	newIce.Rotation = Vector3.new(
			0, -- Random X rotation
			math.random(0, 360), -- Random Y rotation
			0  -- Random Z rotation
		)

	newIce.Parent = workspace
	newIce.Name = "Freeze_ICE_" .. Name
	
	return newIce
end

-- FIRING ROOT TO SERVER
function DebuffHandler.FireRoot(player: Player, userId: number, targetCharacter: Model?, duration: number | boolean)
	if player == nil then warn("Root did not receive a player, cannot fire to server") return end
	if userId == nil then warn("Root did not receive a userId, cannot fire to server") return end
	if targetCharacter == nil then warn("Root did not receive a target character, cannot fire to server") return end
	if duration == nil then warn("Root did not receive a duration number or boolean value, cannot fire to server") return end
	
	RootRemote:FireServer(targetCharacter, duration)
	
end

-- FUNCTION TO ROOT A PLAYER
function DebuffHandler.Root(player: Player, targetCharacter: Model?, duration: number | boolean)
	if not player then warn("Root did not receive a player") return end
	if not targetCharacter then warn("Root did not receive a target character") return end
	if duration == nil then warn("Root did not receive a duration") end
	
	local humanoidRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
	local humanoid = targetCharacter:FindFirstChild("Humanoid")
	
	local rootCount = targetCharacter:GetAttribute("RootCount") or 0
	
	-- Dictionary for storing roots
	if not DebuffHandler.RootVFX[targetCharacter] then
		DebuffHandler.RootVFX[targetCharacter] = {}
	end
	
	if duration and typeof(duration) == "number" then
		
		-- Get current root duration and extend it
		local currentDuration = targetCharacter:GetAttribute("RootDuration") or 0
		targetCharacter:SetAttribute("RootDuration", currentDuration + duration)
		
		targetCharacter:SetAttribute("Rooted", true)
		targetCharacter:SetAttribute("RootCount", rootCount + 1) -- Increment root counter

		-- Anchor all body parts
		for _, part in ipairs(targetCharacter:GetDescendants()) do
			if part:IsA("BasePart") then
				DebuffHandler.RootVFX[targetCharacter][part] = part.Anchored
				part.Anchored = true
			end
		end

		-- Disable movement
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		
		task.spawn(function()
			while targetCharacter:GetAttribute("RootDuration") > 0 do
				task.wait(1)
				local newDuration = targetCharacter:GetAttribute("RootDuration") - 1
				targetCharacter:SetAttribute("RootDuration", math.max(newDuration, 0))
				
				-- Update RootCount when duration ends
				if targetCharacter:GetAttribute("RootDuration") == 0 then
					local updatedRootCount = targetCharacter:GetAttribute("RootCount") - 1
					targetCharacter:SetAttribute("RootCount", math.max(updatedRootCount, 0))
				end
			end

			if targetCharacter:GetAttribute("RootCount") == 0 then
				if targetCharacter and humanoid then
					
					-- Check whether unanchoring is allowed
					local flag = DebuffHandler.CheckUnanchor(targetCharacter)
					local startTime = tick()  -- Start measuring time

					-- Standard repeat-until loop
					repeat
						flag = DebuffHandler.CheckUnanchor(targetCharacter)
						task.wait()  -- Waits for 1 second
					until flag == true or tick() - startTime >= 2  -- Waits for flag to be true or 2 seconds to pass

					if flag == false then return end
					
					-- Unanchor parts
					for part, wasAnchored in pairs(DebuffHandler.RootVFX[targetCharacter]) do
						if part then
							part.Anchored = false
						end
					end

					targetCharacter:SetAttribute("Rooted", false)

					if DebuffHandler.CheckStatus(targetCharacter) then
						humanoid.WalkSpeed = 16 -- Default WalkSpeed
						humanoid.JumpPower = 50 -- Default JumpPower
					end

				end
			end
		end)
		
	elseif typeof(duration) == "boolean" then
		if duration then
			targetCharacter:SetAttribute("Rooted", true)
			targetCharacter:SetAttribute("RootCount", rootCount + 1) -- Increment root counter
			-- Anchor all body parts
			for _, part in ipairs(targetCharacter:GetDescendants()) do
				if part:IsA("BasePart") and part ~= humanoidRootPart then -- Exclude root part for stability
					DebuffHandler.RootVFX[targetCharacter][part] = part.Anchored
					part.Anchored = true
				end
			end

			-- Disable movement
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			
		elseif duration == false then
			
			if targetCharacter and humanoid then
				
				-- Set root to false
				targetCharacter:SetAttribute("Rooted", false)
				
				local updatedRootCount = targetCharacter:GetAttribute("RootCount") - 1
				targetCharacter:SetAttribute("RootCount", math.max(updatedRootCount, 0))
				
				print(`ROOT COUNT IS ABOUT TO BE SUBTRACTED`)
				if targetCharacter:GetAttribute("RootCount") == 0 then
					print(`ROOT COUNT IS ZERO HANDLING  UNANCHORING NOW`)
					
					-- Check whether unanchoring is allowed
					local flag = DebuffHandler.CheckUnanchor(targetCharacter)
					print(`INITIAL FLAG IS: {flag}`)
					local startTime = tick()  -- Start measuring time

					-- Standard repeat-until loop
					repeat
						flag = DebuffHandler.CheckUnanchor(targetCharacter)
						task.wait()  -- Waits for 1 second
					until flag == true or tick() - startTime >= 2  -- Waits for flag to be true or 2 seconds to pass
					
					print(`LAST FLAG IS: {flag}`)
					if flag == false then return end

					-- Unanchor if allowed
					for part, wasAnchored in pairs(DebuffHandler.RootVFX[targetCharacter]) do
						if part then
							part.Anchored = false
							print(`{part.Anchored} from {targetCharacter}`)
						end
					end

					if DebuffHandler.CheckStatus(targetCharacter) then
						humanoid.WalkSpeed = 16 -- Default WalkSpeed
						humanoid.JumpPower = 50 -- Default JumpPower
					end
				end
			end
		end
	end
end

-- LAST ATTACKER AND LAST DAMAGE
function DebuffHandler.LastAttackerAndDamage(player: Player, targetHumanoid: Humanoid, damage: number)
	if player == nil then warn("Last Attacker/Damage did not receive a player") return end
	if targetHumanoid == nil then warn("Last Attacker/Damage did not receive a humanoid") return end
	
	targetHumanoid:SetAttribute("LastAttacker", player.UserId)
	targetHumanoid:SetAttribute("LastDamage", damage)
end

-- PROJECTILE OWNER SETTER
function DebuffHandler.SetOwner(object, name)
	object:SetAttribute("Owner", name)
end

-- CHECKS STATUS
function DebuffHandler.CheckStatus(char: Model?)
	if not char:GetAttribute("Frozen") and not char:GetAttribute("Shielded") and not char:GetAttribute("Rooted") and not char:GetAttribute("Stunned") and not char:GetAttribute("Ragdolled") then
		return true
	else 
		return false
	end 
end

-- CHECKS FOR STATUS THAT WILL BE AFFECTED BY UNANCHOR
function DebuffHandler.CheckUnanchor(char: Model?)
	if not char:GetAttribute("Frozen") and not char:GetAttribute("Rooted") then
		return true
	else 
		return false
	end 
end

-- CHECKS FOR STATUS THAT WILL BE AFFECTED BY RAGDOLLING
function DebuffHandler.CheckRagdoll(char: Model?)
	if not char:GetAttribute("Ragdolled") and not char:GetAttribute("Stunned") then
		return true
	else 
		return false
	end 
end

-- DEDUCTS BARRIER HEALTH
function DebuffHandler.DeductBarrierHealth(barrierHealth, amount)
	
	barrierHealth.Value = barrierHealth.Value - amount
	
end

return DebuffHandler
