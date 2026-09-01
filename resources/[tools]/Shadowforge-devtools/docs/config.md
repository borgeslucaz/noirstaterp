# Configuration reference

Every value lives in [`config.lua`](../config.lua). Defaults are sane; this file documents what each does.

## Commands & keybind

```lua
Config.Commands = { 'sfdev', 'sfdevtools' }   -- additional names allowed; both register
Config.Keybind = {
    enabled     = true,
    name        = 'sfdev_open',                -- internal name used by FiveM key mapping
    description = 'Open ShadowForge DevTools', -- shown in the FiveM key-bindings UI
    defaultKey  = 'F6',
}
```

## Permissions

```lua
Config.Permissions = {
    require   = true,                                 -- false = no ACE check
    ace       = 'shadowforge.devtools',               -- base permission
    dangerous = 'shadowforge.devtools.dangerous',     -- mutating-action permission
}
```

See [permissions.md](permissions.md) for examples.

## Module toggles

Disable any module by setting it to `false`. The corresponding entry simply disappears from the main menu.

```lua
Config.Modules = {
    entity_inspector = true,
    coords           = true,
    zone_builder     = true,
    object_placer    = true,
    vehicle_tools    = true,
    ped_tools        = true,
    player_tools     = true,
    world_tools      = true,
    resource_tools   = true,
    debug_tools      = true,
    snippets         = true,
    settings         = true,
}
```

## Inspector

```lua
Config.Inspector = {
    maxDistance   = 30.0,                                  -- raycast distance in metres
    refreshMs     = 100,                                   -- how often the overlay re-runs the raycast
    drawLine      = true,                                  -- draw line from camera to hit
    drawHitMarker = true,                                  -- draw small marker at hit point
    markerColor   = { r = 192, g = 160, b = 255, a = 200 },
}
```

## Coords

```lua
Config.Coords = {
    maxSavedLocations = 100,   -- KVP-stored locally
    decimals          = 2,     -- how many decimal places for formatted coords
}
```

## Zone builder

```lua
Config.Zones = {
    defaultBoxSize   = vec3(2.0, 2.0, 2.0),
    defaultSphereRad = 1.5,
    debugColor       = { r = 192, g = 160, b = 255, a = 80 },
}
```

## Object placer

```lua
Config.ObjectPlacer = {
    maxDevProps = 50,    -- oldest is removed when limit hit
    moveSpeed   = 0.05,  -- metres per frame
    rotateSpeed = 2.0,   -- degrees per frame
    fastMul     = 4.0,   -- multiplier when Shift held
    slowMul     = 0.25,  -- multiplier when Alt held
    snapToGround = true,
}
```

## Player tools

Each `allow*` is a hard gate. Even with the `dangerous` ACE, if `allowGodmode = false` then godmode is unreachable.

```lua
Config.PlayerTools = {
    allowSelfHeal   = true,
    allowSelfArmor  = true,
    allowNoclip     = true,
    allowGodmode    = true,
    allowInvisible  = true,
    allowDevBlips   = true,
    noclipSpeed     = 1.0,
    noclipFastMul   = 4.0,
    noclipSlowMul   = 0.25,
}
```

## Resource tools

Resource control is **whitelisted only**. Add the resources the panel may `ensure`, `start`, or `stop`:

```lua
Config.SafeResources = {
    'my_test_resource',
    'my_dev_zone_script',
}
```

If empty, the safe-resources menu shows nothing — by design.

## World

```lua
Config.World = {
    weatherTypes = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS', ... },
    syncToServer = false, -- true allows the "Sync to all" button to broadcast (admin-style)
}
```

## Ped scenarios

The list shown in the ped scenario picker. Add or remove freely:

```lua
Config.Scenarios = {
    'WORLD_HUMAN_CLIPBOARD',
    'WORLD_HUMAN_GUARD_STAND',
    -- …
}
```

## UI

```lua
Config.UI = {
    panelIcon       = 'screwdriver-wrench',
    panelTitle      = 'ShadowForge DevTools',
    panelSubtitle   = 'Developer panel',
    sound           = true,
    framework_detect = true,
    debug_markers   = true,
    accent          = '#C0A0FF',
}
```

## Discord logging

```lua
Config.Discord = {
    enabled   = false,
    webhook   = '',
    botName   = 'ShadowForge DevTools',
    botAvatar = '',
    color     = 12624639,
    log = {
        open     = true,
        delete   = true,
        spawn    = true,
        teleport = true,
        noclip   = true,
        godmode  = true,
        snippet  = false,   -- noisy; off by default
        resource = true,
        world    = true,
    },
}
```

A blank webhook is a no-op — safe to ship with `enabled = false` and fill in later.
