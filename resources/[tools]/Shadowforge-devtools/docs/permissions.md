# Permissions

ShadowForge DevTools uses **two tiers** of ACE permission so you can let trusted devs use the panel without giving them keys to mutate the world.

| Tier        | ACE name                          | What it gates                                                |
|-------------|------------------------------------|--------------------------------------------------------------|
| Base        | `shadowforge.devtools`            | Opening the panel · reading data · copying snippets          |
| Dangerous   | `shadowforge.devtools.dangerous`  | Spawning · deleting · noclip · godmode · teleport · resource control · world sync |

Both names are configurable:

```lua
Config.Permissions.require   = true                              -- false to disable all gating
Config.Permissions.ace       = 'shadowforge.devtools'
Config.Permissions.dangerous = 'shadowforge.devtools.dangerous'
```

## Recommended setup (production)

```cfg
# server.cfg
add_ace group.admin     shadowforge.devtools           allow
add_ace group.admin     shadowforge.devtools.dangerous allow

add_ace group.developer shadowforge.devtools           allow
# devs get base + read-only — give them dangerous only if needed:
# add_ace group.developer shadowforge.devtools.dangerous allow
```

## Minimal setup (LAN / dev box)

```lua
Config.Permissions.require = false
```

Anyone on the server can open and use the panel. Convenient for solo development; do not ship to a public server like this.

## Granular gating per identifier

```cfg
add_ace identifier.fivem:1234567        shadowforge.devtools           allow
add_ace identifier.steam:110000100000000 shadowforge.devtools.dangerous allow
```

## Server-side enforcement

The client *asks* the server whether the user is allowed via an `ox_lib` callback. The server is the source of truth — even a tampered client cannot bypass `IsPlayerAceAllowed`. Dangerous-action paths re-check on the server before performing the action.

## Disabling individual dangerous tools

If you want users to have the dangerous tier but not specific tools:

```lua
Config.PlayerTools.allowGodmode  = false
Config.PlayerTools.allowNoclip   = false
Config.PlayerTools.allowInvisible = false
```

Or disable an entire module:

```lua
Config.Modules.player_tools = false
```

## Logging permission denials

Permission failures are notified to the user but not logged to Discord by default. If you want them logged, hook the `sfd:log` server event yourself:

```lua
RegisterNetEvent('sfd:log', function(action, data)
    if action:match('^denied') then
        -- write to your audit log
    end
end)
```
