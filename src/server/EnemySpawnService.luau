--!strict

-- Description
local _ = [[
	Spawns enemies in tagged parts. Handles cloning and respawning
	as well.
]]

-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- Dependencies
local Server = ServerScriptService.Server
local EnemyService = require(Server.EnemyService)
local ItemService = require(Server.ItemService)
local EquipmentService = require(ServerScriptService.Server.EquipmentService)

local Shared = ReplicatedStorage.Shared
local EnemyData = require(Shared.EnemyData)
local Types = require(Shared.Types)

local enemyModels = ReplicatedStorage.enemies
local enemyUi = ReplicatedStorage.templates.enemy_ui

-- Types
type EnemyInfo = Types.EnemyInfo
type StatNames = Types.StatNames
type Item = Types.Item

-- Constants
local SPAWNER_TAG = "EnemySpawner"
local ENEMY_TAG = "Enemy"
local WEAPON_EQUIP_CHANCE = 1

-----------------------------------
-- Module definition & state
-----------------------------------

local EnemySpawnService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function spawn(spawnPoint: BasePart, id: string, config: EnemyInfo, onDead: () -> ()): boolean
	local template = enemyModels:FindFirstChild(id)
	if not template or not template:IsA("Model") then
		warn("[EnemySpawnService] No enemy model named " .. id .. " in ReplicatedStorage.enemies")
		return false
	end

	local model = template:Clone()
	model:PivotTo(spawnPoint.CFrame)
	model.Parent = Workspace.enemies

	CollectionService:AddTag(model, ENEMY_TAG)

	local weapon: Item? = nil
	if config.weapon and math.random() <= WEAPON_EQUIP_CHANCE then
		weapon = ItemService.createItem(config.weapon, "weapons")
	end

	local enemy = EnemyService.new(model, config, weapon, onDead)

	if weapon then
		EquipmentService.equipWeapon(model, weapon.id)
		enemy.model:SetAttribute("weapon", weapon.id)
	end

	local head = enemy.model:FindFirstChild("Head")
	if head then
		local clone = enemyUi:Clone()
		clone.Parent = head
	end
	enemy.model:SetAttribute("damage", enemy.stats["damage" :: StatNames])
	return true
end

local function setupSpawner(spawnPoint: BasePart)
	local id = spawnPoint.Name
	local config = EnemyData.enemies[id]
	if not config then
		warn("[EnemySpawnService] No EnemyData entry for: " .. id)
		return
	end

	local amount = (spawnPoint:GetAttribute("amount") :: number?) or 1
	local cooldown = (spawnPoint:GetAttribute("cooldown") :: number?) or 5
	local activeCount = 0

	local trySpawn
	trySpawn = function()
		if activeCount >= amount then
			return
		end

		local spawned = spawn(spawnPoint, id, config, function()
			task.delay(cooldown, function()
				activeCount -= 1
				trySpawn()
			end)
		end)

		if spawned then
			activeCount += 1
		end
	end

	for _ = 1, amount do
		trySpawn()
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function EnemySpawnService.onStart()
	for _, spawnPoint in CollectionService:GetTagged(SPAWNER_TAG) do
		if not spawnPoint:IsA("BasePart") then
			continue
		end
		setupSpawner(spawnPoint)
	end
end

return EnemySpawnService
