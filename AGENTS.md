# Project notes (shared by Claude and Codex)

Keep this file short: every AI session reads it, so extra lines cost credits.

## What this is
A Roblox balloon game, edited in Roblox Studio. The game's scripts are not in
this repo yet; this file carries shared context between AI tools.

## Balloon skins
- `ReplicatedStorage.Shared.BalloonSkins` is the single source for how a skin
  looks. Own balloons, other players' balloons and the stand previews all use it.
- Every balloon wears exactly the equipped skin (no special gold/metal/rainbow
  extras at high counts).
- The server checks every buy and equip (coins, ownership, double clicks).
- Lava Balloons: cosmetic only, owned only through a Game Pass checked on the
  server (`Config.PremiumSkin.GamePassId`). Not sold for coins.
- Classic, Pastel and Midnight Neon keep their color-only look.
- Current prices in config: Gold Rush 400,000, Rainbow 1,000,000. Don't change
  prices without asking.

## Waiting on the owner
- Mesh ID for `balloon_uv.obj` and the six `*_uv.png` Image IDs.
- Lava Game Pass ID.
- Group ID for the Group Skin (no group check is built yet).

## Rules
- Anything that grants coins, items or passes must be checked on the server.
- Keep replies short and plain.
- Add new decisions to this file so the other AI sees them.
