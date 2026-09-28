--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Dependencies
local Attack = ReplicatedStorage.Remotes.Attack

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
			Attack:FireServer()
		end
	end)
end

return Inputs
