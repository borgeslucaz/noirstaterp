# BGRZ Identity

## Overview

`bgrz_identity` is the character identity and character-creation domain for the BGRZ FiveM server.

The resource is built for:

```text
FiveM GTAV Enhanced
Qbox Framework
qbx_core
bgrz_core
illenium-appearance
ox_lib
oxmysql
```

Its primary responsibilities are:

* Character creation flow.
* Character identity.
* Initial appearance configuration.
* Character creation restrictions.
* Identity validation.
* Persistent BGRZ-specific identity data.
* Integration between Qbox character data and the appearance system.
* Controlling which appearance options are available after character creation.

`bgrz_identity` must **not replace Qbox character management**.

Qbox remains responsible for the underlying player/character lifecycle.

`bgrz_identity` extends that lifecycle with BGRZ Hard RP rules.

---

# 1. Architecture

The intended architecture is:

```text
qbx_core
    │
    ▼
bgrz_core
    │
    ▼
bgrz_identity
    │
    ├── Character Identity
    ├── Character Creation Flow
    ├── Creation State
    ├── Appearance Rules
    └── Identity Documents
            │
            ▼
    illenium-appearance
```

Responsibilities must remain separated.

## qbx_core

Responsible for:

```text
Player lifecycle
Citizen ID
Character data
Jobs
Metadata
Money
Character persistence
```

## bgrz_core

Responsible for:

```text
Normalized BGRZ character API
Shared validation
Shared helpers
Common BGRZ APIs
```

## bgrz_identity

Responsible for:

```text
Character creation workflow
Identity validation
BGRZ identity fields
Creation completion state
Appearance permissions
Identity-related business rules
```

## illenium-appearance

Responsible for:

```text
Ped appearance
Head blend
Face features
Head overlays
Hair
Props
Components
Tattoos
Appearance persistence
```

---

# 2. Core Principle

`bgrz_identity` should control **the rules of character creation**.

`illenium-appearance` should control **how appearance is applied to the ped**.

Do not rewrite GTA appearance natives unless there is a clear technical reason.

### Wrong

```text
bgrz_identity
    ├── manually implements every ped native
    ├── manually stores every drawable
    ├── manually handles tattoos
    └── manually handles clothing
```

### Correct

```text
bgrz_identity
    │
    ├── determines what player may edit
    ├── determines when player may edit it
    ├── validates identity
    ├── manages creation flow
    │
    ▼
illenium-appearance
    │
    └── applies and stores appearance
```

---

# 3. Do Not Modify Qbox

Never modify:

```text
qbx_core
qbx_spawn
qbx_multicharacter
```

to implement BGRZ identity behavior if it can be achieved through:

```text
exports
events
hooks
configuration
bgrz_identity
```

The BGRZ architecture must remain update-friendly.

---

# 4. Resource Structure

Recommended initial structure:

```text
bgrz_identity/
├── fxmanifest.lua
│
├── config/
│   ├── shared.lua
│   ├── client.lua
│   └── server.lua
│
├── shared/
│   ├── constants.lua
│   └── validation.lua
│
├── client/
│   ├── main.lua
│   ├── creator.lua
│   ├── camera.lua
│   └── appearance.lua
│
├── server/
│   ├── main.lua
│   ├── identity.lua
│   ├── creator.lua
│   ├── storage.lua
│   └── events.lua
│
└── locales/
    └── en.json
```

Do not over-engineer the first version.

Files may be merged while the resource is small.

---

# 5. Dependencies

Initial dependencies:

```text
qbx_core
bgrz_core
ox_lib
oxmysql
illenium-appearance
```

Recommended `fxmanifest.lua`:

```lua
fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'BGRZ'
description 'BGRZ Character Identity and Creation'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config/shared.lua',
    'shared/*.lua'
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'config/client.lua',
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config/server.lua',
    'server/*.lua'
}

dependencies {
    'qbx_core',
    'bgrz_core',
    'ox_lib',
    'oxmysql',
    'illenium-appearance',
    '/onesync'
}
```

---

# 6. Character Creation Flow

The initial BGRZ character creator should use the following steps:

```text
1. Identity
      ↓
2. Genetics
      ↓
3. Face
      ↓
4. Hair
      ↓
5. Facial Hair
      ↓
6. Details
      ↓
7. Initial Clothing
      ↓
8. Accessories
      ↓
9. Review
      ↓
10. Confirm
```

The player should not be considered fully created until the final confirmation succeeds.

---

# 7. Step 1 — Identity

Required initial fields:

```text
First Name
Last Name
Date of Birth
Sex
Nationality
```

Potential future fields:

```text
Middle Name
Place of Birth
Ethnicity for game-world records
Preferred Name
State of Origin
```

Do not add fields without a gameplay purpose.

---

# 8. Identity Validation

All identity fields must be validated server-side.

The client validation exists only for user experience.

The server is authoritative.

Example:

```lua
local function validateName(value)
    if type(value) ~= 'string' then
        return false
    end

    value = value:gsub('^%s+', ''):gsub('%s+$', '')

    if #value < 2 or #value > 24 then
        return false
    end

    return value:match("^[%aÀ-ÿ'%- ]+$") ~= nil
end
```

Actual validation should support the characters required by the server community.

---

# 9. Name Rules

Initial recommended constraints:

```text
First Name:
2–24 characters

Last Name:
2–24 characters
```

Allowed:

```text
Letters
Spaces where appropriate
Hyphens
Apostrophes
```

Examples:

```text
John Smith
Mary-Jane Watson
O'Connor
De Luca
```

Reject obvious malformed input such as:

```text
J0hn
!!!!!
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

Do not implement aggressive RP name censorship inside the code.

Administrative rules should remain separate from technical validation.

---

# 10. Date of Birth

Date of birth should be stored in a predictable format.

Recommended persistence format:

```text
YYYY-MM-DD
```

Example:

```text
1994-05-23
```

UI may display:

```text
05/23/1994
```

or another locale-specific representation.

Do not persist localized date strings.

---

# 11. Age Validation

The server should derive age from date of birth.

Do not allow the client to send:

```text
age = 31
```

as authoritative data.

Instead:

```text
birthdate
    ↓
server
    ↓
calculate age
```

Example future rules:

```text
Minimum character age: 18
Maximum character age: configurable
```

These values must remain configurable.

---

# 12. Sex / Ped Model

Initial BGRZ creation should use GTA freemode models:

```text
mp_m_freemode_01
mp_f_freemode_01
```

The selected character sex determines the base ped used by the creator.

Do not allow arbitrary ped models during normal character creation.

Special models should be handled through separate systems.

---

# 13. Step 2 — Genetics

Genetics should use GTA head blend data.

The creator should support:

```text
Mother
Father
Face Mix
Skin Mix
```

The data should ultimately be handled through the existing appearance engine.

Do not maintain a hardcoded copy of all parent combinations unless required by the UI.

---

# 14. Step 3 — Face Features

Support standard face feature controls such as:

```text
Nose Width
Nose Height
Nose Length
Nose Bridge
Nose Tip
Nose Shift

Brow Height
Brow Width

Cheekbone Height
Cheekbone Width
Cheek Width

Eye Opening

Lip Thickness

Jaw Width
Jaw Height

Chin Length
Chin Position
Chin Width
Chin Shape

Neck Width
```

Ranges should match GTA native expectations.

The UI should normalize these values for usability.

Example UI:

```text
-100 ───────── 0 ───────── +100
```

while the underlying value may be:

```text
-1.0 to 1.0
```

---

# 15. Step 4 — Hair

Hair is a ped **component**, not a prop.

Component ID:

```text
2
```

Hair should support:

```text
Style
Texture where applicable
Primary Color
Highlight Color
```

Do not hardcode a global maximum hair ID.

Use the ped/game data dynamically.

Example:

```lua
local count = GetNumberOfPedDrawableVariations(ped, 2)
```

Texture variants:

```lua
local textures = GetNumberOfPedTextureVariations(
    ped,
    2,
    drawable
)
```

The creator must only expose options that are actually valid for the current ped.

---

# 16. Facial Hair

Facial hair is **not clothing** and is **not component 1**.

Facial hair is a head overlay.

Use the appearance engine's head overlay implementation.

Relevant overlay:

```text
1 = Facial Hair
```

Support:

```text
Style
Color
Opacity
```

---

# 17. Head Overlays

The creator should support appropriate GTA head overlays:

```text
0  Blemishes
1  Facial Hair
2  Eyebrows
3  Ageing
4  Makeup
5  Blush
6  Complexion
7  Sun Damage
8  Lipstick
9  Moles / Freckles
10 Chest Hair
11 Body Blemishes
```

Not every option needs to be exposed during initial version.

Recommended initial BGRZ creator:

```text
Facial Hair
Eyebrows
Ageing
Complexion
Sun Damage
Moles/Freckles
Makeup
Blush
Lipstick
```

---

# 18. Opacity

Head overlays that support opacity should expose an opacity control.

Example:

```text
0% ───────────── 100%
```

Do not use only:

```text
On / Off
```

where GTA supports opacity.

---

# 19. Hair Color

Hair-related overlays should use appropriate GTA hair colors.

Examples:

```text
Hair
Facial Hair
Eyebrows
Chest Hair
```

Do not use arbitrary RGB values if GTA expects indexed colors.

---

# 20. Eye Color

Support GTA eye colors using the proper native/appearance API.

Eye color should be part of:

```text
Details
```

not clothing.

---

# 21. Step 6 — Details

Recommended details:

```text
Eyebrows
Eye Color
Ageing
Complexion
Sun Damage
Moles / Freckles
Blemishes
Makeup
Blush
Lipstick
```

These should remain visually grouped in the UI.

Avoid a single list containing dozens of unrelated options.

---

# 22. Initial Clothing

The player should select a simple initial outfit.

Do not expose the entire server clothing catalog during character creation.

Recommended initial categories:

```text
Top
Undershirt
Pants
Shoes
Optional Jacket
```

Potential restricted categories:

```text
Armor
Job uniforms
Police uniforms
EMS uniforms
Gang clothing
Rare clothing
Special event clothing
```

Initial creation should not become a free clothing shop.

---

# 23. Clothing Components

Standard GTA component mapping:

```text
0  Head
1  Mask
2  Hair
3  Torso / Arms
4  Legs
5  Bags / Parachutes
6  Shoes
7  Accessories
8  Undershirt
9  Body Armor
10 Decals
11 Tops
```

Treat components according to their real GTA slot.

---

# 24. Props

Standard prop slots:

```text
0 Hat / Helmet
1 Glasses
2 Ear Accessory
6 Watch
7 Bracelet
```

Props are separate from clothing components.

Do not store:

```text
hair
beard
shirt
pants
```

as props.

---

# 25. Initial Accessories

During initial creation, expose only:

```text
Hat
Glasses
Ear Accessory
Watch
Bracelet
```

depending on server design.

Each category should allow:

```text
None
```

---

# 26. Enhanced-Safe Clothing Identity

BGRZ is being developed for **GTAV Enhanced**.

Appearance persistence should be designed with collection-based natives in mind.

Global drawable indices may change across GTA title updates.

Where technically possible, prefer storing stable clothing references as:

```lua
{
    component = 11,

    collection = 'collection_name',

    drawable = 4,

    texture = 1
}
```

instead of relying only on:

```lua
{
    component = 11,

    drawable = 395,

    texture = 1
}
```

The long-term target should be:

```text
Collection
+
Collection-local drawable index
+
Texture
```

for compatible clothing and props.

---

# 27. Compatibility Layer

Do not immediately rewrite `illenium-appearance` storage.

Instead, implement an abstraction layer in:

```text
client/appearance.lua
```

Example:

```lua
local Appearance = {}

function Appearance.getCurrent()
    -- illenium integration
end

function Appearance.apply(data)
    -- illenium integration
end

function Appearance.openCreator(options)
    -- illenium integration
end

return Appearance
```

Other BGRZ identity code should interact with this abstraction rather than scattering direct Illenium calls everywhere.

---

# 28. Appearance Permissions

Appearance permissions must depend on context.

## Initial Character Creation

Allow:

```text
Ped sex/model
Genetics
Face features
Hair
Facial hair
Eyebrows
Eyes
Head overlays
Initial clothing
Accessories
```

## Barber Shop

Allow:

```text
Hair
Hair color
Facial hair
Facial hair color
Eyebrows
Optional makeup-related options
```

Do not allow:

```text
Genetics
Nose
Jaw
Chin
Ped sex/model
```

---

# 29. Clothing Store

Allow:

```text
Clothing
Hats
Glasses
Accessories
Watches
Bracelets
```

Do not allow:

```text
Genetics
Face
Hair
Facial hair
Ageing
Skin
```

---

# 30. Plastic Surgeon

Future system.

May allow:

```text
Face features
Some head blend adjustments
Selected cosmetic details
```

Potential Hard RP rules:

```text
High cost
Cooldown
Medical interaction
Appointment
Limited changes
Audit record
```

Do not implement this in version 0.1.

---

# 31. Tattoos

Tattoos should remain managed by the appearance system.

Initial creator may:

```text
disable tattoos
```

or allow a limited selection.

Recommended Hard RP approach:

```text
Character Creation:
minimal or no tattoos

Tattoo Shops:
full tattoo system
```

This encourages in-world progression.

---

# 32. Character Creation State

A character must have a server-side state indicating whether creation has been completed.

Example:

```text
identity_complete
```

Do not rely only on:

```text
appearance exists
```

as proof that character creation is complete.

A partially created character may already have appearance data.

---

# 33. BGRZ Identity Database

Do not duplicate Qbox character data unnecessarily.

Qbox already owns:

```text
citizenid
firstname
lastname
birthdate
nationality
sex
```

Use Qbox APIs for data it owns.

Create BGRZ tables only for BGRZ-owned state.

Initial proposed table:

```sql
CREATE TABLE IF NOT EXISTS `bgrz_identity` (
    `citizenid` VARCHAR(50) NOT NULL,

    `creation_completed` BOOLEAN NOT NULL DEFAULT FALSE,

    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    `updated_at` TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (`citizenid`)
);
```

Do not duplicate:

```text
firstname
lastname
birthdate
```

unless a future architectural reason requires it.

---

# 34. Future Identity Fields

Potential future BGRZ-owned data:

```text
State ID number
SSN-style RP identifier
Place of birth
Identity issue date
Identity expiration
Legal name change history
Government record status
```

Add them only when needed.

---

# 35. State ID

Future Hard RP identity should use a human-facing government identifier separate from `citizenid`.

Example:

```text
CitizenId:
technical/internal identifier

State ID:
in-character government identifier
```

Example:

```text
citizenId:
ABC12345

stateId:
LS-482-193-27
```

Players should never be expected to roleplay their internal Qbox `citizenId`.

---

# 36. Character Creation Session

Character creation should have an explicit server-tracked session.

Example runtime state:

```lua
local creationSessions = {
    [source] = {
        citizenId = 'ABC12345',

        startedAt = os.time(),

        stage = 'identity',

        completed = false
    }
}
```

Do not persist temporary creation state unnecessarily.

---

# 37. Creation Session Validation

When receiving creation-related events:

Validate:

```text
Player exists
Character exists
Character matches source
Creation is not already completed
Creation session exists
Requested stage is valid
Data types are valid
Values are within allowed ranges
```

---

# 38. Client Is Not Authoritative

Never accept:

```lua
TriggerServerEvent(
    'bgrz_identity:server:complete',
    {
        citizenId = 'SOMEONE_ELSE',
        creationCompleted = true
    }
)
```

Instead:

```lua
TriggerServerEvent(
    'bgrz_identity:server:complete'
)
```

Server resolves:

```text
source
↓
character
↓
citizenId
↓
session
↓
validation
↓
completion
```

---

# 39. Completion

Character creation should only complete after:

```text
Identity valid
Appearance saved successfully
Required selections completed
Server session valid
Database update succeeds
```

Only then:

```text
creation_completed = true
```

---

# 40. Atomic Completion

Avoid:

```text
save completion
↓
appearance save fails
```

or:

```text
appearance saves
↓
identity completion never updates
```

Design the completion flow so failures are recoverable.

Example:

```text
Validate
↓
Save Appearance
↓
Save Identity Completion
↓
Clear Creation Session
↓
Move Player to Final Spawn
```

---

# 41. Spawn Isolation

Character creation should ideally happen in a controlled routing bucket.

Example:

```text
Player joins creator
        ↓
assign private bucket
        ↓
disable unnecessary population
        ↓
character creation
        ↓
complete
        ↓
return to world bucket
```

This prevents players from:

```text
seeing other creators
being attacked
interfering with creator cameras
having nearby entities affect the scene
```

---

# 42. Entity Lockdown

Because BGRZ targets GTAV Enhanced, the creation routing bucket may use stronger entity lockdown.

Example concept:

```lua
SetRoutingBucketEntityLockdownMode(
    bucketId,
    'strict'
)
```

Potential future Enhanced-specific mode can be evaluated after compatibility testing.

Do not enable aggressive lockdown globally without testing all resources.

---

# 43. Population

Character creation buckets should normally disable population.

Example:

```lua
SetRoutingBucketPopulationEnabled(
    bucketId,
    false
)
```

This gives a predictable creator environment.

---

# 44. Creator Location

Use a controlled creator scene.

Example:

```text
Interior studio
Neutral lighting
Simple background
Fixed environment
No ambient population
```

The scene should prioritize visibility of:

```text
Face
Hair
Clothing
Accessories
```

---

# 45. Camera System

The creator should provide contextual camera presets.

Recommended:

```text
Identity / Overview:
Full Body

Genetics:
Face

Face Features:
Face Close-up

Hair:
Head

Facial Hair:
Face

Details:
Face Close-up

Clothing:
Full Body

Accessories:
Upper Body / Head

Review:
Full Body
```

---

# 46. Camera Controls

Recommended controls:

```text
Rotate character
Zoom
Switch camera preset
Reset camera
```

Avoid free-camera systems that allow players to leave the creator environment.

---

# 47. Preview Without Persistence

Changing creator options must preview them locally.

Do not write SQL every time a slider moves.

### Wrong

```text
player adjusts nose
↓
SQL UPDATE

player adjusts nose
↓
SQL UPDATE

player adjusts nose
↓
SQL UPDATE
```

### Correct

```text
player changes appearance locally
        ↓
preview only
        ↓
final confirmation
        ↓
save
```

---

# 48. Caching

During character creation, maintain draft state client-side.

Example:

```lua
local draft = {
    identity = {},
    appearance = {},
    clothing = {}
}
```

Server receives only data required for:

```text
validation
persistence
completion
```

Do not continuously synchronize every slider through network events.

---

# 49. Disconnect During Creation

If the player disconnects before finishing:

```text
creation_completed remains false
```

On next login:

```text
character creation resumes/restarts
```

The player must not enter the normal world with an incomplete identity.

---

# 50. Resource Restart

The resource must handle:

```text
bgrz_identity restart
```

without permanently trapping players.

On restart:

```text
rebuild runtime state when possible
or
allow incomplete players to restart creation safely
```

Never depend exclusively on in-memory state for permanent progress.

---

# 51. Existing Characters

During initial development, existing Qbox characters may not have a `bgrz_identity` row.

Migration behavior should be configurable.

Possible development mode:

```lua
return {
    treatExistingCharactersAsCompleted = true
}
```

This prevents the creator from forcing every existing test character through onboarding.

Production can use stricter rules.

---

# 52. Suggested Shared Config

```lua
return {
    minimumAge = 18,

    identity = {
        firstNameMin = 2,
        firstNameMax = 24,

        lastNameMin = 2,
        lastNameMax = 24
    },

    creator = {
        allowTattoos = false,

        allowProps = true,

        allowMakeup = true,

        allowFacialHair = true
    }
}
```

---

# 53. Suggested Server Config

```lua
return {
    debug = true,

    existingCharactersCompleted = true,

    creatorBucket = {
        enabled = true,

        population = false,

        lockdown = 'strict'
    }
}
```

---

# 54. Suggested Client Config

```lua
return {
    creatorLocation = vec4(
        402.9,
        -996.7,
        -99.0,
        180.0
    ),

    cameras = {
        body = {},
        face = {},
        head = {}
    }
}
```

Exact coordinates and camera configuration should be decided during implementation.

---

# 55. Public Server API

Initial proposed exports:

```lua
exports('IsCreationComplete', function(source)
end)

exports('GetIdentityState', function(source)
end)
```

Potential future exports:

```lua
GetStateId
GetLegalIdentity
CanChangeName
CanUsePlasticSurgeon
```

Only expose APIs that another resource actually needs.

---

# 56. Events

Recommended network event naming:

```text
bgrz_identity:server:startCreation
bgrz_identity:server:submitIdentity
bgrz_identity:server:completeCreation

bgrz_identity:client:startCreator
bgrz_identity:client:creationCompleted
```

Avoid exposing dozens of small network events.

---

# 57. Internal Events

Useful local events may include:

```text
bgrz_identity:creationStarted
bgrz_identity:creationCompleted
```

Other BGRZ resources can react to creation completion without requiring network traffic.

---

# 58. Character Completion Event

Future example:

```lua
AddEventHandler(
    'bgrz_identity:creationCompleted',
    function(source, citizenId)
        -- other server-side systems may react
    end
)
```

Possible consumers:

```text
bgrz_documents
bgrz_economy
bgrz_government
bgrz_phone
```

---

# 59. Initial Character Package

Do not implement this directly inside identity unless required.

Future onboarding could use another resource to grant:

```text
State ID
Starter phone
Basic clothing
Small amount of cash
Transit pass
```

`bgrz_identity` should emit completion.

Another system may handle starter packages.

---

# 60. Security

Every network input must be considered untrusted.

Validate:

```text
type
length
range
current character
session
creation state
allowed step
allowed option
```

Never trust:

```text
citizenId
permission
completion status
special clothing access
```

received from the client.

---

# 61. Hard RP Rules

The character creator should reinforce permanence.

Initial creation allows substantial customization.

After creation:

```text
Hair
→ barber

Clothing
→ clothing store

Tattoos
→ tattoo shop

Face surgery
→ plastic surgeon

Legal name
→ government / court process
```

Do not allow `/skin` as a normal player command.

---

# 62. Administrative Appearance

Admins may require a separate restricted command for support/debugging.

Example:

```text
/bgrzappearance <playerId>
```

This must:

```text
require ACE permission
create audit log
not be available to normal players
```

Do not reuse normal player permissions for administrative editing.

---

# 63. Logging

Important identity events should be auditable.

Examples:

```text
identity.character_created

identity.creation_started

identity.creation_completed

identity.name_changed

identity.admin_appearance_opened
```

Example log:

```lua
{
    action = 'identity.creation_completed',

    citizenId = 'ABC12345',

    source = 42,

    timestamp = os.time()
}
```

---

# 64. Do Not Log Sensitive Noise

Do not log:

```text
every slider movement
every camera movement
every hair preview
```

Log meaningful state transitions.

---

# 65. Performance

The creator should avoid:

```text
SQL during slider movement

server events every frame

Wait(0) loops performing heavy logic

repeated rebuilding of all appearance options
```

Use:

```text
local preview
cached option counts
events
creator state
```

---

# 66. Dynamic Appearance Options

Available hair, clothing and props should be obtained dynamically when possible.

Do not maintain giant hardcoded arrays such as:

```lua
Config.Hair = {
    0,
    1,
    2,
    3,
    ...
}
```

This is fragile across:

```text
male/female models
DLC
Enhanced updates
custom clothing
different game builds
```

---

# 67. Invalid Drawable Protection

Before applying a component or prop:

```text
validate drawable
validate texture
validate slot
```

An invalid combination should:

```text
fallback safely
```

rather than crash or leave an invisible component.

---

# 68. Save Format

Appearance persistence should remain owned by the appearance engine initially.

`bgrz_identity` should not duplicate the full appearance JSON.

Persist only identity-domain state.

Example:

```text
Qbox
→ character identity base

Illenium
→ appearance

BGRZ Identity
→ creation state and BGRZ identity metadata
```

---

# 69. UI Goals

The creator UI should feel:

```text
clean
minimal
cinematic
easy to understand
Hard RP oriented
```

Avoid a giant developer-style menu.

Prefer:

```text
step-by-step navigation
clear categories
large preview
simple sliders
Back
Next
Confirm
```

---

# 70. UI Navigation

Suggested layout:

```text
┌─────────────────────────────┐
│ BGRZ Character Creation     │
│                             │
│  Genetics                   │
│                             │
│ Father     [  12  ]         │
│ Mother     [  21  ]         │
│ Face Mix   ─────●────       │
│ Skin Mix   ───●──────       │
│                             │
│ Back                Next    │
└─────────────────────────────┘
```

The ped remains visible behind or beside the UI.

---

# 71. Review Screen

Before completion, show a final review.

Identity:

```text
John Michael Smith
May 23, 1994
United States
```

Appearance:

```text
360° character preview
```

Actions:

```text
Back
Confirm Character
```

Require explicit confirmation before permanence.

---

# 72. Confirmation Warning

The user should understand that some choices will later require in-world services to change.

Example message:

```text
Once your character is created, major facial features
and identity information cannot be freely changed.

Hair, clothing and other cosmetic options can be changed
through in-world businesses.
```

Do not use threatening or excessive confirmation dialogs.

---

# 73. Version 0.1 Scope

Implement only:

* [ ] Resource structure.
* [ ] Qbox integration.
* [ ] `bgrz_core` integration.
* [ ] `bgrz_identity` SQL table.
* [ ] Character creation completion state.
* [ ] Private creation routing bucket.
* [ ] Identity validation.
* [ ] Illenium appearance integration wrapper.
* [ ] Genetics configuration.
* [ ] Face features.
* [ ] Hair.
* [ ] Facial hair.
* [ ] Head overlays.
* [ ] Initial clothing.
* [ ] Props.
* [ ] Final confirmation.
* [ ] Save appearance.
* [ ] Save creation completion.
* [ ] Return player to normal world.

---

# 74. Version 0.2

Potential next scope:

* [ ] State ID generation.
* [ ] Identity document.
* [ ] Better onboarding scene.
* [ ] Custom NUI.
* [ ] Character photo.
* [ ] Government identity record.
* [ ] Name change support.
* [ ] Audit integration.
* [ ] Admin support commands.

---

# 75. Version 0.3

Future:

```text
Barber integration

Plastic surgery

Legal name changes

Government records

Driver licenses

Professional licenses

Passport-style identity

Character signatures
```

These may become separate BGRZ resources if their domains grow.

---

# 76. Definition of Done

`bgrz_identity` version 0.1 is considered complete when:

* [x] No Qbox resource was modified.
* [ ] Existing Qbox character lifecycle still works.
* [ ] New character enters creator.
* [x] Creator runs in isolated bucket.
* [x] Population is disabled in creator.
* [x] Identity is validated server-side.
* [x] Appearance uses Illenium.
* [x] Hair uses correct component slot.
* [x] Facial hair uses head overlays.
* [x] Clothing uses correct component slots.
* [x] Accessories use correct prop slots.
* [x] Appearance options are dynamically validated.
* [x] Client cannot complete someone else's character.
* [x] Client cannot forge `citizenId`.
* [x] Character cannot enter world before completion.
* [x] Disconnect before completion is handled safely.
* [x] Resource restart is handled safely.
* [ ] Appearance persists after reconnect.
* [x] Identity completion persists after reconnect.
* [x] Existing test characters can be handled through migration config.
* [x] No SQL query runs on appearance slider updates.
* [x] No unnecessary `Wait(0)` loops exist.
* [ ] Code works on FiveM GTAV Enhanced.

---

# 77. Implementation Order

Implement in this exact order:

```text
STEP 1

Create resource
        ↓
Dependencies
        ↓
SQL
        ↓
Get character through bgrz_core


STEP 2

Creation completion state
        ↓
IsCreationComplete()
        ↓
existing character migration behavior


STEP 3

Creation routing bucket
        ↓
population disabled
        ↓
safe creator scene


STEP 4

Illenium abstraction
        ↓
read appearance
        ↓
apply appearance
        ↓
save appearance


STEP 5

Identity form
        ↓
server validation


STEP 6

Genetics
        ↓
face
        ↓
hair
        ↓
facial hair
        ↓
details


STEP 7

Initial clothing
        ↓
props


STEP 8

Review screen
        ↓
confirmation


STEP 9

save appearance
        ↓
mark identity complete
        ↓
leave creator bucket


STEP 10

reconnect tests
        ↓
restart tests
        ↓
security tests
```

---

# 78. Final Architecture Rule

Always preserve this responsibility flow:

```text
CLIENT
Player selects appearance
        │
        ▼
Illenium
Previews ped appearance
        │
        ▼
bgrz_identity
Controls creation workflow
        │
        ▼
SERVER
Validates identity
        │
        ▼
Qbox
Owns base character
        │
        ▼
Database
Persists domain state
```

And:

```text
Qbox = framework foundation

bgrz_core = BGRZ shared abstraction

bgrz_identity = character identity rules

illenium-appearance = appearance engine
```

Do not mix these responsibilities without a clear reason.
