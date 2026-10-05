--!strict

-- Description
local _ = [[
	Handles player data. Doesn't save the data per session since it's
	excessive for a demo.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SyncData = Remotes:WaitForChild("SyncData") :: RemoteEvent

local StatsService = require(ServerScriptService.Server.StatsService)
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type Item = Types.Item
type PlayerData = Types.PlayerData
type Category = Types.Category

-----------------------------------
-- Module definition & state
-----------------------------------
local PlayerService = {}
local playerData = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function defaultData(): PlayerData
	local data: PlayerData = {
		items = {
			weapons = {},
			armors = {},
			materials = {},
		},
		baseStats = {},
		changedStats = {},
		equipped = {
			weapons = nil,
			armors = {
				head = nil,
				torso = nil,
				legs = nil,
				feet = nil,
			},
		},
		tempBuffs = {},
	}

	StatsService.recalculate(data)

	return data
end

local function setUpData(player: Player)
	if playerData[player] then
		return
	end

	local data = defaultData()
	playerData[player] = data
	SyncData:FireClient(player, data)
end

local function clearData(player: Player)
	playerData[player] = nil
	print("[PlayerService] Data cleaned up for: " .. player.Name)
end

-----------------------------------
-- Public functions
-----------------------------------

function PlayerService.onStart()
	for _, player in Players:GetPlayers() do
		task.spawn(setUpData, player)
	end

	Players.PlayerAdded:Connect(setUpData)
	Players.PlayerRemoving:Connect(clearData)
end

function PlayerService.getData(player: Player): PlayerData?
	local data = playerData[player]
	if not data then
		warn("[PlayerService] No data found for: " .. player.Name)
	end
	return data
end

function PlayerService.sync(player: Player)
	local data = playerData[player]
	if data then
		SyncData:FireClient(player, data)
	end
end

function PlayerService.addItem(player: Player, item: Item, category: Category)
	local data = PlayerService.getData(player)
	if not data then
		return
	end

	local categoryList = data.items[category]
	if not categoryList then
		warn("[PlayerService] Attempted to add item to invalid category: " .. tostring(category))
		return
	end

	if category == "materials" then
		local existing
		for _, existingItem in categoryList do
			if existingItem.id == item.id then
				existing = existingItem
				break
			end
		end

		if existing then
			existing.amount = (existing.amount or 0) + (item.amount or 1)
		else
			table.insert(categoryList, item)
		end
	else
		table.insert(categoryList, item)
	end

	SyncData:FireClient(player, data)
end

return PlayerService
