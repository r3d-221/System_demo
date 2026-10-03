--!strict

-- Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Dependencies
local Server = ServerScriptService.Server
local AnimationTimings = require(ReplicatedStorage.Shared.AnimationTimings)
local ItemData = require(ReplicatedStorage.Shared.ItemData)
local DamageCalculationService = require(Server.DamageCalculationService)
local HitboxService = require(Server.HitboxService)
local PlayerService = require(Server.PlayerService)
local StatsService = require(ServerScriptService.Server.StatsService)

local Remotes = ReplicatedStorage.Remotes
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)
local Attack = Remotes.Attack
local HitConfirmed = Remotes.HitConfirmed
local SwingStarted = Remotes.SwingStarted

-- Types
type PlayerData = Types.PlayerData
type WeaponInfo = Types.WeaponInfo
type DamageContext = Types.DamageContext
type Entity = Types.Entity
type StatMap = Types.StatMap
type Phase = Types.CombatPhase
type SwingState = Types.SwingState

-- Constants
local EMPTY_STATS: StatMap = {}
local HIT_EFFECT_CAP = 5
local MIN_ATTACK_SPEED = 0.1
local ENEMY_TAG = "Enemy"
local SHOW_HITBOX = false

-----------------------------------
-- Module definition & state
-----------------------------------

local CombatService = {}
local states: { [Humanoid]: SwingState } = {}

-----------------------------------
-- Helper functions
-----------------------------------

-- TO DO: cache weapon info
local function getWeaponInfo(data: PlayerData): WeaponInfo?
	local item = StatsService.getEquippedItem(data, "weapons", data.equipped.weapons)
	return item and ItemData.weapons[item.id]
end

-- creates a damage context for the attacker to use
local function createContext(entity: Entity, target: Humanoid): DamageContext
	local targetCharacter = target.Parent
	local targetPlayer = targetCharacter and Players:GetPlayerFromCharacter(targetCharacter :: Model)
	local targetData = targetPlayer and PlayerService.getData(targetPlayer)

	return {
		attackerStats = entity.stats,
		targetStats = if targetData then targetData.changedStats else EMPTY_STATS,
		damageMultiplier = 1,
	}
end

-- gets the state of the attack
local function getState(humanoid: Humanoid): SwingState
	local state = states[humanoid]
	if state then
		return state
	end

	local newState: SwingState = { step = 1, phase = "idle", queued = false, thread = nil, hitbox = nil }
	states[humanoid] = newState

	-- if humanoid is dying when creating state then clear state
	humanoid.Destroying:Once(function()
		if newState.thread then
			task.cancel(newState.thread)
		end
		if newState.hitbox then
			newState.hitbox:Destroy()
		end
		states[humanoid] = nil
	end)

	return newState
end

-- gets the position of the attacked humanoid
local function getHitPosition(entity: Entity, target: Humanoid): Vector3?
	local targetRoot = target.RootPart
	if not targetRoot then
		return nil
	end

	local distance = entity.rootPart.Position - targetRoot.Position
	local flat = Vector3.new(distance.X, 0, distance.Z)
	if flat.Magnitude < 0.01 then
		return targetRoot.Position
	end

	return targetRoot.Position + flat.Unit * 1
end

-- damages all humanoids in range of attack
local function applyHits(entity: Entity, hitbox: any, swing: { hit: { [Humanoid]: boolean }, effects: number })
	for _, target in hitbox:CheckHumanoids() do
		if swing.hit[target] then
			continue
		end
		swing.hit[target] = true

		local targetModel = target.Parent

		-- enemies won't hit other enemies
		if
			CollectionService:HasTag(entity.model, ENEMY_TAG)
			and targetModel
			and CollectionService:HasTag(targetModel, ENEMY_TAG)
		then
			local attacker = Players:GetPlayerFromCharacter(entity.model)
			if attacker and targetModel then
				targetModel:SetAttribute("lastAttacker", attacker.UserId)
			end
			continue
		end

		local wasAlive = target.Health > 0
		local context = createContext(entity, target)
		local result = DamageCalculationService.calculateHit(context)
		target:TakeDamage(result.amount)

		-- creates a hit effect
		if wasAlive and swing.effects < HIT_EFFECT_CAP then
			local hitPosition = getHitPosition(entity, target)
			if hitPosition then
				swing.effects += 1
				HitConfirmed:FireAllClients(hitPosition)
			end
		end

		print("[CombatService] " .. targetModel.Name .. " took " .. result.amount .. " damage")
	end
end

local startSwing

-- resets combo to start
local function finishCombo(state: SwingState)
	state.step = 1
	state.phase = "idle"
	state.queued = false
	state.thread = nil
end

-- logic for wind up, active and recovery
startSwing = function(entity: Entity, weaponInfo: WeaponInfo, state: SwingState)
	local humanoid = entity.humanoid
	local combo = weaponInfo.animations.combo

	-- wind up
	state.phase = "windup"
	state.queued = false

	state.thread = task.spawn(function()
		local step = state.step
		local timing = AnimationTimings.get(combo[step].id)
		local speed = math.max(1 + entity:getStat("attackSpeed" :: any), MIN_ATTACK_SPEED)

		if not timing then
			return
		end

		task.wait(timing.windUp / speed)
		if humanoid.Health <= 0 then
			return
		end

		-- active
		-- all humanoids are hit once in the active window
		state.phase = "active"
		local slash = combo[step].slash
		if slash then
			SwingStarted:FireAllClients(entity.model, step, slash)
		end
		local hitbox = HitboxService.new(weaponInfo.hitbox, entity.rootPart.CFrame, { entity.model }, SHOW_HITBOX)
		state.hitbox = hitbox

		local swing = { hit = {} :: { [Humanoid]: boolean }, effects = 0 }
		local endAt = os.clock() + timing.active / speed

		-- hit for the entire active time
		repeat
			applyHits(entity, hitbox, swing)
			task.wait()
		until os.clock() >= endAt or humanoid.Health <= 0

		hitbox:Destroy()
		state.hitbox = nil

		-- recovery
		local isFinisher = step >= #combo
		local nextStep = step % #combo + 1

		-- queues for the next combo start if clicking too fast
		if state.queued and not isFinisher then
			state.step = nextStep
			startSwing(entity, weaponInfo, state)
			return
		end

		state.phase = "recovery"
		task.wait(timing.recovery / speed)

		if state.queued then
			state.step = 1
			startSwing(entity, weaponInfo, state)
		else
			finishCombo(state)
		end
	end)
end

-- creates an entity table for the player
local function playerEntity(character: Model, humanoid: Humanoid, rootPart: BasePart, data: PlayerData): Entity
	return {
		model = character,
		humanoid = humanoid,
		rootPart = rootPart,
		stats = data.changedStats,
		getStat = function(_self, stat)
			return StatsService.getStat(data, stat)
		end,
	} :: Entity
end

-----------------------------------
-- Public functions
-----------------------------------

function CombatService.onStart()
	local ids = {}
	for _, weapon in ItemData.weapons do
		for _, step in weapon.animations.combo do
			table.insert(ids, step.id)
		end
	end
	AnimationTimings.preload(ids)

	-- basic attack
	Attack.OnServerEvent:Connect(function(player: Player)
		local character = player.Character
		local humanoid, rootPart = Util.checkHumanoid(character)

		if not (character and humanoid and rootPart) or humanoid.Health <= 0 then
			return
		end

		local data = PlayerService.getData(player)
		if not data then
			return
		end

		local weaponInfo = getWeaponInfo(data)
		if not weaponInfo then
			return
		end

		local entity = playerEntity(character, humanoid, rootPart, data)
		CombatService.basicAttack(entity, weaponInfo)
	end)
end

-- does a basic attack and triggers the animation
function CombatService.basicAttack(entity: Entity, weaponInfo: WeaponInfo)
	if #weaponInfo.animations.combo == 0 then
		return
	end

	local state = getState(entity.humanoid)
	local combo = weaponInfo.animations.combo

	if state.phase == "idle" then
		startSwing(entity, weaponInfo, state)
	elseif state.phase == "recovery" and state.step < #combo then
		-- combo continues so recovery is skipped
		if state.thread then
			task.cancel(state.thread)
		end
		state.step += 1
		startSwing(entity, weaponInfo, state)
	else
		-- remembers the click in wind up or recovery
		state.queued = true
	end
end

return CombatService
