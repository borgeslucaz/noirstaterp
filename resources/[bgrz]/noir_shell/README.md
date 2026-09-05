# noir_shell

Reusable shell/interior library for FiveM.

`noir_shell` centralizes the lifecycle of dynamically spawned local shell
entities (model loading, `CreateObject`, freezing, collision loading, relative
offsets, and cleanup) so gameplay resources don't need to reimplement it.

It does not depend on QBCore, Qbox, or `qb-interior`. See
`docs/noir_shell/NOIR_SHELL.md` for the full design rationale.

## Usage

Exports are id-based rather than returning a shell object with methods.
FiveM's export mechanism serializes return values crossing the resource
boundary, which strips metatables — so a `shell:GetOffset(...)`-style object
returned from `exports.noir_shell:Create(...)` would silently lose all of its
methods on the caller's side (this is the same reason `ox_target`'s
`addSphereZone` returns a plain zone id instead of a zone object). Every
operation therefore takes the shell `id` returned by `Create`.

```lua
local shellId, err = exports.noir_shell:Create({
    model = `lev_apartment_shell`,
    origin = vec4(1000.0, 1000.0, -100.0, 0.0),
})

if not shellId then
    print(err)
    return
end

local entrance = exports.noir_shell:GetOffset(shellId, vec3(2.5, -1.2, 0.8))

SetEntityCoords(PlayerPedId(), entrance.x, entrance.y, entrance.z)

-- later
exports.noir_shell:Destroy(shellId)
```

### Registered definitions

```lua
-- shared/config.lua
Config.Shells.lev_apartment = {
    model = `lev_apartment_shell`,
    origin = vec4(1000.0, 1000.0, -100.0, 0.0),
}
```

```lua
local shellId, err = exports.noir_shell:CreateFromDefinition('lev_apartment', {
    origin = Config.InteriorOrigin, -- optional overrides merged onto the definition
})
```

## Exported API

* `exports.noir_shell:Create(definition)` -> `id, err`
* `exports.noir_shell:CreateFromDefinition(name, overrides?)` -> `id, err`
* `exports.noir_shell:GetEntity(id)` -> `entity`
* `exports.noir_shell:GetOrigin(id)` -> `vec4`
* `exports.noir_shell:GetOffset(id, offset: vec3)` -> `vec3`
* `exports.noir_shell:GetOffsetTransform(id, { offset, heading? })` -> `{ coords, heading }`
* `exports.noir_shell:TeleportPed(id, ped, offset: vec4)`
* `exports.noir_shell:Destroy(id)` (idempotent)
* `exports.noir_shell:IsValid(id)` -> `boolean`
* `exports.noir_shell:DestroyAll()`
* `exports.noir_shell:GetActiveInstances()` -> `id[]`

Internally, shells are represented by an OOP instance (`shell:GetOffset(...)`,
`shell:Destroy()`, etc. — see `client/instance.lua`) but that object is only
usable from *inside* this resource (e.g. `client/dev.lua` calls
`Manager.Create` directly, not its own export). Cross-resource consumers must
use the id-based export functions above.

## Errors

`Create`/`CreateFromDefinition` return `nil, reason` on failure instead of an
invalid shell. Possible reasons:

* `invalid_definition`
* `invalid_origin`
* `unknown_definition`
* `invalid_model`
* `model_load_timeout`
* `create_object_failed`
* `collision_timeout`

## Config

See `shared/config.lua`:

* `Config.Debug` - verbose `[noir_shell]` logging
* `Config.ModelLoadTimeout` / `Config.CollisionTimeout` (ms)
* `Config.DefaultOrigin`
* `Config.Shells` - optional named definitions

## Development commands

Restricted to the `command` ace permission:

* `/testshell <model>` - spawn a shell at your position and float you above it
* `/testshell_exit` - destroy the active test shell
* `/shelloffset` - print your current position as a shell-relative `vec3`
