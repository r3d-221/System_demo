--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Dependencies
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Types = require(ReplicatedStorage.Shared.Types)

-- Types
type Janitor = typeof(Janitor.new())
type Config = Types.HitboxConfig
type Properties = {
	janitor: Janitor,
	part: Part?,
	params: OverlapParams?,
	rayParams: RaycastParams?,
	weld: WeldConstraint?,
	weldTo: BasePart?,
	offset: CFrame?,
	origin: CFrame,
	config: Config,
}

export type FilterFunction = (part: BasePart) -> boolean

-- Variables

-- Constants
local RAY_VISUAL_THICKNESS = 0.5

-----------------------------------
-- Module definition & state
-----------------------------------

local HitboxService = {}
HitboxService.__index = HitboxService
export type Hitbox = typeof(setmetatable({} :: Properties, HitboxService))

-----------------------------------
-- Helper functions
-----------------------------------

local function createNewPart(cframe: CFrame, size: Vector3, shape: Enum.PartType, visible: boolean?): Part
	local part = Instance.new("Part")

	part.Name = "Hitbox"
	part.CFrame = cframe
	part.Size = size
	part.Shape = shape
	part.Transparency = if visible then 0.5 else 1

	part.CanCollide = false
	part.CanTouch = false
	part.Anchored = true

	part.Color = Color3.fromRGB(236, 119, 131)
	part.Material = Enum.Material.Neon

	return part
end

local function createNewPararms(ignoreList: { Instance }): OverlapParams
	local params = OverlapParams.new()

	params.FilterDescendantsInstances = ignoreList
	params.FilterType = Enum.RaycastFilterType.Exclude

	return params
end

local function createVolume(config: Config, origin: CFrame, visible: boolean?): Part
	if config.type == "sphere" then
		local diameter = (config.radius or 4) * 2
		return createNewPart(origin, Vector3.new(diameter, diameter, diameter), Enum.PartType.Ball, visible)
	elseif config.type == "arc" then
		-- creates a sphere but the check is in a cone
		local diameter = (config.range or 6) * 2
		return createNewPart(origin, Vector3.new(diameter, diameter, diameter), Enum.PartType.Ball, visible)
	elseif config.type == "cylinder" then
		local diameter = (config.radius or 4) * 2
		local height = config.height or 4
		local orientation = origin * CFrame.Angles(0, 0, math.rad(90))
		return createNewPart(orientation, Vector3.new(height, diameter, diameter), Enum.PartType.Cylinder, visible)
	end
	error(`[HitboxService]: Couldn't make volume for hitbox type "{config.type}"`)
end

local function coneFilter(origin: Vector3, forward: Vector3, maxAngle: number)
	return function(part: BasePart): boolean
		local distanceVector = part.Position - origin
		if distanceVector.Magnitude == 0 then
			return true
		end

		local dot = forward:Dot(distanceVector.Unit)
		local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
		return angle <= maxAngle
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function HitboxService.new(
	config: Config,
	origin: CFrame,
	ignoreList: { Instance },
	visible: boolean?,
	weldTo: BasePart?
): Hitbox
	local self = setmetatable({} :: Properties, HitboxService)
	self.janitor = Janitor.new()
	self.origin = origin
	self.config = config

	if config.type == "raycast" then
		self.rayParams = (function()
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = ignoreList
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			return rayParams
		end)()

		if visible then
			local range = config.range or 10
			local visual = createNewPart(
				origin * CFrame.new(0, 0, -range / 2),
				Vector3.new(RAY_VISUAL_THICKNESS, RAY_VISUAL_THICKNESS, range),
				Enum.PartType.Block,
				true
			)
			visual.CanQuery = false
			visual.Parent = workspace
			self.part = self.janitor:Add(visual, "Destroy", "part")
		end
	else
		local part = createVolume(config, origin, visible)
		self.part = self.janitor:Add(part, "Destroy", "part")
		part.Parent = workspace
		self.params = createNewPararms(ignoreList)
	end

	if weldTo then
		self:WeldTo(weldTo)
	end

	return self
end

function HitboxService.Check(self: Hitbox, filter: FilterFunction?): { BasePart }
	if self.config and self.config.type == "raycast" then
		error("[HitboxService]: Check() can't be used on raycast.")
	end

	assert(self.part and self.params, "[HitboxService]: Hitbox part wasn't created.")

	local parts = Workspace:GetPartsInPart(self.part, self.params)

	local effectiveFilter = filter
	if self.config and self.config.type == "arc" then
		local cone = coneFilter(self:GetOrigin().Position, self:GetOrigin().LookVector, self.config.angle or 60)
		effectiveFilter = if filter
			then function(part: BasePart)
				return cone(part) and (filter :: FilterFunction)(part)
			end
			else cone
	end

	if not effectiveFilter then
		return parts
	end

	local filtered = {}
	for _, part in parts do
		local ok, passes = pcall(effectiveFilter, part)
		if ok and passes then
			table.insert(filtered, part)
		end
	end
	return filtered
end

function HitboxService.Raycast(self: Hitbox): RaycastResult?
	assert(self.config and self.config.type == "raycast", "[HitboxService]: Raycast() is only for raycasts.")
	assert(self.rayParams, "[HitboxService]: Hitbox raycast params wasn't created.")

	local range = self.config.range or 10
	return Workspace:Raycast(self:GetOrigin().Position, self:GetOrigin().LookVector * range, self.rayParams)
end

function HitboxService.CheckHumanoids(self: Hitbox): { Humanoid }
	local humanoids: { Humanoid } = {}
	local seen: { [Humanoid]: true } = {}

	local function collect(part: BasePart?)
		if not part then
			return
		end

		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildWhichIsA("Humanoid", true) :: Humanoid?
		if humanoid and not seen[humanoid] and humanoid.Health > 0 then
			seen[humanoid] = true
			table.insert(humanoids, humanoid)
		end
	end

	if self.config and self.config.type == "raycast" then
		local result = self:Raycast()
		collect(result and result.Instance)
	else
		for _, part in self:Check() do
			collect(part)
		end
	end

	return humanoids
end

function HitboxService.GetOrigin(self: Hitbox): CFrame
	if self.weldTo and self.offset then
		return self.weldTo.CFrame * self.offset
	end
	return self.origin
end

function HitboxService.WeldTo(self: Hitbox, part: BasePart)
	assert(self.part, "[HitboxService] couldn't find a part to weld to")

	if self.weld then
		self.janitor:Remove("weld")
	end

	self.weldTo = part
	self.offset = part.CFrame:ToObjectSpace(self.origin)

	self.part.Anchored = false
	self.part.Massless = true

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = self.part
	weld.Part1 = part
	weld.Parent = self.part
	self.weld = self.janitor:Add(weld, "Destroy", "weld")
end

function HitboxService.Destroy(self: Hitbox)
	self.janitor:Destroy()
end

return HitboxService
