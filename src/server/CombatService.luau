--!strict

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local Server = ServerScriptService.Server
local ItemData = require(ReplicatedStorage.Shared.ItemData)
local DamageCalculationService = require(Server.DamageCalculationService)
local HitboxService = require(Server.HitboxService)
local PlayerService = require(Server.PlayerService)
local StatsService = require(ServerScriptService.Server.StatsService)

local Remotes = ReplicatedStorage.Remotes
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)
local Attack = Remotes.Attack

-- Types
type PlayerData = Types.PlayerData
type WeaponInfo = Types.WeaponInfo
type DamageContext = Types.DamageContext
type Entity = Types.Entity
type StatMap = Types.StatMap

-- Constants
local EMPTY_STATS: StatMap = {}
local ENEMY_TAG = "Enemy"

-----------------------------------
-- Module definition & state
-----------------------------------

local CombatService = {}
local attacking: { [Humanoid]: boolean } = {}

-----------------------------------
-- Helper functions
-----------------------------------

-- TO DO: cache weapon info
local function getWeaponInfo(data: PlayerData): WeaponInfo?
	local item = StatsService.getEquippedItem(data, "weapons", data.equipped.weapons)
	return item and ItemData.weapons[item.id]
end

local function createContext(entity: Entity, target: Humanoid): DamageContext
	local targetCharacter = target.Parent
	local targetPlayer = targetCharacter and Players:GetPlayerFromCharacter(targetCharacter :: Model)
	local targetData = targetPlayer and PlayerService.getData(targetPlayer)

	return {
		attackerStats = entity.stats,
		targetStats = if targetData then targetData.changedStats else EMPTY_STATS,
		damageMultiplier = 1,
	}
end

local function playerEntity(character: Model, humanoid: Humanoid, rootPart: BasePart, data: PlayerData): Entity
	return {
		model = character,
		humanoid = humanoid,
		rootPart = rootPart,
		stats = data.changedStats,
		getStat = function(_self, stat)
			return StatsService.getStat(data, stat)
		end,
	} :: Entity
end

-----------------------------------
-- Public functions
-----------------------------------

function CombatService.onStart()
	Attack.OnServerEvent:Connect(function(player: Player)
		local character = player.Character
		local humanoid, rootPart = Util.checkHumanoid(character)

		if not (character and humanoid and rootPart) or humanoid.Health <= 0 then
			return
		end

		local data = PlayerService.getData(player)
		if not data then
			return
		end

		local weaponInfo = getWeaponInfo(data)
		if not weaponInfo then
			return
		end

		local entity = playerEntity(character, humanoid, rootPart, data)
		CombatService.basicAttack(entity, weaponInfo)
	end)
end

function CombatService.basicAttack(entity: Entity, weaponInfo: WeaponInfo)
	if attacking[entity.humanoid] then
		return
	end
	attacking[entity.humanoid] = true

	task.spawn(function()
		task.wait(weaponInfo.windUp)
		local humanoid = entity.humanoid

		if humanoid.Health > 0 then
			local hitbox =
				HitboxService.new(weaponInfo.hitbox, entity.rootPart.CFrame, { entity.model }, RunService:IsStudio())

			for _, target in hitbox:CheckHumanoids() do
				local targetModel = target.Parent
				if
					CollectionService:HasTag(entity.model, ENEMY_TAG)
					and targetModel
					and CollectionService:HasTag(targetModel, ENEMY_TAG)
				then
					local attacker = Players:GetPlayerFromCharacter(entity.model)
					if attacker and targetModel then
						targetModel:SetAttribute("lastAttacker", attacker.UserId)
					end
					continue
				end
				local context = createContext(entity, target)
				local result = DamageCalculationService.calculateHit(context)
				target:TakeDamage(result.amount)
				print("[CombatService] " .. target.Name .. " took " .. result.amount .. " damage")
			end

			task.delay(weaponInfo.active, function()
				hitbox:Destroy()
			end)
		end

		task.wait(weaponInfo.active + weaponInfo.recovery)
		attacking[humanoid] = nil

		humanoid.Destroying:Once(function()
			attacking[humanoid] = nil
		end)
	end)
end

return CombatService
