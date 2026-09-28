--!strict

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
type Cateogry = Types.Cateogry

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
			weapons = {
				{
					id = "ironSword",
					uid = "test",
					stats = {
						damage = { value = 10, rank = "D" },
						critRate = { value = 1, rank = "D" },
						critDamage = { value = 1.5, rank = "D" },
						attackSpeed = { value = 0.1, rank = "D" },
					},
				},
			},
			armors = {},
			materials = {},
		},
		baseStats = {},
		changedStats = {},
		equipped = {
			weapons = "test",
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
	print(playerData[player])
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

function PlayerService.getData(player: Player)
	local data = playerData[player]
	if not data then
		warn("[PlayerService] No data found for: " .. player.Name)
	end
	return data
end

function PlayerService.addItem(player: Player, item: Item, category: Cateogry)
	local data = PlayerService.getData(player)
	if not data then
		return
	end

	local categoryList = data.items[category]
	if categoryList then
		if category ~= "materials" then
			table.insert(categoryList, item)
			SyncData:FireClient(player, data)
		end
		-- the materials will stack
	else
		warn(string.format("[PlayerService] Attempted to add item to invalid category: '%s'", tostring(category)))
	end
end

return PlayerService
