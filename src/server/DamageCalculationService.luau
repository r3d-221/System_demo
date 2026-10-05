--!strict

-- Description
local _ = [[
	It calculates the damage based on the base and crit.
	It takes context of the damage and applies based on that.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type DamageContext = Types.DamageContext
type DamageResult = Types.DamageResult
type StatNames = Types.StatNames

-- Constants
local ARMOR_CONSTANT = 100
local MAX_MITIGATION = 0.75

-----------------------------------
-- Module definition & state
-----------------------------------

local DamageCalculationService = {}

-----------------------------------
-- Public functions
-----------------------------------

function DamageCalculationService.calculateHit(context: DamageContext): DamageResult
	local attacker = context.attackerStats
	local target = context.targetStats

	local base = (attacker["damage" :: StatNames] or 0) * context.damageMultiplier
	local critRate = attacker["critRate" :: StatNames] or 0
	local critDamage = attacker["critDamage" :: StatNames] or 1

	local isCrit = math.random() < critRate
	local rawDamage = if isCrit then base * critDamage else base

	local armor = target["armor" :: StatNames] or 0
	local mitigation = math.min(armor / (armor + ARMOR_CONSTANT), MAX_MITIGATION)

	return {
		amount = math.max(math.floor(rawDamage * (1 - mitigation)), 0),
		isCrit = isCrit,
	}
end

return DamageCalculationService
