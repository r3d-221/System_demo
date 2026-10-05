--!strict

-- Description
local _ = [[
	returns item data based on the ItemData module.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local ItemData = require(ReplicatedStorage.Shared.ItemData)
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type Category = Types.Category

-----------------------------------
-- Module definition & state
-----------------------------------

local ItemInfo = {}
local CategoryList: { Category } = { "weapons", "armors", "materials" }

-----------------------------------
-- Public functions
-----------------------------------

function ItemInfo.getCategory(id: string): Category?
	for _, category: Category in CategoryList do
		local categoryData = ItemData[category]
		if categoryData and categoryData[id] then
			return category
		end
	end
	return nil
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
