local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService.Server
local CombatService = require(Server.CombatService)
local EnemySpawnService = require(Server.EnemySpawnService)
local InventoryService = require(Server.InventoryService)
local PlayerService = require(Server.PlayerService)
local ItemService = require(Server.ItemService)

PlayerService.onStart()
ItemService.onStart()
CombatService.onStart()
InventoryService.onStart()
EnemySpawnService.onStart()
