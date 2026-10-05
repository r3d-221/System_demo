--!strict

-- Description
local _ = [[
	Handles the teleport pad UI for the client.
]]

-- Services
local RunService = game:GetService("RunService")

-- Types
type UI = { timer: TextLabel, labels: { TextLabel } }

-- Constants
local BILLBOARD_NAMES: { [string]: boolean } = { teleport_info = true, collector_info = true }
local COOLDOWN_ATTRIBUTE = "cooldown"
local DIMMED = 0.5

-----------------------------------
-- Module definition & state
-----------------------------------

local TelerportUI = {}
local tracked: { [BasePart]: UI } = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function bind(billboard: BillboardGui)
	local pad = billboard.Parent
	if not pad or not pad:IsA("BasePart") then
		return
	end

	local panel = billboard:WaitForChild("panel", 10)
	local timer = panel and panel:WaitForChild("timer", 10)
	if not panel or not timer or not timer:IsA("TextLabel") then
		return
	end

	local labels: { TextLabel } = {}
	for _, child in panel:GetChildren() do
		if child:IsA("TextLabel") and child ~= timer then
			table.insert(labels, child)
		end
	end

	tracked[pad] = { timer = timer, labels = labels }
	billboard.Destroying:Once(function()
		tracked[pad] = nil
	end)
end

local function consider(inst: Instance)
	if BILLBOARD_NAMES[inst.Name] and inst:IsA("BillboardGui") then
		task.spawn(bind, inst)
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function TelerportUI.onStart()
	workspace.DescendantAdded:Connect(consider)
	for _, inst in workspace:GetDescendants() do
		consider(inst)
	end

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		for pad, ui in tracked do
			local endsAt = pad:GetAttribute(COOLDOWN_ATTRIBUTE)
			local remaining = if typeof(endsAt) == "number" then endsAt - now else 0
			local onCooldown = remaining > 0

			ui.timer.Text = if onCooldown then string.format("%.1fs", remaining) else ""
			for _, label in ui.labels do
				label.TextTransparency = if onCooldown then DIMMED else 0
			end
		end
	end)
end

return TelerportUI
