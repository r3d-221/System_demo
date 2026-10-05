--!strict

-- Description
local _ = [[
	Handles enemy health bar UI.
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Dependencies
local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client
local HealthbarManager = require(Client.HealthbarManager)

-- Constants
local FULL_SIZE_DISTANCE = 20
local MIN_SCALE = 0.55

-----------------------------------
-- Module definition & state
-----------------------------------

local EnemyHealthbar = {}
local tracked: { [BillboardGui]: { base: UDim2, head: BasePart } } = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function bind(billboard: BillboardGui)
	local head = billboard.Parent :: BasePart?
	local model = head and head.Parent
	if not head or not model then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 10) :: Humanoid?
	local frame = billboard:WaitForChild("healthbar", 10) :: Frame?
	if not humanoid or not frame then
		return
	end
	local view = HealthbarManager.new(frame)
	tracked[billboard] = { base = billboard.Size, head = head }

	local function update(instant: boolean?)
		view:setRatio(humanoid.Health / humanoid.MaxHealth, instant)
	end
	humanoid.HealthChanged:Connect(function()
		update(false)
	end)
	update(true)

	billboard.Destroying:Once(function()
		tracked[billboard] = nil
		view:destroy()
	end)
end

local function consider(inst: Instance)
	if inst.Name == "enemy_ui" and inst:IsA("BillboardGui") then
		task.spawn(bind, inst)
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function EnemyHealthbar.onStart()
	workspace.DescendantAdded:Connect(consider)
	for _, inst in workspace:GetDescendants() do
		consider(inst)
	end

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		for billboard, info in tracked do
			local dist = (info.head.Position - cam.CFrame.Position).Magnitude
			local s = math.clamp(FULL_SIZE_DISTANCE / dist, MIN_SCALE, 1)
			billboard.Size = UDim2.fromOffset(info.base.X.Offset * s, info.base.Y.Offset * s)
		end
	end)
end

return EnemyHealthbar
