--!strict
local Players = game:GetService("Players")

-- Dependencies
local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client
local HealthbarManager = require(Client.HealthbarManager)

-- Constants
local COLOR_NORMAL = Color3.fromHex("00F0FF")
local COLOR_LOW = Color3.fromHex("E96164")
local LOW_THRESHOLD = 0.5

-----------------------------------
-- Module definition & state
-----------------------------------

local Healthbar = {}

-----------------------------------
-- Public functions
-----------------------------------

function Healthbar.onStart()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local frame = gui:WaitForChild("healthbar") :: Frame
	local view = HealthbarManager.new(frame)

	local function bind(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function update(instant: boolean?)
			local ratio = humanoid.Health / humanoid.MaxHealth
			view:setRatio(ratio, instant)
			if view.label then
				view.label.TextColor3 = if ratio <= LOW_THRESHOLD then COLOR_LOW else COLOR_NORMAL
			end
		end
		humanoid.HealthChanged:Connect(function()
			update(false)
		end)
		update(true)
	end

	if player.Character then
		bind(player.Character)
	end
	player.CharacterAdded:Connect(bind)
end

return Healthbar
