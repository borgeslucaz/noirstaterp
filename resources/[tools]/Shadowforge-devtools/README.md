# ShadowForge DevTools

> A free, open-source **in-game developer panel** for FiveM. Built for the people writing the scripts — not the ones running the server.

<p align="center">
  <img src="screenshots/logo.png" alt="ShadowForge DevTools" width="160"/>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"/></a>
  <a href="https://github.com/TonyHinojosa4/Shadowforge-devtools/actions/workflows/lint.yml"><img src="https://github.com/TonyHinojosa4/Shadowforge-devtools/actions/workflows/lint.yml/badge.svg" alt="Lint"/></a>
  <a href="https://github.com/TonyHinojosa4/Shadowforge-devtools/releases"><img src="https://img.shields.io/github/v/release/TonyHinojosa4/Shadowforge-devtools?include_prereleases&sort=semver" alt="Latest release"/></a>
</p>

<p align="center">
  <a href="#installation">Install</a> ·
  <a href="docs/config.md">Config</a> ·
  <a href="docs/permissions.md">Permissions</a> ·
  <a href="docs/examples.md">Workflows</a> ·
  <a href="#license">License</a>
</p>

---

ShadowForge DevTools is a clean, modular developer panel for FiveM that helps you **inspect entities, copy coordinates, build target zones, place props, inspect vehicles and peds, and ship code faster.**

It is *not* an admin panel. There are no kicks, no bans, no warns. Every feature is aimed at people who are actually writing or debugging scripts.

## Features

- **Entity Inspector** — raycast onto any prop / vehicle / ped / player and read or modify it live.
- **Coordinate Tools** — copy player / camera / aim / ground-Z coords in `vector3`, `vector4`, `vec3`, `vec4`, Lua table, or JSON. Save named locations and teleport back.
- **Zone Builder** — design **box / sphere / poly** zones in-game with a real-time preview, then export to `ox_target`, `ox_lib zones`, `qb-target`, or JSON.
- **Object Placer** — spawn props and move them around with WASD / R-F / Q-E. Snap-to-ground, freeze, cleanup, and bulk-export Lua.
- **Vehicle Tools** — inspect any vehicle's model, plate, class, health, fuel, colors, mods. Copy spawn snippets, Qbox-style shared entries, and `ox_target` templates.
- **Ped Tools** — inspect / spawn peds, set scenarios, copy `CreatePed` and `addLocalEntity` templates.
- **Player / Dev Tools** — heal, armor, godmode, invisible, **noclip**, dev blips, waypoint TP, copy own model hash. All permission-locked and individually toggleable in config.
- **World Tools** — set time, freeze time, override weather (local or broadcast), blackout, and read street / zone / interior info.
- **Resource Tools** — see framework + dependency status; controlled `ensure` / `start` / `stop` for resources you whitelist in `Config.SafeResources`.
- **Debug Overlay** — live HUD with FPS, coords, heading, speed, zone, weapon, aimed entity. Each field individually toggleable.
- **Snippet Generator** — ready-to-paste templates for events, commands, `ox_lib` UI (progress bar, context menu, input dialog, notify), `ox_target` zones / models, qb-target, ACE checks, Discord webhooks, and more.
- **Discord logging** — optional, per-action toggles, validates blank webhook and never errors.

## Screenshots

Drop your own screenshots in `screenshots/` and they will appear here once published.

| Main panel | Inspector | Zone builder |
|:---:|:---:|:---:|
| ![main](screenshots/main.png) | ![inspector](screenshots/inspector.png) | ![zones](screenshots/zones.png) |

## Installation

1. Download or clone the repo into your `resources/` folder:
   ```
   resources/
     [shadowforge]/
       shadowforge-devtools/
   ```
2. Add it to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure shadowforge-devtools
   ```
3. Grant the ACE permission to whoever should use it:
   ```cfg
   add_ace group.admin shadowforge.devtools allow
   add_ace group.admin shadowforge.devtools.dangerous allow
   ```
4. Open the panel in-game with **`F6`**, **`/sfdev`**, or **`/sfdevtools`**.

> **Don't want permissions at all?** Set `Config.Permissions.require = false` — useful for dev servers.

## Dependencies

| Required        | Purpose                                          |
|-----------------|--------------------------------------------------|
| `ox_lib`        | Context menus, input dialogs, notifications, callbacks, KVP-friendly clipboard |

| Optional         | What unlocks                                          |
|------------------|-------------------------------------------------------|
| `ox_target`      | Snippet generator targets ox_target syntax            |
| `ox_inventory`   | Item-count detection in player stats                  |
| `qbx_core`       | Auto-detected; pulls job/money/citizenid              |
| `qb-core`        | Auto-detected; pulls job/money/citizenid              |
| `es_extended`    | Auto-detected; pulls job/identifier/accounts          |

Missing optional dependencies are fine — the panel detects what's running and adapts.

## Commands & keybinds

| Command       | Effect                       |
|---------------|------------------------------|
| `/sfdev`      | Open the panel               |
| `/sfdevtools` | Open the panel               |

| Keybind | Default | Purpose         |
|---------|---------|-----------------|
| `sfdev_open` | `F6` | Open the panel  |

Both command names and the keybind are configurable in `config.lua`.

## Configuration

Most servers only need to edit a handful of values. See [`docs/config.md`](docs/config.md) for the full reference.

```lua
Config.Permissions.require = true             -- gate the panel behind ACE
Config.Permissions.ace     = 'shadowforge.devtools'

Config.Modules.player_tools = true            -- enable / disable module-by-module
Config.PlayerTools.allowGodmode = false       -- lock down dangerous self-toggles

Config.Discord.enabled = true                 -- optional logging
Config.Discord.webhook = 'https://...'

Config.SafeResources = {                      -- only these can be ensured/started/stopped from the panel
    'my_test_resource',
}
```

## Example workflows

See [`docs/examples.md`](docs/examples.md) for guided walkthroughs:

- **Inspect a prop you can see** — raycast and read the model hash.
- **Copy coords as `vector4`** — the fastest way out of "I need this position in code."
- **Create an `ox_target` zone** — pick the spot, size it, copy the snippet.
- **Place a prop with the keyboard** — design a scene, then export it as Lua.
- **Export a vehicle config** — generate a Qbox-style shared entry from the car you're sitting in.

## FAQ

**Is this an admin panel?**
No. There are no punishment / moderation tools. Player Tools (heal, godmode, noclip) exist for *your* character only and are off by default if you want them off.

**Will players abuse this?**
Only if you grant them `shadowforge.devtools`. Keep `Config.Permissions.require = true` and add the ACE permission only to your dev/admin groups. Truly destructive actions sit behind a separate `shadowforge.devtools.dangerous` ACE.

**Does it work on Qbox / QBCore / ESX / Standalone?**
Yes. Framework auto-detection runs on resource start; the panel pulls richer player data when a framework is present and gracefully shows nothing when one isn't.

**Why ox_lib?**
Because it's the de-facto standard for FiveM tooling, ships excellent context menus and input dialogs, and is actively maintained. No NUI to write or skin.

**Can I extend it with my own module?**
Yes — see "Extending" below.

## Extending

Drop a new file in `modules/`, add it to `fxmanifest.lua` *before* `client.lua`, and call:

```lua
SFD.RegisterModule({
    id = 'my_tool',
    label = 'My Tool',
    description = 'What it does',
    icon = 'wand-magic-sparkles',
    open = function()
        lib.registerContext({
            id = 'my_tool_main',
            title = 'My Tool',
            menu = 'sfd_main_menu',
            options = {
                { title = 'Do thing', onSelect = function() SFD.Notify.success('Hi!') end },
            },
        })
        lib.showContext('my_tool_main')
    end,
})
```

It will appear in the main panel automatically. Common helpers you can use:

| Helper                            | What it does                              |
|----------------------------------|-------------------------------------------|
| `SFD.Notify.success/error/info/warning(msg)` | ox_lib notifications              |
| `SFD.Copied(label, payload)`     | Copy text + notify the user               |
| `SFD.SetClipboard(text)`         | Clipboard with F8 fallback                |
| `SFD.HasPermission(level)`       | `'base'` or `'dangerous'` — server-checked, cached |
| `SFD.LogServer(action, data)`    | Optional Discord/server log               |
| `SFD.FormatVec3 / FormatVec4`    | Pretty coordinate strings                 |

## Known limitations

- The custom cursor / NUI is intentionally not used — everything routes through `ox_lib` so the resource stays small and themeable.
- Object placement movement is **camera-relative**, not screen-space. If that feels unintuitive on first try, hold **Shift** for fast moves and **Alt** for precision.
- Routing-bucket reading and some framework helpers require the player to be initialized. Cold-load timing edge cases will return `nil` instead of stale data.

## Roadmap

- Optional NUI front-end (no functional gain, just visual polish)
- More framework data: ox_inventory item counter, vehicle-key snippets
- ESX and QBCore-specific snippet templates in the generator
- "Recording" mode that captures a scene of moves into a single Lua snippet
- Per-user persisted settings (favorited modules, custom keybinds)

PRs welcome — open an issue first if it changes behavior.

## Contributing

Full contribution guide in [`CONTRIBUTING.md`](CONTRIBUTING.md). Short version:

1. Fork the repo, branch from `main`.
2. Follow the existing module pattern: register via `SFD.RegisterModule`, gate dangerous actions through `SFD.HasPermission('dangerous')`, log via `SFD.LogServer`.
3. Avoid pulling in any new dependencies. ox_lib only.
4. Open a PR with a short description and, if possible, a screenshot.

Have an idea but not sure it fits? Float it in [Discussions](https://github.com/TonyHinojosa4/Shadowforge-devtools/discussions) first.

## Bug reports

Open an [issue](https://github.com/TonyHinojosa4/Shadowforge-devtools/issues/new/choose) with:

- Server build (`version` from console)
- Framework + version (Qbox / QBCore / ESX / standalone)
- Steps to reproduce
- F8 console output if anything errored

**Found a security issue?** Don't open a public issue — see [`SECURITY.md`](SECURITY.md) for private disclosure.

## License

MIT — see [`LICENSE`](LICENSE). Use it, change it, ship it. Attribution appreciated, not required.

## Credits

- Built on [`ox_lib`](https://github.com/overextended/ox_lib).
- Snippet templates target [`ox_target`](https://github.com/overextended/ox_target), [`qbx_core`](https://github.com/Qbox-project/qbx_core), [`qb-core`](https://github.com/qbcore-framework/qb-core), and [`es_extended`](https://github.com/esx-framework/esx_core).
- Maintained by **ShadowForge**.
