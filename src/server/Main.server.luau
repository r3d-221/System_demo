local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server
local CombatService = require(Server.CombatService)
local EnemySpawnService = require(Server.EnemySpawnService)
local InventoryService = require(Server.InventoryService)
local PlayerService = require(Server.PlayerService)
local TeleportationService = require(Server.TeleportationService)
local ItemCollectorService = require(Server.ItemCollectorService)
local DummyService = require(Server.DummyService)

PlayerService.onStart()
CombatService.onStart()
InventoryService.onStart()
EnemySpawnService.onStart()
ItemCollectorService.onStart()
DummyService.onStart()

local point1 = workspace.spawn.point1
local point2 = workspace.combat.point2
local point3 = workspace.combat.point3
local spawnPoint = workspace.spawn.spawn

TeleportationService.new(point1, point2)
TeleportationService.new(point3, spawnPoint)
