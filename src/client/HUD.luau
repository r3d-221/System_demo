--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client
local PlayerManager = require(Client.PlayerManager)
local UIManager = require(Client.UIManager)
local UIAnimationManager = require(Client.UIAnimationManager)
local Inventory = require(Client.Inventory)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = require(Shared.Util)

-- Constants
local COLOR_PASSIVE = Color3.fromHex("748182")
local COLOR_ACTIVE = Color3.fromHex("00F0FF")

-- Types
type HUDButton = "inventory"

-----------------------------------
-- Module definition & state
-----------------------------------
local HUD = {}

local HUDScreen = PlayerGui:WaitForChild("HUD")
local Screens = PlayerGui:WaitForChild("Screens")
local map = Util.mapUI(HUDScreen)

local currentButton: HUDButton? = nil

-----------------------------------
-- Helper functions
-----------------------------------

local function updateButtonColors()
	if map.inventory and map.inventory:FindFirstChild("icon") then
		local icon = map.inventory.icon :: ImageLabel
		icon.ImageColor3 = (currentButton == "inventory") and COLOR_ACTIVE or COLOR_PASSIVE
	end
end

local function setUpButtons()
	local inventoryButton = map.inventory.button
	local inventory = Screens:FindFirstChild("inventory")
	local canvas = inventory:FindFirstChild("canvas")

	Inventory.ScreenClosed:Connect(function()
		currentButton = nil
		updateButtonColors()
	end)

	inventoryButton.MouseEnter:Connect(function()
		UIAnimationManager.hover(map.inventory, true)
	end)

	inventoryButton.MouseLeave:Connect(function()
		UIAnimationManager.hover(map.inventory, false)
	end)

	inventoryButton.MouseButton1Click:Connect(function()
		UIAnimationManager.popOut(map.inventory)

		local wasOpen = (currentButton == "inventory")

		if not wasOpen then
			UIManager.closeAll()

			UIAnimationManager.windowOpen(inventory, canvas)
			Inventory.playSectionFades()
			currentButton = "inventory"

			Inventory.closeInfo()

			local data = PlayerManager.getData()
			if data and data.items then
				Inventory.updateSlots(data.items)
			end
		else
			UIManager.closeAll()
			currentButton = nil

			UIAnimationManager.windowClose(inventory, canvas)

			Inventory.clearSlots()
			Inventory.clearStats()
			Inventory.closeInfo()
		end

		updateButtonColors()
	end)
end

-----------------------------------
-- Public functions
-----------------------------------

function HUD.onStart()
	updateButtonColors()
	setUpButtons()
end

return HUD
