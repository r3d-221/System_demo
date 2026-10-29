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
	if list[id] then
		Sounds.destroy(id)
	end

	local template = sounds_template:FindFirstChild(id) :: Sound
	if not template then
		return
	end

	local clone = template:Clone()
	clone.Parent = workspace
	list[id] = clone

	clone.Ended:Once(function()
		clone:Destroy()
	end)

	clone:Play()
end

function Sounds.destroy(id: string)
	local sound = list[id]
	if sound.IsPlaying then
		sound:Stop()
	end

	sound:Destroy()
	list[id] = nil
end

return Sounds
