# lcp_hud_v4

Modern, modular FiveM HUD with a dual-circle status block, voice range
indicator, ammo display, job, player ID and a full in-game HUD editor.

## Highlights

- **Dual-circle status** — hunger / thirst in one ring, health / armor in
  the other. Soft glow accents and smooth circular progress, exactly like
  the spec.
- **Row layout** — alternative horizontal-chip layout for hunger, thirst,
  health and armor. Toggle the layout from the editor.
- **Voice indicator** with strict pma-voice integration. Modes are
  normalized to `whisper` / `normal` / `shouting` (supports both string
  *and* numeric formats from pma-voice). Fixed distances:
  `1.5m / 7.5m / 15.0m`.
- **Voice range marker** — short, optionally pulsing ground marker that
  visualises the current range when you switch modes.
- **Ammo display** — only visible when a weapon is equipped, `clip /
  reserve` format.
- **Player ID** — always visible, or only while holding a configurable
  keybind (`U` by default in `Settings → Key Bindings → FiveM`).
- **Job display** — ESX out of the box, QBCore fallback, easy bridge for
  custom frameworks (see `client/bridge.lua`).
- **HUD editor** — open with `/hudeditor`. Drag any element to where you
  want it, scale it, hide it, switch layouts, or reset everything with
  `/hudreset`. All settings persist via FiveM KVP.

## Install

1. Drop the resource folder into `resources/`.
2. Add `ensure lcp_hud_v4` to your `server.cfg`.
3. (Optional) Make sure `pma-voice` is started **before** this resource so
   the voice indicator picks up your range immediately.
4. (Optional) For hunger / thirst from `esx_status`, just keep
   `Config.Status.source = 'auto'`. Otherwise the internal decay loop
   takes over.

## Configuration

All tunables live in `config.lua`. The most useful ones:

| Key | Default | What it does |
| --- | ------- | ------------ |
| `Config.Layout` | `'circles'` | Initial status style (`'circles'` or `'row'`). Players can switch this at runtime. |
| `Config.Framework` | `'auto'` | Force `'esx'`, `'qb'` or `'standalone'`. |
| `Config.Status.decayMinutesHunger` | `50` | Minutes to go from 100% → 0% hunger (internal mode). |
| `Config.Status.decayMinutesThirst` | `45` | Same for thirst. |
| `Config.Voice.marker.enabled` | `true` | Toggle the on-the-ground voice circle. |
| `Config.PlayerId.visibility` | `'always'` | `'always'` or `'keyhold'`. |

## Commands

| Command | Description |
| ------- | ----------- |
| `/hudeditor` | Toggle the in-game editor (drag elements, scale, visibility, switch style). |
| `/hudreset`  | Reset the layout to the defaults from `config.lua`. |
| `/hud`       | Show/hide the entire HUD (useful for screenshots). |

## Voice (pma-voice) details

The voice module reads `LocalPlayer.state.proximity.mode` once every 200ms.
It normalises both string and numeric formats, only emits an NUI update
when the mode actually changes, and clamps the distance to a fixed value:

- `whisper`  → `1.5`
- `normal`   → `7.5`
- `shouting` → `15.0`

If no data is available, the HUD falls back to `normal` exactly once and
will not override valid modes thereafter.

## Custom framework bridge

`client/bridge.lua` has clear seams for plugging in your own framework
later. Implement:

- `Bridge.getJob()` → `{ name, label, grade }` or `nil`
- `Bridge.getFrameworkStatus()` → `{ hunger, thirst }` or `nil`

and set `Config.Framework` to the matching value (or extend the
auto-detect logic).

## License

MIT — do what you want, but please keep the project link in the file
headers if you fork.
