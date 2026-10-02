-- SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- MODULES
local Janitor = require(ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("Janitor"))

-- REMOTE
local AnimationSignal = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("AnimationSignal")
local PlayAnim = ReplicatedStorage:WaitForChild("SYSTEM"):WaitForChild("ModuleScripts"):WaitForChild("AnimationHandler"):WaitForChild("PlayAnim")

local AnimationHandler = {
	
	EnflameChannel = {id = "129297744310285", track = nil},
	EnflameChanneling = {id = "118260489952850", track = nil},
	EnflameCast = {id = "76492442730158", track = nil},
	
	FrostboundChannel = {id = "104956543516550", track = nil},
	FrostboundChanneling = {id = "73817457746132", track = nil},
	FrostboundCast = {id = "126843745394865", track = nil},
	
	BrambleSnareChannel = {id = "102829570250652", track = nil},
	BrambleSnareChanneling = {id = "72231407706254", track = nil},
	
	BoulderChannel = {id = "77365972685706", track = nil},
	BoulderChanneling = {id = "84574186030132", track = nil},
	BoulderCast = {id = "77363005481181", track = nil},
	
	VeilOfReflectionChannel = {id = "90494766181429", track = nil},
	VeilOfReflectionChanneling = {id = "131700096648016", track = nil},
	VeilOfReflectionCast = {id = "72066662212678", track = nil},
	
	FireballChannel = {id = "125127077998092", track = nil},
	FireballChanneling = {id = "128905537780123", track = nil},
	FireballCast = {id = "130854337925024", track = nil},
	
	WindCutterChannel = {id = "123104518032654", track = nil},
	WindCutterChanneling = {id = "136919237757612", track = nil},
	WindCutterCast = {id = "127049694068485", track = nil},
	
	AirPulseChannel = {id = "75532426947059", track = nil},
	AirPulseChanneling = {id = "113230872468433", track = nil},
	AirPulseCast = {id = "103977659686508", track = nil},
	
	TelekineticCrashChannel = {id = "82704489169909", track = nil},
	TelekineticCrashChanneling = {id = "72326804558628", track = nil},
	TelekineticCrashCast = {id = "100617721468781", track = nil},
	
	LightningStrikeChannel = {id = "81775683812526", track = nil},
	LightningStrikeChanneling = {id = "103693699346080", track = nil},
	LightningStrikeCast = {id = "78375617301995", track = nil},
}


AnimationHandler.Poses = {
	RootedVine = {id = "91155487290041"},
	RootedVine2 = {id = "81405441018016"},
	Inversion = {id = "99028705217677"}
}

local ActiveAnimations = {}
local CachedAnimationTracks = {}

-- LOADS ALL ANIMATIONS FOR AN ANIMATOR
function AnimationHandler.LoadAllAnimations(character: Model?)
	if not character then warn("NO PROVIDED CHARACTER TO LOAD ALL ANIMATIONS") return end
		
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	
	if not CachedAnimationTracks[character] then
		CachedAnimationTracks[character] = {}
	end

	CachedAnimationTracks[character][animator] = {} -- Store tracks per animator

	for animName, data in pairs(AnimationHandler) do
		if type(data) == "table" and data.id then
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. data.id

			local animTrack = animator:LoadAnimation(animation)
			animTrack.Name = animName
			data.track = animTrack -- Store in AnimationHandler
			CachedAnimationTracks[character][animator][animName] = animTrack -- Store in cache
		end
	end
	
	for animName, data in pairs(AnimationHandler.Poses) do
		if type(data) == "table" and data.id then
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. data.id

			local animTrack = animator:LoadAnimation(animation)
			animTrack.Name = animName
			data.track = animTrack -- Store in AnimationHandler
			CachedAnimationTracks[character][animator][animName] = animTrack -- Store in cache
		end
	end
end

-- LOADS AN ANIMATION TO THE PROVIDED ANIMATOR
function AnimationHandler.AnimationLoader(animator: Animator, animId: string)
	if not animator or not animId then
		warn("Invalid Animator or Animation provided.")
		return nil
	end

	-- Create a new Animation instance
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animId

	-- Load the animation instance to an animator
	local animTrack = animator:LoadAnimation(animation)
	return animTrack
end

-- LOADS ANIMATIONS INTO THE ANIMATOR (Elemental Setting)
function AnimationHandler.LoadAnimations(animator: Animator)
	if not animator then return warn("Invalid Animator") end

	for animName, data in pairs(AnimationHandler) do
		if type(data) == "table" and data.id then
			data.track = AnimationHandler.AnimationLoader(animator, data.id)
		end
	end
end

-- PLAYS A SPECIFIC ANIMATION BASED ON WEAVENAME AND PHASE
function AnimationHandler.PlayWeaveAnimation(character, WeaveName, phase, shouldMarker)
	
	-- Retrieve important references and locate animator
	local humanoid = character:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not CachedAnimationTracks[character] or not CachedAnimationTracks[character][animator] then
		warn("No cached animations found for", character)
		return false
	end
	
	-- Setup the weave animation key
	local key = WeaveName .. phase
	local track = CachedAnimationTracks[character][animator][key]

	-- Play the animation track if found
	if track then
		track:Play()
		
		local tempJanitor = Janitor.new()
		
		tempJanitor:GiveChore(track:GetMarkerReachedSignal("Signal"):Connect(function()
			AnimationSignal:FireServer(WeaveName, phase)
			tempJanitor:Clean()
		end))
		
		if shouldMarker then
			task.spawn(function()
				local markerReached = false
				local tempJanitor = Janitor.new()

				tempJanitor:GiveChore(track:GetMarkerReachedSignal("End"):Connect(function()
					markerReached = true
					tempJanitor:Clean()
				end))

				repeat task.wait() until markerReached
				return true
			end)
		end
		
		-- **Track when the animation stops and clean up signals**
		tempJanitor:GiveChore(track.Stopped:Connect(function()
			tempJanitor:Clean()
		end))
		
		return true
	else
		warn("Animation track not found for", key)
		return false
	end
end

function AnimationHandler.StopWeaveAnimation(character: Model, WeaveName, phase)
	if not character then return end

	-- Locate animator
	local humanoid = character:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator or not CachedAnimationTracks[character] or not CachedAnimationTracks[character][animator] then
		warn("No cached animations found for", character)
		return
	end

	-- Setup the key for animation
	local key = WeaveName .. phase
	local track = CachedAnimationTracks[character][animator][key]

	-- Stop the animation
	if track then
		track:Stop()
	else
		warn("Animation track not found for", key)
	end
end

-- PLAYS AN ANIMATION FROM CACHED TRACKS
function AnimationHandler.PlayAnimation(character: Model?, animName: string)
	if not character then 
		warn("NO PROVIDED CHARACTER TO PLAY ANIMATION") 
		return 
	end

	local humanoid = character:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("No Animator found in", character)
		return
	end

	local animTrack = CachedAnimationTracks[character][animator] and CachedAnimationTracks[character][animator][animName]
	if animTrack then
		animTrack:Play()
	else
		warn("Animation not found:", animName)
	end
end

-- STOPS AN ANIMATION FROM CACHED TRACKS
function AnimationHandler.StopAnimation(character: Model?, animName: string)
	if not character then 
		warn("NO PROVIDED CHARACTER TO STOP ANIMATION") 
		return 
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("No Animator found in", character)
		return
	end

	local animTable = CachedAnimationTracks[character]
	if not animTable or not animTable[animator] then
		warn("No animations found for", character)
		return
	end

	local animTrack = animTable[animator][animName]
	if animTrack then
		animTrack.Looped = false -- Ensure it doesn't loop
		animTrack:Stop()
	else
		warn("Animation not found:", animName)
	end
end

return AnimationHandler
