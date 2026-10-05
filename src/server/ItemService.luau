--!strict

-- Description
local _ = [[
	Handles creating items. Every module will call this when
	creating any item. Can insert the items to PlayerService.
]]

-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Dependencies
local Server = ServerScriptService.Server
local ItemInfo = require(ReplicatedStorage.Shared.ItemInfo)
local InventoryService = require(Server.InventoryService)

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Util = require(Shared.Util)

-- Types
type Stats = Types.Stats
type Item = Types.Item
type Category = Types.Category

-- Constants
local RANKS = {
	SSS = 0.005,
	SS = 0.015,
	S = 0.05,
	A = 0.15,
	B = 0.20,
	C = 0.25,
	D = 0.35,
}

local RANK_BOOST = {
	SSS = 0.30,
	SS = 0.25,
	S = 0.20,
	A = 0.15,
	B = 0.10,
	C = 0.05,
	D = -0.05,
}

-----------------------------------
-- Module definition & state
-----------------------------------
local ItemService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function rollStats(stats: Stats)
	for name, base in stats do
		local rank = Util.weightedRandom(RANKS)

		local multiplier = RANK_BOOST[rank] or 0

		stats[name] = {
			value = base + (base * multiplier),
			rank = rank,
		}
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function ItemService.createItem(id: string, category: Category, amount: number?): Item?
	local itemData = ItemInfo.getInfo(category, id)
	if not itemData then
		return nil
	end

	if category == "materials" then
		return { id = id, amount = amount or 1 }
	end

	local item: Item = {
		id = id,
		uid = HttpService:GenerateGUID(false),
		level = 1,
		locked = false,
		stats = table.clone(itemData.baseStats),
	}

	if item.stats then
		rollStats(item.stats)
	end

	return item
end

function ItemService.giveItem(player: Player, id: string, category: Category, amount: number?)
	local item = ItemService.createItem(id, category, amount)
	if item then
		InventoryService.addItem(player, item, category)
	end
end

return ItemService
