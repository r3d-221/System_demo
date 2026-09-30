--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local Server = ServerScriptService.Server
local PlayerService = require(Server.PlayerService)
local StatsService = require(Server.StatsService)
local EquipmentService = require(Server.EquipmentService)
local Types = require(ReplicatedStorage.Shared.Types)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipItem = Remotes.EquipItem
local UnequipItem = Remotes.UnequipItem
local SellItem = Remotes.SellItem

-- Types
type Category = Types.Category
type PlayerData = Types.PlayerData

-- Constants
local EQUIPPABLE_CATEGORIES: { [Category]: boolean } = { weapons = true } -- add armors
local SELLABLE_CATEGORIES: { [Category]: boolean } = { weapons = true, armors = true }

-----------------------------------
-- Module definition & state
-----------------------------------

local InventoryService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function findItemIndex(data: PlayerData, category: Category, uid: string): number?
	local list = data.items[category]
	if not list then
		return nil
	end
	for index, item in list do
		if item.uid == uid then
			return index
		end
	end
	return nil
end

local function equipSavedWeapon(player: Player, character: Model)
	local data = PlayerService.getData(player)
	if not data or not data.equipped.weapons then
		return
	end

	local item = StatsService.getEquippedItem(data, "weapons", data.equipped.weapons)
	if not item then
		data.equipped.weapons = nil
		StatsService.recalculate(data)
		PlayerService.sync(player)
		return
	end

	EquipmentService.equipWeapon(character, item.id)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		equipSavedWeapon(player, character)
	end)
	if player.Character then
		task.spawn(equipSavedWeapon, player, player.Character)
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function InventoryService.onStart()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	EquipItem.OnServerEvent:Connect(function(player: Player, category: Category, uid: string)
		if not EQUIPPABLE_CATEGORIES[category] then
			warn("[InventoryService] Equipping" .. tostring(category) .. " isn't supported yet")
			return
		end

		local data = PlayerService.getData(player)
		if not data then
			return
		end

		local item = StatsService.getEquippedItem(data, category, uid)
		if not item then
			warn("[InventoryService] " .. player.Name .. " tried to equip unknown item " .. uid)
			return
		end

		local character = player.Character :: Model
		local didEquip = EquipmentService.equipWeapon(character, item.id)
		if not didEquip then
			return
		end

		data.equipped.weapons = uid
		StatsService.recalculate(data)
		PlayerService.sync(player)
	end)

	UnequipItem.OnServerEvent:Connect(function(player: Player, category: Category)
		if not EQUIPPABLE_CATEGORIES[category] then
			return
		end

		local data = PlayerService.getData(player)
		if not data then
			return
		end

		data.equipped.weapons = nil
		StatsService.recalculate(data)
		EquipmentService.unequipWeapon(player)
		PlayerService.sync(player)
	end)

	SellItem.OnServerEvent:Connect(function(player: Player, category: Category, uid: string)
		if not SELLABLE_CATEGORIES[category] then
			warn("[InventoryService] Selling " .. tostring(category) .. " isn't supported yet")
			return
		end

		local data = PlayerService.getData(player)
		if not data then
			return
		end

		local index = findItemIndex(data, category, uid)
		if not index then
			return
		end

		if category == "weapons" and data.equipped.weapons == uid then
			data.equipped.weapons = nil
			EquipmentService.unequipWeapon(player)
		end

		table.remove(data.items[category], index)
		StatsService.recalculate(data)
		PlayerService.sync(player)
	end)
end

return InventoryService
