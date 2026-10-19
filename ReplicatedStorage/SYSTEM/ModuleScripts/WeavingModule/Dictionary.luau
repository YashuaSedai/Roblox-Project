-- SERVICE
local RS = game:GetService("ReplicatedStorage")

-- ASSETS FOLDER
local Assets = RS:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("Images")

local Dictionary = {
	Enflame = {
		-- IDENTITY
		WeaveKey = "10000",
		InverseKey = "20000",
		Image = Assets:WaitForChild("Enflame").Image,

		-- COST + COOLDOWN
		SourceCost = 10, -- SOURCE COST
		DebounceDuration = 0.5, -- DB_DURATION

		-- CASTING
		Instant = false,
		Charging = false, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0, -- SHOULD BE 0 IF CHARGING IS FALSE
		ServerPaid = true,

		-- TARGETING
		RequiresTarget = true, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = false, -- REQUIRES A MOUSE POSITION?
		CastRange = 30, -- CAST_RANGE

		-- MOVEMENT WHILE CASTING
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.9, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- EFFECT
		DamageOverTime = 20, -- TOTAL DAMAGE OVER TIME
		Duration = 5, -- DURATION
	},

	Frostbound = {
		-- IDENTITY
		WeaveKey = "22400",
		Image = Assets:WaitForChild("Frostbound").Image,

		-- COST + COOLDOWN
		SourceCost = 0.5,
		DebounceDuration = 5, -- WEAVE COOLDOWN
		FizzleCooldown = 1, -- cooldown after an early release

		-- CASTING
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 10, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		ReadyTime = 2,
		RequiresReady = true, -- can't be released until the Channel animation's "Signal" marker has fired

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Area = 15,

		-- MOVEMENT WHILE CASTING
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.2, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- PROJECTILE
		ProjectileSpeed = 100, -- PROJECTILE SPEED
		Lifetime = 3, -- PROJECTILE LIFETIME

		-- EFFECT
		Damage = 20,
		Duration = 1, -- FREEZE DURATION
	},

	BrambleSnare = {
		-- IDENTITY
		WeaveKey = "32300",
		Image = Assets:WaitForChild("BrambleSnare").Image,

		-- COST + COOLDOWN
		SourceCost = 1,
		DebounceDuration = 10, -- WEAVE COOLDOWN

		-- CASTING
		Instant = true,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		MaxHold = 60,
		ReadyTime = 4,

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = true, -- REQUIRES A MOUSE POSITION?
		CastRange = 50, -- CAST_RANGE
		Area = 15,

		-- MOVEMENT WHILE CASTING
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- EFFECT
		Damage = 3, -- THIS IS PER TICK
	},

	Boulder = {
		-- IDENTITY
		WeaveKey = "33000",
		Image = Assets:WaitForChild("Boulder").Image,

		-- COST + COOLDOWN
		SourceCost = 1.5,
		DebounceDuration = 6, -- WEAVE COOLDOWN
		FizzleCooldown = 1, -- cooldown after an early release

		-- CASTING
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 10, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		ReadyTime = 1.67,
		RequiresReady = true, -- can't be released until the Channel animation's "Signal" marker has fired

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Area = 20,

		-- MOVEMENT WHILE CASTING
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- PROJECTILE
		ProjectileSpeed = 70, -- PROJECTILE SPEED
		Lifetime = 3, -- PROJECTILE LIFETIME

		-- EFFECT
		Damage = 35,
		Duration = 2, -- KNOCKBACK DURATION
	},

	VeilOfReflection = {
		-- IDENTITY
		WeaveKey = "52450",
		Image = Assets:WaitForChild("VeilOfReflection").Image,

		-- COST + COOLDOWN
		SourceCost = 0.3,
		DebounceDuration = 5,
		FizzleCooldown = 1,

		-- CASTING
		Instant = true,
		Charging = true,
		MaxCharge = 0, -- CAN BE 0 IF WEAVE IS HELD BUT NOT NECESSARILY NEEDING A CHARGE
		Interval = 0.1,
		MaxHold = 120,
		ReadyTime = 0.4,

		-- TARGETING
		RequiresTarget = false,

		-- MOVEMENT WHILE CASTING
		Controls = true,
		SlowPercentage = 0.3,

		-- EFFECT
		Health = 50,
		MaxHealth = 200,
		RegenRate = 0.1, -- PER SECOND ASSUMINGLY
	},

	Fireball = {
		-- IDENTITY
		WeaveKey = "11000",
		Image = Assets:WaitForChild("Fireball").Image,

		-- COST + COOLDOWN
		SourceCost = 1.5,
		DebounceDuration = 5, -- WEAVE COOLDOWN

		-- CASTING
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 5, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Area = 15,

		-- MOVEMENT WHILE CASTING
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.4, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- PROJECTILE
		ProjectileSpeed = 200, -- PROJECTILE SPEED
		Lifetime = 3, -- PROJECTILE LIFETIME

		-- EFFECT
		Damage = 20,
		DamageOverTime = 20, -- TOTAL DAMAGE OVER TIME
		Duration = 5, -- BURN DURATION
	},

	WindCutter = {
		-- IDENTITY
		WeaveKey = "44000",
		Image = Assets:WaitForChild("WindCutter").Image,

		-- COST + COOLDOWN
		SourceCost = 20,
		DebounceDuration = 4.5, -- WEAVE COOLDOWN

		-- CASTING
		Instant = false,
		Charging = false, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		ServerPaid = true,

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?

		-- MOVEMENT WHILE CASTING
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- PROJECTILE
		ProjectileSpeed = 150, -- PROJECTILE SPEED
		Lifetime = 2, -- PROJECTILE LIFETIME

		-- EFFECT
		Damage = 30,
		CriticalChance = 1,
		CriticalDamage = 1.1,
	},

	AirPulse = {
		-- IDENTITY
		WeaveKey = "40000",
		Image = Assets:WaitForChild("WindCutter").Image,

		-- COST + COOLDOWN
		SourceCost = 1,
		DebounceDuration = 3, -- WEAVE COOLDOWN

		-- CASTING
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 10, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?

		-- MOVEMENT WHILE CASTING
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.5, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- PROJECTILE
		ProjectileSpeed = 300, -- PROJECTILE SPEED
		Lifetime = 2, -- PROJECTILE LIFETIME

		-- EFFECT
		Damage = 50,
	},

	TelekineticCrash = {
		-- IDENTITY
		WeaveKey = "44400",
		Image = Assets:WaitForChild("TelekineticCrash").Image,

		-- COST + COOLDOWN
		SourceCost = 50, -- SOURCE COST
		DebounceDuration = 5, -- DB_DURATION

		-- CASTING
		Instant = true,
		Charging = false, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0, -- SHOULD BE 0 IF CHARGING IS FALSE
		MaxHold = 60,
		CastDelay = 0,
		ServerPaid = true,

		-- TARGETING
		RequiresTarget = true, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = false, -- REQUIRES A MOUSE POSITION?
		CastRange = 20, -- CAST_RANGE

		-- MOVEMENT WHILE CASTING
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- EFFECT
		Damage = 25, -- DAMAGE
	},

	LightningStrike = {
		-- IDENTITY
		WeaveKey = "12400",
		Image = Assets:WaitForChild("TelekineticCrash").Image,

		-- COST + COOLDOWN
		SourceCost = 12, -- SOURCE COST
		DebounceDuration = 5, -- DB_DURATION

		-- CASTING
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 5, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 1, -- SHOULD BE 0 IF CHARGING IS FALSE

		-- TARGETING
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = true, -- REQUIRES A MOUSE POSITION?
		CastRange = 100, -- CAST_RANGE
		Area = 15,

		-- MOVEMENT WHILE CASTING
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE

		-- EFFECT
		Damage = 20, -- DAMAGE
		RagdollDuration = 2,
	},

	Shielding = {
		-- IDENTITY
		WeaveKey = "55500",
		Image = Assets:WaitForChild("TelekineticCrash").Image,

		-- COST + COOLDOWN
		SourceCost = 0.25,
		DebounceDuration = 5,

		-- CASTING
		Instant = true,
		Charging = true,
		MaxCharge = 0,
		Interval = 0.1,

		-- TARGETING
		RequiresTarget = true,
		RequiresPosition = true,
		CastRange = 50,

		-- MOVEMENT WHILE CASTING
		Controls = true, -- (was "Contrls": a typo, so the 50% slow never applied)
		SlowPercentage = 0.5,

		-- EFFECT
		SourceReduction = 0.5,
		BurnMaximum = 20,
	},

	-- LINKING. Weaves that need links (cast with R instead of E) add two fields to their own entry:
	--     RequiresLink = true,   -- cast with R; only the LEADER of a link can cast it; fails without enough links
	--     LinksRequired = 3,     -- how many linkers the leader needs (default 1)
	-- and their server script starts with:  if not LinkService.CanCast(player.Character, Dictionary[WEAVE]) then return end
	Linking = {
		-- IDENTITY
		WeaveKey = "12345",
		Image = Assets:WaitForChild("TelekineticCrash").Image,

		-- COST + COOLDOWN
		SourceCost = 0,
		DebounceDuration = 2,

		-- CASTING
		Instant = true,
		Charging = true,
		MaxCharge = 0,
		Interval = 0,
		MaxHold = 600, -- how long a link can be held. MovementServer's failsafe ALSO reads this: without it the movement lock
		-- was lifted after 35 seconds even though the link was still up

		-- TARGETING
		RequiresTarget = true,
		RequiresPosition = false,
		CastRange = 50,

		-- MOVEMENT WHILE CASTING
		Controls = false, -- the linker can't move while holding the link (MovementServer applies the lock from this)
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE
	},

	-- STILLING (a link weave: cast with R by a leader with 7 linkers). See StillingScript for the whole sequence.
	Stilling = {
		-- IDENTITY
		WeaveKey = "55555", -- PLACEHOLDER: change to the elements you want. It only has to be unique.
		Image = Assets:WaitForChild("TelekineticCrash").Image, -- placeholder icon, like Linking / Shielding

		-- COST + COOLDOWN
		SourceCost = 0, -- no Source for now
		DebounceDuration = 3, -- cooldown after a successful Stilling
		FizzleCooldown = 5, -- cooldown after a failed one

		-- CASTING
		Instant = true,
		Charging = false,
		MaxCharge = 0,
		Interval = 0,
		MaxHold = 60, -- MovementServer's failsafe for the caster's cast lock (the weave's own timeouts end it sooner)
		RequiresLink = true,
		LinksRequired = 1,
		ScriptedAnimations = true, -- ElementalSetting must NOT auto-play Channeling / Cast: StillingReplicator plays them at the right moments

		-- TARGETING
		RequiresTarget = true,
		RequiresPosition = false,
		CastRange = 50,
		FixedRange = true, -- the cast range is exactly CastRange: the caster's Level is NOT added to it

		-- MOVEMENT WHILE CASTING
		Controls = false, -- the leader can't move while channeling
		SlowPercentage = 0,

		-- EFFECT
		HoldTimeout = 20, -- seconds the caster may take to release after the last needle before the weave fizzles
		StilledDuration = 20, -- seconds the target stays Stilled (5 minutes)
		StilledSpeedMult = 0.6, -- a Stilled weaver walks at 60% speed
	},
}

return Dictionary
