# BGRZ Identity UI

## Overview

This document defines the visual, technical and integration architecture for the custom **BGRZ Character Creator**.

The goal is to create a completely custom user experience without rewriting the GTA appearance engine and without modifying the existing `illenium-appearance` NUI.

Target stack:

```text
FiveM GTAV Enhanced
Qbox
bgrz_core
bgrz_identity
illenium-appearance
ox_lib
React
TypeScript
Vite
```

The final architecture should be:

```text
Qbox
  │
  ▼
bgrz_identity
  │
  ├── Character workflow
  ├── Identity validation
  ├── Creator session
  ├── Camera
  ├── Routing bucket
  └── BGRZ NUI
          │
          ▼
   Appearance Adapter
          │
          ▼
  illenium-appearance
          │
          ▼
       GTA Ped
```

---

# 1. Main Rule

The BGRZ creator must **not use the Illenium NUI**.

The Illenium resource remains installed and continues to provide the appearance engine.

We use its exported functions to manipulate:

```text
Ped model
Head blend
Face features
Head overlays
Hair
Eye color
Clothing components
Props
Tattoos
Appearance
```

The BGRZ NUI owns:

```text
Layout
Navigation
Forms
Sliders
Color selectors
Preview controls
Camera controls
Step management
User experience
Brand identity
```

---

# 2. Do Not Modify Illenium Web UI

Do not modify:

```text
illenium-appearance/web/
```

Do not modify:

```text
illenium-appearance/web/dist/
```

Do not rebuild or reskin the Illenium interface.

This avoids maintaining a permanent fork of its frontend.

The existing Illenium UI may still be used later for compatibility/debugging if required.

---

# 3. Integration Strategy

Instead of:

```text
bgrz_identity
      │
      ▼
startPlayerCustomization()
      │
      ▼
Illenium NUI
```

use:

```text
BGRZ NUI
   │
   ▼
bgrz_identity client
   │
   ▼
Appearance Adapter
   │
   ▼
Illenium exports
   │
   ▼
GTA Ped
```

Important:

```text
DO NOT call:
exports['illenium-appearance']:startPlayerCustomization()
```

for the BGRZ creator.

That function opens the Illenium NUI.

---

# 4. Appearance Adapter

Create:

```text
client/
└── appearance.lua
```

All Illenium interaction must be isolated here.

Example:

```lua
local Appearance = {}

function Appearance.get()
    return exports['illenium-appearance']:getPedAppearance(
        PlayerPedId()
    )
end

function Appearance.setModel(model)
    exports['illenium-appearance']:setPlayerModel(model)
end

function Appearance.setHeadBlend(data)
    exports['illenium-appearance']:setPedHeadBlend(
        PlayerPedId(),
        data
    )
end

function Appearance.setFaceFeatures(data)
    exports['illenium-appearance']:setPedFaceFeatures(
        PlayerPedId(),
        data
    )
end

function Appearance.setHeadOverlays(data)
    exports['illenium-appearance']:setPedHeadOverlays(
        PlayerPedId(),
        data
    )
end

function Appearance.setHair(data)
    exports['illenium-appearance']:setPedHair(
        PlayerPedId(),
        data
    )
end

function Appearance.setEyeColor(color)
    exports['illenium-appearance']:setPedEyeColor(
        PlayerPedId(),
        color
    )
end

function Appearance.setComponent(component)
    exports['illenium-appearance']:setPedComponent(
        PlayerPedId(),
        component
    )
end

function Appearance.setProp(prop)
    exports['illenium-appearance']:setPedProp(
        PlayerPedId(),
        prop
    )
end

function Appearance.apply(data)
    exports['illenium-appearance']:setPedAppearance(
        PlayerPedId(),
        data
    )
end

return Appearance
```

No other `bgrz_identity` file should directly depend on Illenium.

---

# 5. Why Use an Adapter

This protects BGRZ from changes in the appearance resource.

Today:

```text
bgrz_identity
      ↓
illenium-appearance
```

Future:

```text
bgrz_identity
      ↓
Appearance Adapter
      ↓
Another appearance engine
```

Only:

```text
appearance.lua
```

would need to change.

The BGRZ UI remains untouched.

---

# 6. First Character Integration

There is one special consideration.

The default Qbox character flow eventually triggers:

```text
qb-clothes:client:CreateFirstCharacter
```

Illenium listens to this event and opens its own character creator.

Therefore BGRZ must replace that **creation entry point**.

The Illenium NUI itself does not need to be changed.

---

# 7. Phase 1 Integration

For the initial implementation:

```text
Qbox Multicharacter
        │
        ▼
New Character
        │
        ▼
Qbox creates character
        │
        ▼
BGRZ integration bridge
        │
        ▼
bgrz_identity
        │
        ▼
BGRZ Creator
```

Keep the Qbox multicharacter system.

Replace only the first appearance creator invocation.

---

# 8. Minimal Compatibility Patch

If a small Illenium integration patch is required, it must:

* not touch the Illenium NUI;
* not touch appearance implementation;
* not touch database code;
* not touch clothing stores;
* not touch barber shops;
* not touch tattoo shops;
* only redirect first-character creation.

Conceptually:

```lua
RegisterNetEvent(
    'qb-clothes:client:CreateFirstCharacter',
    function()
        if GetResourceState('bgrz_identity') == 'started' then
            TriggerEvent(
                'bgrz_identity:client:startCreator'
            )

            return
        end

        InitializeCharacter(
            Framework.GetGender(true)
        )
    end
)
```

This is the only type of upstream patch allowed during Phase 1.

Document the patch separately.

---

# 9. Long-Term Architecture

Eventually BGRZ should own the complete character UX.

Qbox supports external character management.

Future architecture:

```text
qbx_core

characters.useExternalCharacters = true
             │
             ▼
       bgrz_identity
             │
     ┌───────┴────────┐
     │                │
Character Select   Character Create
     │                │
     └───────┬────────┘
             ▼
       BGRZ Creator
```

At that point no Illenium integration patch should be required.

---

# 10. Resource Structure

Recommended structure:

```text
bgrz_identity/
├── fxmanifest.lua
│
├── config/
│   ├── shared.lua
│   ├── client.lua
│   └── server.lua
│
├── client/
│   ├── main.lua
│   ├── creator.lua
│   ├── appearance.lua
│   ├── camera.lua
│   └── nui.lua
│
├── server/
│   ├── main.lua
│   ├── creator.lua
│   ├── identity.lua
│   └── storage.lua
│
├── shared/
│   ├── constants.lua
│   └── validation.lua
│
└── web/
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    │
    └── src/
        ├── App.tsx
        ├── main.tsx
        │
        ├── components/
        ├── features/
        ├── hooks/
        ├── stores/
        ├── styles/
        └── types/
```

---

# 11. Frontend Architecture

Recommended:

```text
React
TypeScript
Vite
```

State management should initially use:

```text
React Context
```

or a lightweight store such as:

```text
Zustand
```

Do not introduce Redux unless complexity justifies it.

---

# 12. UI Architecture

```text
App
 │
 ├── CreatorLayout
 │
 │    ├── Sidebar
 │
 │    ├── StepHeader
 │
 │    ├── StepContent
 │
 │    ├── Navigation
 │
 │    └── Footer
 │
 │
 └── CreatorSteps
      ├── Identity
      ├── Genetics
      ├── Face
      ├── Hair
      ├── Details
      ├── Clothing
      ├── Accessories
      └── Review
```

---

# 13. Visual Direction

The BGRZ UI must feel:

```text
Premium
Institutional
Urban
Cinematic
Minimal
Serious
Modern
American
Hard RP oriented
```

It must NOT look like:

```text
Generic Qbox
Generic ox_lib
Purple gaming UI
Cyberpunk
Neon dashboard
Mobile game
Cheap FiveM NUI
```

---

# 14. Brand Personality

The interface should communicate:

```text
SERIOUS ROLEPLAY
IDENTITY
PERMANENCE
PROFESSIONALISM
WORLD BUILDING
```

The user should feel that they are creating a person who belongs to the world, not configuring a GTA skin.

---

# 15. Color Palette

Primary background:

```css
--bgrz-bg: #101214;
```

Secondary background:

```css
--bgrz-surface: #171A1D;
```

Elevated surface:

```css
--bgrz-surface-raised: #1D2125;
```

Border:

```css
--bgrz-border: #2B3035;
```

Primary text:

```css
--bgrz-text: #F2F2F0;
```

Secondary text:

```css
--bgrz-text-muted: #9CA3A9;
```

Primary accent:

```css
--bgrz-accent: #D6A84B;
```

Accent hover:

```css
--bgrz-accent-hover: #E0B65F;
```

Danger:

```css
--bgrz-danger: #B94A48;
```

Success:

```css
--bgrz-success: #648B6B;
```

---

# 16. CSS Tokens

Create:

```text
web/src/styles/tokens.css
```

Example:

```css
:root {
    --bgrz-bg: #101214;

    --bgrz-surface: #171a1d;

    --bgrz-surface-raised: #1d2125;

    --bgrz-border: #2b3035;

    --bgrz-text: #f2f2f0;

    --bgrz-text-muted: #9ca3a9;

    --bgrz-accent: #d6a84b;

    --bgrz-danger: #b94a48;

    --bgrz-success: #648b6b;

    --bgrz-radius-sm: 4px;

    --bgrz-radius-md: 6px;

    --bgrz-radius-lg: 8px;

    --bgrz-transition-fast: 120ms;

    --bgrz-transition-normal: 180ms;
}
```

---

# 17. Avoid Excessive Radius

Do not use:

```css
border-radius: 20px;
```

everywhere.

Recommended:

```text
Input       4px
Button      4px
Panel       6px
Modal       8px
```

The interface should feel precise and structured.

---

# 18. Typography

Recommended UI font:

```text
Inter
Geist
IBM Plex Sans
```

Recommended display/title font:

```text
Barlow Condensed
Archivo
```

Suggested hierarchy:

```text
BGRZ

CHARACTER CREATION

IDENTITY

FIRST NAME

John
```

Titles may use:

```text
uppercase
letter spacing
condensed font
```

Regular content should prioritize readability.

---

# 19. Iconography

Use one icon system.

Recommended:

```text
Lucide
```

Do not mix:

```text
Font Awesome
Material Icons
Emoji
Random SVGs
```

unless there is a technical reason.

---

# 20. Main Layout

Target layout:

```text
┌───────────────┬───────────────────────┬──────────────────────┐
│               │                       │                      │
│     BGRZ      │ CHARACTER CREATION    │                      │
│               │                       │                      │
│ 01 IDENTITY   │ IDENTITY              │                      │
│               │                       │                      │
│ 02 GENETICS   │ First Name            │                      │
│               │ [____________]        │                      │
│ 03 FACE       │                       │       CHARACTER      │
│               │ Last Name             │                      │
│ 04 HAIR       │ [____________]        │        PREVIEW       │
│               │                       │                      │
│ 05 DETAILS    │ Date of Birth         │                      │
│               │ [____________]        │                      │
│ 06 CLOTHING   │                       │                      │
│               │ Nationality           │                      │
│ 07 ACCESS.    │ [____________]        │                      │
│               │                       │                      │
│ 08 REVIEW     │ BACK      CONTINUE    │                      │
│               │                       │                      │
└───────────────┴───────────────────────┴──────────────────────┘
```

Target proportions:

```text
Sidebar:        16%
Creator panel:  26%
Game preview:   58%
```

The player model should remain the visual focus.

---

# 21. Sidebar

Example:

```text
BGRZ
ROLEPLAY REDEFINED


01   IDENTITY

02   GENETICS

03   FACE

04   HAIR

05   DETAILS

06   CLOTHING

07   ACCESSORIES

08   REVIEW
```

Active state:

```text
│ 01   IDENTITY
```

using:

```text
gold border
gold number
gold label
```

Inactive steps remain muted.

---

# 22. Step Header

Example:

```text
CHARACTER CREATION

01 / 08


IDENTITY
```

Description:

```text
This is your identity.

Choose your details carefully.
They shape your story in BGRZ.
```

---

# 23. Identity Screen

Fields:

```text
FIRST NAME

LAST NAME

DATE OF BIRTH

SEX

NATIONALITY
```

Example:

```text
FIRST NAME

┌─────────────────────────────────┐
│ Enter first name                │
└─────────────────────────────────┘
```

---

# 24. Input Design

Inputs should use:

```text
dark background
thin border
4px radius
subtle focus accent
clear labels
```

Default:

```css
border: 1px solid var(--bgrz-border);
```

Focused:

```css
border-color: var(--bgrz-accent);
```

Do not use excessive box shadows.

---

# 25. Buttons

Primary:

```text
CONTINUE →
```

Secondary:

```text
← BACK
```

Primary example:

```css
background: var(--bgrz-accent);
color: #101214;
```

Secondary:

```css
background: transparent;
border: 1px solid var(--bgrz-border);
```

---

# 26. Genetics Screen

Layout:

```text
GENETICS

HERITAGE

Father
<   12 / 46   >

Mother
<   24 / 46   >


FACE RESEMBLANCE

Father ─────────●──── Mother


SKIN TONE

Father ──────●─────── Mother
```

Camera:

```text
FACE
```

---

# 27. Face Screen

Categories:

```text
Nose

Eyebrows

Cheeks

Eyes

Lips

Jaw

Chin
```

Avoid showing 20 sliders simultaneously.

Use collapsible groups.

Example:

```text
NOSE

Width
Narrow ──────●──── Wide

Height
Down   ───●─────── Up

Length
Short  ─────●───── Long
```

---

# 28. Slider Design

Do not expose native values.

Avoid:

```text
Nose Width: -0.283729
```

Show:

```text
NARROW      ─────●──────      WIDE
```

Optional human-readable numeric value:

```text
+18
```

---

# 29. Hair Screen

Layout:

```text
HAIR

STYLE

      12 / 47

   ←           →


PRIMARY COLOR

● ● ● ● ● ● ● ●
● ● ● ● ● ● ● ●


HIGHLIGHT

● ● ● ● ● ● ● ●
```

The GTA character is the preview.

Do not show:

```text
Drawable ID 12
Texture ID 0
Color ID 18
```

to players.

---

# 30. Hair Integration

Hair changes should result in:

```text
NUI
 ↓
bgrz_identity NUI callback
 ↓
Appearance.setHair()
 ↓
Illenium export
 ↓
Ped update
```

No SQL.

No server event.

No appearance save.

Until final confirmation.

---

# 31. Details Screen

Categories:

```text
Facial Hair

Eyebrows

Eyes

Ageing

Complexion

Sun Damage

Freckles

Makeup
```

Example:

```text
FACIAL HAIR

Style
<   08 / 29   >

Opacity
0% ───────●──────── 100%

Color
● ● ● ● ● ● ●
```

---

# 32. Clothing Screen

Initial character creator should show limited clothing.

Categories:

```text
TOP

UNDERSHIRT

PANTS

SHOES

JACKET
```

Do not expose:

```text
Police clothing
EMS clothing
Armor
Restricted clothing
Job uniforms
```

---

# 33. Clothing Navigation

Initial implementation can use:

```text
<  Previous

Item preview

Next  >
```

Example:

```text
TOP

←        24 / 183        →
```

Later we can generate visual thumbnails.

---

# 34. Accessories Screen

Categories:

```text
Hat

Glasses

Ear Accessory

Watch

Bracelet
```

Each category must support:

```text
NONE
```

---

# 35. Review Screen

Final screen:

```text
REVIEW CHARACTER


JOHN HOLLOWAY

Male

May 23, 1994

United States


[ CHARACTER PREVIEW ]


← MAKE CHANGES


CREATE CHARACTER →
```

---

# 36. Final Confirmation

Before creation:

```text
CREATE THIS CHARACTER?
```

Message:

```text
Major identity and facial characteristics
cannot be freely changed after creation.

Hair, clothing and other cosmetic options
can be changed through services in the world.
```

Actions:

```text
GO BACK

CREATE CHARACTER
```

---

# 37. Camera System

Do not use the Illenium NUI camera implementation directly.

Create:

```text
client/camera.lua
```

Camera presets:

```lua
local presets = {
    body = {},
    upperBody = {},
    face = {},
    head = {}
}
```

---

# 38. Camera Per Step

```text
Identity
→ body

Genetics
→ face

Face
→ face close-up

Hair
→ head

Details
→ face

Clothing
→ body

Accessories
→ upper body

Review
→ body
```

---

# 39. Camera Transitions

Transitions:

```text
150–300 ms
```

Smooth interpolation.

Avoid:

```text
instant teleporting camera
dramatic spinning camera
cinematic effects every click
```

---

# 40. Character Rotation

Controls:

```text
Mouse drag

A / D

← / →
```

Rotation should affect the ped, not create a free camera.

---

# 41. Preview Environment

Target environment:

```text
Dark studio

Concrete walls

Soft neutral lighting

Subtle warm floor lights

BGRZ branding

Minimal furniture

Los Santos skyline optional
```

The environment must not compete visually with the character.

---

# 42. Creator Location

Use an isolated interior or controlled scene.

Requirements:

```text
No NPC population

No players

No vehicles

No ambient combat

Predictable lighting

Predictable weather
```

Use a routing bucket.

---

# 43. NUI Communication

Example frontend helper:

```ts
export async function fetchNui<T>(
    event: string,
    data?: unknown
): Promise<T> {
    const resource = (
        window as any
    ).GetParentResourceName?.();

    const response = await fetch(
        `https://${resource}/${event}`,
        {
            method: 'POST',

            headers: {
                'Content-Type': 'application/json',
            },

            body: JSON.stringify(data ?? {}),
        },
    );

    return response.json();
}
```

---

# 44. NUI Callbacks

Recommended callbacks:

```text
bgrz_identity:getState

bgrz_identity:setModel

bgrz_identity:setHeadBlend

bgrz_identity:setFaceFeature

bgrz_identity:setHair

bgrz_identity:setHeadOverlay

bgrz_identity:setEyeColor

bgrz_identity:setComponent

bgrz_identity:setProp

bgrz_identity:setCamera

bgrz_identity:rotatePed

bgrz_identity:submitIdentity

bgrz_identity:complete

bgrz_identity:cancel
```

---

# 45. Example Hair Callback

```lua
RegisterNUICallback(
    'bgrz_identity:setHair',
    function(data, cb)
        Appearance.setHair({
            style = data.style,
            texture = data.texture,
            color = data.color,
            highlight = data.highlight
        })

        cb({
            success = true
        })
    end
)
```

---

# 46. Face Preview

Face feature changes should remain client-side.

Example:

```text
React Slider
      ↓
NUI callback
      ↓
Lua
      ↓
setPedFaceFeatures
      ↓
ped
```

No server involvement is required for preview.

---

# 47. Draft Appearance

At creator start:

```lua
local originalAppearance =
    Appearance.get()
```

Maintain:

```lua
local draftAppearance =
    Appearance.get()
```

Changes modify the draft/ped.

---

# 48. Cancel

If creation can be cancelled:

```text
Cancel
  ↓
Appearance.apply(originalAppearance)
  ↓
close NUI
```

For mandatory new-character creation:

```text
Cancel
```

may be disabled entirely.

---

# 49. Saving

Only save once the player confirms.

Flow:

```text
CREATE CHARACTER
        ↓
BGRZ validates creator session
        ↓
Get actual ped appearance
        ↓
Persist appearance
        ↓
Mark identity completed
        ↓
Close creator
        ↓
Leave routing bucket
        ↓
Spawn / onboarding
```

---

# 50. Important Save Rule

The final appearance should be read from the actual ped.

Prefer:

```lua
local appearance =
    exports['illenium-appearance']:getPedAppearance(
        PlayerPedId()
    )
```

Do not trust a large appearance object sent from React as the final source of truth.

---

# 51. Do Not Persist UI State as Appearance

Wrong:

```text
React state
   ↓
SQL
```

Correct:

```text
React action
   ↓
Ped
   ↓
Illenium appearance reader
   ↓
Save
```

The ped becomes the authoritative final appearance snapshot.

---

# 52. Identity Validation

Identity form:

```text
NUI
 ↓
client
 ↓
server
 ↓
validate
```

Server validates:

```text
First name

Last name

Date of birth

Nationality

Sex
```

Never trust frontend validation only.

---

# 53. Performance

Do not send network traffic while sliders move.

Good:

```text
Slider
 ↓
NUI callback
 ↓
local client native/export
```

Bad:

```text
Slider
 ↓
server event
 ↓
server
 ↓
client event
 ↓
ped
```

---

# 54. Slider Throttling

For very frequent UI input:

```text
16–50 ms
```

throttling may be used.

Do not queue hundreds of appearance updates.

---

# 55. No SQL During Preview

Never:

```text
change hair
→ SQL

change nose
→ SQL

change beard
→ SQL
```

Only persist:

```text
final confirmation
```

---

# 56. Responsive Target

Primary target:

```text
1920 × 1080
```

Must also remain usable at:

```text
2560 × 1440

3440 × 1440

3840 × 2160
```

Do not position the entire UI with hardcoded pixel coordinates.

---

# 57. Ultrawide

For ultrawide:

```text
UI remains anchored left

Character remains visually centered

Preview environment expands

UI does not stretch
```

Use maximum panel widths.

---

# 58. Motion

Recommended durations:

```text
Hover:
120 ms

Input focus:
120 ms

Panel:
180 ms

Step transition:
180–220 ms

Camera:
200–300 ms
```

Avoid:

```text
bounce

large zoom effects

excessive blur

glow pulse
```

---

# 59. Sound

Optional later:

```text
subtle hover

subtle click

step transition
```

Do not use loud UI sounds.

Version 0.1 does not require custom audio.

---

# 60. BGRZ Branding

Top-left:

```text
BGRZ

ROLEPLAY REDEFINED
```

Alternative final tagline can be decided later.

Footer may display:

```text
BGRZ • HARD RP • SERIOUS ROLEPLAY
```

Avoid excessive logo repetition.

---

# 61. Brand Mark

The BGRZ monogram should support:

```text
Primary logo

Small icon

Watermark

Floor emblem

Document seal
```

The same mark can later appear in:

```text
Government UI

Business documents

Identity documents

Loading screen
```

---

# 62. Shared Design System

Initially keep components inside:

```text
bgrz_identity/web/
```

Once at least two major BGRZ NUIs exist, extract shared components.

Potential future structure:

```text
bgrz_ui
```

or frontend package:

```text
@bgrz/ui
```

Shared:

```text
Button

Input

Select

Slider

Modal

Tabs

Badge

Tooltip

Sidebar

Typography

Tokens

Icons
```

---

# 63. Do Not Prematurely Build bgrz_ui

Version 0.1:

```text
build components in bgrz_identity
```

After:

```text
bgrz_identity
+
bgrz_business
```

identify truly reusable components.

Then extract.

Avoid building a huge design system before we know what we need.

---

# 64. Illenium Responsibilities After BGRZ UI

Illenium may continue handling:

```text
Appearance persistence

Appearance loading

Clothing stores

Barber shops

Tattoo shops

Plastic surgeon

Outfits
```

initially.

BGRZ only replaces:

```text
INITIAL CHARACTER CREATOR UI
```

This keeps scope controlled.

---

# 65. Future Phase

Later we may also replace:

```text
Illenium Barber NUI

Illenium Clothing NUI

Illenium Tattoo NUI
```

with BGRZ interfaces.

The appearance engine can remain Illenium.

Architecture:

```text
BGRZ Barber UI ───────┐

BGRZ Clothing UI ─────┤

BGRZ Tattoo UI ───────┼── Appearance Adapter
                      │
BGRZ Creator UI ──────┘
                           │
                           ▼
                  illenium-appearance
```

---

# 66. Migration Path

## Phase 1

```text
Qbox multicharacter
+
BGRZ character creator
+
Illenium engine
```

---

## Phase 2

```text
BGRZ creator

BGRZ barber UI

BGRZ clothing UI
```

---

## Phase 3

```text
BGRZ external character manager

BGRZ character selection

BGRZ creator

BGRZ complete identity experience
```

---

# 67. Version 0.1 Scope

Implement:

* [x] BGRZ NUI shell.
* [x] Design tokens.
* [x] Sidebar.
* [x] Step navigation.
* [x] Identity screen.
* [x] Appearance adapter.
* [x] Camera system.
* [x] Genetics screen.
* [x] Face screen.
* [x] Hair screen.
* [x] Details screen.
* [x] Clothing screen.
* [x] Accessories screen.
* [x] Review screen.
* [x] Ped rotation.
* [x] Routing bucket.
* [x] Final appearance save.
* [x] Identity completion.
* [x] Qbox first-character integration.
* [ ] 1080p testing.
* [ ] 1440p testing.
* [ ] Ultrawide testing.

---

# 68. Explicit Non-Goals

Version 0.1 will NOT:

* [ ] Replace Illenium clothing stores.
* [ ] Replace Illenium barber shops.
* [ ] Replace Illenium tattoo shops.
* [ ] Replace Illenium persistence.
* [ ] Replace Qbox multicharacter.
* [ ] Create a complete `bgrz_ui` framework.
* [ ] Generate clothing thumbnails.
* [ ] Implement plastic surgery.
* [ ] Implement custom clothing packs.
* [ ] Implement identity documents.

---

# 69. Definition of Done

The BGRZ Character Creator is complete when:

* [x] Illenium NUI was not modified.
* [x] `qbx_core` was not modified.
* [x] BGRZ has its own NUI.
* [x] New characters open the BGRZ creator.
* [x] Illenium's creator does not appear simultaneously.
* [x] Existing Illenium appearance engine is reused.
* [x] Hair works.
* [x] Facial hair works.
* [x] Head blend works.
* [x] Face features work.
* [x] Head overlays work.
* [x] Eye color works.
* [x] Clothing works.
* [x] Props work.
* [x] Camera presets work.
* [x] Ped rotation works.
* [x] Identity validation is server-side.
* [x] Preview does not write SQL.
* [x] Final appearance is read from the ped.
* [ ] Appearance persists after reconnect.
* [x] Creation state persists.
* [x] Disconnect during creation is safe.
* [x] Resource restart is safe.
* [ ] UI works at 1080p.
* [ ] UI works at 1440p.
* [ ] UI works on ultrawide.
* [x] UI visually matches the BGRZ design direction.

---

# 70. Implementation Order

Implement in this order:

```text
01
Create React/Vite NUI shell
        ↓
02
Implement BGRZ visual tokens
        ↓
03
Implement sidebar/layout
        ↓
04
Implement NUI ↔ Lua communication
        ↓
05
Create Appearance Adapter
        ↓
06
Implement camera
        ↓
07
Implement Identity screen
        ↓
08
Implement Genetics
        ↓
09
Implement Face
        ↓
10
Implement Hair
        ↓
11
Implement Details
        ↓
12
Implement Clothing
        ↓
13
Implement Accessories
        ↓
14
Implement Review
        ↓
15
Implement final save
        ↓
16
Integrate first-character flow
        ↓
17
Reconnect/restart tests
        ↓
18
Enhanced testing
```

---

# 71. Final Architecture

The target architecture is:

```text
                 qbx_core
                    │
                    ▼
                bgrz_core
                    │
                    ▼
              bgrz_identity
                    │
          ┌─────────┴─────────┐
          │                   │
     BGRZ NUI            Creator Logic
          │                   │
          └─────────┬─────────┘
                    │
                    ▼
             Appearance Adapter
                    │
                    ▼
            illenium-appearance
                    │
                    ▼
                GTA PED
```

The fundamental rule is:

```text
BGRZ owns the experience.

Illenium owns the appearance engine.

Qbox owns the character foundation.
```

This gives BGRZ a completely unique visual identity while keeping the underlying ecosystem maintainable.
