--!strict

-- Description
local _ = [[
	Handles the inventory UI.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts:WaitForChild("Client")
local PlayerManager = require(Client.PlayerManager)
local UIManager = require(Client.UIManager)
local UIAnimations = require(Client.UIAnimations)

local Shared = ReplicatedStorage:FindFirstChild("Shared")
local ItemData = require(Shared.ItemData)
local Types = require(Shared.Types)
local Util = require(Shared.Util)
local Signal = require(Shared.Signal)

-- Templates
local templates = ReplicatedStorage:FindFirstChild("templates")
local slotTemplate = templates:WaitForChild("slot_template") :: Frame
local statTemplate = templates:WaitForChild("stat_template") :: Frame
local filterInfoTemplate = templates:WaitForChild("filter_info_template") :: CanvasGroup
local filterInfoTemplateBackground = filterInfoTemplate:FindFirstChild("background") :: ImageLabel
local filterInfoTemplateText = filterInfoTemplate:FindFirstChild("text") :: TextLabel

-- Types
type Item = Types.Item
type Tab = Types.Category
type InfoTab = "stats" | "passives" | "description"
type FilterCategory = "rarity" | "type" | "tags"
type FilterState = { [FilterCategory]: { [string]: boolean? } }

-- Constants
local TAB_KEYS: { Tab } = { "weapons", "armors", "materials" }
local INFO_TAB_KEYS: { InfoTab } = { "stats", "passives", "description" }
local FILTER_CATEGORIES: { FilterCategory } = { "rarity", "type", "tags" }
local RARITY_ORDER = { "common", "rare", "epic", "legendary", "mythic", "secret" }
local FILTER_DEFAULT_COLOR: Color3 = filterInfoTemplateBackground.ImageColor3
local FILTER_DEFAULT_TEXT_COLOR: Color3 = filterInfoTemplateText.TextColor3
local FILTER_DEFAULT_SELECTED_TEXT_COLOR = Color3.fromHex("1F2636")
local BRIGHT_COLOR = Color3.fromRGB(0, 240, 255)
local SEARCH_DEBOUNCE_SECONDS = 0.15
local SEARCH_FUZZY_EDIT_DISTANCE = 2

-----------------------------------
-- Module definition & state
-----------------------------------
local Inventory = {}
Inventory.ScreenClosed = Signal.new()

local Screens = PlayerGui:WaitForChild("Screens")
local inventory = Screens:WaitForChild("inventory") :: CanvasGroup
local canvas = inventory:WaitForChild("canvas") :: Frame
local map = Util.mapUI(canvas)

local currentTab: Tab = "weapons"
local currentItem: Item? = nil
local currentSlotUI: Frame? = nil
local dataConnection: (() -> ())? = nil

local slotItemData = setmetatable({}, { __mode = "k" })

local isFilterOpen = false
local pendingFilters: FilterState = { rarity = {}, type = {}, tags = {} }
local activeFilters: FilterState = { rarity = {}, type = {}, tags = {} }
local filterSLots: { [FilterCategory]: { [string]: CanvasGroup } } = { rarity = {}, type = {}, tags = {} }

local currentSearchQuery = ""
local searchDebounceToken = 0
local searchKeyCache: { [any]: string } = {}

-----------------------------------
-- Helper functions
-----------------------------------

-- capitalizes the first character
local function capitalize(text: string): string
	return text:sub(1, 1):upper() .. text:sub(2)
end

-- only weapons can be uquipped right now
local function isItemEquipped(item: Item): boolean
	local data = PlayerManager.getData()
	if not data or currentTab ~= "weapons" then
		return false
	end
	return data.equipped.weapons == item.uid
end

-- sets the selected slot image for the currenlty inspected slot
local function setSelectedSlot(newSlot: Frame?)
	if currentSlotUI then
		local prev = currentSlotUI:FindFirstChild("selected") :: ImageLabel?
		if prev then
			prev.Visible = false
		end
	end

	currentSlotUI = newSlot

	if currentSlotUI then
		local new = currentSlotUI:FindFirstChild("selected") :: ImageLabel?
		if new then
			new.Visible = true
			UIAnimations.popOut(new)
		end
	end
end

-- changes the info tabs
local function switchInfoTab(tabName: InfoTab)
	for _, key in INFO_TAB_KEYS do
		local isTarget = (key == tabName)
		local container = map[key .. "_info"]
		local tab = map[key]

		if container then
			container.Visible = isTarget
		end
		if tab and tab:FindFirstChild("selected") then
			tab.selected.Visible = isTarget
		end
	end

	if tabName == "stats" then
		Inventory.updateStats()
	end

	if tabName == "description" then
		Inventory.updateDescription()
	end
end

-- changes the category tabs
local function switchTab(newTab: Tab)
	currentTab = newTab

	for _, key in TAB_KEYS do
		local tab = map[key]
		if tab and tab:FindFirstChild("selected") then
			tab.selected.Visible = (key == currentTab)
		end
	end

	Inventory.closeInfo()
	Inventory.updateCurrentTab()
end

-- alternative names for search
local function searchKeys(): ({ string }, { string })
	local typeSet = {}
	local tagSet = {}

	for _, name in TAB_KEYS do
		local category = ItemData[name]
		if category then
			for _, itemData in pairs(category) do
				if itemData.type then
					typeSet[itemData.type] = true
				end
				if itemData.tags then
					for _, tag in itemData.tags do
						tagSet[tag] = true
					end
				end
			end
		end
	end

	local types = {}
	local tags = {}
	for name in pairs(typeSet) do
		table.insert(types, name)
	end
	for name in pairs(tagSet) do
		table.insert(tags, name)
	end
	table.sort(types)
	table.sort(tags)

	return types, tags
end

-- creates stats
local function createStat(name: string, rank: string, text: string, delayIndex: number)
	local statFrame = statTemplate:Clone()
	statFrame.Name = name

	local statAmount = statFrame:FindFirstChild("stat_amount") :: TextLabel?
	local statRank = statFrame:FindFirstChild("stat_rank") :: TextLabel?
	local statName = statFrame:FindFirstChild("stat_name") :: TextLabel?

	if statAmount then
		statAmount.MaxVisibleGraphemes = 0
	end
	if statRank then
		statRank.MaxVisibleGraphemes = 0
	end
	if statName then
		statName.MaxVisibleGraphemes = 0
	end

	statFrame.Parent = map.stats_info

	task.delay(delayIndex * 0.08, function()
		if statFrame.Parent then
			if statName then
				UIAnimations.typewrite(statName, name .. ":", 0.02)
			end
			if statRank then
				UIAnimations.typewrite(statRank, rank, 0.02)
			end
			if statAmount then
				UIAnimations.typewrite(statAmount, text, 0.02)
			end
		end
	end)
end

-- creates inventory slots
local function createInventorySlot(item: Item, parent: Instance?): Frame?
	local category = ItemData[currentTab]
	local itemData = category and category[item.id]
	if not itemData then
		warn(string.format("[Inventory] Missing data for '%s' in tab '%s'", item.id, currentTab))
		return nil
	end

	local slot = slotTemplate:Clone()
	slot.Name = "slot"
	slot:SetAttribute("uid", item.uid)

	local background = slot:FindFirstChild("background") :: ImageLabel?
	if background and ItemData.itemFrames then
		background.Image = ItemData.itemFrames[itemData.rarity]
	end

	local selectedFrame = slot:FindFirstChild("selected") :: Frame?
	if selectedFrame then
		selectedFrame.Visible = false
	end

	local equippedHighlight = Instance.new("UIStroke")
	equippedHighlight.Name = "EquippedHighlight"
	equippedHighlight.Thickness = 2
	equippedHighlight.Color = BRIGHT_COLOR
	equippedHighlight.Enabled = isItemEquipped(item)
	equippedHighlight.Parent = slot

	local image = slot:FindFirstChild("image") :: ImageLabel?
	if itemData.image and image then
		image.Image = itemData.image
	end

	local amount = slot:FindFirstChild("amount") :: Frame?
	if amount and currentTab == "materials" then
		local text = amount:FindFirstChild("text") :: TextLabel?
		if text then
			amount.Visible = true
			UIAnimations.typewrite(text, tostring(item.amount) .. "x", 0.03)
		end
	end

	local button = slot:FindFirstChild("button") :: TextButton?
	if button then
		button.MouseEnter:Connect(function()
			UIAnimations.hover(slot, true)
		end)
		button.MouseLeave:Connect(function()
			UIAnimations.hover(slot, false)
		end)

		button.MouseButton1Click:Connect(function()
			UIAnimations.popOut(slot)
			setSelectedSlot(slot)
			currentItem = item
			Inventory.updateInfo()
		end)
	end

	slot.Parent = parent or map.list

	-- Only slots in the main grid (not the "item" preview slot in the info
	-- panel) need to participate in filtering/search.
	if not parent then
		slotItemData[slot] = itemData
	end

	return slot
end

-----------------------------------
-- Item equipping
-----------------------------------

-- updates the equip, unequip, sell buttons
local function updateInfoButtons()
	local item = currentItem
	local equipped = item ~= nil and isItemEquipped(item)
	local supportsEquip = (currentTab == "weapons")

	map.equip.Visible = supportsEquip and not equipped
	map.unequip.Visible = supportsEquip and equipped
	map.sell.Visible = (currentTab ~= "materials")
end

-- equips current item
local function equipCurrentItem()
	local item = currentItem
	if not item then
		return
	end

	if not item.uid then
		return
	end

	PlayerManager.equipItem(currentTab, item.uid)
end

-- unequips current item
local function unequipCurrentItem()
	if currentTab ~= "weapons" then
		return
	end
	PlayerManager.unequipItem(currentTab)
end

-- sells current item
local function sellCurrentItem()
	local item = currentItem
	if not item or not item.uid then
		return
	end
	PlayerManager.sellItem(currentTab, item.uid)
	Inventory.closeInfo()
end

local function setUpButtons()
	local closeButton = map.close:FindFirstChild("button") :: TextButton

	closeButton.MouseEnter:Connect(function()
		UIAnimations.hover(map.close, true)
	end)
	closeButton.MouseLeave:Connect(function()
		UIAnimations.hover(map.close, false)
	end)
	closeButton.MouseButton1Click:Connect(function()
		UIAnimations.popOut(map.close)

		UIAnimations.windowClose(inventory, canvas)

		if isFilterOpen then
			isFilterOpen = false
			map.filter_info.Visible = false
			map.filter_close.Visible = false
		end

		UIManager.closeAll()
		Inventory.clearSlots()
		Inventory.clearStats()
		Inventory.closeInfo()

		Inventory.ScreenClosed:Fire()
	end)

	for _, name in TAB_KEYS do
		local tab = map[name]
		if tab and tab:FindFirstChild("button") then
			local button = tab.button
			button.MouseEnter:Connect(function()
				UIAnimations.hover(tab, true)
			end)
			button.MouseLeave:Connect(function()
				UIAnimations.hover(tab, false)
			end)
			button.MouseButton1Click:Connect(function()
				UIAnimations.popOut(tab)
				switchTab(name :: Tab)
			end)
		end
	end

	for _, name in INFO_TAB_KEYS do
		local info = map[name]
		if info and info:FindFirstChild("button") then
			local button = info.button
			button.MouseEnter:Connect(function()
				UIAnimations.hover(info, true)
			end)
			button.MouseLeave:Connect(function()
				UIAnimations.hover(info, false)
			end)
			button.MouseButton1Click:Connect(function()
				if name ~= "description" and currentTab == "materials" then
					return
				end
				UIAnimations.popOut(info)
				switchInfoTab(name :: InfoTab)
			end)
		end
	end

	local filterButton = map.filter:FindFirstChild("button") :: TextButton?
	if filterButton then
		filterButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.filter, true)
		end)
		filterButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.filter, false)
		end)
		filterButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.filter)
			Inventory.toggleFilterPanel()
		end)
	end

	local filterCloseButton = map.filter_close:FindFirstChild("button") :: TextButton?
	if filterCloseButton then
		filterCloseButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.filter_close, true)
		end)
		filterCloseButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.filter_close, false)
		end)
		filterCloseButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.filter_close)
			Inventory.closeFilterPanel()
		end)
	end

	local applyButton = map.filter_apply:FindFirstChild("button") :: TextButton?
	if applyButton then
		applyButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.filter_apply, true)
		end)
		applyButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.filter_apply, false)
		end)
		applyButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.filter_apply)
			Inventory.applyPendingFilters()
		end)
	end

	local resetButton = map.filter_reset:FindFirstChild("button") :: TextButton?
	if resetButton then
		resetButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.filter_reset, true)
		end)
		resetButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.filter_reset, false)
		end)
		resetButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.filter_reset)
			Inventory.resetFilters()
		end)
	end

	local searchBox = map.search_text :: TextBox
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		searchDebounceToken += 1
		local requestToken = searchDebounceToken

		task.delay(SEARCH_DEBOUNCE_SECONDS, function()
			if requestToken ~= searchDebounceToken then
				return
			end
			currentSearchQuery = searchBox.Text:lower()
			Inventory.refreshVisibility()
		end)
	end)

	local equipButton = map.equip:FindFirstChild("button") :: TextButton?
	if equipButton then
		equipButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.equip, true)
		end)
		equipButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.equip, false)
		end)
		equipButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.equip)
			equipCurrentItem()
		end)
	end

	local unequipButton = map.unequip:FindFirstChild("button") :: TextButton?
	if unequipButton then
		unequipButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.unequip, true)
		end)
		unequipButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.unequip, false)
		end)
		unequipButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.unequip)
			unequipCurrentItem()
		end)
	end

	local sellButton = map.sell:FindFirstChild("button") :: TextButton?
	if sellButton then
		sellButton.MouseEnter:Connect(function()
			UIAnimations.hover(map.sell, true)
		end)
		sellButton.MouseLeave:Connect(function()
			UIAnimations.hover(map.sell, false)
		end)
		sellButton.MouseButton1Click:Connect(function()
			UIAnimations.popOut(map.sell)
			sellCurrentItem()
		end)
	end
end

-----------------------------------
-- Filter
-----------------------------------

-- checks which filters are currently active
local function checkActiveFilter(itemData: any): boolean
	if not itemData then
		return false
	end

	local rarityFilters = activeFilters["rarity" :: FilterCategory]
	local typeFilters = activeFilters["type" :: FilterCategory]
	local tagFilters = activeFilters["tags" :: FilterCategory]

	-- if rarity is not selected then skips it, doesn't return false
	-- only returns flase if both conditions true
	-- the next() checks if the table is empty
	if next(rarityFilters) and not rarityFilters[itemData.rarity] then
		return false
	end

	if next(typeFilters) and not typeFilters[itemData.type] then
		return false
	end

	if next(tagFilters) then
		local matchedTag = false
		for _, tag in itemData.tags or {} do
			if tagFilters[tag] then
				matchedTag = true
				break
			end
		end
		if not matchedTag then
			return false
		end
	end

	return true
end

-- changes the filter slots to selected if clicked
local function toggleFilterSlot(slot: CanvasGroup, isSelected: boolean, selectedColor: Color3?)
	local background = slot:FindFirstChild("background") :: ImageLabel?
	local text = slot:FindFirstChild("text") :: TextLabel?

	if background then
		background.ImageColor3 = isSelected and (selectedColor or BRIGHT_COLOR) or FILTER_DEFAULT_COLOR
	end
	if text then
		text.TextColor3 = isSelected and FILTER_DEFAULT_SELECTED_TEXT_COLOR or FILTER_DEFAULT_TEXT_COLOR
	end
end

-- creates filter slots
local function createFilterSlot(category: FilterCategory, value: string, name: string, parent: Instance)
	local filterSlot = filterInfoTemplate:Clone()
	filterSlot.Name = value

	local text = filterSlot:FindFirstChild("text") :: TextLabel?
	if text then
		text.Text = name
	end

	toggleFilterSlot(filterSlot, pendingFilters[category][value] == true)

	local button = filterSlot:FindFirstChild("button") :: TextButton?
	if button then
		button.MouseEnter:Connect(function()
			UIAnimations.hover(filterSlot, true)
		end)
		button.MouseLeave:Connect(function()
			UIAnimations.hover(filterSlot, false)
		end)
		button.MouseButton1Click:Connect(function()
			UIAnimations.popOut(filterSlot)

			local isSelected = not pendingFilters[category][value]
			pendingFilters[category][value] = isSelected or nil
			toggleFilterSlot(filterSlot, isSelected)
		end)
	end

	filterSlot.Parent = parent
	filterSLots[category][value] = filterSlot
	return filterSlot
end

-- clears the filter slots
local function clearFilterSLots(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("CanvasGroup") then
			child:Destroy()
		end
	end
end

-- updates the filter options based on the data
local function updateFilterOptions()
	clearFilterSLots(map.filter_rarity)
	clearFilterSLots(map.filter_types)
	clearFilterSLots(map.filter_tags_scroll)
	filterSLots = { rarity = {}, type = {}, tags = {} }

	for _, name in RARITY_ORDER do
		createFilterSlot("rarity", name, capitalize(name), map.filter_rarity)
	end

	local typeOptions, tagOptions = searchKeys()

	for _, name in typeOptions do
		createFilterSlot("type", name, capitalize(name), map.filter_types)
	end

	for _, name in tagOptions do
		createFilterSlot("tags", name, capitalize(name), map.filter_tags_scroll)
	end
end

-- clears the pending filter list
local function syncPendingFromActive()
	for _, category: FilterCategory in FILTER_CATEGORIES do
		local slots = filterSLots[category]
		for value, slot in pairs(slots) do
			local isSelected = activeFilters[category][value] == true
			pendingFilters[category][value] = isSelected or nil

			toggleFilterSlot(slot, isSelected)
		end
	end
end

-- creates a copy of the filter state
local function copyFilterState(source: FilterState): FilterState
	local copy: FilterState = { rarity = {}, type = {}, tags = {} }
	for _, category: FilterCategory in FILTER_CATEGORIES do
		for value in pairs(source[category]) do
			copy[category][value] = true
		end
	end
	return copy
end

-----------------------------------
-- Search
-----------------------------------

-- Wagner–Fischer
-- changes string a to string b if they are close
local function editDistance(a: string, b: string): number
	local lengthA, lengthB = #a, #b
	if lengthA == 0 then
		return lengthB
	end
	if lengthB == 0 then
		return lengthA
	end

	-- O(n) space complexity
	-- uses two 1D arrays instead of the whole matrix
	local previousRow: { number } = table.create(lengthB + 1, 0)
	local currentRow: { number } = table.create(lengthB + 1, 0)

	-- add to the table
	for j = 0, lengthB do
		previousRow[j + 1] = j
	end

	-- remove data from previous row and add it to the next row
	for i = 1, lengthA do
		currentRow[1] = i
		local charA = string.byte(a, i)

		for j = 1, lengthB do
			local charB = string.byte(b, j)
			local cost = (charA == charB) and 0 or 1

			local deletion = previousRow[j + 1] + 1
			local insertion = currentRow[j] + 1
			local substitution = previousRow[j] + cost

			currentRow[j + 1] = math.min(deletion, insertion, substitution)
		end

		-- swap rows
		previousRow, currentRow = currentRow, previousRow
	end

	return previousRow[lengthB + 1]
end

-- looks for if the input string is a close match
local function isCloseMatch(query: string, word: string): boolean
	if #query == 0 or #word == 0 then
		return false
	end

	if string.find(word, query, 1, true) then
		return true
	end

	local maxDistance = (#query <= 4) and 1 or SEARCH_FUZZY_EDIT_DISTANCE
	return editDistance(query, word) <= maxDistance
end

-- gets the search key of an item from the item data
local function getItemSearchKey(itemData: any): string
	local cached = searchKeyCache[itemData]
	if cached then
		return cached
	end

	local parts: { string } = { tostring(itemData.name or "") }

	local keywords = itemData.keywords :: { string }?
	if keywords then
		for _, keyword in keywords do
			table.insert(parts, tostring(keyword))
		end
	end

	local key = table.concat(parts, " "):lower()
	searchKeyCache[itemData] = key
	return key
end

local function matchesSearchQuery(itemData: any, query: string): boolean
	if query == "" then
		return true
	end

	local searchKey = getItemSearchKey(itemData)

	if string.find(searchKey, query, 1, true) then
		return true
	end

	-- checks for typos and has leeway
	for queryWord in string.gmatch(query, "%S+") do
		local foundMatch = false

		for itemWord in string.gmatch(searchKey, "%S+") do
			if isCloseMatch(queryWord, itemWord) then
				foundMatch = true
				break
			end
		end

		if not foundMatch then
			return false
		end
	end

	return true
end

local function checkSearch(itemData: any): boolean
	return matchesSearchQuery(itemData, currentSearchQuery)
end

-----------------------------------
-- Public functions
-----------------------------------

function Inventory.onStart()
	setUpButtons()
	updateFilterOptions()

	dataConnection = PlayerManager.onChange(function(data)
		if data and data.items then
			Inventory.updateSlots(data.items)
		end
		if currentItem then
			updateInfoButtons()
		end
	end)

	Inventory.updateCurrentTab()
end

-- opens the filter panel
function Inventory.openFilterPanel()
	if isFilterOpen then
		return
	end
	isFilterOpen = true

	syncPendingFromActive()

	UIAnimations.windowOpen(map.filter_info, map.filter_info)
	UIAnimations.windowOpen(map.filter_close, map.filter_close)
end

-- closes the filter panel
function Inventory.closeFilterPanel()
	if not isFilterOpen then
		return
	end
	isFilterOpen = false

	UIAnimations.windowClose(map.filter_info, map.filter_info)
	UIAnimations.windowClose(map.filter_close, map.filter_close)
end

-- toggle for filter panel
function Inventory.toggleFilterPanel()
	if isFilterOpen then
		Inventory.closeFilterPanel()
	else
		Inventory.openFilterPanel()
	end
end

-- applies the pending filters
function Inventory.applyPendingFilters()
	activeFilters = copyFilterState(pendingFilters)
	Inventory.refreshVisibility()
	Inventory.closeFilterPanel()
end

-- resets the filter settings
function Inventory.resetFilters()
	pendingFilters = { rarity = {}, type = {}, tags = {} }
	activeFilters = { rarity = {}, type = {}, tags = {} }

	for _, category: FilterCategory in FILTER_CATEGORIES do
		for value, filterSlot in pairs(filterSLots[category]) do
			local accentColor = (category == "rarity") and ItemData.rarityColors[value] or nil
			toggleFilterSlot(filterSlot, false, accentColor)
		end
	end

	Inventory.refreshVisibility()
end

-- sets the visibility of the inventory slots based on the filters
function Inventory.refreshVisibility()
	for _, slot in map.list:GetChildren() do
		if slot:IsA("Frame") then
			local itemData = slotItemData[slot]
			slot.Visible = (itemData ~= nil) and checkActiveFilter(itemData) and checkSearch(itemData)
		end
	end
end

-- destroys all inventory slots
function Inventory.clearSlots()
	setSelectedSlot(nil)
	for _, child in map.list:GetChildren() do
		if child:IsA("Frame") then
			UIAnimations.cancel(child)
			child:Destroy()
		end
	end
end

-- destroys all stats
function Inventory.clearStats()
	for _, child in map.stats_info:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- toggle for info panel
function Inventory.toggleInfo(isVisible: boolean)
	if map.info:IsA("CanvasGroup") then
		UIAnimations.fade(map.info, isVisible)
	else
		for _, child in map.info:GetChildren() do
			child.Visible = isVisible
		end
	end

	if not isVisible then
		for _, child in map.item:GetChildren() do
			if child:IsA("Frame") or child:IsA("ImageLabel") then
				child:Destroy()
			end
		end
	end
end

-- closes the info panel
function Inventory.closeInfo()
	setSelectedSlot(nil)
	currentItem = nil

	for _, child in map.info:GetChildren() do
		child.Visible = false
	end
end

-- sets animations for the panels
function Inventory.playSectionFades()
	local sectionsToFade = {}

	local order = { "search", "filter", "weapons", "armors", "materials", "grid", "info" }

	for _, name in ipairs(order) do
		local element = map[name]
		if element and element:IsA("CanvasGroup") then
			table.insert(sectionsToFade, element)
		end
	end

	UIAnimations.staggerSectionsIn(sectionsToFade)
end

-- updates the inventory slots
function Inventory.updateSlots(items)
	Inventory.clearSlots()

	local tabItems = items and items[currentTab]
	if not tabItems then
		return
	end

	local index = 0
	for _, item in tabItems do
		local slot = createInventorySlot(item)
		if slot then
			index += 1
			UIAnimations.staggerPopIn(slot, index)
		end
	end

	Inventory.refreshVisibility()
end

-- updates the current tab
function Inventory.updateCurrentTab()
	local data = PlayerManager.getData()
	if data and data.items then
		Inventory.updateSlots(data.items)
	end
end

function Inventory.updateStats()
	local item = currentItem
	if not item or not item.stats then
		return
	end

	Inventory.clearStats()

	local itemStats = item.stats :: { [string]: Types.Roll }

	local index = 0
	for _, name in ipairs(ItemData.statOrder) do
		local stat = itemStats[name]

		if stat then
			index += 1
			local isPercent = ItemData.statTypes[name] == "percent"
			local displayValue = if isPercent
				then string.format("%.1f%%", stat.value * 100)
				else tostring(math.floor(stat.value))

			createStat(ItemData.statNames[name], stat.rank, displayValue, index)
		end
	end
end

function Inventory.updateDescription()
	local item = currentItem
	if not item then
		return
	end

	local itemData = ItemData[currentTab][item.id]
	if not itemData then
		return
	end

	local fill = "A description about something."

	if itemData.description then
		map.description_info.text.Text = itemData.description
	else
		map.description_info.text.Text = fill
	end
end

function Inventory.updateInfo()
	local item = currentItem
	if not item then
		return
	end

	local category = ItemData[currentTab]
	local itemData = category and category[item.id]
	if not itemData then
		return
	end

	Inventory.toggleInfo(false)

	local slot = createInventorySlot(item, map.item)
	if slot then
		local button = slot:FindFirstChild("button")
		if button then
			button:Destroy()
		end

		local selected = slot:FindFirstChild("selected")
		if selected then
			selected:Destroy()
		end

		UIAnimations.popOut(slot)
	end

	if map.item:IsA("CanvasGroup") then
		UIAnimations.fade(map.item, true)
	else
		map.item.Visible = true
	end

	local hasStats = (currentTab ~= "materials")

	Inventory.toggleInfo(true)
	map.item_info.Visible = true
	map.info_tabs.Visible = true
	map.stats.Visible = hasStats
	map.passives.Visible = hasStats
	map.description.Visible = true

	map.title.Visible = true
	UIAnimations.typewrite(map.title.text, itemData.name, 0.03)

	updateInfoButtons()
	switchInfoTab(if hasStats then "stats" else "description")
end

function Inventory.onDestroy()
	if dataConnection then
		dataConnection()
		dataConnection = nil
	end
	Inventory.clearSlots()
	Inventory.clearStats()
end

return Inventory
