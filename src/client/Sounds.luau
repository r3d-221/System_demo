--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local sounds_template = ReplicatedStorage.sounds

-- Types

-- Variables

-- Constants

-----------------------------------
-- Module definition & state
-----------------------------------

local Sounds = {}
local list: { [string]: Sound } = {}

-----------------------------------
-- Helper functions
-----------------------------------

-----------------------------------
-- Public functions
-----------------------------------

function Sounds.new(id: string)
	local template = sounds_template:FindFirstChild(id) :: Sound
	if not template then
		return
	end

	local clone = template:Clone()
	clone.Parent = workspace
	list[id] = clone

	clone.Ended:Once(function()
		clone:Destroy()
		list[id] = nil
	end)

	clone:Play()
end

return Sounds
