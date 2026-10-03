local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")

local Client = PlayerScripts.Client

local DamageIndication = require(Client.DamageIndication)
local HitEffects = require(Client.HitEffects)
local Inputs = require(Client.Inputs)
local WeaponAnimations = require(Client.WeaponAnimations)
local PlayerManager = require(Client.PlayerManager)
local Inventory = require(Client.Inventory)
local HUD = require(Client.HUD)

PlayerManager.onStart()
HUD.onStart()
Inventory.onStart()
Inputs.onStart()
HitEffects.onStart()
WeaponAnimations.onStart()
DamageIndication.onStart()
