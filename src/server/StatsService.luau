--!strict

-- Description
local _ = [[
	Creates the stats for the weapons and buffs the player with
	temp or permanent stat boosts.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type StatNames = Types.StatNames
type PlayerData = Types.PlayerData
type Category = Types.Category
type Item = Types.Item
type StatContribution = { [StatNames]: number }

-- Variables
local STAT_KEYS: { StatNames } = {
	"damage",
	"critRate",
	"critDamage",
	"luck",
	"attackSpeed",
	"cooldownReduction",
	"armor",
	"health",
	"speed",
}

-----------------------------------
-- Module definition & state
-----------------------------------

local StatsService = {}

-----------------------------------
-- Helper functions
-----------------------------------

-- currently works for weapons only
local function calculateEquippedItems(data: PlayerData): StatContribution
	local contribution: StatContribution = {}
	local weaponUid = data.equipped.weapons
	if weaponUid then
		local item = StatsService.getEquippedItem(data, "weapons", weaponUid)
		if item and item.stats then
			for stat, roll in item.stats do
				local statName: StatNames = stat :: StatNames
				contribution[statName] = (contribution[statName] or 0) + roll.value
			end
		end
	end
	return contribution
end

local function mergeFlat(contributions: { StatContribution }): StatContribution
	local total: StatContribution = {}
	for _, stat: StatNames in STAT_KEYS do
		total[stat] = 0
	end
	for _, contribution in contributions do
		for stat: StatNames, value in contribution do
			total[stat] = (total[stat] or 0) + value
		end
	end
	return total
end

local function applyTempBuffs(data: PlayerData)
	local base = data.baseStats
	local activeBuffs = data.tempBuffs

	local combined: StatContribution = {}
	for _, buff in activeBuffs do
		combined[buff.stat] = (combined[buff.stat] or 0) + buff.percent
	end

	local finalStats: StatContribution = {}
	for _, stat: StatNames in STAT_KEYS do
		finalStats[stat] = (base[stat] or 0) * (1 + (combined[stat] or 0))
	end
	data.changedStats = finalStats
end

-----------------------------------
-- Public functions
-----------------------------------

function StatsService.getEquippedItem(data: PlayerData, category: Category, uid: string?): Item?
	local list = data.items[category] :: { Item }?
	if not list then
		return nil
	end

	-- linear look up
	for _, item in list do
		if item.uid == uid then
			return item
		end
	end
	return nil
end

function StatsService.recalculate(data: PlayerData)
	data.baseStats = mergeFlat({ calculateEquippedItems(data) })
	applyTempBuffs(data)
end

function StatsService.getStat(data: PlayerData, stat: StatNames): number
	return (data.changedStats and data.changedStats[stat]) or 0
end

return StatsService
