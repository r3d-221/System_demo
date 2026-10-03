--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client
local HitEffects = require(Client.HitEffects)
local PlayerManager = require(Client.PlayerManager)

local Shared = ReplicatedStorage.Shared
local ItemData = require(Shared.ItemData)
local Types = require(Shared.Types)

local Remotes = ReplicatedStorage.Remotes
local SwingStarted = Remotes.SwingStarted
local Attack = Remotes.Attack

-- Types
type WeaponInfo = Types.WeaponInfo
type Phase = Types.CombatPhase

-- Variables
local humanoid: Humanoid? = nil
local animator: Animator? = nil
local weaponId: string? = nil
local attackSpeed = 0
local moving = false

local idleTrack: AnimationTrack? = nil
local runTrack: AnimationTrack? = nil
local comboTracks: { AnimationTrack } = {}
local trackConnections: { RBXScriptConnection } = {}
local characterConnections: { RBXScriptConnection } = {}

local step = 1
local phase: Phase = "idle"
local queued = false
local current: AnimationTrack? = nil
local slashReach: number? = nil

-- Constants
local SLASH_OFFSET = Vector3.new(0, 0.5, -2.5) -- in front the player
local SLASH_TILT = 55
local MAX_SLASH_DISTANCE = 120 -- how far the effect can be seen by others
local SLASH_BASE_REACH = 8 -- the hitbox reach the slash template looks right at

-----------------------------------
-- Module definition & state
-----------------------------------

local WeaponAnimationManager = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function disconnectAll(list: { RBXScriptConnection })
	for _, connection in list do
		connection:Disconnect()
	end
	table.clear(list)
end

-- creates a track for the given animation
local function loadTrack(id: string, priority: Enum.AnimationPriority, looped: boolean?): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{id}`

	local track = (animator :: Animator):LoadAnimation(animation)
	track.Priority = priority
	if looped ~= nil then
		track.Looped = looped
	end
	return track
end

-- clears all animation tracks
local function clearTracks()
	disconnectAll(trackConnections)

	for _, track in comboTracks do
		track:Stop(0)
	end
	table.clear(comboTracks)

	if idleTrack then
		idleTrack:Stop(0)
		idleTrack = nil
	end
	if runTrack then
		runTrack:Stop(0)
		runTrack = nil
	end

	current = nil
	slashReach = nil
	step = 1
	phase = "idle"
	queued = false
end

-- sets up idle, run animations
local function setMovementAnimations()
	if phase ~= "idle" or not humanoid then
		return
	end

	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air

	if idleTrack then
		if moving or not grounded then
			idleTrack:Stop(0.2)
		elseif not idleTrack.IsPlaying then
			idleTrack:Play(0.2)
		end
	end

	if runTrack then
		if moving and grounded then
			if not runTrack.IsPlaying then
				runTrack:Play(0.2)
			end
		else
			runTrack:Stop(0.2)
		end
	end
end

-- plays one attack from the combo
local function playStep(index: number)
	local track = comboTracks[index]
	if not track then
		return
	end

	local previous = current
	step = index
	phase = "windup"
	queued = false
	current = track

	if idleTrack then
		idleTrack:Stop(0.1)
	end
	if runTrack then
		runTrack:Stop(0.1)
	end

	if previous == track then
		track.TimePosition = 0
	elseif previous then
		previous:Stop(0.05)
	end

	track:Play(0.05, 1, 1 + attackSpeed)
end

-- runs slash effect
local function playSlash(index: number, name: string?, root: BasePart?, reach: number?)
	if not name or not root then
		return
	end

	local odd = index % 2 == 1
	local scale = if reach then math.clamp(reach / SLASH_BASE_REACH, 0.5, 2.5) else 1

	-- for left-to-right slash
	local rotation = CFrame.Angles(math.rad(90), 0, 0)
	local offset = Vector3.new(SLASH_OFFSET.X, SLASH_OFFSET.Y, SLASH_OFFSET.Z * scale)
	local tilt = CFrame.Angles(0, math.rad(if odd then SLASH_TILT else -SLASH_TILT), 0)
	local cframe = root.CFrame * CFrame.new(offset) * rotation * tilt

	-- for right-to-left slash
	if not odd then
		cframe *= CFrame.Angles(math.pi, 0, 0)
	end

	HitEffects.playSlash(cframe, scale)
end

-- sets up connection for the combo based on the markers in the animation
local function createTracks(info: WeaponInfo)
	local combo = info.animations.combo
	slashReach = info.hitbox.range or info.hitbox.radius

	for index, comboStep in combo do
		local track = loadTrack(comboStep.id, Enum.AnimationPriority.Action, false)
		comboTracks[index] = track

		-- wind up end, active start
		table.insert(
			trackConnections,
			track:GetMarkerReachedSignal("start"):Connect(function()
				if current ~= track then
					return
				end
				phase = "active"
				local character = player.Character
				playSlash(
					index,
					comboStep.slash,
					character and character:FindFirstChild("HumanoidRootPart") :: BasePart?,
					slashReach
				)
			end)
		)

		-- active end, recovery start
		table.insert(
			trackConnections,
			track:GetMarkerReachedSignal("end"):Connect(function()
				if current ~= track then
					return
				end
				phase = "recovery"
				-- skip recovery
				if queued and index < #combo then
					playStep(index + 1)
				end
			end)
		)

		-- recovery end or animation end, idle start
		table.insert(
			trackConnections,
			track.Stopped:Connect(function()
				if current ~= track then
					return
				end

				current = nil
				step = 1
				if queued then
					queued = false
					playStep(1)
				else
					phase = "idle"
					-- transition to idle animation
					setMovementAnimations()
				end
			end)
		)
	end

	-- sets the track for idle and run animations
	local idleId = info.animations.idle
	if idleId then
		idleTrack = loadTrack(idleId, Enum.AnimationPriority.Idle, true)
	end

	local runId = info.animations.run
	if runId then
		runTrack = loadTrack(runId, Enum.AnimationPriority.Movement, true)
	end

	setMovementAnimations()
end

-- get the equipped weapon data from player
local function getEquippedWeapon(data: any): (string?, WeaponInfo?)
	local uid = data.equipped and data.equipped.weapons
	if not uid or not data.items or not data.items.weapons then
		return nil, nil
	end

	for _, item in data.items.weapons do
		if item.uid == uid then
			return item.id, ItemData.weapons[item.id]
		end
	end
	return nil, nil
end

local function refresh()
	local data = PlayerManager.getData()
	if not data or not animator then
		return
	end

	attackSpeed = if data.changedStats then data.changedStats.attackSpeed or 0 else 0

	local id, info = getEquippedWeapon(data)
	if id == weaponId then
		return
	end

	clearTracks()
	weaponId = id
	if info then
		createTracks(info)
	end
end

local function characterAnimations(character: Model)
	disconnectAll(characterConnections)
	clearTracks()
	weaponId = nil
	moving = false

	local newHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid = newHumanoid
	animator = newHumanoid:WaitForChild("Animator") :: Animator

	-- set movement animation for the character
	table.insert(
		characterConnections,
		newHumanoid.Running:Connect(function(speed: number)
			moving = speed > 0.5
			setMovementAnimations()
		end)
	)

	-- changes the animation when jumping
	table.insert(
		characterConnections,
		newHumanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(setMovementAnimations)
	)

	-- resets the animation on death
	table.insert(
		characterConnections,
		newHumanoid.Died:Connect(function()
			clearTracks()
		end)
	)

	refresh()
end

-----------------------------------
-- Public functions
-----------------------------------

function WeaponAnimationManager.onStart()
	PlayerManager.onChange(refresh)

	player.CharacterAdded:Connect(characterAnimations)
	if player.Character then
		task.spawn(characterAnimations, player.Character)
	end

	-- sets animation for enemies
	SwingStarted.OnClientEvent:Connect(function(model: Model?, index: number, name: string, reach: number?)
		-- return if player since the animation already played
		if not model or model == player.Character then
			return
		end

		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = workspace.CurrentCamera
		if not root or not camera or (camera.CFrame.Position - root.Position).Magnitude > MAX_SLASH_DISTANCE then
			return
		end

		playSlash(index, name, root, reach)
	end)
end

-- fires on every click
function WeaponAnimationManager.attack()
	Attack:FireServer()

	local count = #comboTracks
	if count == 0 then
		return
	end

	if phase == "idle" then
		playStep(1)
	elseif phase == "recovery" and step < count then
		playStep(step + 1)
	else
		-- queues for the next combo start if clicking too fast
		-- check the CombatService timer too
		queued = true
	end
end

return WeaponAnimationManager
