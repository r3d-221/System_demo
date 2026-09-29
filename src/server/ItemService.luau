--!strict

-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Dependencies
local Server = ServerScriptService:WaitForChild("Server")
local ItemInfo = require(ReplicatedStorage.Shared.ItemInfo)
local PlayerService = require(Server.PlayerService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Util = require(Shared.Util)

-- Types
type Stats = Types.Stats
type Item = Types.Item
type Category = Types.Category

-- Constants
local GENERATOR_TAG = "Generator"
local PROMPT_NAME = "prompt"

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
		PlayerService.addItem(player, item, category)
	end
end

function ItemService.onStart()
	for _, object in CollectionService:GetTagged(GENERATOR_TAG) do
		local prompt = object:FindFirstChild(PROMPT_NAME) :: ProximityPrompt?
		local id = object:FindFirstChild("id") :: StringValue?

		local category = object:FindFirstChild("category") :: StringValue?

		if prompt and id and category then
			prompt.Triggered:Connect(function(player: Player)
				if category.Value ~= "materials" then
					ItemService.giveItem(player, id.Value, category.Value :: Category)
					print(string.format("[ItemService] %s obtained %s", player.Name, id.Value))
				end
			end)
		else
			warn("[ItemService] Generator missing prompt, id, or category: " .. object.Name)
		end
	end
end

return ItemService
