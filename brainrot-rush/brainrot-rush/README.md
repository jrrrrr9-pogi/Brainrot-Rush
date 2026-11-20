# Brainrot Rush

A multiplayer Roblox collector-tycoon about absurd, procedurally generated brainrot creatures. Every character is an original, randomly assembled combination of silly words and primitive parts. No copyrighted characters and no external assets.

## How to play

1. A conveyor belt carries random brainrots past six player bases.
2. Walk up to one and press **E** to buy it with coins.
3. Your brainrots sit in your base (10 slots) and earn coins every second.
4. Hold **F** next to a brainrot in your base to sell it for 50% of its value.
5. Save up and **Rebirth**: coins reset, but income permanently goes up by 50% per rebirth.

## Features

- **5 rarities**: Common, Uncommon, Rare, Epic, Legendary, each bigger, pricier and richer.
- **Mutations**: 10% Golden (x2 income, metallic) and 3% Rainbow (x5 income, color-cycling).
- **Procedural characters**: name, color, eyes, mouth and accessory are all generated from a seed.
- **Surge events**: every 2.5 minutes the belt speeds up and rare odds go up 4x for 30 seconds.
- **Server-wide shout-outs** when someone pulls an Epic, Legendary, Golden or Rainbow.
- **Saving**: coins, rebirths and brainrots persist with DataStore (retries, and never overwrites a save after a failed load).
- **Rebirth leaderboard** through Roblox's built-in leaderboard stats.

## Project layout

```
default.project.json         Rojo project
src/shared/BrainrotData.luau rarities, mutations, name generator, economy formulas
src/server/Main.server.luau  world, conveyor, buying/selling, income, events, lifecycle
src/server/BrainrotFactory.luau  builds a character model from parts
src/server/PlayerData.luau   DataStore save/load
src/client/UI.client.luau    HUD, toasts, surge banner, bobbing animation
```

## Run it

1. Install [Rojo](https://rojo.space) (`aftman install rojo-rbx/rojo` or the VS Code extension).
2. Build a place file: `rojo build -o BrainrotRush.rbxlx`, open it in Roblox Studio and press Play.
   Or run `rojo serve` and connect from the Studio Rojo plugin.
3. To test saving, enable **Game Settings -> Security -> Enable Studio Access to API Services**.

Tune the economy in `src/shared/BrainrotData.luau`.
