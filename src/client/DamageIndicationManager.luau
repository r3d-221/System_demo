--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Dependencies
local DamageDealt = ReplicatedStorage.Remotes:WaitForChild("DamageDealt") :: RemoteEvent

-- Constants
local NORMAL_COLOR = Color3.fromRGB(255, 255, 255)
local CRIT_COLOR = Color3.fromRGB(255, 200, 40)
local LIFETIME = 0.8
local FLOAT_UP = 100
local SPREAD = 40
local MAX_PER_ENEMY = 6
local INDICATOR = "damage_indicator"

-----------------------------------
-- Module definition & state
-----------------------------------

local DamageIndicationManager = {}
local active: { [BillboardGui]: number } = setmetatable({}, { __mode = "k" }) :: any

-----------------------------------
-- Helper functions
-----------------------------------

local function show(humanoid: Humanoid, amount: number, isCrit: boolean)
	local model = humanoid.Parent
	local head = model and model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild(INDICATOR) :: BillboardGui?
	local template = gui and gui:FindFirstChild("text") :: TextLabel?
	if not gui or not template then
		return
	end

	local count = active[gui] or 0
	if count >= MAX_PER_ENEMY then
		return
	end
	active[gui] = count + 1

	local label = template:Clone()
	label.Text = if isCrit then `{amount}!` else tostring(amount)
	label.TextColor3 = if isCrit then CRIT_COLOR else NORMAL_COLOR
	label.Position = UDim2.new(0.5, math.random(-SPREAD, SPREAD), 0.7, 0)
	label.Visible = true
	label.Parent = gui

	-- pop in
	local scale = label:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = if isCrit then 1.8 else 1.3
		TweenService:Create(
			scale,
			TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = if isCrit then 1.3 else 1 }
		):Play()
	end

	-- float up
	local riseInfo = TweenInfo.new(LIFETIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, riseInfo, {
		Position = label.Position - UDim2.fromOffset(0, FLOAT_UP),
	}):Play()

	-- fade out
	local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, LIFETIME - 0.35)
	TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()

	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, fadeInfo, { Transparency = 1 }):Play()
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function DamageIndicationManager.onStart()
	DamageDealt.OnClientEvent:Connect(function(humanoid: Humanoid?, amount: number, isCrit: boolean)
		if humanoid then
			show(humanoid, amount, isCrit)
		end
	end)
end

return DamageIndicationManager
