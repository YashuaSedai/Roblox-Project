local EnemyDictionary = {}

EnemyDictionary.Information = {
	PlayerBaseInfo = {exp = 250, marks = 8},
	Trolloc_Normal1 = {key = "TrollocN1", exp = 50, marks = 5},
	Trolloc_Normal2 = {key = "TrollocN2", exp = 50, marks = 5},
	Trolloc_Normal3 = {key = "TrollocN3", exp = 50, marks = 5},
	Trolloc_Ranged1 = {key = "TrollocR1", exp = 35, marks = 8},
	Trolloc_Ranged2 = {key = "TrollocR2", exp = 35, marks = 8},
	Trolloc_Tank1 = {key = "TrollocT1", exp = 75, marks = 8},
	Shadowspawn = {key = "Shadowspawn", exp = 100, marks = 10}
}

EnemyDictionary.Stats = {
	Trolloc_Normal1 = {health = 75, speed = 16, range = 2, damage = 0},
	Trolloc_Normal2 = {health = 75, speed = 16, range = 2, damage = 0},
	Trolloc_Normal3 = {health = 75, speed = 16, range = 2, damage = 0},
	Trolloc_Ranged1 = {health = 60, speed = 14, range = 15, damage = 0},
	Trolloc_Ranged2 = {health = 60, speed = 14, range = 15, damage = 0},
	Trolloc_Tank1 = {health = 150, speed = 12, range = 1, damage = 0},
	Shadowspawn = {health = 125, speed = 18, range = 4, damage = 0}
}

EnemyDictionary.DamageTracker = {}

return EnemyDictionary
