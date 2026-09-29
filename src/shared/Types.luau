--!strict
local Types = {}

export type Roll = {
	value: number,
	rank: string,
}

export type Category = "weapons" | "armors" | "materials"
export type WeaponStatName = "damage" | "critRate" | "critDamage" | "luck" | "attackSpeed" | "cooldownReduction"
export type ArmorStatName = "armor" | "health" | "luck" | "speed"
export type RarityName = "common" | "rare" | "epic" | "legendary" | "mythic" | "secret"
export type ItemTags = "sword" | "spear" | "axe" | "greatSword" | "bow" | "crossBow" | "mechanicalBow" | "unique"
export type ItemTypes = "melee" | "range"
export type HitboxType = "arc" | "sphere" | "raycast" | "cylinder"
export type EnemyType = "melee" | "range" | "boss"
export type EnemySubType = "fast" | "tank" | "armor" | "miniBoss" | "none"
export type EnemyStatNames = "health" | "damage" | "armor" | "speed" | "critRate" | "critDamage"

export type StatNames = WeaponStatName | ArmorStatName
export type WeaponStats = { [WeaponStatName]: Roll }
export type ArmorStats = { [ArmorStatName]: Roll }
export type StatMap = { [StatNames]: number }
export type EnemyTypeStats = { [EnemyType]: number }
export type EnemySubTypeStats = { [EnemySubType]: number }
export type EnemyStats = { [EnemyStatNames]: number }

export type Stats = { [string]: Roll }

export type Weapon = {
	id: string,
	uid: string,
	level: number,
	locked: boolean,
	stats: WeaponStats,
}

export type Armor = {
	id: string,
	uid: string,
	level: number,
	locked: boolean,
	stats: ArmorStats,
}

export type Material = {
	id: string,
	uid: string,
	amount: number,
}

export type Item = {
	id: string,
	uid: string?,
	level: number?,
	amount: number?,
	locked: boolean?,
	stats: Stats?,
}

export type HitboxConfig = {
	type: HitboxType,
	range: number?,
	radius: number?,
	angle: number?,
	height: number?,
	distance: number?,
}

export type WeaponInfo = {
	name: string,
	rarity: RarityName,
	baseStats: { [WeaponStatName]: number },
	passives: { [string]: any },
	abilities: { [string]: any },
	description: string,
	keywords: { string },
	hitbox: HitboxConfig,
	windUp: number,
	active: number,
	recovery: number,
	type: ItemTypes,
	tags: { ItemTags },
}

export type EnemyInfo = {
	type: EnemyTypeStats,
	subType: EnemySubTypeStats,
	stats: EnemyStats,
	attackRange: number,
	chaseRange: number,
	maxChaseRange: number,
	rest: number,
	drops: {},
	weapon: string?,
}

export type Entity = {
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	getStat: (self: Entity, stat: StatNames) -> number,
	stats: StatMap,
}

export type Buff = {
	stat: StatNames,
	percent: number,
}

export type PlayerData = {
	items: { [Category]: { any } },
	baseStats: StatMap,
	changedStats: StatMap,
	equipped: {
		weapons: string?,
		armors: {
			head: string?,
			torso: string?,
			legs: string?,
			feet: string?,
		},
	},
	tempBuffs: { Buff },
}

export type DamageContext = {
	attackerStats: StatMap,
	targetStats: StatMap,
	damageMultiplier: number,
}

export type DamageResult = {
	amount: number,
	isCrit: boolean,
}

export type RarityMap = { [RarityName]: number }
export type WeaponDataMap = { [string]: WeaponInfo }
export type EnemyDataMap = { [string]: EnemyInfo }

return Types
