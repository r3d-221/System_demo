--!strict

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Dependencies
local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client

local WeaponAnimationManager = require(Client.WeaponAnimationManager)

-- Types

-- Variables

-- Constants

-----------------------------------
-- Module definition & state
-----------------------------------

local Inputs = {}

-----------------------------------
-- Helper functions
-----------------------------------

-----------------------------------
-- Public functions
-----------------------------------
function Inputs.onStart()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponAnimationManager.attack()
		end
	end)
end

return Inputs
