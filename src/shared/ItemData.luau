--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type WeaponData = Types.WeaponDataMap
type Rarity = Types.RarityMap
type RarityName = Types.RarityName

type ItemsList = {
	weapons: WeaponData,
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
			hitbox = { type = "arc", range = 8, angle = 70 },
			windUp = 0.2,
			active = 0.15,
			recovery = 0.35,
			passives = {},
			abilities = {},
			description = "A basic iron sword.",
			keywords = { "iron", "melee", "sword", "blade", "common" },
		},
		crimsonBlade = {
			name = "Crimson Blade",
			rarity = "mythic",
			type = "melee",
			tags = { "sword", "unique" },
			baseStats = { damage = 25, critRate = 0.10, critDamage = 1.6, attackSpeed = 0.4 },
			hitbox = { type = "arc", range = 10, angle = 90 },
			windUp = 0.18,
			active = 0.15,
			recovery = 0.3,
			passives = {},
			abilities = {},
			description = "A basic iron sword.",
			keywords = { "crimson", "melee", "sword", "blade", "mythic" },
		},
	},

	rarity = {
		common = 0.6,
		rare = 0.2,
		mythic = 0.01,
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
