# `noir_rival_alerts` — Rival Activity Notifications

## Purpose
Warn online members when another ghetto is actively pressuring their controlled area.

Alerts create urgency without providing GPS intelligence.

## Example
```text
Ballas controls Davis.
Families starts selling and tagging in Davis.
```

Expected:
```text
Rival activity detected in Davis.
```

Do not notify once per sale/tag.

## Pressure aggregation
Aggregate hostile controller-loss in a rolling window.

Initial example:
```text
window = 10 minutes
```

```lua
Config.AlertLevels = {
    { pressure = 25,  level = 'LOW' },
    { pressure = 75,  level = 'MEDIUM' },
    { pressure = 150, level = 'HIGH' },
}
```

## Example messages
LOW:
```text
There are signs of rival activity in Davis.
```

MEDIUM:
```text
Rival activity is increasing in Davis.
```

HIGH:
```text
Your control of Davis is under serious pressure.
```

## Never reveal
- exact rival coordinates
- GPS markers
- exact rival influence
- exact controller influence
- exact number of rival players

Rival gang identity may be omitted initially.

## Recipients
Notify online members of the current controller.

Use `noir_gangs` / Qbox server-side membership lookup.

First version:
```text
all online members
```

Rank filtering can be added later.

## Cooldown
Initial:
```text
1 notification / territory / controller / 10 minutes
```

Escalation may bypass cooldown when:
```text
LOW → HIGH
```

## Integration
Listen only to `noir_influence`.

Recommended event:
```text
noir_influence:server:rivalPressure
```

Do not directly subscribe to graffiti/drug resources.

## Transport
Start with the project's notification abstraction or `ox_lib`.

Do not couple to a specific phone resource.

A future burner-phone app may consume the same alert service.

## Acceptance criteria
- [ ] Rival pressure accumulates.
- [ ] Controller receives alerts.
- [ ] Notifications are aggregated.
- [ ] Cooldown works.
- [ ] Escalation works.
- [ ] Only online controller members receive alerts.
- [ ] No GPS/exact standings are exposed.
