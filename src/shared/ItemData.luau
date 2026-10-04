--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type WeaponData = Types.WeaponDataMap
type MaterialData = Types.MaterialDataMap
type Rarity = Types.RarityMap
type RarityName = Types.RarityName

type ItemsList = {
	weapons: WeaponData,
	materials: MaterialData,
	rarity: Rarity,
	itemFrames: { [RarityName]: string },
	rarityColors: {},
	statNames: {},
	statOrder: { string },
	statTypes: { [string]: string },
}

-----------------------------------
-- Module definition & state
-----------------------------------

local ItemData: ItemsList = {
	weapons = {
		ironSword = {
			name = "Iron Sword",
			rarity = "common",
			type = "melee",
			tags = { "sword" },
			baseStats = { damage = 10, critRate = 0, critDamage = 1.1, attackSpeed = 0.2 },
			hitbox = { type = "arc", range = 5, angle = 70 },
			animations = {
				idle = "99417398372789",
				combo = {
					{ id = "87455361709207", slash = "slash" },
					{ id = "89807628429330", slash = "slash" },
				},
			},
			passives = {},
			abilities = {},
			image = "rbxassetid://129810535952681",
			description = "A basic iron sword.",
			keywords = { "iron", "melee", "sword", "blade", "common" },
		},
		blueHaze = {
			name = "Blue Haze",
			rarity = "mythic",
			type = "melee",
			tags = { "sword", "unique" },
			baseStats = { damage = 25, critRate = 0.10, critDamage = 1.6, attackSpeed = 0.4 },
			hitbox = { type = "arc", range = 10, angle = 90 },
			animations = {
				idle = "99417398372789",
				combo = {
					{ id = "87455361709207", slash = "slash" },
					{ id = "89807628429330", slash = "slash" },
				},
			},
			passives = {},
			abilities = {},
			image = "rbxassetid://129810535952681",
			description = "It is said that those cut by the blade only see a blue haze.",
			keywords = { "blue", "haze", "melee", "sword", "blade", "mythic" },
		},
	},

	materials = {
		scraps = {
			name = "Scraps",
			rarity = "common",
			image = "rbxassetid://129810535952681",
			description = "Used as a basic material in crafting various weapons",
		},
		cloths = {
			name = "Cloths",
			rarity = "rare",
			image = "rbxassetid://129810535952681",
			description = "It's clothings and stuff",
		},
	},

	rarity = {
		common = 0.6,
		rare = 0.25,
		epic = 0.109,
		legendary = 0.03,
		mythic = 0.01,
		secret = 0.001,
	},

	rarityColors = {
		common = Color3.fromHex("CBD5E0"),
		rare = Color3.fromHex("3182CE"),
		epic = Color3.fromHex("805AD5"),
		legendary = Color3.fromHex("D7DD20"),
		mythic = Color3.fromHex("F59326"),
		secret = Color3.fromHex("222324"),
	},

	itemFrames = {
		common = "rbxassetid://107102273200611",
		rare = "rbxassetid://125232445526828",
		epic = "rbxassetid://90154252114083",
		legendary = "rbxassetid://119592190921038",
		mythic = "rbxassetid://91129267111260",
		secret = "rbxassetid://89880526346253",
	},
	statNames = {
		damage = "Damage",
		critRate = "Crit rate",
		critDamage = "Crit Damage",
		attackSpeed = "Attack Speed",
	},

	statOrder = {
		"damage",
		"critRate",
		"critDamage",
		"attackSpeed",
	},

	statTypes = {
		damage = "flat",
		critRate = "percent",
		critDamage = "percent",
		attackSpeed = "percent",
	},
}

return ItemData
