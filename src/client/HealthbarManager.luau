--!strict

-- Services
local TweenService = game:GetService("TweenService")

-- Constants
local FULL_RECT = Vector2.new(1018, 71)
local FILL_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LAG_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.3)

-----------------------------------
-- Module definition & state
-----------------------------------

local HealthbarManager = {}
HealthbarManager.__index = HealthbarManager

export type View = typeof(setmetatable(
	{} :: {
		progress: ImageLabel,
		lag: ImageLabel,
		label: TextLabel?,
		fullSize: UDim2,
		fill: NumberValue,
		lagValue: NumberValue,
		ratio: number,
		conns: { RBXScriptConnection },
	},
	HealthbarManager
))

-----------------------------------
-- Helper functions
-----------------------------------

local function apply(img: ImageLabel, full: UDim2, ratio: number)
	img.ImageRectSize = Vector2.new(FULL_RECT.X * ratio, FULL_RECT.Y)
	img.Size = UDim2.new(full.X.Scale * ratio, 0, full.Y.Scale, full.Y.Offset)
end

-----------------------------------
-- Public functions
-----------------------------------

function HealthbarManager.new(frame: Frame): View
	local progress = frame:FindFirstChild("progress", true) :: ImageLabel
	local lag = frame:FindFirstChild("lag", true) :: ImageLabel
	local label = frame:FindFirstChild("health", true)
	local self = setmetatable({
		progress = progress,
		lag = lag,
		label = if label and label:IsA("TextLabel") then label else nil,
		fullSize = progress.Size,
		fill = Instance.new("NumberValue"),
		lagValue = Instance.new("NumberValue"),
		ratio = 1,
		conns = {},
	}, HealthbarManager)

	self.fill.Value = 1
	self.lagValue.Value = 1
	table.insert(
		self.conns,
		self.fill.Changed:Connect(function(v)
			apply(progress, self.fullSize, v)
		end)
	)
	table.insert(
		self.conns,
		self.lagValue.Changed:Connect(function(v)
			apply(lag, self.fullSize, v)
		end)
	)
	apply(progress, self.fullSize, 1)
	apply(lag, self.fullSize, 1)
	return self
end

function HealthbarManager.setRatio(self: View, ratio: number, instant: boolean?)
	ratio = math.clamp(ratio, 0, 1)
	self.ratio = ratio
	if instant then
		self.fill.Value = ratio
		self.lagValue.Value = ratio
	else
		TweenService:Create(self.fill, FILL_TWEEN, { Value = ratio }):Play()
		TweenService:Create(self.lagValue, LAG_TWEEN, { Value = ratio }):Play()
	end
	if self.label then
		self.label.Text = string.format("%d%%", math.round(ratio * 100))
	end
end

function HealthbarManager.destroy(self: View)
	for _, c in self.conns do
		c:Disconnect()
	end
	self.fill:Destroy()
	self.lagValue:Destroy()
end

return HealthbarManager
