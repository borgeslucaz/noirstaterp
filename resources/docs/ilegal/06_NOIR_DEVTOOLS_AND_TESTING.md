# `noir_devtools` — Admin Simulation and Testing

## Purpose
Allow a solo developer to test and balance the illegal system without many real players.

This is development/admin tooling only.

## Security
ACE:
```text
noir.devtools
```

Every command and server mutation must validate ACE.

## Commands

### Inspect
```text
/noirterritory davis
```

Example admin output:
```text
DAVIS

Ballas    2180
Families  1740
Vagos      320

Controller: Ballas
Reward: cocaine_lab
```

### Set influence
```text
/noirsetinf ballas davis 2100
```

### Simulate activity
```text
/noirsim sale families davis 100
/noirsim graffiti families davis 5
/noirsim remove_graffiti families davis 2
```

### Reset
```text
/noirreset davis
```

### Scenario
```text
/noirscenario davis_takeover
```

## Data-driven scenarios
```lua
Scenarios.davis_takeover = {
    initial = {
        ballas = 2300,
        families = 900,
    },

    actions = {
        { gang = 'families', action = 'drug_sale', count = 150 },
        { gang = 'families', action = 'graffiti_place', count = 8 },
        { gang = 'ballas', action = 'drug_sale', count = 40 },
    }
}
```

## Headless testing rule
Core influence logic must not require a FiveM player.

Bad:
```lua
function AddInfluence(source)
```

Preferred:
```lua
function ProcessActivity(activity)
```

Player adapters turn real gameplay into normalized activity objects.

## Boundary tests
Automatically test:
```text
1999
2000
2001
```

And takeover margins:
```text
controller + 199
controller + 200
controller + 201
```

## Concurrency stress
Simulate:
```text
1000 activities
10 gangs
4 territories
```

Verify:
- no lost updates
- no negative values
- max cap works
- controllerChanged fires once per actual transition

## Monte Carlo balancing
Optional but strongly recommended.

Example:
```text
Gang A: 6 active players
Gang B: 4 active players
Duration: 3 hours
Sessions: 1000
```

Generate weighted:
```text
drug_sale
graffiti_place
graffiti_remove
```

Report:
```text
average influence/hour
average takeover time
takeover probability
activity counts
```

## Real-client tests
Use actual FiveM clients for:
- graffiti rendering
- NUI
- animations
- wall placement
- proximity streaming
- notifications
- OneSync/player state

Use simulation for:
- influence math
- thresholds
- ownership
- diminishing returns
- concurrency
- decay

## Acceptance criteria
- [ ] Commands are ACE protected.
- [ ] Exact influence is inspectable by admin.
- [ ] Activity can be simulated without players.
- [ ] Takeover scenarios execute automatically.
- [ ] Boundary tests exist.
- [ ] Stress tests do not lose updates.
- [ ] Devtools can be disabled without breaking gameplay.
