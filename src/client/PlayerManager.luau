local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage.Remotes
local SyncData = Remotes.SyncData

local EquipItem = Remotes.EquipItem
local UnequipItem = Remotes.UnequipItem
local SellItem = Remotes.SellItem

local listeners = {}
local public = {}
local cache = nil

function public.onStart()
	SyncData.OnClientEvent:Connect(function(data)
		cache = data
		for _, fn in listeners do
			fn(data)
		end
	end)
end

function public.getData()
	return cache
end

function public.onChange(fn)
	table.insert(listeners, fn)
end

function public.equipItem(category, uid)
	EquipItem:FireServer(category, uid)
end

function public.unequipItem(category)
	UnequipItem:FireServer(category)
end

function public.sellItem(category, uid)
	SellItem:FireServer(category, uid)
end

return public
