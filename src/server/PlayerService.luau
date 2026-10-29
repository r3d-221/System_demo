--!strict

-- Description
local _ = [[
	Handles player data. Uses profile store to save the data.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local Remotes = ReplicatedStorage.Remotes
local SyncData = Remotes.SyncData

local StatsService = require(ServerScriptService.Server.StatsService)
local Profilestore = require(ServerScriptService.ServerPackages.Profilestore)
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type Item = Types.Item
type PlayerData = Types.PlayerData
type Category = Types.Category

-- Constants
local KEY = "test 1.1"

-----------------------------------
-- Module definition & state
-----------------------------------
local PlayerService = {}

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

local store = Profilestore.New(KEY, defaultData())
local profiles = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return not player:IsDescendantOf(Players)
		end,
	})

	if not profile then
		player:Kick("Failed to load player data!")
		return
	end

	profile:AddUserId(player.UserId)
	profiles[player] = profile
	profile:Reconcile()

	StatsService.recalculate(profile.Data)
	PlayerService.sync(player)
end

local function onPlayerRemoved(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
		profiles[player] = nil
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function PlayerService.onStart()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoved)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function PlayerService.getData(player: Player): PlayerData?
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerService.sync(player: Player)
	local data = PlayerService.getData(player)
	if data then
		SyncData:FireClient(player, data)
	end
end

return PlayerService
