local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client

local Inputs = require(StarterPlayer.StarterPlayerScripts.Client.Inputs)
local PlayerManager = require(Client.PlayerManager)
local Inventory = require(Client.Inventory)
local HUD = require(Client.HUD)

PlayerManager.onStart()
HUD.onStart()
Inventory.onStart()
Inputs.onStart()
