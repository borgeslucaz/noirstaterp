# Noir Gangs — Qbox Gang Management Redesign

## 1. Purpose

Replace the default command-heavy Qbox gang management experience with a more immersive and visual system designed for Noir State.

The goal is to keep Qbox as the source of truth for gang membership and grades while replacing normal player-facing management flows with:

- Radial menu interactions
- Nearby-player recruitment
- Visual gang management UI
- Configurable gang management locations
- Rank-based permissions
- Admin-only in-game gang setup tools
- Persistent gang locations
- Audit logs and permission validation

Normal players must **never** use `/gangsetup`.

`/gangsetup` is strictly an administrative/development convenience command used to configure gangs in-game without manually editing coordinates in Lua files.

---

# 2. Design Principles

## 2.1 Qbox remains the source of truth

Do not create a completely separate membership system.

Qbox should continue to own:

- Gang membership
- Gang name
- Gang grade
- Player gang state
- Online/offline gang membership data

`noir_gangs` should act as the gameplay and UI layer around Qbox.

Conceptually:

```text
QBOX
│
├── Gang membership
├── Gang grades
└── Player state
     │
     ▼
NOIR_GANGS
│
├── Visual management
├── Radial actions
├── Permissions
├── Gang locations
├── Invitations
└── Logs
```

---

# 3. Scope

This document covers only **group/gang management**.

It does **not** implement:

- Territory influence
- Drug labs
- Graffiti influence
- Turf wars
- Illegal economy
- Gang business ownership
- Criminal market control

Those systems should be implemented separately and integrate with `noir_gangs` later.

---

# 4. Resource Name

Recommended resource:

```text
noir_gangs
```

Suggested structure:

```text
noir_gangs/
├── client/
│   ├── main.lua
│   ├── radial.lua
│   ├── management.lua
│   ├── setup.lua
│   └── nui.lua
│
├── server/
│   ├── main.lua
│   ├── qbox.lua
│   ├── permissions.lua
│   ├── invitations.lua
│   ├── setup.lua
│   ├── persistence.lua
│   └── logs.lua
│
├── shared/
│   ├── config.lua
│   └── permissions.lua
│
├── web/
│   └── ...
│
├── locales/
│   └── en.json
│
├── migrations/
│   └── noir_gangs.sql
│
└── fxmanifest.lua
```

---

# 5. Remove Command-Driven Player Management

The normal gameplay flow must not depend on commands such as:

```text
/gang
/setgang
```

These commands may remain available for:

- Server console
- Developers
- Administrators
- Emergency recovery/debugging

They must not be part of the normal gang experience.

Normal gang members should interact through UI and contextual actions.

---

# 6. Player Recruitment

## 6.1 Recruitment must be proximity-based

Do not recruit players by server ID.

Bad UX:

```text
/setgang 42 ballas 0
```

Desired UX:

```text
Player A approaches Player B
        ↓
Radial Menu
        ↓
Gang Actions
        ↓
Invite to Gang
```

The system must determine the nearby player internally.

---

# 7. Radial Menu

Integrate gang actions into the existing radial menu system.

Recommended structure:

```text
Gang
├── My Gang
├── Nearby Player
│   ├── Invite to Gang
│   └── Member Actions
└── Quick Info
```

Only show actions that are valid for the current context.

For example:

If the target player is not in the gang:

```text
Invite to Gang
```

If the target is already a member:

```text
Member Actions
├── Promote
├── Demote
└── Remove
```

Actions must also respect the acting player's permissions.

---

# 8. Recruitment Flow

Example:

```text
Marcus Reed
Ballas — Shot Caller

approaches

Andre Mills
No Gang
```

Marcus opens:

```text
Radial
→ Gang
→ Invite to Gang
```

Andre receives:

```text
BALLAS

Marcus Reed wants you to join the gang.

[ ACCEPT ]
[ DECLINE ]
```

If accepted:

```text
Andre Mills joined Ballas.
Initial Rank: Youngin
```

The server performs the Qbox membership update.

---

# 9. Invitation Rules

An invitation must:

- Be initiated while both players are online
- Require proximity
- Expire automatically
- Be validated server-side
- Verify the inviter still has permission when accepted
- Verify the target is still eligible
- Prevent duplicate invitations
- Prevent invitation spam

Recommended defaults:

```lua
Config.Invitation = {
    maxDistance = 3.0,
    duration = 30,
    cooldown = 10,
}
```

Never trust the client-provided target or gang blindly.

The server must validate:

```text
source
target
distance
gang
permissions
membership
```

---

# 10. Initial Rank

Every gang must define a default recruitment grade.

Example:

```lua
defaultGrade = 0
```

Possible presentation:

```text
Grade 0 → Youngin
Grade 1 → Member
Grade 2 → Enforcer
Grade 3 → Shot Caller
Grade 4 → OG
```

The displayed rank names should come from Qbox gang grade configuration whenever possible.

---

# 11. Gang Management Point

Each gang may have one or more management locations.

Examples:

- Gang house
- Back room
- Clubhouse
- Office
- Warehouse
- Hideout

A player approaches the configured location:

```text
Manage Gang
```

Only authorized gang members may open the management UI.

---

# 12. No Mandatory Tablet

Do not design the resource around a physical tablet item.

The management UI is contextual.

For example:

```text
Ballas
→ wall / desk / gang spot

Lost MC
→ clubhouse table

Mafia
→ office desk

Cartel
→ back office
```

All may open the same backend/UI while using different world interaction points.

The UI must therefore not visually require a tablet frame.

---

# 13. Management UI

Initial version should focus on group administration only.

Main view:

```text
BALLAS

8 MEMBERS
4 ONLINE

Leader
Marcus Reed

[ MEMBERS ]
[ HIERARCHY ]
[ PERMISSIONS ]
[ ACTIVITY ]
```

---

# 14. Members View

Example:

```text
MEMBERS

Marcus Reed
OG
ONLINE

Darius King
Shot Caller
ONLINE

Andre Mills
Member
OFFLINE

Tyler Brown
Youngin
OFFLINE
```

Do not display server IDs.

Never present:

```text
Player ID: 42
```

Use character names.

---

# 15. Member Details

Selecting a member:

```text
Andre Mills

Rank
Member

Status
Offline

Joined
August 23, 2026

Last Seen
Yesterday

[ PROMOTE ]
[ DEMOTE ]
[ REMOVE ]
```

Available actions depend on permissions and hierarchy.

---

# 16. Promotion and Demotion

Promotion/demotion may happen from:

1. Gang Management UI
2. Nearby-player radial interaction

Both must use the same server-side service.

Example internal operation:

```text
ChangeMemberGrade(
    actor,
    target,
    newGrade
)
```

Do not duplicate business logic between NUI and radial handlers.

---

# 17. Hierarchy Protection

A player must not be able to manage another member with an equal or higher protected rank unless explicitly allowed.

Recommended baseline:

```text
OG
  ↓ manages
Shot Caller
  ↓ manages
Enforcer
  ↓ manages
Member
  ↓ manages
Youngin
```

Example:

```text
Enforcer cannot remove Shot Caller.
Shot Caller cannot demote OG.
```

The highest rank should have special protection.

---

# 18. Permission System

Avoid hardcoding every action as:

```lua
if grade >= 3 then
```

Create semantic permissions.

Recommended permissions:

```lua
invite
remove_member
promote
demote
view_members
view_offline_members
manage_permissions
manage_ranks
manage_management_points
```

Future permissions may include:

```lua
access_stash
manage_vehicles
access_labs
manage_business
manage_territory
```

---

# 19. Permission Example

```lua
Config.DefaultPermissions = {
    [0] = {
        view_members = true,
    },

    [1] = {
        view_members = true,
    },

    [2] = {
        view_members = true,
        invite = true,
    },

    [3] = {
        view_members = true,
        view_offline_members = true,
        invite = true,
        remove_member = true,
        promote = true,
        demote = true,
    },

    [4] = {
        view_members = true,
        view_offline_members = true,
        invite = true,
        remove_member = true,
        promote = true,
        demote = true,
        manage_permissions = true,
        manage_ranks = true,
    }
}
```

Qbox grade remains authoritative.

`noir_gangs` adds permission semantics on top.

---

# 20. Gang Activity Log

Store management-related activity.

Examples:

```text
23:42
Marcus Reed promoted Andre Mills
Member → Enforcer

22:18
Darius King invited Tyler Brown

21:55
Marcus Reed removed James Walker
```

Log at minimum:

- Invitation sent
- Invitation accepted
- Invitation declined
- Member joined
- Member removed
- Promotion
- Demotion
- Permission change
- Management point change by admin

---

# 21. Admin-Only `/gangsetup`

## CRITICAL REQUIREMENT

`/gangsetup` is **ADMIN ONLY**.

Normal gang leaders, bosses, members or players must never have permission to use it.

Gang grade must not grant access.

Being a gang boss must not grant access.

This command exists only to make server administration easier.

---

# 22. `/gangsetup` Authorization

Use ACE permissions or another server-authoritative admin permission.

Recommended ACE:

```text
noir.gangsetup
```

Example server.cfg:

```cfg
add_ace group.admin noir.gangsetup allow
```

Server-side validation is mandatory.

Never rely only on hiding the command client-side.

Example logic:

```lua
if not IsPlayerAceAllowed(source, 'noir.gangsetup') then
    return
end
```

---

# 23. Gang Setup UI

When an administrator executes:

```text
/gangsetup
```

Open an administrative setup interface.

Example:

```text
GANG SETUP

Select Gang:
Ballas

Management Points
[ Add Management Point ]

Other Locations
[ Add Stash ]
[ Add Garage ]

Danger Zone
[ Remove Location ]
```

For the initial implementation, only **Management Point** is required.

Stash and garage may be added later.

---

# 24. Creating a Management Point

Admin workflow:

```text
/gangsetup
      ↓
Select Ballas
      ↓
Add Management Point
      ↓
Admin moves to desired position
      ↓
Confirm Position
```

Capture:

```lua
coords = GetEntityCoords(PlayerPedId())
heading = GetEntityHeading(PlayerPedId())
```

Optionally allow editing:

```text
Width
Depth
Height
Rotation
Interaction Distance
```

Recommended default size:

```lua
vec3(1.5, 1.5, 1.5)
```

---

# 25. Placement Preview

When placing a management point, show a temporary preview zone.

Recommended controls:

```text
E       Confirm
BACKSPACE Cancel
Mouse Wheel Rotate
Arrow Keys Fine Position
```

Optional developer visualization:

- Transparent box
- Marker
- Debug outline

This visualization must only exist during admin setup mode.

---

# 26. Gang Selection

The setup UI should read available gangs from the server/Qbox configuration.

Do not require the admin to type:

```text
ballas
```

Prefer:

```text
Select Gang

Ballas
Families
Vagos
Lost MC
```

Store the internal gang key separately from the display label.

Example:

```text
label: Ballas
name: ballas
```

---

# 27. Persistence

Management locations created through `/gangsetup` must survive resource/server restarts.

Do not rely only on runtime registration.

Persist them in SQL.

Recommended table:

```sql
CREATE TABLE IF NOT EXISTS noir_gang_locations (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    gang_name VARCHAR(64) NOT NULL,
    location_type VARCHAR(32) NOT NULL,
    x DOUBLE NOT NULL,
    y DOUBLE NOT NULL,
    z DOUBLE NOT NULL,
    heading FLOAT NOT NULL DEFAULT 0,
    size_x FLOAT NOT NULL DEFAULT 1.5,
    size_y FLOAT NOT NULL DEFAULT 1.5,
    size_z FLOAT NOT NULL DEFAULT 1.5,
    created_by VARCHAR(128) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_noir_gang_locations_gang (gang_name),
    INDEX idx_noir_gang_locations_type (location_type)
);
```

Initial location type:

```text
management
```

Future types:

```text
stash
garage
vehicle_spawn
meeting_point
safehouse
```

---

# 28. Startup Registration

On resource start:

```text
Load locations from SQL
        ↓
Register interaction zones
        ↓
Make them available to authorized gang members
```

If using `qbx_management` boss menu registration internally, register them again during resource startup.

Persistence belongs to `noir_gangs`.

Runtime registration alone is not sufficient.

---

# 29. Multiple Management Points

Support multiple management points per gang.

Example:

```text
Ballas
├── Davis House
└── Warehouse Office
```

This costs little architecturally and avoids having to redesign the database later.

---

# 30. Delete / Move Management Point

Admin should be able to:

```text
/gangsetup
→ Ballas
→ Management Points
```

See:

```text
#12 Davis House
#23 Warehouse
```

Actions:

```text
Teleport To
Move
Delete
```

All operations require admin permission.

---

# 31. Normal Player Permissions

Normal players may:

```text
Open gang management UI
Invite players
Promote/demote
Remove members
View roster
```

only according to gang permissions.

Normal players may NOT:

```text
Create management points
Move management points
Delete management points
Run /gangsetup
Change world coordinates
Configure another gang
```

---

# 32. Gang Boss Is Not Server Admin

This distinction must exist everywhere.

Example:

```text
Ballas OG
```

may have:

```text
invite = true
promote = true
remove_member = true
manage_ranks = true
```

but:

```text
gangsetup = false
```

`gangsetup` is not a gang permission.

It is a server administration permission.

---

# 33. Radial Menu Visibility

Recommended behavior:

### Player has no gang

Do not show gang management options.

### Player is gang member

Show:

```text
Gang
→ My Gang
```

### Nearby eligible player exists and actor has invite permission

Show:

```text
Gang
→ Invite Nearby Player
```

### Nearby same-gang member exists

Show permitted member actions.

---

# 34. Nearby Player Resolution

Do not trust a client-submitted arbitrary server ID.

Client may suggest a nearby target.

Server must validate:

```text
Actor exists
Target exists
Both online
Distance <= configured max
Actor belongs to gang
Actor has permission
Target is eligible
```

---

# 35. Server-Side Service Layer

Recommended server functions:

```lua
GangService.InviteMember(actorSource, targetSource)

GangService.AcceptInvitation(targetSource, invitationId)

GangService.RemoveMember(actorSource, citizenId)

GangService.PromoteMember(actorSource, citizenId)

GangService.DemoteMember(actorSource, citizenId)

GangService.SetMemberGrade(actorSource, citizenId, grade)

GangService.GetMembers(actorSource)

GangService.GetGangInfo(actorSource)
```

Setup:

```lua
GangSetup.CreateLocation(adminSource, gangName, data)

GangSetup.UpdateLocation(adminSource, locationId, data)

GangSetup.DeleteLocation(adminSource, locationId)

GangSetup.GetLocations(adminSource, gangName)
```

---

# 36. Do Not Trust NUI

Every NUI callback is untrusted.

For example:

```text
NUI requests:
promote citizen ABC
```

Server must independently verify:

```text
Who is the actor?
What gang are they in?
What grade do they have?
Do they have promote permission?
Is ABC in the same gang?
Can they manage ABC's grade?
Is the requested grade valid?
```

Only then call Qbox.

---

# 37. Admin Setup Security

Every setup mutation must verify:

```text
IsPlayerAceAllowed(source, "noir.gangsetup")
```

including:

- Create
- Move
- Delete
- Teleport
- Change gang assignment

Do not perform this check only when `/gangsetup` is opened.

Check again for every server mutation.

---

# 38. Suggested Events

Client → Server:

```text
noir_gangs:server:invite
noir_gangs:server:acceptInvite
noir_gangs:server:declineInvite
noir_gangs:server:promote
noir_gangs:server:demote
noir_gangs:server:removeMember
```

Admin:

```text
noir_gangs:server:createLocation
noir_gangs:server:updateLocation
noir_gangs:server:deleteLocation
```

Server → Client:

```text
noir_gangs:client:invitation
noir_gangs:client:openManagement
noir_gangs:client:refreshManagement
noir_gangs:client:setupMode
```

Names are examples and may be adjusted to match project conventions.

---

# 39. Suggested Exports

Future resources should not need to know Qbox internals.

Recommended exports:

```lua
exports('GetGang', GetGang)

exports('HasGangPermission', HasGangPermission)

exports('GetGangMembers', GetGangMembers)

exports('GetGangManagementLocations', GetGangManagementLocations)
```

Future territory and illegal systems can integrate through these exports.

---

# 40. UX Requirements

The system should feel like an in-world gang management experience, not an admin panel.

Avoid:

- Server IDs
- Debug terminology
- Qbox internals
- Raw grade numbers
- `/setgang`
- Command-driven recruitment
- Tablet dependency

Prefer:

- Character names
- Rank labels
- Online/offline indicators
- Nearby interactions
- Confirmation dialogs
- Contextual world locations

---

# 41. Visual Direction

Use the Noir State NUI design language.

Recommended characteristics:

- Minimal
- Dark
- Compact
- Clean typography
- Low visual noise
- No oversized tablet frame
- No fake futuristic operating system
- No corporate dashboard styling

The same UI can later receive organization-specific presentation.

Example:

```text
Street Gang
→ gang roster / board feeling

Motorcycle Club
→ club ledger

Mafia
→ office roster
```

The backend remains identical.

---

# 42. Confirmation Dialogs

Dangerous actions require confirmation.

Example:

```text
Remove Andre Mills from Ballas?

[ CANCEL ]
[ REMOVE ]
```

Promotion:

```text
Promote Andre Mills

Member
→ Enforcer

[ CANCEL ]
[ CONFIRM ]
```

---

# 43. Notifications

Example invitation:

```text
Ballas

Marcus Reed invited you to join the gang.
```

Promotion:

```text
You were promoted to Enforcer.
```

Removal:

```text
You are no longer a member of Ballas.
```

Admin setup:

```text
Management point created for Ballas.
```

---

# 44. Logging

Every management action should have structured server logs.

Recommended payload:

```lua
{
    action = 'gang_member_promoted',
    actor = actorCitizenId,
    target = targetCitizenId,
    gang = 'ballas',
    oldGrade = 1,
    newGrade = 2,
    timestamp = os.time()
}
```

Administrative setup logs should include:

```text
Admin identifier
Gang
Location ID
Coordinates
Action
Timestamp
```

---

# 45. Suggested Database Tables

## Gang locations

```text
noir_gang_locations
```

Required.

## Gang activity

Optional but recommended:

```sql
CREATE TABLE IF NOT EXISTS noir_gang_activity (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    gang_name VARCHAR(64) NOT NULL,
    action VARCHAR(64) NOT NULL,
    actor_citizenid VARCHAR(64) NULL,
    target_citizenid VARCHAR(64) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_noir_gang_activity_gang_created (gang_name, created_at)
);
```

Do not duplicate Qbox's gang membership database unless necessary.

---

# 46. Admin Setup Example

Full expected flow:

```text
Admin:
/gangsetup
```

UI:

```text
GANG SETUP

Select Organization
→ Ballas
```

Then:

```text
BALLAS

Management Points

[ + ADD POINT ]
```

Admin chooses add.

System enters placement mode.

```text
Move to the desired location.

[E] Confirm
[BACKSPACE] Cancel
```

Admin confirms.

Server validates ACE.

SQL:

```text
gang_name = ballas
type = management
coords = ...
```

Zone is created immediately.

No restart required.

---

# 47. Player Example

Marcus is Ballas grade 3.

He visits the configured management point.

Interaction:

```text
Manage Gang
```

UI:

```text
BALLAS

Members: 8
Online: 4

Members
Hierarchy
Activity
```

He selects Andre.

```text
Andre Mills
Member

[ Promote ]
[ Demote ]
[ Remove ]
```

Promotion is validated server-side and executed through Qbox.

---

# 48. Recruitment Example

Marcus approaches Tyler.

Radial:

```text
Gang
→ Invite to Ballas
```

Tyler:

```text
Marcus Reed wants you to join Ballas.

Accept
Decline
```

Tyler accepts.

Qbox membership becomes:

```text
gang = ballas
grade = 0
```

UI/log:

```text
Tyler Brown joined Ballas as Youngin.
```

No command is exposed to either player.

---

# 49. Acceptance Criteria

## Recruitment

- [ ] Authorized member can recruit a nearby player
- [ ] Recruitment does not require player ID
- [ ] Target can accept or decline
- [ ] Invitation expires
- [ ] Server validates distance
- [ ] Server validates permission
- [ ] Qbox gang membership updates correctly
- [ ] Activity is logged

## Management UI

- [ ] Authorized player can open management at configured location
- [ ] Member list displays character names
- [ ] Online/offline state is visible
- [ ] Server IDs are never displayed
- [ ] Promotion works
- [ ] Demotion works
- [ ] Removal works
- [ ] Hierarchy restrictions are enforced
- [ ] Permissions are validated server-side

## Radial

- [ ] Gang actions appear contextually
- [ ] Invite appears only when allowed
- [ ] Member actions appear only for same-gang nearby members
- [ ] Unauthorized actions are hidden
- [ ] Hidden actions are still protected server-side

## `/gangsetup`

- [ ] Command exists only for administrators
- [ ] ACE permission is required
- [ ] Gang boss status does not grant access
- [ ] Admin can select a gang
- [ ] Admin can place a management point
- [ ] Coordinates persist in SQL
- [ ] Location becomes usable immediately
- [ ] Locations reload after resource/server restart
- [ ] Admin can move existing locations
- [ ] Admin can delete existing locations
- [ ] All mutations revalidate admin permission server-side

---

# 50. Testing Scenarios

## Unauthorized player attempts `/gangsetup`

Expected:

```text
Access denied.
```

No setup NUI is opened.

---

## Gang boss attempts `/gangsetup`

Even if:

```text
gang = ballas
grade = highest
```

Expected:

```text
Access denied.
```

Gang hierarchy has no relation to server setup permissions.

---

## Admin uses `/gangsetup`

Expected:

```text
Gang setup UI opens.
```

---

## Player forges create-location event

Expected:

```text
Server rejects request because noir.gangsetup ACE is missing.
```

---

## Enforcer tries to promote OG

Expected:

```text
Rejected by hierarchy validation.
```

---

## Player invites someone 100 meters away by forged event

Expected:

```text
Rejected by server distance validation.
```

---

# 51. Future Extensions

Do not implement these in the first version, but design APIs so they can be added later:

```text
Gang stash
Gang garage
Gang vehicles
Territory
Influence
Graffiti
Drug labs
Gang businesses
Gang finances
Motorcycle clubs
Organization-specific UI themes
Temporary alliances / diplomacy rules
Criminal reputation
```

---

# 52. Implementation Priority

## Phase 1

```text
Qbox integration
Permission service
Nearby invitation system
Radial actions
```

## Phase 2

```text
Management point
Members UI
Promote/demote/remove
Activity log
```

## Phase 3

```text
Admin-only /gangsetup
SQL persistence
Placement mode
Move/delete points
```

## Phase 4

```text
Polish
Animations
Notifications
Organization-specific visual presentation
```

---

# 53. Final Architecture

```text
                           QBOX
                             │
                   membership / grades
                             │
                             ▼
                       noir_gangs
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
       RADIAL          MANAGEMENT UI       ADMIN SETUP
          │                  │                  │
     recruit           members/ranks        /gangsetup
     nearby            permissions          locations
     actions            activity            persistence
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                        SERVER SERVICE
                             │
                     server-side checks
                             │
                        Qbox updates
```

---

# 54. Non-Negotiable Rules

1. Qbox remains the membership source of truth.
2. Normal players do not need `/gang` or `/setgang`.
3. Recruitment is proximity-based and visual.
4. Server IDs are hidden from normal gameplay.
5. Every sensitive action is validated server-side.
6. Gang hierarchy is separate from server administration.
7. `/gangsetup` is **ADMIN ONLY**.
8. Gang bosses cannot use `/gangsetup` unless they separately have the required server admin ACE.
9. Management point coordinates persist in SQL.
10. Normal gangs cannot move or create their own management points.
11. The UI must not require a tablet aesthetic.
12. The architecture must remain ready for future territory and illegal economy systems.

