--!strict

-- Description
local _ = [[
	Useful functions to have.	
]]

local Util = {}

-- formats numbers and returns a string
function Util.formatNumber(n: number): string
	n = math.floor(n)
	if n >= 1_000_000_000 then
		return string.format("%.1fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end
	return tostring(n)
end

-- exp calculator
function Util.calculateRequiredExp(level: number, exponent: number): number
	exponent = exponent or 1.5 -- default is 1.5
	return math.floor(100 * (level ^ exponent))
end

-- gets a random value from the given loot table
function Util.weightedRandom(weightPool: { [any]: number }): any
	local totalWeight = 0

	-- total weight
	for _, weight in pairs(weightPool) do
		totalWeight += weight
	end

	-- random number
	local roll = math.random() * totalWeight
	local cumulative = 0

	-- get key
	for key, value in pairs(weightPool) do
		cumulative += value
		if roll <= cumulative then
			return key
		end
	end

	return nil
end

-- checks if there is a humanoid in a character
function Util.checkHumanoid(character: Model?): (Humanoid?, BasePart?)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart

	if not humanoid or not rootPart or humanoid.Health <= 0 then
		return nil, nil
	end

	return humanoid, rootPart
end

-- ui mapper
function Util.mapUI(rootElement: Instance): { [string]: any }
	local map: { [string]: any } = {}
	map[rootElement.Name] = rootElement

	local ignoreNames = {
		["button"] = true,
		["text"] = true,
		["base"] = true,
		["icon"] = true,
		["fill"] = true,
		["fill_tabs"] = true,
		["scroll"] = true,
	}

	for _, child in rootElement:GetDescendants() do
		if
			(
				child:IsA("Frame")
				or child:IsA("ScrollingFrame")
				or child:IsA("ImageLabel")
				or child:IsA("TextLabel")
				or child:IsA("TextButton")
				or child:IsA("CanvasGroup")
				or child:IsA("TextBox")
			) and not ignoreNames[child.Name]
		then
			map[child.Name] = child
		end
	end

	return map
end

return Util
