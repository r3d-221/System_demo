--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type EnemyType = Types.EnemyType
type EnemySubType = Types.EnemySubType
type EnemyDataMap = Types.EnemyDataMap
type EnemySubTypeStats = Types.EnemySubTypeStats
type EnemyTypeStats = Types.EnemyTypeStats
export type EnemyData = {
	enemies: EnemyDataMap,
	types: { [EnemyType]: EnemyTypeStats },
	subTypes: { [EnemySubType]: EnemySubTypeStats },
}

local EnemyData: EnemyData = {
	enemies = {
		basic = {
			type = {
				melee = 0.7,
				range = 0.3,
			},
			subType = {
				none = 0.7,
				armor = 0.3,
			},
			stats = {
				health = 100,
				damage = 10,
				armor = 5,
				speed = 10,
				critRate = 0.2,
				critDamage = 1.1,
			},
			drops = {},
			attackRange = 10,
			chaseRange = 25,
			maxChaseRange = 40,
			rest = 0.3,
			weapon = "ironSword",
		},
	},

	types = {
		melee = {
			health = 1.1,
			armor = 1.05,
		},
		range = {
			health = 0.9,
			damage = 1.02,
			speed = 1.05,
			critRate = 1.1,
			critDamage = 1.2,
		},
	},

	subTypes = {
		none = {},
		armor = {
			armor = 1.3,
		},
	},
}

return EnemyData
