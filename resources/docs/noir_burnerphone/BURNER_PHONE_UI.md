Redesign the current Burner Phone NUI into a touchscreen phone inspired by the classic Windows Phone / Metro UI.

IMPORTANT:
- Do NOT redesign or rewrite the backend logic unnecessarily.
- Preserve all existing FiveM NUI callbacks, Lua events, JS events, exports, and resource functionality.
- Focus primarily on the HTML/CSS/JS presentation layer.
- Reuse the existing phone container if possible.
- Do not add external UI frameworks unless absolutely necessary.

## Main concept

The burner phone should look like a cheap early-2010s touchscreen smartphone.

It is NOT a modern iPhone/Android smartphone and it must NOT have a physical numeric keypad.

The visual style should be inspired by:
- Windows Phone 7 / Windows Phone 8
- Metro UI
- Nokia Lumia-era interfaces
- Minimal flat design
- Dark anonymous burner-phone aesthetic

The result should feel like an inexpensive touchscreen phone used specifically for anonymous/illegal activities in a GTA/FiveM RP environment.

---

## PHONE HARDWARE

Keep the external phone shell.

The phone should have:

- dark gray / graphite plastic body
- rounded corners
- relatively thick bezels
- small speaker slit at the top
- touchscreen occupying most of the front
- NO physical numeric keypad
- NO physical navigation buttons
- NO green/red call buttons
- NO home button
- NO visible manufacturer logo

The device should feel slightly old and inexpensive instead of premium.

Do not make it look like a modern bezel-less smartphone.

---

## SCREEN

The display should use:

background:
#090909 / #0c0c0c

with subtle variations of dark gray.

Do not use gradients everywhere.

The UI should be flat and clean.

At the top create a very small status bar.

Example:

[signal icon]                         [battery icon]

Do NOT display:

- "Burner OS"
- "Burner Phone"
- "Início"
- device brand
- Android/iOS indicators

The phone itself should communicate that it is a burner phone through its appearance and functionality.

---

# HOME SCREEN

Create a vertical Metro-style menu.

The main screen should contain exactly these options:

1. Telefone
2. Contatos
3. Mensagens
4. Atividades Ilegais
5. Fechar

Do not add a page title above them.

The screen should immediately show the options.

Example structure:

┌───────────────────────────────┐
│ signal                 battery│
│                               │
│ ┌──────┬────────────────────┐ │
│ │ icon │ Telefone           │ │
│ └──────┴────────────────────┘ │
│                               │
│ ┌──────┬────────────────────┐ │
│ │ icon │ Contatos           │ │
│ └──────┴────────────────────┘ │
│                               │
│ ┌──────┬────────────────────┐ │
│ │ icon │ Mensagens          │ │
│ └──────┴────────────────────┘ │
│                               │
│ ┌──────┬────────────────────┐ │
│ │ icon │ Atividades Ilegais │ │
│ └──────┴────────────────────┘ │
│                               │
│ ┌──────┬────────────────────┐ │
│ │ icon │ Fechar             │ │
│ └──────┴────────────────────┘ │
│                               │
└───────────────────────────────┘

---

# METRO TILE DESIGN

Each option should be a horizontal Metro-style tile.

Structure:

[ square icon area ][ text area ]

Example:

┌────────┬──────────────────────────┐
│   ☎    │ Telefone                 │
└────────┴──────────────────────────┘

The icon block should use the accent color.

Default accent suggestion:

#1f4f82

or a slightly muted/darker Windows Phone blue.

Do not make the blue extremely saturated.

The text section should be:

background:
#181818

hover:
#222222

active:
#292929

Text:

#f2f2f2

Use thin/simple icons.

Recommended icons:

Telefone
- phone handset

Contatos
- person silhouette

Mensagens
- speech bubble

Atividades Ilegais
- anonymous mask / balaclava / subtle criminal-related icon

Fechar
- power icon

Do not use emoji.

Use the icon library already available in the project if one exists.

Otherwise prefer inline SVG icons.

---

# TYPOGRAPHY

The typography should strongly resemble Windows Phone.

Use something similar to:

Segoe UI
Segoe UI Light
Inter

CSS example:

font-family:
"Segoe UI", "Inter", sans-serif;

Menu labels should use a relatively thin font weight:

font-weight: 300 or 400;

Avoid bold text unless needed.

The labels should be large enough to be immediately readable.

Example:

font-size: 22px–28px depending on the existing phone scale.

---

# TOUCH INTERACTION

This phone is touchscreen.

Therefore the whole menu tile must be clickable.

Do NOT create tiny buttons inside the tile.

Interaction:

hover:
- slightly brighten the tile
- subtle icon area change

active:
- small press feedback
- optionally scale to ~0.985 for ~80ms

Example:

transform: scale(0.985);

Do not use exaggerated animations.

Transitions should be around:

100ms–160ms.

---

# FECHAR

"Fechar" must behave exactly like another menu item.

Do NOT create a separate close button below the menu.

Do NOT create an X in the corner.

It should be the final item:

Atividades Ilegais
Fechar

Clicking it must trigger the existing NUI close behavior.

Reuse the existing callback/event used by the current interface.

---

# TELEFONE

Clicking "Telefone" should open the phone/call screen.

If the current project already has this functionality, connect the new tile to the existing logic.

Do not implement duplicate backend logic.

---

# CONTATOS

Clicking "Contatos" should open the existing contacts screen.

If it does not exist yet, create only the frontend navigation structure required to support it later without inventing backend data.

---

# MENSAGENS

Clicking "Mensagens" should open the messages screen.

Keep the same Metro visual language.

Future screens should have a simple back navigation.

Example:

‹ mensagens

or

← mensagens

Do not add Android/iOS-style navigation bars.

---

# ATIVIDADES ILEGAIS

This is the special section of the burner phone.

Clicking it should open the existing illegal activities functionality if available.

If functionality is not implemented yet, create a placeholder screen such as:

ATIVIDADES

Nenhuma atividade disponível.

However, preserve any existing events/data/callbacks already implemented by the resource.

This section may eventually contain things such as:

- street dealing
- jobs
- contracts
- burner contacts
- missions
- territory-related activities

Do not implement those systems unless they already exist.

The current task is UI/navigation only.

---

# SCREEN TRANSITIONS

Navigation should feel similar to Windows Phone.

Avoid:

- page flips
- huge fades
- iPhone-style slide animations
- material-design effects

Preferred transitions:

fade + very small horizontal movement

Example:

opacity: 0 → 1
translateX: 8px → 0

Duration:

120–180ms

---

# RESPONSIVENESS

This is a FiveM NUI rendered over the GTA world.

The phone must remain proportional across common resolutions:

1920x1080
2560x1440
3440x1440

Avoid hardcoding the entire interface purely with pixels.

Use combinations of:

vh
vw
rem
clamp()

while maintaining a reasonable maximum phone size.

The phone should normally appear toward the lower-right side of the screen unless the current resource already defines another position.

Do not stretch the phone.

Maintain its original aspect ratio.

---

# IMPORTANT DESIGN RULES

Avoid making the interface look like:

- modern Android
- iOS
- banking application
- admin dashboard
- web browser
- futuristic cyberpunk UI

It should look like:

cheap touchscreen phone
+
Windows Phone Metro
+
anonymous burner phone
+
GTA RP criminal tool

Keep the screen intentionally simple.

The minimalism is part of the design.

---

# CODE QUALITY

Refactor the frontend where useful.

Prefer semantic structure such as:

.phone
.phone-screen
.status-bar
.app-list
.app-tile
.app-icon
.app-label

Avoid unnecessary deeply nested CSS.

Create reusable components/classes for tiles.

Do not duplicate CSS for every menu item.

If the frontend uses React/Vue/Svelte, create a reusable component such as:

<AppTile />

If it is vanilla HTML/JS, generate the items from a JS configuration array where practical.

Example concept:

const apps = [
    {
        id: "phone",
        label: "Telefone",
        icon: ...
    },
    {
        id: "contacts",
        label: "Contatos",
        icon: ...
    },
    {
        id: "messages",
        label: "Mensagens",
        icon: ...
    },
    {
        id: "illegal",
        label: "Atividades Ilegais",
        icon: ...
    },
    {
        id: "close",
        label: "Fechar",
        icon: ...
    }
];

---

# PRESERVE EXISTING INTEGRATION

Before modifying anything:

1. Inspect the current resource.
2. Identify the NUI entrypoint.
3. Identify the existing close-phone callback.
4. Identify existing message/event listeners.
5. Identify existing phone/contact/message/illegal activity callbacks.
6. Reuse them instead of replacing them.

Do not rename events without updating every reference.

Do not remove FiveM NUI communication code.

---

# FINAL RESULT

The first thing the player should see after opening the burner phone is:

Telefone
Contatos
Mensagens
Atividades Ilegais
Fechar

presented as large touchscreen Metro-style tiles.

There should be no numeric keypad.

There should be no "Burner OS".

There should be no "Início".

There should be no additional introductory card.

There should be no separate close button.

The final result should closely resemble an old touchscreen Windows Phone interface integrated into a cheap anonymous burner phone.