# `noir_influence` — Ghetto Influence Engine

## Purpose
Implement:
> Activity by one ghetto increases its influence in an area and pressures the current dominant ghetto.

## Example state
```text
DAVIS

Ballas:    2180
Families:  1730
Vagos:      420
```

Example reward requirement:
```text
Cocaine Lab: 2000 influence
```

## Initial activity values
| Action | Actor gain | Current-controller loss |
|---|---:|---:|
| Small drug sale | +2 | -1 |
| Gang graffiti | +25 | -15 |
| Remove rival graffiti | +15 | -20 |

All values are configuration.

## Semantic API
```lua
exports.noir_influence:AddActivity({
    gang = 'families',
    territory = 'davis',
    action = 'graffiti_place',
    actorCitizenId = '...',
    sourceResource = 'noir_graffiti',
})
```

Clients never call a raw AddInfluence endpoint.

## Persistence
```sql
CREATE TABLE IF NOT EXISTS noir_territory_influence (
    territory_id VARCHAR(64) NOT NULL,
    gang_name VARCHAR(64) NOT NULL,
    influence INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (territory_id, gang_name)
);
```

Ledger:
```sql
CREATE TABLE IF NOT EXISTS noir_influence_activity (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    territory_id VARCHAR(64) NOT NULL,
    gang_name VARCHAR(64) NOT NULL,
    action VARCHAR(64) NOT NULL,
    delta INT NOT NULL,
    controller_delta INT NOT NULL DEFAULT 0,
    actor_citizenid VARCHAR(64) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_activity_territory_created (territory_id, created_at),
    INDEX idx_activity_gang_created (gang_name, created_at)
);
```

## Cap
Initial:
```text
MIN = 0
MAX = 3000
```

Configurable globally/per territory.

## Controller rule
A new gang takes control when:
```text
candidate influence >= threshold
AND
candidate has highest influence
AND
candidate >= current controller + takeoverMargin
```

Prototype:
```text
threshold = 2000
takeoverMargin = 200
```

This prevents rapid 1999/2001 flipping.

## Rival pressure
When Families acts in Ballas-controlled Davis:
```text
Families + configured gain
Ballas   - configured controller loss
```

Do not reduce every other gang.

## No alliance mechanic
Influence belongs only to the gang performing the action.

No:
```text
Donate influence
Merge influence
Shared territory
```

## Anti-farming for sales
Example rolling rule:
```text
First 25 qualifying sales/hour: 100%
26–50: 50%
51+: 10%
```

Graffiti uses spatial/cooldown restrictions instead.

## Decay
Implement capability but default OFF for first prototype.

Future option:
```text
No qualifying activity for 24h → -3%/day
```

## Exports
```lua
exports('AddActivity', AddActivity)
exports('GetInfluence', GetInfluence)
exports('GetTerritoryStandings', GetTerritoryStandings)
exports('GetController', GetController)
exports('GetInfluenceState', GetInfluenceState)
```

## Normal-player UI
Do not expose exact rival numbers.

Qualitative states:
```text
DOMINANT
STRONG
STABLE
CONTESTED
WEAK
```

Exact values are ADMIN/dev-only.

## Events
```text
noir_influence:server:activityProcessed
noir_influence:server:rivalPressure
noir_influence:server:controllerChanged
```

Controller change payload:
```lua
{
    territory = 'davis',
    previousController = 'ballas',
    newController = 'families',
    reward = 'cocaine_lab',
}
```

## Concurrency
Influence mutation must be atomic/serialized.

Two simultaneous actions must not overwrite one another.

## Acceptance criteria
- [ ] Activity adds configured influence.
- [ ] Controller loses configured pressure.
- [ ] Influence stays within min/max.
- [ ] Client cannot grant influence.
- [ ] Standings persist.
- [ ] Takeover margin works.
- [ ] Controller event fires only on real transition.
- [ ] Sale diminishing returns work.
- [ ] Exact values are restricted to admin/dev interfaces.
