# `noir_labs` — Territory Rewards and Lab Access

## Purpose
Turn territory control into a gameplay reward.

Prototype:
```text
Davis
Required Influence: 2000
Reward: Cocaine Lab
```

The lab is not permanently assigned to one gang.

Access always follows the controller returned by `noir_influence`.

## Configuration
```lua
Config.Rewards = {
    davis = {
        type = 'lab',
        id = 'cocaine_lab',
        requiredInfluence = 2000,
    },
}
```

```lua
Config.Labs = {
    cocaine_lab = {
        label = 'Cocaine Lab',
        territory = 'davis',
        entry = vec4(...),
        craft = vec3(...),
    }
}
```

## Access flow
```text
player interacts
    ↓
server resolves real player gang
    ↓
noir_influence:GetController('davis')
    ↓
compare gang
    ↓
allow or deny
```

Do not cache controller indefinitely on the client.

## Responsibility separation
```text
noir_influence = decides controller
noir_labs      = consumes controller
```

`noir_labs` must never change territory influence.

## Prototype craft
Implement only enough to prove reward transfer.

Example abstract recipe:
```text
cocaine_material
+ processing_supply
→ cocaine_package
```

Full drug-economy balancing comes later.

## Losing control while inside
If a gang loses control while members are inside:
- do not teleport players out
- prevent starting new crafts
- allow active craft to finish safely or cancel cleanly
- deny re-entry once they leave

## Discovery
Do not create a mandatory public map blip.

Admin/dev mode may expose a temporary marker for testing.

## Events
Listen to:
```text
noir_influence:server:controllerChanged
```

## Exports
```lua
exports('CanAccessLab', CanAccessLab)
exports('GetLabController', GetLabController)
exports('GetLabByTerritory', GetLabByTerritory)
```

## Server security
Craft validation must check:
- actual player gang
- current controller
- player position
- required items
- recipe limits/cooldowns

Never trust client claims such as:
```text
gang
controller
craft output
```

## Acceptance criteria
- [ ] Davis can reference cocaine lab.
- [ ] Current controller can use it.
- [ ] Rival cannot use it.
- [ ] Control transfer updates access without restart.
- [ ] Losing control mid-craft is handled safely.
- [ ] Craft is server-authoritative.
- [ ] No public lab blip is required.
