--!strict

-- Description
local _ = [[
	Manages the toggling of UI.
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local screenContainer = playerGui:WaitForChild("Screens")

local Signal = require(ReplicatedStorage.Shared.Signal)

-----------------------------------
-- Module definition & state
-----------------------------------

local UIManager = {}

UIManager.ScreenOpened = Signal.new()
UIManager.ScreenClosed = Signal.new()

-----------------------------------
-- Helper functions
-----------------------------------

local function getScreen(name: string)
	return screenContainer:FindFirstChild(name)
end

-----------------------------------
-- Public functions
-----------------------------------

function UIManager.toggle(name: string): boolean?
	local screen = getScreen(name)
	if not screen then
		return nil
	end

	screen.Visible = not screen.Visible

	if screen.Visible then
		UIManager.ScreenOpened:Fire(name, screen)
	else
		UIManager.ScreenClosed:Fire(name, screen)
	end

	return screen.Visible
end

function UIManager.open(name: string)
	local screen = getScreen(name)
	if screen and not screen.Visible then
		screen.Visible = true
		UIManager.ScreenOpened:Fire(name, screen)
	end
end

function UIManager.close(name: string)
	local screen = getScreen(name)
	if screen and screen.Visible then
		screen.Visible = false
		UIManager.ScreenClosed:Fire(name, screen)
	end
end

function UIManager.closeAll()
	for _, screen in screenContainer:GetChildren() do
		if (screen:IsA("Frame") or screen:IsA("LayerCollector")) and screen.Visible then
			screen.Visible = false
			UIManager.ScreenClosed:Fire(screen.Name, screen)
		end
	end
end

function UIManager.openExclusive(name: string)
	for _, screen in screenContainer:GetChildren() do
		if screen:IsA("Frame") or screen:IsA("LayerCollector") then
			if screen.Name == name then
				if not screen.Visible then
					screen.Visible = true
					UIManager.ScreenOpened:Fire(screen.Name, screen)
				end
			else
				if screen.Visible then
					screen.Visible = false
					UIManager.ScreenClosed:Fire(screen.Name, screen)
				end
			end
		end
	end
end

return UIManager
