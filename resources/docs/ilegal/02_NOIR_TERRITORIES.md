# `noir_territories` — Geographic Territory Engine

## Purpose
Represent named criminal areas such as:
```text
Davis
Chamberlain Hills
Rancho
Strawberry
```

This resource answers:
> Which configured criminal territory contains these coordinates?

It does not calculate influence.

## Zone model
Use polygon zones.

Example:
```lua
{
    id = 'davis',
    label = 'Davis',
    enabled = true,
    points = {
        vec3(...),
        vec3(...),
        vec3(...),
    },
    minZ = 18.0,
    maxZ = 40.0,
}
```

## Persistence
```sql
CREATE TABLE IF NOT EXISTS noir_territories (
    id VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    polygon JSON NOT NULL,
    min_z FLOAT NULL,
    max_z FLOAT NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);
```

## ADMIN-only editor
Command:
```text
/territorysetup
```

ACE:
```text
noir.territorysetup
```

Gang leaders/bosses do not receive this permission automatically.

## Editor flow
```text
/territorysetup
    ↓
Create Territory
    ↓
ID + label
    ↓
walk polygon
    ↓
Add Point
    ↓
preview
    ↓
save
```

Actions:
```text
Add Point
Undo Point
Finish Polygon
Cancel
Edit Territory
Delete Territory
```

Every server mutation must revalidate ACE.

## Runtime API
```lua
exports('GetTerritoryAtCoords', GetTerritoryAtCoords)
exports('GetTerritory', GetTerritory)
exports('GetTerritories', GetTerritories)
exports('IsInsideTerritory', IsInsideTerritory)
```

## Authority rule
Client zone detection may exist for UI/debug, but authoritative gameplay is server-resolved.

Bad:
```lua
TriggerServerEvent('drugSold', 'davis')
```

Preferred:
```text
server gets player/action coords
    ↓
GetTerritoryAtCoords()
    ↓
determines Davis
```

## Metadata
Keep extensible:
```json
{
  "category": "street",
  "reward": "cocaine_lab",
  "influenceThreshold": 2000
}
```

Behavior still belongs to dedicated resources.

## Prototype territories
Start with only:
```text
Davis
Chamberlain Hills
Rancho
Strawberry
```

Do not map the whole city before gameplay validation.

## Overlap policy
If polygons overlap, behavior must be deterministic.

Recommended:
1. Prefer a zone with higher explicit priority.
2. Otherwise prefer the smallest matching polygon.
3. Log overlaps in ADMIN debug mode.

## Acceptance criteria
- [ ] Admin can create a polygon in-game.
- [ ] Normal player cannot use setup.
- [ ] Polygon persists.
- [ ] Polygon can be edited/deleted/disabled.
- [ ] Server resolves territory by coordinates.
- [ ] Client territory claim is never authoritative.
- [ ] Overlap is deterministic.
