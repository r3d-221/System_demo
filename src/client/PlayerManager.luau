--!strict

-- Description
local _ = [[
	Syncs the player data from server to client.	
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Remotes = ReplicatedStorage.Remotes
local SyncData = Remotes.SyncData
local EquipItem = Remotes.EquipItem
local UnequipItem = Remotes.UnequipItem
local SellItem = Remotes.SellItem

local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type PlayerData = Types.PlayerData
type Category = Types.Category
type Listener = (data: PlayerData) -> ()

-----------------------------------
-- Module definition & state
-----------------------------------

local listeners: { [any]: Listener } = {}
local public = {}
local cache: PlayerData? = nil

-----------------------------------
-- Public functions
-----------------------------------

function public.onStart()
	SyncData.OnClientEvent:Connect(function(data: PlayerData)
		cache = data
		for _, fn in listeners do
			fn(data)
		end
	end)
end

function public.getData(): PlayerData?
	return cache
end

-- returns a function that removes this listener
function public.onChange(fn: Listener): () -> ()
	local token = {}
	listeners[token] = fn

	return function()
		listeners[token] = nil
	end
end

function public.equipItem(category: Category, uid: string)
	EquipItem:FireServer(category, uid)
end

function public.unequipItem(category: Category)
	UnequipItem:FireServer(category)
end

function public.sellItem(category: Category, uid: string)
	SellItem:FireServer(category, uid)
end

return public
