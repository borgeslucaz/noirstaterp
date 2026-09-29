# noir_tireslash

Target based tire slashing.

Based on wasabi_tireslash by [wasabirobby](https://github.com/wasabirobby/wasabi_tireslash) (v1.0.4, 2022).
This copy was rewritten for the ox stack: ox_target instead of qtarget/qb-target,
ox_lib notifications/progress/locales, and a validated server-side sync path.

## Features

- ox_target wheel bones, so the option only shows on the tire you are aiming at
- Weapon check, bulletproof tire check, cancellable progress bar
- Works on parked/unowned vehicles and on vehicles being driven by another player
- Server-side validation (distance, tire index, per-player cooldown)
- Smoke/air venting from the slashed wheel (several emitters), skipped cleanly if the ptfx asset is missing from the build
- Puncture sound played from the vehicle for everyone nearby, through `mana_audio` when it is running
- Locales via ox_lib (`en`, `pt-br`)

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- `mana_audio` (optional — without it the slash is simply silent)

## Installation

1. Put the folder in your resources directory.
2. `ensure noir_tireslash` in your `server.cfg` (after `ox_lib` and `ox_target`).
3. Adjust `config.lua` if needed.

For Portuguese, set `setr ox_lib:locale "pt-br"` in your `server.cfg`.

## Notes

- Tires are flattened, not shredded to the rim. Set `Config.burstOnRim = true` to change that.
- Slashed tires are not persisted; they reset when the vehicle is respawned from a garage.
