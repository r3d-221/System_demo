--!strict

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

-- Dependencies
local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client
local WeaponAnimations = require(Client.WeaponAnimations)

-----------------------------------
-- Module definition & state
-----------------------------------

local Inputs = {}

-----------------------------------
-- Public functions
-----------------------------------
function Inputs.onStart()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponAnimations.attack()
		end
	end)
end

return Inputs
