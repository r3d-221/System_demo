--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemData = require(ReplicatedStorage.Shared.ItemData)
local Types = require(ReplicatedStorage.Shared.Types)

type Category = Types.Category

local CategoryList: { Category } = { "weapons", "armors", "materials" }

local ItemInfo = {}

function ItemInfo.getCategory(id: string): Category?
	local category: Category? = nil
	for _, v: Category in CategoryList do
		for key, _ in ItemData[CategoryList] do
			if key == id then
				category = v
				break
			end
		end
	end
	return category
end

function ItemInfo.getInfo(category: Category, id: string): any?
	local categoryData = ItemData[category]
	local itemData = categoryData and categoryData[id]

	if not itemData then
		warn("[ItemInfo] Invalid item id " .. id .. " for category: " .. category)
		return nil
	end

	return itemData
end

return ItemInfo
