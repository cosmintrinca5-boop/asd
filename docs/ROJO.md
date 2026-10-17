# Rojo setup for Balloon Up

Rojo syncs Luau files from this folder into Roblox Studio. It is set up so it
only touches what `default.project.json` lists by name. Everything else in the
game (models, UI, terrain, sounds and every script still edited in Studio) is
left alone.

## What Rojo manages right now

| Studio location | File | Type |
| --- | --- | --- |
| `ReplicatedStorage.RojoManaged` | `src/ReplicatedStorage/RojoManaged/` | Folder |
| `ReplicatedStorage.RojoManaged.SyncCheck` | `src/ReplicatedStorage/RojoManaged/SyncCheck.luau` | ModuleScript (test only, never runs) |

Nothing else. No gameplay script has been moved yet.

## Why this is safe

- `"$ignoreUnknownInstances": true` is set on the game root, on
  `ReplicatedStorage` and on `RojoManaged`. Rojo does not delete anything it
  doesn't know about at those levels.
- No other services are listed, so Rojo doesn't change their children or
  properties.
- The old starter template has been removed. It changed `Workspace` and
  `Lighting` properties, added a `Baseplate` part, and owned whole folders such
  as `ReplicatedStorage.Shared`, so it could have deleted your scripts.

## Folder layout

```
default.project.json   what Rojo syncs (explicit list only)
rokit.toml             pins Rojo 7.7.0
src/<Service>/...      Luau files, placed like their Studio path
docs/ROJO.md           this file
backups/               local place backups (git ignores this folder)
```

File names set the script type:

| File | Becomes |
| --- | --- |
| `Name.server.luau` | Script |
| `Name.client.luau` | LocalScript |
| `Name.luau` | ModuleScript |
| `Name.meta.json` | extra properties/attributes for `Name` (e.g. `RunContext`, `Disabled`, attributes) |
| `Name/init.server.luau` (etc.) | a script that has children (the other files in `Name/`) |

## One-time install (on the PC that runs Studio)

1. Install Rokit: https://github.com/rojo-rbx/rokit (follow its install steps).
2. In this folder run `rokit install`. Then `rojo --version` should say `7.7.0`.
3. Install the Studio plugin: `rojo plugin install`, then restart Studio.

## Starting Rojo and Claude Code together

1. Open the Balloon Up place in Studio as usual. (Don't use `rojo build` to
   make a new place: that would be an almost empty game.)
2. Terminal 1, in this folder: `rojo serve`
3. In Studio: Plugins > Rojo > Connect (default `localhost:34872`).
4. Rojo shows the changes it wants to make before applying them. **Check this
   list.** The first time it should only add `RojoManaged` and `SyncCheck` in
   ReplicatedStorage. If it shows any delete or any other instance, click
   Reject and stop.
5. Terminal 2, in this folder: `claude`. Keep the Point58 MCP Bridge
   configured in that Claude Code session for looking at Studio and for
   handling models and assets.

Test: change `Version = 1` to `Version = 2` in `SyncCheck.luau` and save. Studio
should show the new source within a second or two.

## How changes flow

- Files → Studio: live while `rojo serve` is running and Studio is connected.
- Studio → files: no. Rojo does not write Studio edits back. Once a script is
  managed by Rojo, edit only the file, or Rojo will overwrite your Studio edit
  on the next sync.
- Scripts not in `default.project.json` stay Studio-only and are edited as
  before (by you or through the MCP Bridge).
- Saving: Rojo changes the open place like any other edit. Save or publish in
  Studio as you normally do. Rojo never publishes.
- Commit the files to git as the source history for managed scripts.

## Backup before any migration

1. In Studio: File > Save to File As... and save a `.rbxl` copy to
   `backups/BalloonUp-YYYY-MM-DD.rbxl` (git ignores this folder).
2. Check Roblox's Version History for the place has the current version.
3. Open the backup once to confirm it loads.

## Moving an existing script into Rojo (only after the owner approves)

Do this one script at a time, in a local Claude Code session that has the MCP
Bridge.

1. Make the backup above.
2. Through the MCP Bridge, record for the script: full path, ClassName,
   `RunContext`, `Enabled`/`Disabled`, attributes, tags, children, and the full
   `Source`. Check that no sibling has the same name.
3. Write the file under `src/` at the matching path with the exact source.
   Confirm it matches Studio (same length and same text). Put properties and
   attributes in a `.meta.json`. If the script has children, either move them
   too or set `"$ignoreUnknownInstances": true` on that script's node so Rojo
   keeps them.
4. Add one entry for that script in `default.project.json` at its exact
   location. Example:

   ```json
   "ServerScriptService": {
     "$className": "ServerScriptService",
     "$ignoreUnknownInstances": true,
     "SkinService": {
       "$path": "src/ServerScriptService/SkinService.server.luau"
     }
   }
   ```

   Never point `$path` at a whole existing Studio folder (like
   `ReplicatedStorage.Shared`). That makes Rojo own the folder and delete
   anything not in it.
5. Connect Rojo. The change list must show the existing script being
   **updated** (same name and class), not a new one added beside it, and no
   deletes. Otherwise click Reject.
6. In Studio, check there is still exactly one copy of the script and that its
   source matches.
7. Commit, and add the script to the table at the top of this file.

Order to move things in: ModuleScripts that only hold data or config first,
then shared modules (e.g. `BalloonSkins`), then server scripts, then client
scripts.
