local ServerScriptService = game:GetService("ServerScriptService")

local CombatService = require(ServerScriptService.Server.CombatService)
local PlayerService = require(ServerScriptService.Server.PlayerService)
local ItemService = require(ServerScriptService.Server.ItemService)

PlayerService.onStart()
ItemService.onStart()
CombatService.onStart()
