--=========================================== MAIN REQUIREMENTS ===========================================
-- SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

-- INITIALIZATION
local Player = Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRP = Character:WaitForChild("HumanoidRootPart")
local Animator = Humanoid:FindFirstChildOfClass("Animator")
local Mouse = Player:GetMouse()

-- CONTROLS
local PlayerScripts = Player:WaitForChild("PlayerScripts")
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()
Controls:Disable()
task.wait()
Controls:Enable()

-- MODULES
local ElementalHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("ElementalHandler"):WaitForChild("ElementalHandler"))
local WeavingModule = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingModule"))
local GuiRelatedThings = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("GUI"):WaitForChild("GuiRelatedThings"))
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationHandler"))
local Utilities = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("UTILITIES"))
local Dictionary = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("Dictionary"))
local MovementService = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("MovementService"))
local LinkData = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("LinkData"))

local DebounceHandler = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("DebounceHandler"):WaitForChild("Debounces"))
--=========================================== MAIN REQUIREMENTS ===========================================

--=========================================== CORE REQUIREMENTS =========================================== 
-- GENERIC
local ElementalMixing = ReplicatedStorage:WaitForChild("ElementalMixing")
local Assign = ElementalMixing:WaitForChild("Assign")
local DrawEvent = ElementalMixing:WaitForChild("Drawing"):WaitForChild("Draw")
local WeavingEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingEvent")
local WeavingInstantEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantEvent")
local WeavingInstantReleaseEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingInstantReleaseEvent")
local WeavingFxEvent = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxEvent")
local WeavingFxClear = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("WeavingFxClear")
local InversingRemote = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("WeavingModule"):WaitForChild("InversingRemote")
local ChargeEvent = ReplicatedStorage:WaitForChild("ElementalMixing"):WaitForChild("Charging"):WaitForChild("Charge")
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")

-- PLAYER STATS
local leaderstats = Player:WaitForChild("leaderstats")
local Level = leaderstats:WaitForChild("Level")
local Exp = leaderstats:WaitForChild("Exp")
local Marks = leaderstats:WaitForChild("Marks")
--=========================================== CORE REQUIREMENTS =========================================== 

--=========================================== ANIMATIONS =========================================== 
local Animations = {
	Default = {Id = "139743518303099", Track = nil},
	Draw1 = {Id = "103432995574444", Track = nil},
	Draw2 = {Id = "94041050623006", Track = nil},
}

-- Iterate through the animations table and load animations
for _, animData in pairs(Animations) do
	if animData and animData.Id then
		-- Call AnimationLoader with the animator and animation ID
		animData.Track = AnimationHandler.AnimationLoader(Animator, animData.Id)
	end
end

Animations.Default.Track.Looped = true
AnimationHandler.LoadAnimations(Animator)
AnimationHandler.LoadAllAnimations(Character)
--=========================================== ANIMATIONS =========================================== 


-- INITIALIZE SLOTS
task.spawn(function()
	local gui = Character:WaitForChild("Head"):WaitForChild("SlotsUI"):WaitForChild("BillboardGui", math.huge)
	local function show(child)
		if child:IsA("Frame") then child.Visible = true end
	end
	for _, child in gui:GetChildren() do show(child) end
	gui.ChildAdded:Connect(show) -- a slot that arrives late still gets turned on
end)

-- VARIABLES
local elementKeyMap = {
	[Enum.KeyCode.One] = "Fire",
	[Enum.KeyCode.Two] = "Water",
	[Enum.KeyCode.Three] = "Earth",
	[Enum.KeyCode.Four] = "Air",
	[Enum.KeyCode.Five] = "Spirit"
}

-- MAIN CONTROL TO TOGGLE WEAVING
UserInputService.InputBegan:Connect(function(input, gpe)
	if input.KeyCode ~= Enum.KeyCode.LeftAlt then return end
	ElementalHandler.IsWeaving(Player, gpe)
end)

-- MAIN CONTROL FOR ADDING/REMOVING ELEMENTS
UserInputService.InputBegan:Connect(function(input, gpe)
	local element = elementKeyMap[input.KeyCode]
	if element then
		ElementalHandler.MainHandler(Player, input, gpe, Animations)
	elseif input.KeyCode == Enum.KeyCode.Q then
		ElementalHandler.DeleterHandler(Player, input, gpe, Animations)
	end
end)

local inputDebounce = false
-- The clean up of the cast that is being held right now (nil when nothing is held).
-- The four connections of a cast (key release, death, status effect, source depleted) are LOCAL to that cast, see BeginCast.
-- They used to be shared variables: pressing R (Stilling) while E (Shielding) was still held overwrote them, so letting go of E
-- later disconnected the STILLING's key-release listener and the weave sat in "Holding" until the 20s timeout.
local activeCast = nil

-- CONTROL FOR RELEASING THE WEAVE
-- E casts a normal weave. R casts a weave that REQUIRES LINKING (Dictionary: RequiresLink = true).
-- Both keys run the same code below; castKey is the key that was pressed, and it is also the key whose release ends the cast.
local function BeginCast(castKey: Enum.KeyCode)
	local isLinkCast = castKey == Enum.KeyCode.R
	if inputDebounce then return end
	inputDebounce = true
	task.delay(0.5, function() inputDebounce = false end)

	-- A Frozen / Shielded / Rooted / Stunned / Ragdolled player can't cast. Checked BEFORE Start so the drawn slots aren't wasted.
	-- (the server enforces the same rule in WeavingModule.DeductSource, this is just the instant feedback)
	if not MovementService.CanCast(Character) then
		GuiRelatedThings.ErrorMessage(Player, "You can't cast right now")
		return
	end

	-- Acquire the Name of the Weave
	local WeaveName = WeavingModule.Start(Player, Animations)
	if WeaveName == nil then return warn("There is no WeaveName specified") end

	-- PRIMARY CHECKERS
	local WeaveData = Dictionary[WeaveName]
	if not WeaveData then return warn("No data found for the specified WeaveName") end

	-- LINKING: a weave that needs a link is cast with R, everything else with E.
	-- (the drawn elements are already spent at this point, so a failed link cast costs them: "the weave fails")
	if WeaveData.RequiresLink and not isLinkCast then
		GuiRelatedThings.ErrorMessage(Player, `{WeaveName} needs a link: cast it with R`)
		return
	elseif isLinkCast and not WeaveData.RequiresLink then
		GuiRelatedThings.ErrorMessage(Player, `{WeaveName} doesn't need a link: cast it with E`)
		return
	end
	if WeaveData.RequiresLink then
		local linkOk, linkReason = LinkData.CheckRequirement(Character, WeaveData)
		if not linkOk then
			GuiRelatedThings.ErrorMessage(Player, linkReason or "Not enough links")
			return
		end
	end

	-- Checks if Weave is on cooldown
	local isOnCooldown = DebounceHandler.DebounceCheck2(Player, Humanoid, WeaveName)
	if isOnCooldown then
		GuiRelatedThings.ErrorMessage(Player, `{WeaveName} is not ready yet`)
		return
	end

	-- Acquires Cast Range
	-- (FixedRange weaves, like Stilling, use exactly CastRange and don't add the Level)
	local CastRange = WeaveData.CastRange and (WeaveData.CastRange + (WeaveData.FixedRange and 0 or Level.Value)) or nil
	local MousePos = Mouse.Hit.Position

	-- Acquires Target
	local MouseTarget
	if WeaveData.RequiresTarget then 
		MouseTarget = Utilities.findCharacter(Mouse.Target, CastRange, Player) 
	end


	-- Checks Range & Target Requirement
	if CastRange and WeaveData.Instant and WeaveData.RequiresPosition and not WeavingModule.CheckRange(CastRange, MousePos, HumanoidRP.Position) then
		GuiRelatedThings.ErrorMessage(Player, `{WeaveName} is unable to reach the target point`)
		return
	elseif CastRange and WeaveData.Instant and WeaveData.RequiresTarget and not MouseTarget then
		GuiRelatedThings.ErrorMessage(Player, `{WeaveName} is unable to detect a target`)
		return
	end

	-- MOVEMENT WHILE CASTING (Dictionary: Controls / SlowPercentage) is applied by the SERVER (MovementServer + MovementService),
	-- not here. The old client code disabled the controls / slowed WalkSpeed BEFORE the Source check, so "not enough Source"
	-- returned early and left the player unable to move (bug 8), and its clean up wrote WalkSpeed = 16 even while shielded (bug 6).

	-- Deduct the source
	local Sourced, SourceDepleted = WeavingModule.InitiateSourceDeduction(Humanoid, WeaveData.SourceCost, WeaveData.Charging, WeaveData.Interval, WeaveData.MaxCharge, WeaveData.ServerPaid)

	if Sourced == false then 
		GuiRelatedThings.ErrorMessage(Player, "You do not have enough Source") 
		return 
	end

	-- ONE HELD CAST AT A TIME: starting a new weave ends the one still held (the server does the same, e.g. ShieldingScript lets go
	-- of the shield when another weave is pressed). This runs BEFORE the new cast tells the server anything, so the old cast's
	-- release / clear can never land on top of the new one.
	local InputEndedConnection, DeathConnection, StatusEffectConnection, SourceDepletionConnection
	if activeCast then
		local previous = activeCast
		activeCast = nil
		previous()
	end

	-- Start Charging which may be useful for weaves that requires charging
	ChargeEvent:FireServer(WeaveData.Charging, WeaveData.MaxCharge, Level.Value, WeaveName)

	-- Begin creating the effects
	WeavingFxEvent:FireServer(WeaveName, MousePos, Level.Value)

	-- Fire Weaving Instant Events (used for weaves that require an instant effect or proc)
	WeavingInstantEvent:FireServer(WeaveName, MouseTarget, MousePos, Level.Value) -- For the charge value, let the replicators retrieve the charge value

	-- Play the Channel animation
	AnimationHandler.PlayWeaveAnimation(Character, WeaveName, "Channel", true)

	-- Play the Channeling animation which is a loop that comes after Channel
	-- (ScriptedAnimations weaves, like Stilling, start it themselves at the right moment)
	if not WeaveData.ScriptedAnimations then
		AnimationHandler.PlayWeaveAnimation(Character, WeaveName, "Channeling", false)
	end

	local pressedAt = os.clock()

	-- Cleanup function
	local cleaned = false
	local function CleanUp()
		if WeaveName == nil or cleaned then return end -- SourceDepleted, a status effect and the key release can all land together
		cleaned = true
		if activeCast == CleanUp then activeCast = nil end

		if WeaveData.RequiresReady and os.clock() - pressedAt < WeaveData.ReadyTime then
			GuiRelatedThings.ErrorMessage(Player, `{WeaveName} wasn't ready yet`)
		end

		-- Find Target 
		local MouseTarget
		MousePos = Mouse.Hit.Position
		if WeaveData.RequiresTarget then MouseTarget = Utilities.findCharacter(Mouse.Target, CastRange, Player) end

		-- If Sourced is a connection, store it for later disconnection
		if Sourced and typeof(Sourced) == "RBXScriptConnection" then
			Sourced:Disconnect()
			Sourced = nil
		end

		-- Clear the effects
		WeavingFxClear:FireServer(WeaveName)

		-- Release the weave by signaling the server, send the WeaveName and the Charge amount
		WeavingEvent:FireServer(WeaveName, Humanoid:GetAttribute("Charge"), MouseTarget, MousePos, Level.Value)

		-- Releases instant weaves, basically a clean up 
		WeavingInstantReleaseEvent:FireServer(WeaveName)

		-- Stops Charging and sets Charge back to 0
		ChargeEvent:FireServer(false)

		-- Stop the Channeling
		AnimationHandler.StopWeaveAnimation(Character, WeaveName, "Channel")
		AnimationHandler.StopWeaveAnimation(Character, WeaveName, "Channeling")
		-- Play the cast animation of the weave
		-- (ScriptedAnimations weaves play it only if the SERVER says the cast succeeded)
		if not WeaveData.ScriptedAnimations then
			AnimationHandler.PlayWeaveAnimation(Character, WeaveName, "Cast", false)
		end

		-- (movement is given back by the server when it sees the weave end: WeavingFxClear / WeavingEvent above)

		-- Put Weave back to Cooldown
		if not isOnCooldown then
			DebounceHandler.DebounceWait(Player, Humanoid, WeaveName, WeaveData.DebounceDuration)
			GuiRelatedThings.DebounceIcon(Player, WeaveName)
		end

		-- DISCONNECT CONNECTIONS
		if InputEndedConnection then InputEndedConnection:Disconnect(); InputEndedConnection = nil end
		if SourceDepletionConnection then SourceDepletionConnection:Disconnect(); SourceDepletionConnection = nil end
		if StatusEffectConnection then StatusEffectConnection:Disconnect(); StatusEffectConnection = nil end
		if DeathConnection then DeathConnection:Disconnect(); DeathConnection = nil end

	end

	activeCast = CleanUp

	-- InputEnded connection
	InputEndedConnection = UserInputService.InputEnded:Connect(function(input, gpe)
		if input.KeyCode ~= castKey or gpe then return end
		CleanUp()
	end)

	-- SourceDepleted connection
	if SourceDepleted then
		SourceDepletionConnection = SourceDepleted:Connect(function()
			CleanUp()
		end)
	end

	-- Death Listener
	DeathConnection = Humanoid.Died:Connect(function()
		GuiRelatedThings.ErrorMessage(Player, `You died, canceling {WeaveName}`)
		CleanUp()
	end)

	-- Status Effect Listener
	StatusEffectConnection = Character.AttributeChanged:Connect(function(attributeName)
		if attributeName == "Frozen" or attributeName == "Shielded" or attributeName == "Rooted" or 
			attributeName == "Stunned" or attributeName == "Ragdolled" or attributeName == "Stilling" or attributeName == "Stilled" then
			local attrValue = Character:GetAttribute(attributeName)
			if attrValue == true or (typeof(attrValue) == "number" and attrValue > 0) then
				GuiRelatedThings.ErrorMessage(Player, `Status effect {attributeName} detected, canceling weave`)
				CleanUp()
			end
		end
	end)

	-- (the "can't cast while Frozen / Shielded / Stunned" check is at the top of this handler and on the server in WeavingModule.DeductSource)
end

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.R then
		BeginCast(input.KeyCode)
	end
end)


local CutDebounce = false
-- CONTROL FOR CUTTING OFF A WEAVE
UserInputService.InputBegan:Connect(function(input, gpe)
	if input.KeyCode ~= Enum.KeyCode.F or gpe or CutDebounce then return end
	CutDebounce = true
	task.delay(2, function() CutDebounce = false end)

	-- Acquire the Name of the Weave
	local InverseName = WeavingModule.StartInversing(Player, Animations)
	if InverseName == nil then return warn("There is no inverse weave for this") end

	-- PRIMARY CHECKERS
	local WeaveData = Dictionary[InverseName]
	if not WeaveData then return warn("No data found for the specified inverse name") end

	for _, parts in CollectionService:GetTagged("Locking") do
		if parts:IsA("BasePart") and parts:GetAttribute("Locking") then
			print(`part found: {parts:GetFullName()}`)
			-- Calculate distance within 30 studs around player
			local distance = (HumanoidRP.Position - parts.Position).Magnitude

			if distance <= 30 then
				-- Using the InverseName, check the WeaveName attribute of the detected part, if name matches then proceed
				if (parts:GetAttribute("WeaveName") or "") == InverseName then

					-- Check for character's LockedWeave attribute and match the name, if name matches then proceed
					if (Character:GetAttribute("LockedWeave" .. InverseName)) then

						-- Fire InversingRemote for effects
						-- Send the InverseKey as paramater (WeaveData.InverseKey) as well as the parts (As that is the trail of the incoming weave)
						InversingRemote:FireServer(InverseName, WeaveData.InverseKey, parts.CFrame)

						-- Play the inversion animation of the weave
						AnimationHandler.PlayAnimation(Character, "Inversion")
					end
				end
			end
		end
	end
end)