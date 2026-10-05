# System Demo

A Roblox combat and inventory showcase. Built with server authority and strict type checking in mind.

**[Video](<https://youtu.be/RGUKrVYJtXE>)**  |  **[Play it on Roblox](<https://ro.blox.com/Ebh5?af_dp=roblox%3A%2F%2Fnavigation%2Fgame_details%3FgameId%3D10604324354&af_web_dp=https%3A%2F%2Fwww.roblox.com%2Fgames%2F135649865031852>)**

## What's in it

- **Combat:** attacks have a wind-up, active and recovery time. They also have combos based on the weapon.
- **Hitbox:** arc, sphere, raycast and cylinder hitbox that is compatible with both moving and static attacks.
- **Enemies:** uses state machine to check whether to roam, chase, attack. Cleans up afterwards with drops and respawning.
- **Drops:** drop pools with 15 second timer for owner to collect and 60 seconds before despawn. Other can collect drops on the remaining time.
- **Inventory:** item with stats rolling, stacking and with uid for non-stackables.
- **Lobby:** teleport pads and item collectors, each with a cooldown timer shown above the pad.

## Architecture

**Combat** `HitboxService` only decides what is in the shape. `CombatService` decides when a swing is active and what each hit does, and `DamageCalculationService` calculates base with crit rate. The client only decides when to attack.

**Data** all generic weapon data sits in `ItemData` module. The server reads the hitbox data from it, and the client only gets info for the UI and vfx.

**Central item generation** Collectors, drops and every other source of items call `ItemService.giveItem` where the item is created along with its stats.

**Stat calculation** stats are changed on every equip or buff. Temp buffs are stored differently and never fix with the permanent stats.

### The bug that shaped this
In my old game, the client and the server each hardcoded their own attack cone and damage which caused a lot of problems and inaccurate info. In this project, the server owns the hitbox and the damage, and the client only does the UI and effects.

## Tech

Rojo, Wally, `--!strict` Luau, and a per-module `onStart()` pattern so startup order is explicit in one place.

```
src/
  server/   combat, hitbox, enemies, drops, items, teleport
  client/   UI, inputs, animations, effects
  shared/   item data, types, utilities
```

## Known limitations

- Progress is session-only: inventory and equipped items reset when you rejoin since this is a demo.
- Item icons are placeholders.
- No settings menu or popups yet.

## Contact

Open for commissions:
- Discord: r3d221 (that_guy)
- Roblox: [I0_0ne](<https://www.roblox.com/users/2043040360/profile>)
- [Talent hub](<https://create.roblox.com/talent/creators/2043040360>)
- [Dev forum](<https://devforum.roblox.com/t/commissions-open-scripter-ui-designer/4915903>)