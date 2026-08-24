# Illegal / Ghetto System — Implementation Order

## Goal
Implement the illegal ghetto loop incrementally after `noir_gangs`.

## Target resources
```text
noir_gangs          # already implemented
noir_graffiti       # physical graffiti
noir_territories    # geographic areas
noir_influence      # influence and controller
noir_labs           # territory rewards
noir_rival_alerts   # rival-pressure notifications
noir_devtools       # admin simulation/balancing
```

## Dependency graph
```text
noir_gangs
   ├──────────────┐
   ▼              ▼
noir_graffiti  noir_territories
   └──────┬───────┘
          ▼
    noir_influence
      ┌───┴────┐
      ▼        ▼
 noir_labs  noir_rival_alerts
      └───┬────┘
          ▼
    noir_devtools
```

## Phase 1 — `noir_graffiti`
Implement spray can, wall placement, persistence, rendering, removal and semantic events.
Do not implement influence here.

## Phase 2 — `noir_territories`
Implement polygon areas, server-authoritative lookup and ADMIN-only in-game editor.

## Phase 3 — `noir_influence`
Implement gang influence per territory, rival pressure, caps, takeover threshold and activity adapters.

Initial activity sources:
- graffiti placement
- rival graffiti removal
- street drug sales

## Phase 4 — `noir_labs`
Implement territory reward definitions and a cocaine-lab prototype whose access follows the current controller.

## Phase 5 — `noir_rival_alerts`
Aggregate hostile activity and notify online members without GPS or exact rival numbers.

## Phase 6 — `noir_devtools`
Implement ADMIN-only inspection, simulation, takeover scenarios, stress tests and balance tooling.

## First playable milestone
```text
Families member enters Davis
        ↓
places Families graffiti
        ↓
noir_graffiti emits event
        ↓
noir_territories resolves Davis
        ↓
noir_influence adds Families influence
        ↓
current controller loses pressure/influence
        ↓
controller members receive rival alert
        ↓
Families crosses takeover requirement
        ↓
noir_labs transfers cocaine-lab access
```

## Architecture rules
1. Resources communicate through exports/server events.
2. Never directly mutate another resource's SQL tables.
3. Gang identity comes from `noir_gangs` / Qbox.
4. Territory is always resolved server-side for authoritative actions.
5. Clients can never directly add influence.
6. ADMIN tools are ACE protected.
7. All gameplay numbers are config-driven.

## Non-goals for this iteration
- formal turf-war timers
- kill-based capture
- gang alliances
- MC market system
- cartel system
- laundering
- police investigation

## Definition of done
- [ ] Resources can restart independently.
- [ ] No client can grant influence.
- [ ] No client can claim a gang or territory authoritatively.
- [ ] Admin commands require ACE.
- [ ] Influence parameters are configurable.
- [ ] End-to-end Davis takeover can be simulated and played.
