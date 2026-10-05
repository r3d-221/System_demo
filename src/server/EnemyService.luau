--!strict

-- Description
local _ = [[
	State machine for the enemies. Handles their movement, damage and
	death. Calls drop service and combat service.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local CombatService = require(ServerScriptService.Server.CombatService)
local DropService = require(ServerScriptService.Server.DropService)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Shared = ReplicatedStorage.Shared
local ItemInfo = require(Shared.ItemInfo)
local Signal = require(Shared.Signal)
local Types = require(Shared.Types)
local Util = require(Shared.Util)

-- Types
type Janitor = typeof(Janitor.new())
type Signal = typeof(Signal.new())
type Entity = Types.Entity
type EnemyInfo = Types.EnemyInfo
type Connection = Signal.Connection
type EnemyStatNames = Types.EnemyStatNames
type WeaponInfo = Types.WeaponInfo
type Item = Types.Item
type StatMap = Types.StatMap
type DropEntry = Types.DropEntry

type EnemyState = "idle" | "chase" | "attack" | "dead"
type Properties = {
	janitor: Janitor,
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	state: EnemyState,
	target: Player?,
	id: string,
	origin: Vector3,
	stateChanged: Signal,
	connections: { [string]: thread },
	_destroyed: boolean,
	config: EnemyInfo,
	weapon: Item?,
	weaponInfo: WeaponInfo?,
	stats: StatMap,
	onDead: (() -> ())?,
}

-- Variables

-- Constants
local MIN_IDLE = 0.5
local MAX_IDLE = 1.3
local ROAM_RANGE = 15
local CHASE_CHECK_TICK = 0.5
local ATTACK_DISENGAGE_BUFFER = 3
local OFFENSE_STATS = { "damage", "critRate", "critDamage" }

-----------------------------------
-- Module definition & state
-----------------------------------

local EnemyService = {}
EnemyService.__index = EnemyService
export type Enemy = typeof(setmetatable({} :: Properties, EnemyService))

-----------------------------------
-- Helper functions
-----------------------------------

local function createStats(config: EnemyInfo, weapon: Item?): StatMap
	local stats: StatMap = {}
	for stat, value in config.stats do
		stats[stat :: any] = value
	end

	if weapon and weapon.stats then
		for _, stat in OFFENSE_STATS do
			local roll = weapon.stats[stat :: any]
			if roll then
				stats[stat :: any] = roll.value
			end
		end
	end

	return stats
end

local function safeCancel(thread)
	if thread and thread ~= coroutine.running() then
		task.cancel(thread)
	end
end

local function transition(self: Enemy, state: EnemyState)
	task.wait()
	self[state](self)
end

local function isTargetInRange(self: Enemy, range: number, from: Vector3?): boolean
	if not self.target then
		return false
	end

	local humanoid, targetRoot = Util.checkHumanoid(self.target.Character)
	if not humanoid or not targetRoot then
		return false
	end

	local origin = from or self.rootPart.Position
	return (origin - targetRoot.Position).Magnitude <= range
end

local function findNearestTarget(self: Enemy, range: number): Player?
	local closestPlayer: Player? = nil
	local closestDistance = range

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid, rootPart = Util.checkHumanoid(character)

		if rootPart and humanoid and humanoid.Health > 0 then
			local distance = (self.rootPart.Position - rootPart.Position).Magnitude
			if distance <= closestDistance then
				closestDistance = distance
				closestPlayer = player
			end
		end
	end

	return closestPlayer
end

local function enemyEntity(self: Enemy): Entity
	return {
		model = self.model,
		humanoid = self.humanoid,
		rootPart = self.rootPart,
		stats = self.stats,
		getStat = function(_self, stat: EnemyStatNames)
			return self.stats[stat] or 0
		end,
	} :: Entity
end

-----------------------------------
-- Public functions
-----------------------------------

function EnemyService.new(model: Model, config: EnemyInfo, weapon: Item?, onDead: (() -> ())?): Enemy
	local self = setmetatable({} :: Properties, EnemyService)

	self.janitor = Janitor.new()

	self.model = model
	self.humanoid = model and model:FindFirstChildOfClass("Humanoid") :: Humanoid
	self.rootPart = model and model:FindFirstChild("HumanoidRootPart") :: BasePart

	self.id = `enemy_{model.Name}_{os.clock()}`
	self.state = "idle"
	self.target = nil
	self._destroyed = false
	self.config = config
	self.origin = self.rootPart.Position

	self.weapon = weapon
	self.weaponInfo = weapon and (ItemInfo.getInfo("weapons", weapon.id) :: WeaponInfo?)
	self.stats = createStats(config, weapon)
	self.humanoid.WalkSpeed = self.config.stats["speed" :: EnemyStatNames] or 10
	self.onDead = onDead

	self.connections = {}
	self.stateChanged = Signal.new()

	local diedConnection
	diedConnection = self.humanoid.Died:Connect(function()
		diedConnection:Disconnect()
		self:dead()
	end)

	self:idle()

	return self
end

function EnemyService.getState(self: Enemy): EnemyState
	return self.state
end

function EnemyService.idle(self: Enemy)
	self.state = "idle"
	self.target = nil
	self.stateChanged:Fire("idle")

	self.connections.roam = task.spawn(function()
		while not self._destroyed and self.state == "idle" do
			local rootPart = self.rootPart
			if not rootPart or not rootPart.Parent then
				break
			end

			local origin = self.origin
			local y = rootPart.Position.Y
			local x = math.random(math.floor(origin.X - ROAM_RANGE), math.floor(origin.X + ROAM_RANGE))
			local z = math.random(math.floor(origin.Z - ROAM_RANGE), math.floor(origin.Z + ROAM_RANGE))

			self.humanoid:MoveTo(Vector3.new(x, y, z))

			local moved = false
			local moveConnection
			moveConnection = self.humanoid.MoveToFinished:Connect(function()
				moved = true
				moveConnection:Disconnect()
			end)

			local elapsed = 0
			while not moved and elapsed < 5 and self.state == "idle" do
				task.wait(0.1)
				elapsed += 0.1
			end
			moveConnection:Disconnect()

			if self.state ~= "idle" then
				break
			end

			local idleTime = math.random() * (MAX_IDLE - MIN_IDLE) + MIN_IDLE
			task.wait(idleTime)
		end
	end)

	self.connections.aggroCheck = task.spawn(function()
		while not self._destroyed and self.state == "idle" do
			local candidate = findNearestTarget(self, self.config.chaseRange)
			if candidate then
				self.target = candidate
				transition(self, "chase")
				break
			end
			task.wait(CHASE_CHECK_TICK)
		end
	end)
end

function EnemyService.chase(self: Enemy)
	self.state = "chase"
	self.stateChanged:Fire("chase")

	self.connections.chase = task.spawn(function()
		while not self._destroyed and self.state == "chase" do
			local character
			if self.target then
				character = self.target.Character
			end

			if not character or not character:FindFirstChild("HumanoidRootPart") then
				transition(self, "idle")
				break
			end

			local targetRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart

			if isTargetInRange(self, self.config.attackRange) then
				transition(self, "attack")
				break
			elseif not isTargetInRange(self, self.config.maxChaseRange, self.origin) then
				transition(self, "idle")
				break
			else
				self.humanoid:MoveTo(targetRoot.Position)
			end

			task.wait(CHASE_CHECK_TICK)
		end
	end)
end

function EnemyService.attack(self: Enemy)
	self.state = "attack"
	self.stateChanged:Fire("attack")

	self.connections.attack = task.spawn(function()
		while not self._destroyed and self.state == "attack" do
			if not self.target or not Util.checkHumanoid(self.target.Character) then
				transition(self, "idle")
				break
			end

			if not isTargetInRange(self, self.config.attackRange + ATTACK_DISENGAGE_BUFFER) then
				transition(self, "chase")
				break
			end

			if self.weaponInfo then
				CombatService.basicAttack(enemyEntity(self), self.weaponInfo)
			end

			task.wait(self.config.rest)
		end
	end)
end

function EnemyService.dead(self: Enemy)
	if self._destroyed then
		return
	end

	for _, thread in pairs(self.connections) do
		safeCancel(thread)
	end

	self.state = "dead"
	self.stateChanged:Fire("dead")
	self:drops()

	if self.onDead then
		self.onDead()
	end

	task.delay(1, function()
		self:destroy()
	end)
end

function EnemyService.drops(self: Enemy)
	if not self.config.drops or not next(self.config.drops) then
		return
	end

	local ownerUserId = self.model:GetAttribute("lastAttacker") :: number?
	DropService.spawnDrops(self.rootPart.Position, self.config.drops, ownerUserId)
end

function EnemyService.destroy(self: Enemy)
	if self._destroyed then
		return
	end
	self._destroyed = true

	for _, thread in pairs(self.connections) do
		safeCancel(thread)
	end

	if self.model and self.model.Parent then
		self.model:Destroy()
	end
end

return EnemyService
