--!strict
local Players = game:GetService("Players")

-- Constants
local DEFAULT_COOLDOWN = 3
local DEFAULT_LANDING_OFFSET = Vector3.new(0, 4, 0)
local COOLDOWN_ATTRIBUTE = "cooldown"

-- Types
export type Config = {
	cooldown: number?,
	landingOffset: Vector3?,
}

export type Teleporter = {
	destroy: (self: Teleporter) -> (),
}

type PadState = {
	part: BasePart,
	highlight: Highlight?,
	cooldownUntil: number,
	generation: number,
}

local pads: { [BasePart]: PadState } = {}

-----------------------------------
-- Module definition
-----------------------------------

local TeleportationService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function getPad(part: BasePart, expectHighlight: boolean): PadState
	local existing = pads[part]
	if existing then
		return existing
	end

	local highlight = part:FindFirstChildWhichIsA("Highlight")
	if not highlight and expectHighlight then
		warn(`TeleportationService: {part:GetFullName()} has no Highlight`)
	end

	local pad: PadState = {
		part = part,
		highlight = highlight,
		cooldownUntil = 0,
		generation = 0,
	}
	pads[part] = pad
	return pad
end

local function startCooldown(pad: PadState, duration: number)
	local endsAt = os.clock() + duration
	if endsAt <= pad.cooldownUntil then
		return
	end

	pad.generation += 1
	local generation = pad.generation
	pad.cooldownUntil = endsAt

	if pad.highlight then
		pad.highlight.Enabled = false
	end
	pad.part:SetAttribute(COOLDOWN_ATTRIBUTE, workspace:GetServerTimeNow() + duration)

	task.delay(duration, function()
		if pad.generation ~= generation then
			return
		end
		pad.cooldownUntil = 0
		if pad.highlight then
			pad.highlight.Enabled = true
		end
		pad.part:SetAttribute(COOLDOWN_ATTRIBUTE, nil)
	end)
end

-----------------------------------
-- Public functions
-----------------------------------

function TeleportationService.new(source: BasePart, destination: BasePart, config: Config?): Teleporter
	local cooldown = if config and config.cooldown then config.cooldown else DEFAULT_COOLDOWN
	local landingOffset = if config and config.landingOffset then config.landingOffset else DEFAULT_LANDING_OFFSET

	local sourcePad = getPad(source, true)
	local destinationPad = getPad(destination, false)

	local connection: RBXScriptConnection
	connection = source.Touched:Connect(function(hit: BasePart)
		if os.clock() < sourcePad.cooldownUntil then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end

		startCooldown(sourcePad, cooldown)
		if destinationPad ~= sourcePad then
			startCooldown(destinationPad, cooldown)
		end

		local landing = destination.CFrame:PointToWorldSpace(landingOffset)
		character:PivotTo(CFrame.new(landing) * root.CFrame.Rotation)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)

	local teleporter: Teleporter
	teleporter = {
		destroy = function()
			connection:Disconnect()
			pads[source] = nil
		end,
	}

	source.Destroying:Once(function()
		teleporter:destroy()
	end)

	return teleporter
end

return TeleportationService
