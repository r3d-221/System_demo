--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local weaponTemplates = ReplicatedStorage:WaitForChild("weaponTemplates")

-- Types

-- Variables

-- Constants
local GRIP_LIMB_NAME = "Right Arm"

-----------------------------------
-- Module definition & state
-----------------------------------

local EquipmentService = {}

-----------------------------------
-- Helper functions
-----------------------------------

local function unequip(character: Model)
	local rightArm = character:FindFirstChild(GRIP_LIMB_NAME)
	if not rightArm then
		return
	end

	local grip = rightArm:FindFirstChild("WeaponGrip")
	if grip then
		grip:Destroy()
	end

	local held = character:FindFirstChild("EquippedWeapon")
	if held then
		held:Destroy()
	end
end

-----------------------------------
-- Public functions
-----------------------------------

function EquipmentService.equipWeapon(player: Player, weaponModelId: string): boolean
	local character = player.Character
	if not character then
		return false
	end

	local rightArm = character:FindFirstChild(GRIP_LIMB_NAME) :: BasePart?
	if not rightArm then
		warn("[EquipmentService] No " .. GRIP_LIMB_NAME .. " on " .. player.Name)
		return false
	end

	unequip(character)

	local template = weaponTemplates:FindFirstChild(weaponModelId)
	if not template then
		warn("[EquipmentService] No weapon model for: " .. weaponModelId)
		return false
	end

	local weaponModel = template:Clone()
	weaponModel.Name = "EquippedWeapon"

	local handle = weaponModel:FindFirstChild("Handle") :: BasePart?
	if not handle then
		warn("[EquipmentService] '" .. weaponModelId .. "' has no Handle part")
		weaponModel:Destroy()
		return false
	end

	local grip = Instance.new("Motor6D")
	grip.Name = "WeaponGrip"
	grip.Part0 = rightArm
	grip.Part1 = handle
	grip.C0 = (handle:GetAttribute("GripC0") :: CFrame?) or CFrame.new()
	grip.C1 = (handle:GetAttribute("GripC1") :: CFrame?) or CFrame.new()
	grip.Parent = rightArm

	weaponModel.Parent = character
	return true
end

function EquipmentService.unequipWeapon(player: Player)
	local character = player.Character
	if character then
		unequip(character)
	end
end

return EquipmentService
