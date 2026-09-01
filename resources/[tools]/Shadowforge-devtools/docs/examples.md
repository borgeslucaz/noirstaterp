# Workflow examples

Five common things you can do faster with the panel. Open it with `F6`, `/sfdev`, or `/sfdevtools`.

---

## 1. Inspect a prop you can see

You're walking past a prop and want its model + coords without alt-tabbing into a model viewer.

1. Open the panel → **Entity Inspector** → **Inspect aimed entity now**.
2. The action menu opens. You see:
   - Model hash
   - Coords (vector3) and coords + heading (vector4)
   - Distance, network ID, mission flag, frozen / visible / collision state
   - Health (for peds and vehicles)
3. Click **Spawn snippet** → it copies a ready-to-paste `CreateObject` block:
   ```lua
   local hash = `1234567890`
   lib.requestModel(hash)
   local obj = CreateObject(hash, -1037.42, -2737.5, 20.17, true, true, false)
   SetEntityHeading(obj, 327.0)
   SetEntityCollision(obj, true, true)
   FreezeEntityPosition(obj, true)
   ```

For a continuous overlay (read-only, multi-entity), pick **Start inspector** instead. Press `E` to lock onto whatever you're aiming at, `G` to print to F8, `Backspace` to exit.

---

## 2. Copy your current coords as `vector4`

You found "the spot" in-game and want it in your script.

1. Panel → **Coordinate Tools** → **Player coords**.
2. Pick **vector4** → it copies `vector4(123.45, -678.90, 12.34, 270.0)` to your clipboard.

Other formats available in the same submenu: `vector2/3`, `vec3/4`, Lua table, JSON, `/tp` command, heading-only, or save it as a named location for later teleporting.

---

## 3. Create an ox_target box zone where you're standing

You want a target zone on a counter, and you don't want to eyeball coords.

1. Panel → **Zone Builder** → **Box zone**.
2. Pick **Set center to player coords** (or **Set center to aim/raycast hit** for further away).
3. Adjust **Size** (`X`, `Y`, `Z`) and **Rotation**. The wireframe preview updates live in the world.
4. Pick **Copy ox_target snippet** — paste:
   ```lua
   exports.ox_target:addBoxZone({
       coords   = vec3(-1037.42, -2737.50, 20.17),
       size     = vec3(2.0, 1.5, 1.5),
       rotation = 327.0,
       debug    = true,
       options  = {
           { label = 'Interact', icon = 'fa-solid fa-hand', onSelect = function(data) end },
       },
   })
   ```

Same workflow for **sphere** and **poly** zones (poly: walk the perimeter, hit "Add point at player coords" at each corner, then "Copy ox_lib poly zone").

---

## 4. Place a prop with the keyboard

You need a custom prop placement and don't want to reload your test resource ten times.

1. Panel → **Object Placer** → **Spawn by model name**.
2. Type a prop model — e.g. `prop_chair_01a`. It spawns 1.5m in front of you and enters placement mode.
3. Move it:
   - **W / A / S / D** — slide on the X-Y plane (camera-relative)
   - **R / F** — up / down
   - **Q / E** — rotate
   - **Shift** — 4× speed · **Alt** — 0.25× speed (precision)
   - **G** — snap to ground
4. **Enter** confirms (the prop is frozen and tracked). **Backspace** cancels.
5. Place a few more props the same way, then go to **Object Placer → Export placed objects (Lua)** to dump them all:
   ```lua
   local objects = {
       { model = 1234567890, coords = vector4(...) },
       { model = 9876543210, coords = vector4(...) },
   }
   ```

When you stop the resource (or pick **Cleanup all dev props**), every tracked prop is removed.

---

## 5. Export a vehicle config from the car you're driving

You configured a livery + colors + plate in-game and want to ship those defaults.

1. Hop in the vehicle.
2. Panel → **Vehicle Tools** → **Inspect current vehicle**.
3. Pick:
   - **Copy spawn snippet** — `CreateVehicle` with your current colors and plate baked in.
   - **Copy Qbox shared entry** — a `vehicles.lua`-style table.
   - **Copy ox_target template** — a `addModel` template scoped to the vehicle's hash.

Repair / clean / flip / engine-toggle all live in the same menu so you can fix the test vehicle without leaving the panel.

---

## Bonus: snippet-grab without context

You don't want to inspect anything — you just need a `lib.progressBar` template right now.

1. Panel → **Snippet Generator** → **ox_lib UI** → **lib.progressBar**.
2. It's on your clipboard. Paste, change the label, ship it.

Same path for events, commands, ACE checks, Discord webhook helpers, and zone templates.
