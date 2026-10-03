local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client

local HitEffects = require(Client.HitEffects)
local Inputs = require(Client.Inputs)
local WeaponAnimationManager = require(Client.WeaponAnimationManager)
local PlayerManager = require(Client.PlayerManager)
local Inventory = require(Client.Inventory)
local HUD = require(Client.HUD)

PlayerManager.onStart()
HUD.onStart()
Inventory.onStart()
Inputs.onStart()
HitEffects.onStart()
WeaponAnimationManager.onStart()
