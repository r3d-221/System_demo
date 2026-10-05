--!strict

-- Description
local _ = [[
	Handles the enemy hit effects and weapon effects for all clients.	
]]

-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local vfx = require(ReplicatedStorage.EmitModule) -- from UI forge
local HitConfirmed = ReplicatedStorage.Remotes.HitConfirmed

-- Constants
local TEXTURE_LOAD_TAG = "LoadVFXTextures"
local MAX_ACTIVE = 12
local CLEANUP_DELAY = 2

-----------------------------------
-- Module definition & state
-----------------------------------

local HitEffects = {}
local templates = {}
local active = 0

-----------------------------------
-- Helper functions
-----------------------------------

-- helper for scaling particles
local function scaleSequence(sequence: NumberSequence, scale: number): NumberSequence
	local keypoints = {}
	for _, keypoint in sequence.Keypoints do
		table.insert(
			keypoints,
			NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale)
		)
	end
	return NumberSequence.new(keypoints)
end

-- scales particles
local function applyScale(effect: Instance, scale: number)
	for _, descendant in effect:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Size = scaleSequence(descendant.Size, scale)
		end
	end
end

-- creates the effect at the target position
local function play(name: string, cframe: CFrame, scale: number?)
	local template = templates[name]
	if not template or active >= MAX_ACTIVE then
		return
	end
	active += 1

	local effect = template:Clone()
	if scale and scale ~= 1 then
		applyScale(effect, scale)
	end
	effect.Anchored = true
	effect.CanCollide = false
	effect.CanQuery = false
	effect.CanTouch = false
	effect.Transparency = 1
	effect.CFrame = cframe
	effect.Parent = workspace.Terrain

	-- debounce set
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		active -= 1
		effect:Destroy()
	end

	-- runs the debounce again if it didn't trigger the first time
	local ok, handle = pcall(vfx.emit, effect)
	if ok and handle then
		handle.Finished:finally(release)
		task.delay(CLEANUP_DELAY, release)
	else
		release()
	end
end

-----------------------------------
-- Public functions
-----------------------------------

-- runs the effects for the slash from template
function HitEffects.playSlash(cframe: CFrame, scale: number?)
	play("slash", cframe, scale)
end

function HitEffects.onStart()
	vfx.init() -- UI forge

	-- sets up the templates table on start
	local folder = ReplicatedStorage:WaitForChild("vfx")
	templates.hit = folder:WaitForChild("hit")
	templates.slash = folder:WaitForChild("slash")

	-- UI forge tags
	CollectionService:AddTag(templates.hit, TEXTURE_LOAD_TAG)
	CollectionService:AddTag(templates.slash, TEXTURE_LOAD_TAG)

	-- runs the hit effect
	HitConfirmed.OnClientEvent:Connect(function(position: Vector3)
		play("hit", CFrame.new(position))
	end)
end

return HitEffects
