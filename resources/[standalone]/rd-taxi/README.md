# RD Taxi V1.1 – Advanced AI NPC Taxi Service System

> **v1.1** fixes all reported issues from community feedback.

---

## Installation

1. Drop the `rd-taxi` folder into your server's `resources/` directory.
2. Add `ensure rd-taxi` to your `server.cfg` **after** `ensure PolyZone`.
3. *(Optional)* Import `database/rd_taxi.sql` if you want ride history logs.
4. Open `config.lua` and set:
   - `Config.Framework` → `"standalone"`, `"qbcore"`, or `"esx"`
   - `Config.PaymentEnabled` → `true` / `false`
   - `Config.Locale` → `"en"` (or your locale file name)
5. Restart the resource or reboot your server.

---

## Localization

Copy `locales/en.lua` to `locales/es.lua` (or any language code), translate
the strings, then set `Config.Locale = "es"` in `config.lua`.

The `L("KEY")` helper automatically loads the correct locale.

---

## Folder structure

```
rd-taxi/
├── fxmanifest.lua
├── config.lua
├── locales/
│   └── en.lua              ← translate this for other languages
├── database/
│   └── rd_taxi.sql         ← optional: ride history table
├── client/
│   ├── main.lua
│   └── zones.lua
├── server/
│   └── main.lua
└── html/
    ├── index.html
    ├── style.css
    ├── script.js
    ├── images/             ← put driver*.png and taxi.png here
    └── sounds/             ← put driver*.mp3 here (optional)
```

---

## Images & Sounds

| File | Purpose |
|------|---------|
| `html/images/driver1.png` | Avatar for driver 1 |
| `html/images/driver2.png` | Avatar for driver 2 |
| `html/images/driver3.png` | Avatar for driver 3 |
| `html/images/taxi.png` | Vehicle image shown in panel |
| `html/sounds/driver1.mp3` | Voice played when taxi arrives (optional) |

Set `voiceFile = "none"` in `config.lua` to disable voice for any driver.

---

## Changelog

### v1.1 (current)
- **FIX** Taxi now actually drives to the player after being called.
  Added entity-replication wait loop (up to 5 s) before issuing drive task.
- **FIX** Taxi blip / map icon now appears immediately when taxi is called.
- **FIX** Doors no longer locked after entering the taxi. Proximity door-toggle
  loop removed; doors are only unlocked on arrival for the specific passenger.
- **FIX** Taxi was idle after destination confirmed. Drive-to-destination event
  now waits for vehicle entity to exist before issuing `TaskVehicleDriveToCoord`.
- **FIX** `demandTimeout` was registered as a client NetEvent instead of server.
- **FIX** `SetNuiFocus` was not released in all branches of the confirmation dialog.
- **FIX** G-key entry check now correctly reads `currentTaxiId` set by `taxiArrived`.
- **ADD** `locales/en.lua` – all UI strings are now translatable.
- **ADD** `database/rd_taxi.sql` – optional ride log table (was missing in v1.0).
- **ADD** `playerDropped` server handler to reset taxi state when a player disconnects mid-ride.
- **ADD** Guard against dispatching a taxi before its `vehicle` netId is registered.

### v1.0
- Initial release.
