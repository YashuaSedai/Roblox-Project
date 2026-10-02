-- SERVICE
local RS = game:GetService("ReplicatedStorage")

-- ASSETS FOLDER
local Assets = RS:WaitForChild("Assets"):WaitForChild("Weaves"):WaitForChild("Images")

local Dictionary = {
	Enflame = {
		WeaveKey = "10000",
		InverseKey = "20000",
		DebounceDuration = 2.5, -- DB_DURATION
		DamageOverTime = 15, -- TOTAL DAMAGE OVER TIME
		Duration = 5, -- DURATION
		CastRange = 30, -- CAST_RANGE
		SourceCost = 10, -- SOURCE COST
		RequiresTarget = true, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = false, -- REQUIRES A MOUSE POSITION?
		Instant = false,
		Charging = false, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0, -- SHOULD BE 0 IF CHARGING IS FALSE
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.9, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("Enflame").Image
	},
	
	Frostbound = {
		WeaveKey = "22400",
		DebounceDuration = 5, -- WEAVE COOLDOWN
		Damage = 15,
		Duration = 1, -- FREEZE DURATION
		ProjectileSpeed = 100, -- PROJECTILE SPEED
		Lifetime = 3, -- PROJECTILE LIFETIME
		Area = 15,
		SourceCost = 1,
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 10, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.2, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("Frostbound").Image
	},
	
	BrambleSnare = {
		WeaveKey = "32300",
		DebounceDuration = 10, -- WEAVE COOLDOWN
		Damage = 2, -- THIS IS PER TICK
		CastRange = 50, -- CAST_RANGE
		Area = 15,
		SourceCost = 1.2,
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = true, -- REQUIRES A MOUSE POSITION?
		Instant = true,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("BrambleSnare").Image
	},
	
	Boulder = {
		WeaveKey = "33000",
		DebounceDuration = 6, -- WEAVE COOLDOWN
		Damage = 35,
		Duration = 2, -- KNOCKBACK DURATION
		ProjectileSpeed = 70, -- PROJECTILE SPEED
		Lifetime = 3, -- PROJECTILE LIFETIME
		Area = 20,
		SourceCost = 1.2,
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 10, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("Boulder").Image
	},
	
	VeilOfReflection = {
		WeaveKey = "52450",
		DebounceDuration = 5,
		Health = 50,
		MaxHealth = 200,
		RegenRate = 0.1, -- PER SECOND ASSUMINGLY
		SourceCost = 0,
		RequiresTarget = false,
		Charging = true,
		MaxCharge = 0, -- CAN BE 0 IF WEAVE IS HELD BUT NOT NECESSARILY NEEDING A CHARGE
		Instant = true,
		Interval = 0.1,
		Controls = true,
		SlowPercentage = 0.3,
		Image = Assets:WaitForChild("VeilOfReflection").Image
	},
	
	Fireball = {
		WeaveKey = "11000",
		DebounceDuration = 5, -- WEAVE COOLDOWN
		DamageOverTime = 20, -- TOTAL DAMAGE OVER TIME
		Damage = 20,
		Duration = 5, -- BURN DURATION
		ProjectileSpeed = 200, -- PROJECTILE SPEED
		Lifetime = 3, -- PROJECTILE LIFETIME
		Area = 15,
		SourceCost = 1,
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 5, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.4, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("Fireball").Image
	},
	
	WindCutter = {
		WeaveKey = "44000",
		DebounceDuration = 4.5, -- WEAVE COOLDOWN
		Damage = 30,
		CriticalChance = 1,
		CriticalDamage = 1.1,
		ProjectileSpeed = 150, -- PROJECTILE SPEED
		Lifetime = 2, -- PROJECTILE LIFETIME
		SourceCost = 20,
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Instant = false,
		Charging = false, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("WindCutter").Image
	},
	
	AirPulse = {
		WeaveKey = "40000",
		DebounceDuration = 3, -- WEAVE COOLDOWN
		Damage = 50,
		ProjectileSpeed = 300, -- PROJECTILE SPEED
		Lifetime = 2, -- PROJECTILE LIFETIME
		SourceCost = 1,
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 10, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 0.1, -- SHOULDBE 0 IF CHARGING IS FALSE
		Controls = true, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0.5, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("WindCutter").Image
	},
	
	TelekineticCrash = {
		WeaveKey = "44400",
		DebounceDuration = 5, -- DB_DURATION
		Damage = 25, -- DAMAGE
		CastRange = 20, -- CAST_RANGE
		SourceCost = 3, -- SOURCE COST
		RequiresTarget = true, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = false, -- REQUIRES A MOUSE POSITION?
		Instant = true,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 0, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 1, -- SHOULD BE 0 IF CHARGING IS FALSE
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("TelekineticCrash").Image
	},
	
	LightningStrike = {
		WeaveKey = "12400",
		DebounceDuration = 5, -- DB_DURATION
		Damage = 40, -- DAMAGE
		Area = 15,
		CastRange = 100, -- CAST_RANGE
		SourceCost = 15, -- SOURCE COST
		RequiresTarget = false, -- REQUIRES A MOUSE TARGET?
		RequiresPosition = true, -- REQUIRES A MOUSE POSITION?
		Instant = false,
		Charging = true, -- DOES THIS WEAVE CHARGE?
		MaxCharge = 5, -- SHOULDBE 0 IF CHARGING IS FALSE
		Interval = 1, -- SHOULD BE 0 IF CHARGING IS FALSE
		Controls = false, -- IF TRUE THEN ADJUST SLOW PERCENTAGE
		SlowPercentage = 0, -- SHOULD BE 0 IF CONTROLS IS FALSE
		Image = Assets:WaitForChild("TelekineticCrash").Image
	},
}

return Dictionary
