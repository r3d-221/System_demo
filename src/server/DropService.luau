--!strict

-- Description
local _ = [[
	Spawns collectable drops when killing enemies.
	Only owner can collect for the first few seconds and 
	then it becomes public.
]]

-- Services
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

-- Dependencies
local ItemInfo = require(ReplicatedStorage.Shared.ItemInfo)
local ItemService = require(ServerScriptService.Server.ItemService)
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type Category = Types.Category
type DropEntry = Types.DropEntry

-- Variables
local templateFolders: { [Category]: Folder } = {
	weapons = ReplicatedStorage.weapons,
	materials = ReplicatedStorage.materials,
}

-- Constants
local DROP_TAG = "drop"
local DROP_LIFETIME = 60
local PUBLIC_AFTER = 15

-----------------------------------
-- Module definition & state
-----------------------------------

local DropService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function spawn(position: Vector3, id: string, category: Category, amount: number, userId: number?)
	local folder = templateFolders[category]
	local template = folder and folder:FindFirstChild(id)
	if not template or not template:IsA("BasePart") then
		warn("[DropService] No drop template for " .. category .. " / " .. id)
		return
	end

	local drop = template:Clone()
	drop.Position = position + Vector3.new(0, 1, 0)
	drop.Anchored = false
	drop.Parent = Workspace.drops

	CollectionService:AddTag(drop, DROP_TAG)

	if userId then
		drop:SetAttribute("owner", userId)
		task.delay(PUBLIC_AFTER, function()
			if drop.Parent then
				drop:SetAttribute("owner", nil)
			end
		end)
	end

	local prompt = drop:FindFirstChild("prompt") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function(player: Player)
			ItemService.giveItem(player, id, category, amount)
			drop:Destroy()
		end)
	end

	Debris:AddItem(drop, DROP_LIFETIME)
end

-----------------------------------
-- Public functions
-----------------------------------

function DropService.spawnDrops(position: Vector3, drops: { [string]: DropEntry }, userId: number?)
	for id, entry in drops do
		if math.random() <= entry.chance then
			local category: Category? = ItemInfo.getCategory(id)
			if not category then
				warn("[DropService] Could not resolve category for drop id: " .. id)
				continue
			end
			local amount = math.random(entry.amount.min, entry.amount.max)
			spawn(position, id, category, amount, userId)
		end
	end
end

return DropService
