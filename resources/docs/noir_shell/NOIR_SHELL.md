# noir_shell

Reusable shell/interior library for FiveM.

`noir_shell` provides a small abstraction layer around dynamically spawned shell interiors, allowing other resources to create, position, use, and destroy interior shells without directly dealing with `RequestModel`, `CreateObject`, collision loading, offsets, or cleanup.

The project is inspired by the shell lifecycle used by `qb-interior`, but is designed as a standalone and reusable library.

It does **not** depend on QBCore, Qbox, or `qb-interior`.

---

## Why?

Several FiveM systems require temporary interiors:

* house robberies;
* apartments;
* motels;
* drug labs;
* warehouses;
* illegal missions;
* instanced mission interiors;
* temporary properties.

Without an abstraction, every resource tends to implement the same logic:

```lua
RequestModel(model)

CreateObject(...)

FreezeEntityPosition(...)

RequestCollisionAtCoord(...)

GetOffsetFromEntityInWorldCoords(...)

DeleteEntity(...)
```

This creates duplicated code and makes shell lifecycle bugs much easier to introduce.

`noir_shell` centralizes this behavior.

Instead of knowing how a shell works internally, another resource should only need something conceptually similar to:

```lua
local shell = exports.noir_shell:Create({
    model = `lev_apartment_shell`,
    origin = vec4(1000.0, 1000.0, -100.0, 0.0)
})
```

Then:

```lua
local coords = shell:GetOffset(
    vec3(2.5, -1.2, 0.8)
)
```

And finally:

```lua
shell:Destroy()
```

---

# Goals

The main goals of `noir_shell` are:

* provide a reusable shell API;
* keep shell logic outside gameplay resources;
* support locally spawned shell entities;
* provide reliable model loading;
* provide reliable collision loading;
* support relative offsets;
* support shell rotation;
* provide deterministic cleanup;
* prevent orphaned shell entities;
* support multiple shell models;
* support multiple resources using the library;
* remain framework independent;
* work well with FiveM Enhanced;
* remain small and easy to maintain.

---

# Non-Goals

`noir_shell` is **not**:

* a housing system;
* a property ownership system;
* a routing bucket manager;
* a robbery system;
* a loot system;
* an inventory system;
* a doorlock system;
* a persistence system;
* an MLO manager.

Those systems should consume `noir_shell`.

For example:

```text
noir_houserobbery
        │
        │ Create shell
        ▼
    noir_shell
        │
        ▼
FiveM CreateObject
```

---

# Architecture

The intended architecture is:

```text
Gameplay Resource

noir_houserobbery
noir_druglabs
noir_motels
noir_warehouses
        │
        │
        ▼
    noir_shell
        │
        ├── model loading
        ├── CreateObject
        ├── rotation
        ├── collision
        ├── offsets
        ├── teleport helpers
        └── cleanup
```

Gameplay resources should not need to directly manage shell entities.

---

# Shell Lifecycle

A shell instance follows this lifecycle:

```text
Create request
    ↓
Validate definition
    ↓
Request model
    ↓
Wait for model
    ↓
CreateObject
    ↓
Set rotation / heading
    ↓
Freeze entity
    ↓
Request collision
    ↓
Wait for collision
    ↓
Shell ready
    ↓
Use shell
    ↓
Destroy
    ↓
DeleteEntity
    ↓
Clear instance state
```

---

# Local Shells

By default, shells should be created as **local client-side entities**.

Example:

```lua
CreateObject(
    model,
    x,
    y,
    z,
    false,
    false,
    false
)
```

A shell is normally static environment geometry.

It generally does not need:

* network ownership;
* a Network ID;
* server-side replication.

Gameplay entities inside the shell can still be networked independently.

For example:

```text
Shell walls/floor
→ local

TV
→ networked

Laptop
→ networked

Player
→ networked

Dropped loot
→ networked
```

This distinction is particularly useful for instanced systems such as house robberies.

---

# Routing Buckets

`noir_shell` should **not manage routing buckets**.

Routing bucket ownership belongs to the gameplay/session system.

Example:

```text
noir_houserobbery

Robbery Session 1501
        │
        ├── routing bucket 1501
        ├── participants
        ├── loot
        └── interiorId
                 │
                 ▼
             noir_shell
```

The gameplay resource can place players and networked entities into the appropriate bucket.

`noir_shell` is only responsible for creating the local environment.

---

# Multiple Players

Multiple players may share the same logical interior.

For example:

```text
Robbery Session 1501

Player A
Player B
Player C
```

Each client may create its own local copy:

```text
Client A
→ lev_apartment_shell

Client B
→ lev_apartment_shell

Client C
→ lev_apartment_shell
```

All copies use:

```text
same model
same origin
same heading
same offsets
```

The gameplay/session resource remains responsible for synchronizing shared state.

---

# Multiple Instances

Different sessions can use the same shell model and the same physical origin.

Example:

```text
Session 1501
Bucket 1501
lev_apartment_shell
1000, 1000, -100
```

and:

```text
Session 1502
Bucket 1502
lev_apartment_shell
1000, 1000, -100
```

The shell itself is local.

Players and networked gameplay entities are isolated by the owning gameplay system.

`noir_shell` should not attempt to understand why multiple clients are using the same origin.

---

# Suggested Project Structure

```text
noir_shell/
│
├── fxmanifest.lua
│
├── README.md
│
├── LICENSE
│
├── client/
│   ├── manager.lua
│   ├── instance.lua
│   ├── collision.lua
│   └── utils.lua
│
└── shared/
    └── config.lua
```

Keep the library small.

Do not introduce server-side files unless a real server-side responsibility appears later.

---

# Shell Instance

Every spawned shell should be represented internally by a shell instance.

Conceptually:

```lua
ShellInstance = {
    id = "...",

    model = `...`,

    entity = 0,

    origin = vec4(...),

    destroyed = false
}
```

A shell instance should expose operations instead of forcing consumers to directly manipulate its entity.

---

# Proposed API

The exact API can be adjusted during implementation, but the library should expose a small and predictable surface.

## Create

```lua
local shell = exports.noir_shell:Create({
    model = `lev_apartment_shell`,

    origin = vec4(
        1000.0,
        1000.0,
        -100.0,
        0.0
    )
})
```

Expected result:

```lua
shell
```

representing a valid shell instance.

---

# Create From Registered Definition

The library may optionally support named definitions.

Example:

```lua
local shell = exports.noir_shell:CreateFromDefinition(
    'lev_apartment'
)
```

With:

```lua
Config.Shells = {
    lev_apartment = {
        model = `lev_apartment_shell`,

        origin = vec4(
            1000.0,
            1000.0,
            -100.0,
            0.0
        ),

        entranceOffset = vec3(
            ...
        )
    }
}
```

Do not require consumers to use the registry.

Both direct creation and registered definitions should be possible if the implementation remains simple.

---

# Get Entity

When advanced consumers genuinely need access to the underlying entity:

```lua
local entity = shell:GetEntity()
```

Avoid exposing the entity as the primary API.

Consumers should prefer library methods.

---

# Get Origin

```lua
local origin = shell:GetOrigin()
```

Returns the origin used when the shell was created.

---

# Get Offset

Convert a shell-relative offset to world coordinates.

```lua
local coords = shell:GetOffset(
    vec3(
        2.5,
        -1.2,
        0.8
    )
)
```

Internally this should use the shell entity whenever appropriate:

```lua
GetOffsetFromEntityInWorldCoords(...)
```

The consumer should not have to calculate:

```text
world position - shell origin
```

manually.

---

# Get Offset With Heading

It may be useful to expose a helper returning both position and heading:

```lua
local position = shell:GetOffsetTransform({
    offset = vec3(...),
    heading = 90.0
})
```

Potential result:

```lua
{
    coords = vec3(...),
    heading = ...
}
```

Only add this if it meaningfully simplifies consumer code.

---

# Teleport

An optional helper may teleport a ped using a shell-relative offset.

Example:

```lua
shell:TeleportPed(
    PlayerPedId(),
    vec4(
        1.2,
        -3.5,
        0.2,
        180.0
    )
)
```

This should remain a convenience helper.

Shell creation must not automatically teleport the player.

---

# Destroy

```lua
shell:Destroy()
```

Destroy must:

* check whether the entity exists;
* safely delete it;
* clear internal references;
* mark the instance as destroyed;
* be safe when called multiple times.

Calling:

```lua
shell:Destroy()
shell:Destroy()
shell:Destroy()
```

must not throw errors or create invalid state.

---

# Destroy All

The library should maintain a registry of active local instances.

This allows:

```lua
exports.noir_shell:DestroyAll()
```

This is particularly useful during:

```text
resource restart
development
error recovery
```

---

# Model Loading

Consumers should never have to manually call:

```lua
RequestModel(...)
```

`Create` should handle model loading internally.

Recommended flow:

```text
validate model
↓
RequestModel
↓
wait until HasModelLoaded
↓
timeout if required
↓
CreateObject
↓
SetModelAsNoLongerNeeded
```

If `ox_lib` is already available in the environment, its model loading helper may be used.

However, `noir_shell` should avoid unnecessary framework coupling.

If practical, implement a very small internal loader.

---

# Model Validation

Before spawning, validate:

```lua
IsModelInCdimage(model)
```

and/or other appropriate model checks.

Invalid model names should fail gracefully.

For example:

```text
[noir_shell] Failed to create shell: invalid model lev_apartmnt_shell
```

Do not create an infinite loading loop.

---

# Collision

Collision handling is one of the main responsibilities of this library.

Consumers should not need to manually implement shell collision loading.

Suggested flow:

```text
CreateObject
↓
RequestCollisionAtCoord
↓
wait for collision
↓
mark shell ready
```

Use appropriate natives based on what is actually required by the shell models.

The implementation should be defensive.

---

# Collision Timeout

Never wait forever.

Example:

```lua
Config.CollisionTimeout = 5000
```

If collision does not become ready:

```text
destroy shell
↓
return error
```

The gameplay resource can then decide how to recover.

---

# Creation Result

Creation should make failure explicit.

Possible design:

```lua
local shell, err = exports.noir_shell:Create({
    model = `lev_apartment_shell`,
    origin = vec4(...)
})

if not shell then
    print(err)
    return
end
```

Avoid silently returning invalid entities.

---

# Error Handling

Expected errors include:

```text
unknown definition
invalid model
model loading timeout
CreateObject failure
collision timeout
invalid origin
destroyed instance access
```

Errors should be understandable during development.

Example:

```text
[noir_shell] Create failed
model: lev_apartment_shell
reason: model_load_timeout
```

---

# Debug Mode

Support:

```lua
Config.Debug = true
```

Potential logs:

```text
[noir_shell] Loading model lev_apartment_shell
[noir_shell] Model loaded
[noir_shell] Creating shell at 1000.0 1000.0 -100.0
[noir_shell] Shell entity created: 42891
[noir_shell] Waiting for collision
[noir_shell] Collision ready
[noir_shell] Shell ready
[noir_shell] Destroying shell 42891
```

Do not spam these logs when debug mode is disabled.

---

# Development Command

A development-only command would be useful.

Example:

```text
/testshell lev_apartment_shell
```

Expected behavior:

```text
create shell
↓
teleport player to shell
↓
allow testing
```

And:

```text
/testshell_exit
```

should:

```text
return player
↓
destroy shell
```

This should be restricted to development/admin usage.

Do not make gameplay depend on these commands.

---

# Offset Development

A future development helper may allow copying shell-relative offsets.

Example workflow:

```text
/testshell lev_apartment_shell
        ↓
walk to desired position
        ↓
/shelloffset
        ↓
clipboard:
vec3(2.321, -1.552, 0.932)
```

This would make it easier to configure:

* entrances;
* exits;
* loot positions;
* beds;
* stashes;
* interaction points;
* wardrobes.

This feature is useful but should not complicate the first version of the runtime library.

---

# Gizmo Support

A future version may integrate a gizmo placement mode.

Example:

```text
Spawn prop
↓
Move with gizmo
↓
Save position
↓
Convert world position to shell-relative offset
```

Potential output:

```lua
{
    model = `prop_tv_flat_01`,

    offset = vec3(
        3.213,
        -1.834,
        1.052
    ),

    rotation = vec3(
        0.0,
        0.0,
        91.4
    )
}
```

This should be implemented separately from the core shell lifecycle.

---

# Resource Stop Cleanup

`noir_shell` must clean up its local instances on resource stop.

Example:

```lua
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    DestroyAllShells()
end)
```

Do not leave orphaned shell entities after restarting the resource.

---

# Consumer Resource Restart

A gameplay resource may stop without `noir_shell` stopping.

The API should make cleanup easy enough that consumers can destroy their shell during their own `onResourceStop`.

For example:

```lua
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    if currentShell then
        currentShell:Destroy()
    end
end)
```

---

# FiveM Enhanced

`noir_shell` is intended to support FiveM Enhanced.

The library itself only handles runtime entity creation.

Asset compatibility remains the responsibility of the shell resource.

For example:

```text
Legacy shell asset
↓
convert/prepare for Enhanced
↓
stream asset
↓
noir_shell creates object
```

`noir_shell` should not perform asset conversion.

---

# Shell Assets

A shell normally requires some combination of:

```text
YDR
YTD
YBN
YTYP
```

A YMAP may be included by shell authors simply to provide a preview or predefined world placement.

For dynamically spawned shells, such YMAP files may not be needed.

The shell resource must still preserve all assets required for:

```text
model
textures
collision
archetype
```

Do not assume every YMAP can be removed without inspecting the asset.

---

# Example: House Robbery

`noir_houserobbery` should eventually be able to do something similar to:

```lua
local shell, err = exports.noir_shell:Create({
    model = robbery.interior.model,
    origin = Config.InteriorOrigin
})

if not shell then
    HandleInteriorFailure(err)
    return
end

local entrance = shell:GetOffset(
    robbery.interior.entranceOffset
)

SetEntityCoords(
    PlayerPedId(),
    entrance.x,
    entrance.y,
    entrance.z
)
```

When leaving:

```lua
shell:Destroy()
```

The robbery resource should not need to call:

```lua
RequestModel()
CreateObject()
FreezeEntityPosition()
RequestCollisionAtCoord()
DeleteEntity()
```

directly.

---

# Example: Drug Lab

The same API can later be reused by another resource:

```lua
local shell = exports.noir_shell:Create({
    model = `drug_lab_shell`,
    origin = Config.InteriorOrigin
})
```

Nothing inside `noir_shell` needs to know whether this shell represents:

```text
a house
a meth lab
an apartment
a warehouse
a robbery
```

That is the responsibility of the consumer.

---

# Example: Registered Shells

Possible registry:

```lua
Config.Shells = {
    lev_apartment = {
        model = `lev_apartment_shell`,

        entranceOffset = vec4(
            1.25,
            -3.11,
            0.10,
            180.0
        )
    },

    tier1_small_01 = {
        model = `tier1_small_01`,

        entranceOffset = vec4(
            ...
        )
    }
}
```

Consumer:

```lua
local shell = exports.noir_shell:CreateFromDefinition(
    'lev_apartment',
    {
        origin = Config.InteriorOrigin
    }
)
```

---

# Configuration

Suggested initial configuration:

```lua
Config = {}

Config.Debug = false

Config.ModelLoadTimeout = 5000

Config.CollisionTimeout = 5000

Config.DefaultOrigin = vec4(
    1000.0,
    1000.0,
    -100.0,
    0.0
)
```

Do not over-configure the first version.

---

# Performance

A dynamically spawned shell should exist only while it is needed.

Example:

```text
0 active interiors
→ 0 local shell entities
```

Instead of permanently loading many placed shells:

```text
server/client starts
→ 20 shell placements exist
```

The exact asset streaming behavior still depends on FiveM and the shell resource, but runtime entities can be created and destroyed as required.

---

# Framework Independence

`noir_shell` should not import:

```text
qb-core
qbx_core
es_extended
housing resources
robbery resources
```

It may optionally use `ox_lib` if the project decides it is an acceptable low-level dependency.

Prefer keeping even that dependency optional when practical.

---

# Naming

Resource name:

```text
noir_shell
```

Suggested exported API:

```text
Create
CreateFromDefinition
DestroyAll
GetActiveInstances
```

Shell instance API:

```text
GetEntity
GetOrigin
GetOffset
TeleportPed
Destroy
IsValid
```

Keep names short and predictable.

---

# Reference: qb-interior

`qb-interior` should be studied as the main implementation reference, especially its handling of:

* shell model loading;
* `CreateObject`;
* `FreezeEntityPosition`;
* shell offsets;
* house robbery interiors;
* teleporting;
* shell cleanup.

The goal is **not to port `qb-interior`**.

The goal is to extract the reusable shell lifecycle concept and create a smaller, framework-independent abstraction suitable for the Noir ecosystem.

---

# First Version Scope

Version `0.1.0` should focus only on:

* creating a shell;
* loading models;
* freezing the shell;
* waiting for collision;
* relative offsets;
* optional ped teleport helper;
* destroying a shell;
* destroying all shells;
* resource stop cleanup;
* debug logging;
* clear errors.

Do not implement yet:

* routing buckets;
* persistence;
* loot;
* housing;
* ownership;
* doors;
* wardrobes;
* stashes;
* database integration;
* session management.

Keep the first release intentionally small.

---

# Acceptance Criteria

The initial implementation is complete when all of the following work:

1. `lev_apartment_shell` can be spawned through `noir_shell`.

2. A second supported shell can be spawned without changing the library code.

3. Shell creation does not require QBCore or Qbox.

4. The shell is local and non-networked by default.

5. Model loading has a timeout.

6. Invalid models fail safely.

7. Collision is available before the shell is reported as ready.

8. A shell-relative offset returns the expected world position.

9. A player can be teleported to an entrance offset.

10. `Destroy()` removes the shell.

11. Calling `Destroy()` multiple times is safe.

12. `DestroyAll()` removes all active shells.

13. Restarting `noir_shell` does not leave shell entities behind.

14. Two shell instances can exist independently when required.

15. Two different resources can consume the library without knowing its internal implementation.

16. `noir_houserobbery` no longer needs to directly manage shell creation once migrated.

---

# Long-Term Direction

The intended dependency structure for Noir is:

```text
                    noir_shell
                    /    |    \
                   /     |     \
                  /      |      \
                 ▼       ▼       ▼

noir_houserobbery   noir_druglabs   noir_motels

        ▼                 ▼              ▼

     gameplay          gameplay        gameplay
      state             state           state
```

`noir_shell` should remain focused on one responsibility:

> **Create and manage temporary shell interiors safely and consistently.**

Everything else belongs to the systems consuming the library.

