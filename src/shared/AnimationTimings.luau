--!strict

-- Description
local _ = [[
	Gets the timers from the animation keyframes and markers.
]]

-- Services
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
export type Timing = Types.Timing

-- Constants
-- info was gathered from the markers of the animations
-- set as the default value
local BAKED: { [string]: Timing } = {
	["87455361709207"] = { windUp = 0.208, active = 0.417, recovery = 0.708, length = 1.333 }, -- attack1
	["89807628429330"] = { windUp = 0.208, active = 0.334, recovery = 0.791, length = 1.333 }, -- attack2
}
local FALLBACK: Timing = { windUp = 0.2, active = 0.15, recovery = 0.35, length = 0.7 }

-----------------------------------
-- Module definition & state
-----------------------------------

local AnimationTimings = {}
local cache: { [string]: Timing } = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function read(id: string): (Timing?, string?)
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(`rbxassetid://{id}`)
	end)
	if not ok then
		return nil, tostring(result)
	end
	if not result then
		return nil, "no keyframe sequence returned"
	end

	local sequence = result :: KeyframeSequence
	local length = 0
	local count = 0
	local startTime: number? = nil
	local endTime: number? = nil

	-- sets the start and end timer by going through the key frames
	for _, instance in sequence:GetKeyframes() do
		local keyframe = instance :: Keyframe
		count += 1
		length = math.max(length, keyframe.Time)
		for _, marker in keyframe:GetMarkers() do
			if marker.Name == "start" then
				startTime = keyframe.Time
			elseif marker.Name == "end" then
				endTime = keyframe.Time
			end
		end
	end
	sequence:Destroy()

	if not startTime or not endTime or endTime <= startTime then
		return nil, `markers not found (keyframes = {count}, start = {tostring(startTime)}, end = {tostring(endTime)})`
	end

	local timing: Timing = {
		windUp = startTime,
		active = endTime - startTime,
		recovery = math.max(length - endTime, 0),
		length = length,
	}
	return timing, nil
end

-----------------------------------
-- Public functions
-----------------------------------

-- chcecks if animation info is given and if not then fallback
local function resolve(id: string): Timing
	local baked = BAKED[id]
	if baked then
		return baked
	end

	local timing, reason = read(id)
	if timing then
		return timing
	end

	warn(`[AnimationTimings] fallback for {id}: {reason or "unknown"}`)
	return FALLBACK
end

-- runs only when an unbaked id is requested
function AnimationTimings.get(id: string): Timing
	local cached = cache[id]
	if cached then
		return cached
	end

	local timing = resolve(id)
	cache[id] = timing
	return timing
end

-- caches all info for animation
function AnimationTimings.preload(ids: { string })
	for _, id in ids do
		task.spawn(AnimationTimings.get, id)
	end
end

return AnimationTimings
