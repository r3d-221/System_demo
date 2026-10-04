--!strict
local DummyService = {}

local REGEN_DELAY = 3
local DUMMY_NAME = "Dummy"

local function bind(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	local lastHit = 0
	humanoid.HealthChanged:Connect(function(health)
		if health < humanoid.MaxHealth then
			lastHit = os.clock()
			local stamp = lastHit
			task.delay(REGEN_DELAY, function()
				if lastHit == stamp and humanoid.Parent then
					humanoid.Health = humanoid.MaxHealth
				end
			end)
		end
	end)
end

function DummyService.onStart()
	for _, model in workspace.combat:GetChildren() do
		if model.Name == DUMMY_NAME and model:IsA("Model") then
			bind(model)
		end
	end
end

return DummyService
