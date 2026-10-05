--!strict

-- Description
local _ = [[
	Handles cooldown and drops for item collectors.
]]

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local Server = ServerScriptService:WaitForChild("Server")
local ItemService = require(Server.ItemService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemData = require(Shared.ItemData)
local ItemInfo = require(Shared.ItemInfo)
local Types = require(Shared.Types)

-- Types
type Category = Types.Category
type State = { cooldownUntil: number, generation: number }

-- Constants
local TAG = "ItemCollector"
local BILLBOARD_NAME = "collector_info"
local COOLDOWN_ATTRIBUTE = "cooldown"
local DURATION_ATTRIBUTE = "cooldownDuration"
local DEFAULT_COOLDOWN = 5

-- Variables
local bound: { [Instance]: boolean } = {}

-----------------------------------
-- Module definition
-----------------------------------

local ItemCollectorService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function applyBillboard(pad: BasePart, itemData: any)
	local billboard = pad:FindFirstChild(BILLBOARD_NAME)
	local panel = billboard and billboard:FindFirstChild("panel")
	local label = panel and panel:FindFirstChild("item")
	if not label or not label:IsA("TextLabel") then
		return
	end

	label.Text = string.upper(itemData.name)
	local color = (ItemData.rarityColors :: any)[itemData.rarity]
	if typeof(color) == "Color3" then
		label.TextColor3 = color
	end
end

local function startCooldown(pad: BasePart, highlight: Highlight?, state: State, duration: number)
	state.generation += 1
	local generation = state.generation
	state.cooldownUntil = os.clock() + duration

	if highlight then
		highlight.Enabled = false
	end
	pad:SetAttribute(COOLDOWN_ATTRIBUTE, workspace:GetServerTimeNow() + duration)

	task.delay(duration, function()
		if state.generation ~= generation then
			return
		end
		state.cooldownUntil = 0
		if highlight then
			highlight.Enabled = true
		end
		pad:SetAttribute(COOLDOWN_ATTRIBUTE, nil)
	end)
end

local function bind(pad: Instance)
	if bound[pad] or not pad:IsA("BasePart") then
		return
	end

	local idValue = pad:FindFirstChild("id")
	local categoryValue = pad:FindFirstChild("category")
	if not idValue or not idValue:IsA("StringValue") or not categoryValue or not categoryValue:IsA("StringValue") then
		warn(`[ItemCollectorService] {pad:GetFullName()} needs StringValues named "id" and "category"`)
		return
	end

	local id = idValue.Value
	local category: Category = categoryValue.Value :: Category
	local itemData = ItemInfo.getInfo(category, id) -- warns on its own if the id is invalid
	if not itemData then
		return
	end

	bound[pad] = true
	pad.Destroying:Once(function()
		bound[pad] = nil
	end)

	applyBillboard(pad, itemData)

	local highlight = pad:FindFirstChildWhichIsA("Highlight")
	local durationAttr = pad:GetAttribute(DURATION_ATTRIBUTE)
	local duration = if typeof(durationAttr) == "number" and durationAttr > 0 then durationAttr else DEFAULT_COOLDOWN
	local state: State = { cooldownUntil = 0, generation = 0 }

	pad.Touched:Connect(function(hit: BasePart)
		-- Touched fires for every body part, so reject the cheap case first.
		if os.clock() < state.cooldownUntil then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Lock the pad BEFORE giving the item so queued touches from the same step are ignored.
		startCooldown(pad, highlight, state, duration)
		ItemService.giveItem(player, id, category)
	end)
end

-----------------------------------
-- Public functions
-----------------------------------

function ItemCollectorService.onStart()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)
	for _, pad in CollectionService:GetTagged(TAG) do
		bind(pad)
	end
end

return ItemCollectorService
