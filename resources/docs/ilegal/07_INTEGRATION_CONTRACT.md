# Illegal System — Inter-Resource Integration Contract

## Goal
Keep the illegal ecosystem modular and independently replaceable.

No resource may directly modify another resource's database.

## `noir_gangs`
Authority:
```text
player → gang
gang → members
gang → grade/permissions
```

Expected:
```lua
GetPlayerGang(source)
GetGangMembers(gangName)
```

## `noir_territories`
Authority:
```text
coordinates → territory
```

Exports:
```lua
GetTerritoryAtCoords(coords)
GetTerritory(id)
GetTerritories()
```

## `noir_graffiti`
Authority:
```text
placement
removal
rendering
persistence
```

Emits:
```text
noir_graffiti:server:placed
noir_graffiti:server:removed
```

## `noir_influence`
Authority:
```text
gang + territory → influence
territory → controller
```

Consumes normalized activities.

Emits:
```text
noir_influence:server:activityProcessed
noir_influence:server:rivalPressure
noir_influence:server:controllerChanged
```

## `noir_labs`
Consumes:
```text
GetController()
controllerChanged
```

Never mutates influence.

## `noir_rival_alerts`
Consumes:
```text
rivalPressure
```

Never mutates influence.

## Normalized activity object
```lua
{
    gang = 'families',
    territory = 'davis',
    action = 'drug_sale',
    actorCitizenId = 'ABC123',
    sourceResource = 'noir_drugs',
    metadata = {}
}
```

## Territory rule
Do not trust client territory IDs.

Server resolves authoritative coordinates through `noir_territories`.

## Gang rule
Do not trust gang identity from client.

Server resolves through `noir_gangs` / Qbox.

## Event naming
```text
noir_<resource>:server:<event>
noir_<resource>:client:<event>
```

## Database ownership
```text
noir_graffiti
    → noir_graffiti

noir_territories
    → noir_territories

noir_influence
    → noir_territory_influence
    → noir_influence_activity
```

Normal gameplay must not depend on cross-resource SQL joins.

## Recommended start order
```text
qbx_core
ox_lib
oxmysql
ox_target
ox_inventory

noir_gangs
noir_territories
noir_graffiti
noir_influence
noir_labs
noir_rival_alerts
noir_devtools
```

## Failure behavior
If `noir_rival_alerts` stops, influence still works.

If `noir_labs` stops, influence still works.

If `noir_influence` stops, graffiti should fail gracefully rather than crash.

## End-to-end contract
```text
Player performs criminal activity
    ↓
source resource validates it
    ↓
server resolves gang
    ↓
server resolves territory
    ↓
noir_influence processes activity
    ↓
atomic influence change
    ↓
rival pressure event
    ↓
possible controller change
    ↓
alerts notify gang
    ↓
labs use new controller
```
