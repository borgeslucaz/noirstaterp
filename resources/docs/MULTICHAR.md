CODEX IMPLEMENTATION BRIEF — noir_multichar

1. Objective

Modify the public FiveM resource based on:

https://github.com/AfterLifeStudio/Afterlife_ivmulticharacter2.0

The final resource/package name must be:

noir_multichar

The goal is not to rewrite the multicharacter system from scratch. Preserve the existing character selection, character creation, preview camera, deletion, framework adapters, scene selector, profile image, admin panel, NUI callbacks, and current gameplay behavior wherever possible.

The main work is:

Rebrand the resource to noir_multichar.

Redesign the character-selection NUI into a cleaner, darker, minimal Noir State interface.

Keep the rendered GTA scene, player ped, preview vehicle, camera, animation, weather/time scene logic, and current FiveM flow behind the UI.

Replace the current generic information-icon row with exactly three character information fields:

CASH

JOB

LAST SEEN

Add/normalize the lastSeen value from the character's stored position.

Keep existing character create/play/delete behavior functional.

Build and validate the React/Vite NUI.

This document is the source of truth for the implementation.

2. Current repository architecture to preserve

The upstream resource currently contains:

Framework/
  esx/
  qb/
  qbx/

modules/
  Charactersmenu.lua
  Createmenu.lua
  adminpanel.lua
  loadresource.lua
  logout.lua
  nuicallbacks.lua
  profileimage.lua
  sceneselector.lua

server/
  server.lua

ui/
  src/
    components/
      adminpanel/
      charDetails/
      confirmpage/
      loading/
      profilepicture/
      registeration/
      sceneselector/
    providers/
    store/
    utils/
    App.jsx
    App.css
    index.css
    main.jsx
  package.json
  vite.config.js

fxmanifest.lua
multicharacter.sql
shared.lua

The current NUI is React 18 + Vite and already uses Redux, Tailwind utilities and styled-components.

Do not replace the frontend stack unless there is an unavoidable technical reason.

The current fxmanifest.lua loads:

ox_lib

qbx_core playerdata module

oxmysql

QB, QBX and ESX framework adapters

ui/dist/index.html

The current NUI callbacks include important existing behavior such as:

GetCharacters

playcharacter

PreviewCharacter

CreateCharacter

DeleteCharacter

Preserve these callback contracts unless changing one is absolutely necessary. Prefer changing the normalized character data returned to the frontend rather than changing the underlying play/create/delete protocol.

3. Resource rename

3.1 Final FiveM resource name

The resource directory must be deployable as:

noir_multichar

Do not require the old resource folder name.

Update visible package/resource branding from the old project name to noir_multichar.

Required changes

Update fxmanifest.lua with metadata similar to:

name 'noir_multichar'
author 'Noir State'
description 'Noir State multicharacter selection resource'
version '1.0.0'

Keep the existing:

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

Do not remove framework compatibility declarations or required scripts.

Update the frontend package name in:

ui/package.json

to:

"name": "noir_multichar"

Update lockfile package metadata if the lockfiles contain the old package name.

If safe and not referenced by runtime code, rename:

multicharacter.sql

to:

noir_multichar.sql

Do not rename runtime events only for cosmetic reasons if doing so risks breaking compatibility. Existing internal event names such as legacy IV:*, QB, QBX or ESX events may remain if they are part of the working protocol.

NUI resource resolution

The frontend already resolves its resource dynamically through window.GetParentResourceName().

Preserve this behavior.

Never hardcode:

Afterlife_ivmulticharacter2.0

or:

noir_multichar

inside NUI fetch URLs.

The NUI fetch helper must continue to work regardless of the folder name.

4. Design direction

4.1 Core visual idea

The existing GTA scene must remain the visual focus.

The NUI should feel like a subtle overlay on a cinematic character preview, not like a large web dashboard floating over GTA.

Target style:

minimal

monochrome

cinematic

premium

restrained

modern

readable

dark

serious roleplay aesthetic

no neon

no RPG-style colored stat bars

no large glassmorphism cards

no excessive blur

no oversized glowing buttons

no gradients using bright colors

The screen must keep the same conceptual layout as the original resource:

character identity on the left

game scene visible in the center/right

character selector near the bottom

action to play the selected character

create-new-character slot

settings and delete access

However, clean up the old presentation and make it significantly more deliberate.

5. Target composition

Use the following wireframe as the layout reference.

┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  ◇  NOIR STATE                                                   21:34      │
│     ROLEPLAY                                                       24°C      │
│                                                                             │
│                                                                             │
│  01                                                                         │
│                                                                             │
│  BOB BROWN                                                                  │
│                                                                             │
│  ─────────                                                                  │
│                                                                             │
│  ▣  CASH                                                                    │
│     $1,840                                                                  │
│                                                                             │
│  ▰  JOB                                                                     │
│     UNEMPLOYED                                                              │
│                                                                             │
│  ●  LAST SEEN                                                               │
│     ROCKFORD HILLS                                                          │
│                                                                             │
│  ┌────────────────────────────┐                                             │
│  │ PLAY CHARACTER          →  │                                             │
│  └────────────────────────────┘                                             │
│                                                                             │
│                                                                             │
│                     <   ┌─────────────────────┐  ┌──────────────────────┐  > │
│                         │ 01  BOB BROWN       │  │ +  NEW CHARACTER     │    │
│                         │     CIVILIAN        │  │    CREATE A NEW STORY│    │
│                         └─────────────────────┘  └──────────────────────┘    │
│                                                                             │
│  ⚙ SETTINGS     🗑 DELETE CHARACTER                              01 / 02     │
└─────────────────────────────────────────────────────────────────────────────┘

The actual GTA ped, car and world scene are rendered behind this NUI and must remain unobstructed as much as possible.

6. Screen layers

The character selection screen should have only subtle dark overlays.

6.1 Left readability gradient

Add a left-side gradient that allows white typography to remain readable without drawing a visible rectangular panel.

Recommended direction:

background:
  linear-gradient(
    90deg,
    rgba(3, 5, 7, 0.88) 0%,
    rgba(3, 5, 7, 0.70) 18%,
    rgba(3, 5, 7, 0.28) 34%,
    rgba(3, 5, 7, 0.05) 48%,
    transparent 62%
  );

Do not create an obvious black sidebar rectangle.

6.2 Bottom readability gradient

Add a subtle bottom gradient for the carousel/action area:

linear-gradient(
  0deg,
  rgba(2, 4, 6, 0.70) 0%,
  rgba(2, 4, 6, 0.25) 22%,
  transparent 42%
)

The background scene should remain clearly visible.

6.3 Vignette

A very subtle vignette is acceptable, but do not make the center scene too dark.

7. Color system

Use a nearly monochrome palette.

Suggested tokens:

--noir-white: #F3F3F1;
--noir-text: rgba(243, 243, 241, 0.96);
--noir-muted: rgba(243, 243, 241, 0.56);
--noir-subtle: rgba(243, 243, 241, 0.32);
--noir-border: rgba(255, 255, 255, 0.24);
--noir-border-hover: rgba(255, 255, 255, 0.48);
--noir-surface: rgba(7, 9, 11, 0.48);
--noir-surface-hover: rgba(7, 9, 11, 0.70);
--noir-danger: #C85A5A;

No bright accent color is required.

If an accent is used at all, use it only as a tiny optional detail. The default presentation should look black/white/graphite.

8. Typography

Do not load fonts from Google Fonts or another remote CDN. FiveM NUI should work without external web access.

Prefer an already bundled local font if the project contains one. Otherwise use a safe stack:

font-family:
  Inter,
  "Helvetica Neue",
  Arial,
  sans-serif;

Typography rules:

Branding

NOIR STATE
ROLEPLAY

uppercase

medium/semibold

wide letter spacing

small and understated

Character number

01

12–14 px equivalent

white/muted

tabular numbers if available

Character name

BOB BROWN

34–48 px depending on resolution

uppercase

first and last name on one line where possible

do not use the old layout where surname is a tiny line above the first name

if the name is long, use clamp() or responsive font sizing rather than overflow

Information labels

CASH
JOB
LAST SEEN

11–13 px

uppercase

muted

Information values

$1,840
UNEMPLOYED
ROCKFORD HILLS

13–16 px

semibold

uppercase except formatted currency

9. Noir State branding

Place a small brand block in the upper-left corner.

Example:

◇  NOIR STATE
   ROLEPLAY

Do not make this larger than the character name.

If a Noir State icon/logo asset exists in the repository, use it.

If no logo asset exists, use a minimal inline SVG geometric mark or render only the text.

Do not download third-party logos.

10. Character information panel

10.1 Mandatory information

There are exactly three required character information rows:

CASH

JOB

LAST SEEN

Do not display these old fields in the selection panel:

bank

date of birth

nationality

playtime

residence

armor

health

phone

citizen ID

inventory weight

any other stats

This requirement is strict.

10.2 Explicit rendering

The current UI generically loops over:

Object.keys(character.additionalInfo)

Do not continue using this for the main character detail section.

Render the three required rows explicitly.

Example normalized frontend shape:

{
  id: 1,
  firstname: "Bob",
  lastname: "Brown",
  citizenid: "...",
  emptyslot: false,
  img: "...",
  sex: true,
  additionalInfo: {
    cash: 1840,
    job: "Mechanic",
    lastSeen: "Rockford Hills"
  }
}

Render:

CASH        $1,840
JOB         MECHANIC
LAST SEEN   ROCKFORD HILLS

Do not depend on object-key ordering to select icons.

11. Information row icons

Use a small monochrome icon beside each label/value group:

cash: wallet/card/cash icon

job: briefcase icon

last seen: map pin icon

Do not install a large icon library just for three icons.

Preferred options:

inline SVG components

existing local image assets

a very small reusable local icon component

Icons should use currentColor when SVG is used.

Size approximately:

18–22 px

Opacity around:

0.55–0.70

Do not place each icon in its own outlined square like the current UI.

12. Character name and slot number

The selected character should display:

01
BOB BROWN

The slot number is a small label above the name.

Do not put the slot number inside a circular badge.

The character name should be rendered as a single visual title:

<span className="first-name">BOB</span>
<span className="last-name"> BROWN</span>

It is acceptable to use a subtle weight or opacity difference between first and last name, but they must read as one title.

For an empty slot, the left panel must not pretend there is a player character.

Use:

02
NEW CHARACTER

CREATE A NEW STORY

and replace the play action with a create action or reuse the existing playcharacter behavior for empty slots, since the current Lua callback already routes empty slots to character creation.

13. Play button

Remove the current small centered play icon button.

The primary action must be a rectangular text CTA in the left panel:

PLAY CHARACTER                         →

Approximate visual size:

width: 280–320 px
height: 54–64 px

Style:

transparent/dark surface

1 px subtle border

white text

no heavy radius; use 0–4 px

no glow

no bright fill

hover may increase border opacity and background opacity slightly

For an empty slot:

CREATE CHARACTER                       →

The callback behavior must remain compatible with the existing flow.

14. Character carousel

Replace the old tall portrait cards with shorter horizontal minimal cards.

14.1 Position

Place the carousel near the bottom center.

Do not place it directly over the character's face/body.

It should occupy a relatively narrow band.

14.2 Existing character card

Suggested content:

01   BOB BROWN
     CIVILIAN

The secondary line may use the current job/category if appropriate.

The card should not duplicate CASH or LAST SEEN.

Suggested size:

width: 270–320 px
height: 86–106 px

Selected card:

border opacity approximately 0.45–0.60

background approximately rgba(5,7,9,.52)

Unselected:

border opacity approximately 0.15–0.24

background approximately rgba(5,7,9,.30)

Do not use scale transforms larger than approximately 1.02.

Avoid the current strong scale(1.1) selected-card effect.

14.3 New-character card

Use:

+    NEW CHARACTER
     CREATE A NEW STORY

Do not render a fake portrait silhouette as the main design.

14.4 Navigation arrows

Keep left/right navigation.

Use thin arrow icons.

Hover should only raise opacity.

Keep the existing PreviewCharacter callback behavior when selection changes.

The selected GTA ped/vehicle/camera preview must continue updating exactly as before.

15. Bottom utility actions

Place low-priority actions at bottom-left:

SETTINGS
DELETE CHARACTER

Settings:

preserve the existing screen dispatch behavior

use a small gear icon

Delete:

only show or enable for a non-empty slot

preserve the existing delete-confirmation screen and DeleteCharacter NUI callback

use muted white by default

only turn danger/red on hover or inside confirmation state

Do not show a trash icon directly on the character card.

This removes visual clutter from the carousel.

16. Slot counter

At bottom-right display:

01 / 02

Use the current selected slot index and total available slots.

Formatting requirements:

pad numbers to two digits

current slot brighter

total muted

Example:

`${String(counter + 1).padStart(2, "0")} / ${String(playersStore.length).padStart(2, "0")}`

17. Optional ambient information

The design may display small ambient information at the top-right:

21:34   |   24°C

This is secondary and must not delay or complicate the core implementation.

Rules:

do not hardcode time

do not hardcode temperature

if a reliable in-game value is not already available, omit this block

do not add a weather dependency solely for this UI

Character information remains limited to:

CASH

JOB

LAST SEEN

18. Responsive behavior

The NUI must remain usable at:

1920×1080

2560×1440

3440×1440 ultrawide

3840×2160

Use responsive CSS:

clamp()

vw

vh

min()

max()

Do not build the whole interface around hardcoded 1920×1080 coordinates.

Recommended safe margins:

left: clamp(32px, 3vw, 72px);
top: clamp(28px, 4vh, 64px);
bottom: clamp(24px, 3vh, 50px);

The left character panel should be approximately:

320–390 px

depending on viewport width.

On ultrawide screens, keep the UI anchored to meaningful safe areas instead of stretching elements across the screen.

19. Character data normalization

The current framework adapters already create a normalized array for the NUI.

Keep this approach.

Every non-empty character passed to the NUI should provide:

{
    id = number,
    firstname = string,
    lastname = string,
    citizenid = string,
    emptyslot = false,
    img = string,
    sex = boolean,
    additionalInfo = {
        cash = number,
        job = string,
        lastSeen = string
    }
}

Every empty slot should provide safe defaults:

{
    id = number,
    firstname = '',
    lastname = '',
    citizenid = 'UNKNOWN',
    emptyslot = true,
    img = '',
    additionalInfo = {
        cash = 0,
        job = 'UNEMPLOYED',
        lastSeen = 'UNKNOWN'
    }
}

The frontend must handle missing data without throwing.

20. Qbox/QBX integration

The existing Qbox adapter currently obtains characters through:

lib.callback.await('qbx_core:server:getCharacters')

and already exposes:

data.charinfo.firstname

data.charinfo.lastname

data.citizenid

data.job.label

data.money.cash

data.money.bank

The redesigned NUI only needs:

cash = data.money.cash
job = data.job.label
lastSeen = <resolved from saved position>

Remove bank and dob from the selection-screen additionalInfo data contract unless they are still required by another existing screen.

Do not break other screens merely to remove these values visually. If another screen uses them, keep them outside the main selection UI or keep them in a separate internal data property.

21. LAST SEEN implementation

LAST SEEN means the saved neighborhood/area corresponding to the character's last persisted coordinates.

Examples:

ROCKFORD HILLS
DOWNTOWN VINEWOOD
VESPUCCI
STRAWBERRY
DAVIS
PALETO BAY
SANDY SHORES

Do not hardcode a sample location.

21.1 Preferred data source

Use the saved character position already returned by the active framework if available.

For QBX this is typically character/player position data.

Inspect the actual object returned by:

qbx_core:server:getCharacters

and use its stored position field.

The position may be:

a Lua table

a JSON string

a table with x, y, z, w

framework-specific coordinate data

Normalize it safely.

21.2 Suggested helper

Create a reusable client-side helper conceptually similar to:

local function decodePosition(position)
    if type(position) == 'table' then
        return position
    end

    if type(position) == 'string' and position ~= '' then
        local ok, decoded = pcall(json.decode, position)
        if ok and type(decoded) == 'table' then
            return decoded
        end
    end

    return nil
end

Then resolve the area.

Prefer the neighborhood/zone label:

GetNameOfZone(x, y, z)
GetLabelText(zoneName)

If the zone label is unavailable, fall back to the street:

GetStreetNameAtCoord(x, y, z)
GetStreetNameFromHashKey(streetHash)

Normalize bad results such as:

NULL
nil
""

to:

UNKNOWN

Suggested conceptual function:

local function getLastSeenLabel(position)
    local coords = decodePosition(position)

    if not coords or not coords.x or not coords.y then
        return 'UNKNOWN'
    end

    local z = coords.z or 0.0

    local zoneCode = GetNameOfZone(coords.x, coords.y, z)
    if zoneCode and zoneCode ~= '' then
        local zoneLabel = GetLabelText(zoneCode)
        if zoneLabel and zoneLabel ~= '' and zoneLabel ~= 'NULL' then
            return string.upper(zoneLabel)
        end
    end

    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, z)
    if streetHash and streetHash ~= 0 then
        local streetName = GetStreetNameFromHashKey(streetHash)
        if streetName and streetName ~= '' then
            return string.upper(streetName)
        end
    end

    return 'UNKNOWN'
end

Adjust native return values correctly according to Lua/FiveM behavior.

Do not copy the pseudocode blindly if the exact native signature differs. Validate it.

21.3 Framework compatibility

Implement the same normalized lastSeen field for:

QBX

QB

ESX

Use each framework's existing saved position field.

Do not query the database repeatedly per frame or per React render.

Character position should be resolved once when building the character selection array.

If a framework does not expose stored coordinates through the current character callback, use a single appropriate server-side query/callback during character-list loading rather than repeated NUI requests.

22. Cash formatting

Keep or reuse the existing frontend currency formatting utility.

Desired examples:

0       -> $0
100     -> $100
1840    -> $1,840
250000  -> $250,000

Do not show decimals for normal character cash.

If cash is missing:

$0

23. Job formatting

Use the framework's job label, not the internal job name when possible.

Correct:

LOS SANTOS POLICE
MECHANIC
UNEMPLOYED
PARAMEDIC

Less desirable:

police
mechanic
unemployed
ambulance

Display the final value uppercase in the NUI.

Fallback:

UNEMPLOYED

24. React implementation requirements

The main file to redesign is expected to be:

ui/src/components/charDetails/CharDetails.jsx

Refactor this component rather than stacking more markup around the existing UI.

Recommended decomposition:

charDetails/
  CharDetails.jsx
  CharacterIdentity.jsx
  CharacterInfo.jsx
  CharacterCarousel.jsx
  CharacterCard.jsx
  NoirIcon.jsx

Do not over-componentize tiny fragments if it makes the project harder to maintain.

A reasonable implementation can also keep everything in CharDetails.jsx plus one or two helper components.

Required behavior to preserve

initial GetCharacters

selected counter

PreviewCharacter

previous/next selection

playcharacter

settings screen

delete confirmation

create-character path

character image/profile fallback

NUI hover/click sound callbacks where they already exist

Remove from the current selection UI

generic Object.keys(additionalInfo) icon loop

tall 125×150 card aesthetic

1.1 selected-card scaling

central video-player-looking play button

per-card trash button

circular slot-number badge

large bright borders

excessive outlined icon squares

25. Local mock data

The frontend currently has local/mock character data used during development.

Update the mock shape to match the new contract.

Example:

{
  id: 1,
  firstname: "Bob",
  lastname: "Brown",
  citizenid: "NOIR001",
  emptyslot: false,
  img: "",
  sex: true,
  additionalInfo: {
    cash: 1840,
    job: "Mechanic",
    lastSeen: "Rockford Hills"
  }
}

Include at least:

one populated slot

one empty slot

one character with a long first/last name for overflow testing

one character with lastSeen: "UNKNOWN"

26. Existing settings, delete, registration and other screens

The character-selection screen is the priority.

Do not unnecessarily rewrite:

admin panel

scene selector

registration/create form

loading screen

profile picture system

confirmation system

However, ensure they still open and render after the selection-screen refactor.

If the existing delete confirmation looks visually incompatible, it may receive a minimal monochrome styling pass, but its behavior must remain unchanged.

The registration screen may also receive minor token-level theme alignment only if needed.

Do not expand scope into a full resource redesign unless required to prevent obvious visual breakage.

27. NUI event compatibility

Preserve the current client callbacks.

At minimum verify:

GetCharacters
playcharacter
PreviewCharacter
CreateCharacter
DeleteCharacter
exit

playcharacter currently receives the selected slot/character ID.

Do not change this to send the entire character object unless the Lua side is intentionally updated and validated.

PreviewCharacter must continue receiving enough information to select and render the correct ped preview.

28. Camera and GTA scene behavior

Do not rewrite the existing camera scene unless needed for a bug fix.

Keep:

CreateCamScene

preview vehicle spawning

player model/skin loading

shallow depth of field

configured weather

configured time

scene animation

character preview switching

camera cleanup

vehicle cleanup

The NUI redesign should not alter the core world composition.

A major requirement is:

The character, vehicle and GTA scene remain the hero visual. The NUI is only a minimal overlay.

29. Empty-slot behavior

When the selected slot is empty:

Left panel:

02
NEW CHARACTER

CREATE A NEW STORY

Do not display:

CASH
JOB
LAST SEEN

for an empty character unless placeholders are visually necessary.

Primary button:

CREATE CHARACTER →

Use the existing empty-slot path.

The current Lua playcharacter handler already detects character.emptyslot and calls the create menu. Preserve or reuse that behavior.

30. Delete behavior

For populated characters:

Bottom-left utility action:

DELETE CHARACTER

On click:

open the existing delete confirmation state

show the actual selected character name

require explicit confirmation

invoke the existing DeleteCharacter NUI callback

refresh character slots afterward

For empty slots, hide or disable delete.

Never allow accidental one-click deletion.

31. Interaction styling

Hover:

border opacity increases

text opacity increases

optional background opacity increases slightly

transition 120–220 ms

Do not use:

bounce

large scale effects

neon glow

pulsing animation

excessive blur

rotating icons

Focus-visible:

Provide a clear keyboard focus outline.

Example:

outline: 1px solid rgba(255,255,255,.70);
outline-offset: 3px;

32. Keyboard navigation

Preserve any current Q/E or arrow navigation behavior if it exists.

Additionally, where safe:

ArrowLeft -> previous character

ArrowRight -> next character

Enter -> play/create selected character

Do not trigger character deletion from a simple keyboard shortcut.

Keyboard support is secondary to preserving current FiveM controls.

33. Character card image handling

The current resource supports:

custom slot image

male fallback image

female fallback image

create-slot image

The new horizontal card does not need a large portrait.

If an image is kept:

use it as a very subtle small thumbnail/silhouette

do not let it dominate the card

do not use large background portraits with heavy radial overlays

It is also acceptable to omit character images from the carousel completely if doing so improves the minimal design.

Do not remove the profile image subsystem from the resource merely because the selection card no longer depends on it.

34. Performance

The NUI must remain lightweight.

Requirements:

no continuous React interval unless required

no repeated NUI callback for static character data

no position lookup every frame

no expensive animated blur

no video background

no external HTTP assets

no oversized image assets if not necessary

no unnecessary new dependencies

Character data should be fetched on screen entry/refresh, not every render.

35. Accessibility and robustness

Even though this is an in-game NUI:

interactive elements should use buttons when practical

add meaningful aria-label for icon-only controls

do not rely on color alone for selected state

provide visible hover/focus state

protect against undefined playersStore[counter]

protect against empty character arrays

protect against missing additionalInfo

protect against missing images

use stable React keys

Avoid runtime errors while character data is loading.

36. Suggested UI state model

Keep existing Redux screen state, but simplify the character-selection component state.

Suggested conceptual state:

const [characters, setCharacters] = useState([]);
const [selectedIndex, setSelectedIndex] = useState(0);
const selectedCharacter = characters[selectedIndex] ?? null;

Derived:

const isEmpty = selectedCharacter?.emptyslot === true;

Do not duplicate selected-character data in multiple independent state objects unless necessary.

37. Formatting helpers

Add small safe helpers as needed.

Examples:

const uppercase = (value, fallback = "UNKNOWN") =>
  String(value ?? fallback).toUpperCase();

const padSlot = (value) =>
  String(value ?? 0).padStart(2, "0");

Do not call the currency formatter on non-currency values.

The current UI appears to pass all additionalInfo values through the currency formatter because it generically loops them. This must be fixed.

Correct:

formatNumberToCurrency(character.additionalInfo.cash)

Incorrect:

formatNumberToCurrency(character.additionalInfo.job)
formatNumberToCurrency(character.additionalInfo.lastSeen)

38. Suggested DOM hierarchy

A clear implementation structure could be:

<div className="noir-character-select">
  <div className="noir-overlay noir-overlay--left" />
  <div className="noir-overlay noir-overlay--bottom" />

  <header className="noir-brand">
    ...
  </header>

  <main className="noir-character-panel">
    <div className="noir-slot-number">01</div>
    <h1>BOB BROWN</h1>

    <div className="noir-divider" />

    <CharacterInfo ... />

    <button className="noir-primary-action">
      PLAY CHARACTER
      <ArrowIcon />
    </button>
  </main>

  <nav className="noir-character-carousel">
    <button aria-label="Previous character">...</button>

    <div className="noir-character-cards">
      ...
    </div>

    <button aria-label="Next character">...</button>
  </nav>

  <div className="noir-utility-actions">
    ...
  </div>

  <div className="noir-slot-counter">
    01 / 02
  </div>
</div>

This is guidance, not a requirement to use exactly these class names.

39. CSS architecture

Prefer dedicated semantic classes for this screen instead of huge Tailwind class strings for every element.

The existing component currently contains long utility-class blocks with fixed pixel coordinates.

For the redesigned screen, it is preferable to create a dedicated stylesheet, for example:

ui/src/components/charDetails/charDetails.css

or:

ui/src/components/charDetails/noirCharacterSelect.css

Use CSS custom properties for the Noir theme.

Tailwind can still be used where useful, but do not make the layout impossible to maintain.

40. Build process

After implementation:

cd ui
npm ci
npm run lint
npm run build

If npm ci cannot be used because the lockfile is inconsistent, fix the lockfile rather than bypassing dependency integrity without explanation.

The Vite build is currently configured with:

vite build --base=/ui/dist/

Verify that generated files match the fxmanifest.lua paths:

ui/dist/index.html
ui/dist/assets/*.css
ui/dist/assets/*.js

For actual FiveM deployment, ui/dist must exist inside the resource even if the repository chooses not to commit build output.

41. FiveM validation checklist

Test all of the following in game.

Character selection

NUI opens.

GTA scene is visible.

Left gradient does not hide the scene.

Selected character name is correct.

Slot number is correct.

CASH is correct.

JOB is correct.

LAST SEEN reflects the saved character location.

No bank field is visible.

No DOB field is visible.

No extra character stats are visible.

Carousel

Previous character works.

Next character works.

Preview ped changes.

Preview skin changes.

Preview scene does not duplicate entities.

Selected card state changes.

Empty slot appears as NEW CHARACTER.

Slot counter updates.

Play/create

PLAY CHARACTER loads the selected character.

Empty slot uses CREATE CHARACTER.

Existing character creation form still opens.

New character is created successfully.

Spawn flow still works.

Delete

Delete is unavailable for empty slots.

Delete opens confirmation.

Confirm deletes correct character.

Cancel does nothing.

Character list refreshes after delete.

Settings/other screens

Settings still opens.

Scene selector still works.

Profile image feature still works.

Admin panel remains functional if enabled.

Loading screen still works.

Cleanup

Leaving the menu removes camera correctly.

Preview vehicle is deleted correctly.

No frozen/invisible player remains.

NUI focus is released correctly.

42. Resolution validation

Capture/test screenshots at:

1920×1080
2560×1440
3440×1440
3840×2160

Check:

no text clipping

no name overflow

no carousel clipping

no UI outside safe areas

no giant UI on 4K

no center drift on ultrawide

no overlap between left panel and central character in normal scene compositions

43. LAST SEEN validation

Test with characters saved in at least three different areas.

Example test cases:

Character A saved in Rockford Hills
Character B saved in Vespucci
Character C saved in Sandy Shores

Expected:

The UI must show a different LAST SEEN value for each based on their actual saved coordinates.

Also test:

missing position
invalid JSON
missing x/y
zone native returns NULL

Expected fallback:

UNKNOWN

No Lua error should occur.

44. Framework validation

The original project contains:

QB

QBX

ESX

Do not intentionally remove these adapters.

At minimum ensure the code still parses for all three.

QBX/Qbox is the primary target for the Noir State implementation, but the UI data contract should remain framework-agnostic.

Every adapter should attempt to produce:

cash
job
lastSeen

with safe fallbacks.

45. Do not introduce unnecessary database schema changes

LAST SEEN should come from existing stored character position data.

Do not create a new database table just for the selection screen.

Do not add a new column unless the current frameworks genuinely do not persist position anywhere, which would be unexpected.

If a SQL change becomes absolutely required, document the reason before implementing it.

46. Preserve upstream attribution

Do not remove upstream license headers, author comments, or attribution notices if present.

The deployed resource may be branded as Noir State / noir_multichar, but upstream attribution should remain in source/docs where required.

Do not claim original authorship of third-party code.

47. Code quality expectations

Before finishing:

remove dead imports from old icons/assets

remove generic stat-loop code no longer used

remove unused state

no console.log left for normal runtime debugging

no temporary hardcoded Bob Brown data in production path

no hardcoded cash/job/location

no duplicated callback calls

no uncaught promise errors from NUI fetches

no React missing-key warnings

no lint errors

no obvious Lua syntax errors

48. Preferred implementation sequence

Follow this order.

Phase 1 — Establish baseline

Inspect current resource.

Inspect current character payloads.

Run current UI build.

Record existing callbacks and behavior.

Do not modify Lua behavior yet.

Phase 2 — Rename

Update resource/package metadata to noir_multichar.

Verify NUI callback resource resolution still uses GetParentResourceName().

Update documentation/package metadata.

Build again.

Phase 3 — Normalize character data

Modify framework adapters to expose:

cash

job

lastSeen

Add robust saved-position decoding.

Add area-name resolution.

Add safe fallbacks.

Update frontend mock data.

Phase 4 — NUI redesign

Refactor CharDetails.jsx.

Add semantic CSS/theme tokens.

Build left identity panel.

Add the three explicit info rows.

Add left-side play/create CTA.

Rebuild bottom carousel.

Move settings/delete to bottom-left.

Add slot counter.

Remove old UI clutter.

Phase 5 — Regression validation

Build.

Lint.

Test character preview.

Test create.

Test play.

Test delete.

Test settings.

Test all resolutions.

Test at least QBX in FiveM.

Document anything not testable locally.

49. Definition of done

This task is complete only when all of the following are true:

The resource is deployable under the name:

noir_multichar

The character-selection NUI uses the Noir State minimal design.

The center GTA scene remains visually dominant.

The left panel displays only these character information rows:

CASH
JOB
LAST SEEN

LAST SEEN comes from the selected character's saved position and is not hardcoded.

The central old play-icon button is gone.

The primary CTA is in the left panel.

Character cards are horizontal/minimal instead of tall portrait boxes.

Create-new-character remains supported.

Character preview switching still works.

Delete confirmation still works.

Existing framework functionality is not intentionally removed.

The React app passes lint/build.

The built NUI works using FiveM's ui/dist path.

No obvious hardcoded demo values remain in production code.

50. Final output expected from Codex

When implementation is finished, provide a concise implementation report containing:

Files changed

List each modified/created/renamed file.

Data changes

Explain exactly how:

cash
job
lastSeen

are populated for QBX, QB and ESX.

LAST SEEN

Explain which stored position field is used by each supported framework and which GTA native(s) convert coordinates into an area label.

Compatibility

State which flows were verified:

select
preview
play
create
delete
settings
scene selector
profile image

Build

Report:

npm run lint
npm run build

results.

Known limitations

List only real remaining limitations; do not invent issues.

Final design principle

The final result should feel like a custom Noir State character selector, but it should still be recognizably based on the original resource's efficient interaction model.

The player should primarily see:

their character, their car, and the GTA world

not:

a giant web application covering the game.

Minimal UI, strong hierarchy, subtle contrast, and reliable multicharacter behavior are more important than decorative effects.