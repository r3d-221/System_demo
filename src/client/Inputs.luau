--!strict

-- Description
local _ = [[
	Handles the inputs from the client.	
]]

-- Services
local ContextActionService = game:GetService("ContextActionService")
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

	ContextActionService:BindAction("Attack", function(_, state)
		if state == Enum.UserInputState.Begin then
			WeaponAnimations.attack()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("Attack", "Attack")
	ContextActionService:SetPosition("Attack", UDim2.new(1, -150, 1, -150))
end

return Inputs
