# `noir_graffiti` — Preset + Text Graffiti

## Selected base

Use:

```text
Peak-Studios/peak-sprays
```

Repository:

```text
https://github.com/Peak-Studios/peak-sprays
```

The resource is MIT licensed, open source, supports Qbox, ox_lib and oxmysql, and already contains persistent in-world text/image rendering.

Do **not** use the freehand painting feature for Noir State.

Do **not** allow arbitrary image URLs.

We will fork/adapt the resource into:

```text
noir_graffiti
```

## Core Noir design

Only two graffiti modes are allowed:

```text
1. PRESET GANG TAG
2. TEXT GRAFFITI
```

There is no freehand drawing.

There is no public URL/image upload.

---

# 1. Preset Gang Tags

Gang members can place predefined graffiti associated with their gang.

Examples:

```text
Ballas
Families
Vagos
Marabunta
Lost MC
```

Whenever possible, use graffiti/art assets that already exist in GTA V for these organizations.

Do not let normal players upload new gang images.

Configuration example:

```lua
Config.GangGraffiti = {
    ballas = {
        {
            id = 'ballas_01',
            label = 'Ballas Tag 01',
            type = 'preset',
            asset = 'ballas_01'
        },
        {
            id = 'ballas_02',
            label = 'Ballas Tag 02',
            type = 'preset',
            asset = 'ballas_02'
        }
    },

    vagos = {
        {
            id = 'vagos_01',
            label = 'Vagos Tag 01',
            type = 'preset',
            asset = 'vagos_01'
        }
    }
}
```

The server decides which preset list the player can access based on the player's actual Qbox gang.

A Ballas member cannot request a Vagos preset.

---

# 2. GTA Existing Graffiti Assets

Preferred visual source order:

```text
1. Existing GTA V gang graffiti asset
2. Existing GTA V gang-style decal/texture adapted for the renderer
3. Server-provided approved fallback texture
```

Do not create a system where players browse local files or submit URLs.

Keep the actual asset mapping server/config controlled.

Example abstraction:

```lua
Config.PresetAssets = {
    ballas_01 = {
        type = 'bundled',
        texture = 'ballas_01.png'
    }
}
```

If direct reuse of a GTA texture dictionary is practical in the chosen rendering implementation, prefer referencing it rather than duplicating unnecessary assets.

Because GTA V Enhanced may differ in streamed assets, validate every preset in Enhanced before enabling it in production.

---

# 3. Text Graffiti

Players may also spray text.

Examples:

```text
Ballas
Ballas 4 Life
Davis
Vagos
Stay Out
South LS
```

Text is rendered by the graffiti system onto the wall.

The text workflow should expose only:

```text
Text
Font
Size
Rotation
```

Color can either:

```text
A. follow the gang automatically
```

or use a very small approved palette.

Recommended for first version:

```text
color determined by gang
```

Example:

```lua
Config.GangTextStyle = {
    ballas = {
        font = 'pricedown',
        color = '#6B4AA5'
    },

    families = {
        font = 'pricedown',
        color = '#3B8C4A'
    },

    vagos = {
        font = 'pricedown',
        color = '#D6C33A'
    }
}
```

Do not rely on these exact colors until the visual style is validated.

---

# 4. Text Restrictions

Text graffiti must be server-controlled.

Configuration:

```lua
Config.Text = {
    enabled = true,
    minLength = 2,
    maxLength = 24,
    allowLineBreaks = false,
    allowEmoji = false,
}
```

Apply:

```text
blacklist
rate limiting
server sanitation
length validation
```

Optionally add a whitelist mode later for strict servers.

Do not trust the client-rendered/sanitized value.

The server sanitizes again before persistence.

---

# 5. Remove Freehand Features

From the Peak Sprays fork, disable/remove player access to:

```text
brush drawing
erase brush
undo/redo drawing
brush-size editor
free color picker
image URL input
remote image hosts
live collaborative painting
```

Keep only infrastructure useful for:

```text
placement
DUI rendering
persistence
streaming
text
preset images
admin deletion
```

The goal is to reduce the resource into a controlled gang-graffiti engine.

---

# 6. Player Flow — Gang Preset

```text
Player uses spraycan
        ↓
server resolves player's gang
        ↓
menu shows:

Gang Tag
Text
        ↓
player selects Gang Tag
        ↓
menu lists only that gang's presets
        ↓
player chooses preset
        ↓
aims at wall
        ↓
position / scale / rotation preview
        ↓
spray animation
        ↓
server validates
        ↓
persist
        ↓
emit semantic graffiti event
```

Example:

```text
SPRAY

> Gang Tag
  Text
```

Then:

```text
BALLAS TAGS

> Tag 01
  Tag 02
  Tag 03
```

---

# 7. Player Flow — Text

```text
Player uses spraycan
        ↓
Text
        ↓
enter text
        ↓
server/client validation
        ↓
placement preview
        ↓
scale / rotation
        ↓
spray animation
        ↓
server final validation
        ↓
persist
```

No font/color designer with dozens of options.

Keep it fast and immersive.

---

# 8. Inventory

Use:

```text
spraycan
sprayremover
```

Optional metadata:

```lua
{
    uses = 5
}
```

Do not use:

```text
ballas_spraycan
vagos_spraycan
families_spraycan
```

Gang identity comes from Qbox / `noir_gangs`.

---

# 9. Graffiti Types

Database field:

```text
graffiti_type
```

Allowed values:

```text
preset
text
```

Never:

```text
freehand
remote_image
```

---

# 10. Persistence

Recommended schema:

```sql
CREATE TABLE IF NOT EXISTS noir_graffiti (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,

    gang_name VARCHAR(64) NOT NULL,

    graffiti_type ENUM('preset', 'text') NOT NULL,

    preset_id VARCHAR(64) NULL,
    text_value VARCHAR(64) NULL,

    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,

    normal_x FLOAT NOT NULL,
    normal_y FLOAT NOT NULL,
    normal_z FLOAT NOT NULL,

    rotation FLOAT NOT NULL DEFAULT 0,
    scale FLOAT NOT NULL DEFAULT 1,

    territory_id VARCHAR(64) NULL,

    placed_by VARCHAR(64) NOT NULL,
    placed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    removed_at TIMESTAMP NULL,
    removed_by VARCHAR(64) NULL,

    PRIMARY KEY (id),

    INDEX idx_noir_graffiti_gang (gang_name),
    INDEX idx_noir_graffiti_territory (territory_id),
    INDEX idx_noir_graffiti_type (graffiti_type)
);
```

Use soft deletion.

---

# 11. Server Validation

For every placement validate:

```text
player exists
player has gang
player possesses spraycan
player is close to target coords
graffiti type is valid
preset belongs to player's gang
text satisfies restrictions
territory is server-resolved
placement cooldown is valid
minimum graffiti spacing is valid
```

Never trust client-provided:

```text
gang name
territory ID
preset path
asset URL
text after sanitation
influence amount
```

---

# 12. Anti-Spam

Initial values:

```lua
Config.Placement = {
    maxDistanceFromPlayer = 4.0,
    minimumTagSpacing = 4.0,
    playerCooldownSeconds = 45,
    gangTerritoryCooldownSeconds = 120,
}
```

Keep these values configurable.

---

# 13. Removing Graffiti

Use:

```text
sprayremover
```

Flow:

```text
Target graffiti
        ↓
Remove Graffiti
        ↓
animation/progress
        ↓
server validates
        ↓
soft delete
        ↓
remove from nearby clients
        ↓
emit graffitiRemoved
```

If the remover belongs to a rival gang, this event can later affect influence.

---

# 14. Events

`noir_graffiti` must not directly change influence.

Emit:

```text
noir_graffiti:server:placed
noir_graffiti:server:removed
```

Placement payload:

```lua
{
    graffitiId = 123,
    gang = 'families',
    territory = 'davis',
    graffitiType = 'preset',
    presetId = 'families_01',
    actorCitizenId = 'ABC123',
}
```

Text example:

```lua
{
    graffitiId = 124,
    gang = 'families',
    territory = 'davis',
    graffitiType = 'text',
    text = 'DAVIS',
    actorCitizenId = 'ABC123',
}
```

Removal:

```lua
{
    graffitiId = 123,
    territory = 'davis',
    ownerGang = 'ballas',
    actorGang = 'families',
    actorCitizenId = 'ABC123',
}
```

---

# 15. Influence Integration

Later `noir_influence` listens to these events.

Example:

```text
Families places valid tag in Davis

Families +25
Current Controller -15
```

Rival removal:

```text
Families removes Ballas tag

Families +15
Ballas -20
```

The exact values belong in `noir_influence`, not this resource.

---

# 16. Text vs Gang Tag Influence

Recommended initial balancing:

```text
Preset Gang Tag:
full graffiti influence

Text Graffiti:
reduced graffiti influence
```

Example:

```text
Preset:
+25

Text:
+10
```

Reason:

Players should be encouraged to mark gang identity clearly.

Text remains useful for RP and provocation without becoming the optimal influence spam method.

Alternative:

Text only grants influence when it contains the configured gang name/alias.

Do not implement this complexity until needed.

---

# 17. Streaming / Rendering

Reuse Peak Sprays' proximity rendering architecture where practical.

Only load nearby graffiti.

Do not render every server graffiti for every client.

Persist sufficient render metadata to recreate:

```text
preset asset
or
text scene
```

after resource restart.

---

# 18. Admin Tools

Retain/adapt an ADMIN-only graffiti management interface.

Required operations:

```text
List graffiti
Teleport to graffiti
Preview metadata
Delete graffiti
```

ACE:

```text
noir.graffitiadmin
```

Gang leaders do not receive this permission automatically.

---

# 19. Enhanced Compatibility

Validate in GTA V Enhanced before connecting influence:

```text
preset image renders
text renders
transparent background
scale
rotation
wall alignment
stream in/out
multiple nearby graffiti
resource restart
removal
```

Particularly test any GTA V-native gang artwork separately.

Do not assume every Legacy texture/prop behaves identically in Enhanced.

---

# 20. Acceptance Criteria

## Preset

- [ ] Ballas sees only Ballas preset tags.
- [ ] Vagos sees only Vagos preset tags.
- [ ] Client cannot spoof another gang preset.
- [ ] Approved preset renders correctly.
- [ ] Preset persists through restart.

## Text

- [ ] Gang member can create text graffiti.
- [ ] Text length is restricted.
- [ ] Text is sanitized server-side.
- [ ] Text renders persistently.
- [ ] No arbitrary images/URLs are accepted.

## General

- [ ] No freehand painting exists in player UI.
- [ ] No remote-image upload exists.
- [ ] Spray can is an inventory item.
- [ ] Spray remover works.
- [ ] Placement and removal emit semantic server events.
- [ ] Territory is server-resolved.
- [ ] Gang is server-resolved.
- [ ] Rate limits work.
- [ ] Nearby streaming works.
- [ ] GTA V Enhanced behavior is validated.

---

# 21. Final V1 UX

```text
USE SPRAY CAN

┌─────────────────────┐
│      SPRAY          │
│                     │
│  > Gang Tag         │
│    Text             │
└─────────────────────┘
```

Gang Tag:

```text
BALLAS

Tag 01
Tag 02
Tag 03
```

Text:

```text
TEXT
[ BALLAS 4 LIFE ]

[ Continue ]
```

Then both use the same wall placement system.

This is the intended Noir State graffiti scope.
