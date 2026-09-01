Noir House Robbery — Tier 1 Implementation Specification

Resource

noir_houserobbery

Status

Initial implementation / Tier 1 MVP.

This document defines the first version of the Noir house robbery system. The resource must be built by using qbx_houserobbery as the technical foundation and selectively porting the burglary gameplay concepts from TheIndra55/fivem-burglary.

The intention is not to install both resources side by side and connect them with events. noir_houserobbery should become a single clean Qbox-native resource.

1. Primary Goal

Create a low-tier residential burglary loop with the following experience:

The player uses noir_burnerphone.

The player sends a message to a configured criminal contact number.

The contact returns the location of one available Tier 1 house.

The player travels to the assigned house.

The player lockpicks the front door.

The player enters an instanced interior based on the existing Qbox house robbery architecture.

A resident may be sleeping inside.

A visible NOISE meter becomes active while inside the house.

Movement and robbery actions generate noise.

Excessive noise can wake the resident.

Small searchable loot can continue using the Qbox-style loot system.

Large physical props must be physically picked up and carried out of the house.

A carried prop can be stored in any valid nearby car; there is no Boxville requirement.

Once the player leaves or the robbery reaches an end condition, the mission is finalized and the house enters cooldown.

The central gameplay concept is:

Enter quietly, steal what is worth the risk, avoid waking the resident, and physically move valuable objects from the house to a vehicle.

2. Source Projects

2.1 Technical base — Qbox house robbery

Repository:

https://github.com/Qbox-project/qbx_houserobbery

Use this project as the main starting point for:

Qbox integration;

resource structure;

house configuration;

interior configuration;

routing buckets;

server-side distance validation;

house state synchronization;

loot point generation;

physical pickup configuration;

skill checks;

fingerprints/evidence hooks where compatible;

existing Qbox conventions.

Important existing files to study before changing behavior:

config/shared.lua

config/client.lua

config/server.lua

client/main.lua

server/main.lua

The current Qbox resource already separates searchable loot points from physical pickups. Preserve that distinction.

Do not rewrite the whole system from scratch unless a Qbox implementation is fundamentally incompatible with the new design.

2.2 Gameplay reference — FiveM Burglary

Repository:

https://github.com/TheIndra55/fivem-burglary

Relevant files:

burglary/houses.lua

burglary/client.lua

burglary/gameplay/pickups.lua

Use this project as the gameplay reference for:

burglary-style interiors;

initial exterior house locations;

sleeping residents;

resident hearing behavior;

native stealth noise;

physical objects placed in the interiors;

attaching stolen props to the player;

box-carry animation;

preserving the carried prop while leaving the interior.

Do not port its old mission architecture directly.

Specifically, do not port:

Boxville-only mission requirements;

its old ESX integration;

global burglary blips;

its old time/money reward flow;

unrestricted client-authoritative logic;

old UI helpers when ox_lib or Noir UI can replace them.

3. Licensing

qbx_houserobbery is GPL-3.0 licensed.

Because noir_houserobbery is being created as a derivative of that resource:

retain the applicable GPL-3.0 license;

do not remove upstream copyright/license notices;

document the Qbox origin in the resource README.

fivem-burglary is MIT licensed.

If actual code is copied or substantially adapted from it rather than merely reimplementing the idea:

retain the required MIT attribution/license notice for that code.

Do not copy code without preserving its license requirements.

4. Scope of This Milestone

This milestone implements Tier 1 only.

The architecture should make tier = 1, tier = 2, and tier = 3 possible later, but Tier 2 and Tier 3 gameplay must not be implemented yet.

Included

noir_burnerphone contract request;

server-selected target house;

temporary GPS location/blip;

six initial exterior burglary locations;

burglary interior templates;

lockpick entry;

Qbox routing bucket system;

searchable small loot;

physical large loot;

carrying props outside;

storing carried objects in any car;

noise meter;

sleeping residents;

resident wake-up logic;

configurable resident reactions;

server-authoritative mission/loot state;

house cooldown;

disconnect/death cleanup;

debug tooling for development.

Explicitly not included yet

burglary bag / duffel bag;

Tier 2 houses;

Tier 3 houses / mansions;

advanced alarm panels;

CCTV disabling;

safes;

hacking laptops;

criminal reputation requirements;

gang influence;

fence/pawn-shop economy redesign;

house scouting system;

police investigation UI;

persistent physical cargo rendered inside vehicles;

complex multi-player crew contracts.

Do not expand the scope before Tier 1 is stable.

5. Tier Model

Every house must already have a tier field even though only Tier 1 is currently enabled.

Example:

{
    id = 'grove_01',
    tier = 1,
    ...
}

Future code should be able to perform:

local tierConfig = Config.Tiers[house.tier]

instead of scattering checks like:

if house.id == 1 then

This is important because the resource will eventually contain three distinct house robbery tiers.

6. Tier 1 Gameplay Flow

NOIR BURNER PHONE
       |
       | send message to criminal number
       v
HOUSE ROBBERY CONTACT
       |
       | validates eligibility
       | chooses available house
       v
GPS LOCATION RECEIVED
       |
       v
TRAVEL TO HOUSE
       |
       v
LOCKPICK DOOR
       |
       +---- failed ---> optional noise / lockpick consequence
       |
       v
ENTER HOUSE
       |
       +--> routing bucket
       +--> generate loot
       +--> spawn resident
       +--> start noise meter
       |
       v
STEALTH BURGLARY
       |
       +--> search small loot
       |
       +--> pick up physical valuables
       |
       +--> generate noise
       |
       +--> resident may wake
       |
       v
LEAVE HOUSE CARRYING OBJECT
       |
       v
ANY NEARBY CAR
       |
       v
STORE OBJECT IN VEHICLE
       |
       v
RETURN FOR MORE OR LEAVE
       |
       v
MISSION END / HOUSE COOLDOWN

7. noir_burnerphone Integration

7.1 Principle

House robberies must not begin by approaching random houses and receiving an interaction automatically.

For the Tier 1 MVP, a player must first obtain a target through noir_burnerphone.

The burner phone acts as the criminal job discovery mechanism.

7.2 Do not invent Burner Phone APIs

The agent implementing this resource already has project context for noir_burnerphone.

Before implementing this integration:

inspect the current noir_burnerphone resource;

identify its existing server/client exports and events;

identify how incoming/outgoing messages are represented;

identify how phone numbers are represented;

identify whether messages can contain GPS/location payloads;

reuse the existing system.

Do not create a second phone messaging implementation inside noir_houserobbery.

Do not hardcode an assumed burner phone event name from this document.

7.3 Create an integration adapter

Keep phone-specific code isolated.

Recommended structure:

noir_houserobbery/
└── server/
    └── integrations/
        └── burnerphone.lua

The rest of the house robbery system should interact with a small internal API such as:

RequestHouseContract(source)
SendHouseLocation(source, contract)
SendContractMessage(source, message)

Those names are examples of internal functions, not required public APIs.

This keeps future phone changes isolated from burglary logic.

7.4 Criminal contact

Add a configurable contact definition.

Conceptually:

Config.BurnerContact = {
    enabled = true,
    number = '...',
}

Use the actual Noir burner-phone number format already present in the project.

The accepted message/request text should also follow the current noir_burnerphone design and remain configurable where appropriate.

7.5 Contract request flow

When the criminal contact receives a valid request:

Server must verify:

player exists;

player does not already have an active house contract;

player is not currently inside another house robbery instance;

global/player cooldown permits a new contract;

at least one Tier 1 house is available;

selected house is not already reserved/active;

any future eligibility hook returns true.

Then:

select a random eligible house;

create a server-side contract id;

reserve the house;

associate the contract with the player's citizen id/source;

send a burner phone reply;

include the location through the existing phone GPS/location mechanism;

create a temporary route/blip only for the contract owner as appropriate to the phone flow.

Do not send all available house locations.

The player receives one target.

8. Contract State

Avoid relying only on client variables.

Maintain authoritative server state.

Suggested conceptual model:

ActiveContracts[citizenid] = {
    id = 'uuid-or-server-generated-id',
    houseId = 'grove_01',
    tier = 1,
    state = 'assigned',
    createdAt = os.time(),
    enteredAt = nil,
    ownerSource = source,
}

House state:

HouseState[houseId] = {
    status = 'available', -- available/reserved/active/cooldown
    contractId = nil,
    cooldownUntil = nil,
    loot = {},
    pickups = {},
}

Recommended contract states:

assigned
arrived
breaching
inside
looting
escaped
completed
failed
cancelled

Not every state needs a network event. The purpose is to keep lifecycle logic understandable.

9. Initial Exterior House Locations

Start with the same six exterior door locations configured by fivem-burglary.

These are temporary initial test/content locations and should be moved into Noir configuration rather than referenced directly from the other resource.

Noir ID

Burglary interior

Exterior coordinates

tier1_01

1

vec3(-46.34, -1446.24, 32.43)

tier1_02

2

vec3(-139.48, -1588.042, 34.24)

tier1_03

2

vec3(257.11, -1723.26, 29.65)

tier1_04

3

vec3(455.21, -1579.75, 32.79)

tier1_05

1

vec3(256.57, -2023.59, 19.27)

tier1_06

4

vec3(-93.44, -1787.61, 28.82)

These locations come from:

fivem-burglary/burglary/houses.lua

Do not expose all six as map blips.

Only the currently assigned contract location should be shown.

10. Initial Interior Templates

The original fivem-burglary defines four initial interior layouts.

For the first Noir implementation, keep the same concept so development can focus on systems instead of content creation.

Interior 1

Entry approximately:

265.53, -1002.90, -99.90

Exit approximately:

265.985, -1007.247, -101.008

This overlaps closely with the first Qbox robbery interior and can reuse the Qbox implementation where possible.

Interior 2

Entry approximately:

346.798, -1009.72, -100.09

Exit approximately:

346.420, -1012.641, -99.196

This also overlaps with an existing Qbox robbery interior.

Interior 3

Entry approximately:

151.85, -1005.84, -99.99

Exit approximately:

151.29, -1007.59, -99.0

Add this as a proper Noir interior template rather than forcing the exterior onto an unrelated Qbox interior.

Interior 4

Entry approximately:

172.76, -1006.09, -99.0

Exit approximately:

172.9, -1008.34, -99.0

Add this as a proper Noir interior template as well.

11. Qbox Routing Bucket Architecture

Preserve the Qbox approach of instancing house interiors using routing buckets.

The current Qbox implementation:

teleports the player to the configured interior exit/entry coordinate;

assigns a house routing bucket through Qbox;

restores bucket 0 on exit;

validates the player position server-side.

Keep this design.

However, avoid assuming the existing numeric bucket values will always remain unique.

Provide a clear Noir allocation strategy.

For example:

routingBucket = Config.BaseRoutingBucket + houseIndex

or use the project's existing bucket allocator if one already exists.

Do not allow arbitrary client-selected bucket ids.

12. House Entry Requirements

Tier 1 requires an active burner-phone contract.

A player should only be able to breach the specific house assigned by the server.

Entry validation must happen server-side.

Minimum checks:

active contract exists
contract house == attempted house
house is reserved for this contract
player is close to exterior door
house is Tier 1
house is not on cooldown
player has required lockpick
player is not already inside another robbery

Keep Qbox's existing lockpick integration where possible.

Do not trust a client event like:

TriggerServerEvent('noir_houserobbery:server:enterHouse', arbitraryHouseId)

without checking the player's active contract and physical location.

13. Police Alert Behavior Change

The stock qbx_houserobbery can alert police immediately after a successful entry.

That behavior should not remain the default for Noir Tier 1.

The entire point of Tier 1 is stealth.

A clean successful entry should not automatically guarantee a dispatch.

Police notification should instead come from events such as:

serious lockpick failure, if configured;

outside witness system, if later implemented;

resident waking up;

resident reaching a successful 911-call state;

other explicit burglary mistakes.

Keep dispatch integration behind a function/adapter so the actual police dispatch resource can change later.

14. Noise System

14.1 Goal

The player should constantly decide between speed and stealth.

Noise is represented as a Noir-owned value:

0 ------------------------------------------------ 100

The UI appears only while the player is inside an active robbery interior.

14.2 Reference implementation

fivem-burglary displays:

GetPlayerCurrentStealthNoise(PlayerId())

through its noise bar while the player is inside the burglary area.

Use the native stealth-noise value as an important input, but do not make the Noir meter a direct visual copy of the raw native value.

Noir needs additional noise generated by explicit robbery actions.

14.3 Noir noise accumulator

Maintain:

currentNoise = 0.0 -- 0-100

The final meter should combine:

GTA native stealth noise
        +
movement behavior
        +
robbery actions
        +
failed actions
        -
noise decay when quiet

All values must be configurable.

Initial tuning proposal:

Action

Noise effect

standing still

decay

slow/sneak movement

very low

normal walking

low

running

medium continuous

sprinting

high continuous

jumping

+10

bump/impact

configurable

searching drawer

+3

searching cabinet

+5

taking small item

+3

picking up large prop

+8

dropping large prop

+15

failed interior skill check

+15

loud break/forced action

+20 to +30

These are initial balancing values, not hardcoded constants.

14.4 Suggested thresholds

0 - 29
Quiet
Resident remains asleep.

30 - 49
Noticeable
Resident may briefly stir but remains asleep.

50 - 69
Risk
Periodic wake-up checks begin.

70 - 89
Danger
High probability of waking the resident.

90 - 99
Critical
Very high probability of waking the resident.

100
Resident wakes immediately.

Do not make 100 noise automatically equal police dispatch.

Noise wakes the resident.

The resident's behavior determines whether police are contacted.

14.5 Noise decay

Noise must fall while the player is quiet.

Example concept:

player stops moving
    -> short grace period
    -> currentNoise slowly decreases

This allows a player to stop, listen, and recover instead of the meter functioning only as an irreversible timer.

Keep a minimum decay rate configurable.

15. Noise UI

Create a small Noir-styled UI rather than copying the old timerbar directly.

MVP example:

NOISE
██████░░░░  58

Requirements:

minimal;

no large panel;

displayed only inside an active house robbery;

update smoothly;

hide immediately on exit/death/resource stop;

no permanent HUD footprint.

The UI should support future thresholds visually, but do not over-design the first iteration.

A simple NUI component is acceptable.

Avoid sending NUI messages every frame if the value has not meaningfully changed.

16. Residents

16.1 Reference

fivem-burglary defines residents per interior and spawns them using a sleeping animation.

The reference uses:

amb@lo_res_idles@
lying_face_up_lo_res_base

and configures hearing/seeing/alertness on the ped.

Use the same idea, cleaned up for the Noir architecture.

16.2 Resident configuration

Each interior should support zero or more resident spawn definitions.

Example structure:

residents = {
    {
        coords = vec4(...),
        models = {
            'a_m_y_beach_02',
            'a_f_y_hipster_01',
        },
        spawnChance = 0.75,
        reaction = 'random',
    }
}

Do not hardcode one exact ped model forever.

16.3 Tier 1 spawn chance

Not every Tier 1 house must contain a resident.

Initial recommendation:

resident chance: 60-80%

Keep this configurable globally and overridable per interior/house.

One of the original burglary interior templates intentionally has no resident; retain support for this.

16.4 Resident states

Use an explicit state machine.

SLEEPING
   |
   | noise rises
   v
STIRRING
   |
   | wake condition
   v
AWAKE
   |
   +--> FLEE
   +--> HIDE / CALL 911
   +--> CONFRONT
   +--> ARMED CONFRONTATION (rare)

Do not use a single boolean residentAwake for all behavior if it makes reactions difficult to extend.

16.5 Initial reaction probabilities

Initial proposed Tier 1 tuning:

60% - frightened / flee and attempt to call police
20% - hide and attempt to call police
15% - verbally confront / move toward exit
 5% - armed confrontation

All probabilities must be configurable.

This is an initial gameplay proposal and should be easy to rebalance.

16.6 Armed resident

fivem-burglary already demonstrates aggressive residents and can give an aggressive ped a pistol.

For Noir Tier 1:

armed reaction must be rare;

weapon choice must be configurable;

do not guarantee perfect NPC aim;

do not make every resident combat-focused;

do not spawn an armed resident simply because noise reaches 100.

The goal is tension, not an NPC shooting gallery.

17. Resident Police Call

Waking up should not instantaneously teleport a dispatch alert to police.

Prefer a short behavior sequence:

resident wakes
      |
      v
reaction chosen
      |
      +--> reaches safe location / gets phone
                    |
                    v
                calls 911
                    |
                    v
                dispatch

For MVP this can be simplified internally, but preserve a configurable delay before dispatch.

This gives the burglar a small opportunity to escape before police are notified.

Do not implement mechanics that encourage or reward killing the resident to cancel dispatch.

18. Loot Categories

Keep the Qbox distinction between two types of loot.

18.1 Search loot

Small items discovered by interacting with furniture/search points.

Examples:

cash
watch
phone
jewelry
small electronics
keys
misc valuables

For the current milestone, these can continue entering the player's inventory normally.

There is no burglary bag yet.

This is intentionally temporary and can be changed when the bag system is implemented.

18.2 Physical carry loot

Large/visible objects that should not instantly enter the player's inventory when stolen.

Examples:

TV
microwave
large speaker
computer
large monitor
valuable case
large electronics

These must follow the physical carry flow.

19. Physical Carry System

19.1 Reference

fivem-burglary/gameplay/pickups.lua attaches the stolen prop to the player and uses:

anim@heists@box_carry@

as the carry animation.

Use this concept.

Do not reuse its Boxville-specific destination logic.

19.2 Picking up an object

Current Qbox behavior gives the configured pickup reward directly to the player after the pickup progress completes.

For Noir physical pickups, change this.

New flow:

interact with physical pickup
        |
        v
server validates pickup
        |
        v
server reserves pickup
        |
        v
client hides/removes original interior prop
        |
        v
client creates/attaches carry prop
        |
        v
player is now HOLDING ITEM

Do not grant the final item to the player at this point.

19.3 Carry restrictions

While holding a large item:

force unarmed state;

prevent weapon switching;

use carry animation;

prevent normal vehicle entry while appropriate;

prevent initiating another pickup;

prevent searching another loot point if animation/state conflicts;

preserve held object when teleporting through the house exit;

restore animation after the interior-to-exterior teleport if GTA cancels it.

The original burglary script explicitly restarts the carry animation after leaving the interior. Preserve this behavior conceptually.

19.4 Carry token

Never let the client invent the reward item.

When the server approves a pickup, create a short-lived server-side carry record/token.

Example concept:

ActiveCarry[citizenid] = {
    contractId = contract.id,
    houseId = contract.houseId,
    pickupId = pickupId,
    reward = pickup.reward,
    model = pickup.model,
    createdAt = os.time(),
}

The final vehicle deposit must match this server record.

20. Any-Car Storage

20.1 Major difference from fivem-burglary

The original burglary resource starts the mission using specific Boxville models and stores the mission vehicle in currentVan.

Its physical pickup flow then calculates a point behind that specific mission van and only accepts the item there.

Remove this entire vehicle restriction.

Noir Tier 1 must have:

NO mission vehicle whitelist
NO Boxville requirement
NO currentVan contract dependency

Any valid nearby car can be used to store stolen physical loot.

20.2 Vehicle detection

When the player is outside the robbery interior and holding an object:

identify a nearby networked vehicle;

calculate its trunk/rear interaction position;

prefer the boot bone when available;

fall back to a rear vehicle offset when the model has no usable trunk bone;

show Store stolen item only when the player is sufficiently close.

Do not whitelist vehicle models.

The implementation must work with ordinary player-owned and ambient/networked cars where the inventory system supports them.

20.3 Storage destination

Because the Noir/Qbox environment uses ox_inventory, the preferred implementation is to convert the carried object into its configured stolen inventory item inside the selected vehicle's trunk inventory, not the player's inventory.

Conceptual flow:

PLAYER HOLDING TV
        |
        v
rear of nearby vehicle
        |
        v
Store stolen item
        |
        v
server validates vehicle + carry token
        |
        v
check/load trunk inventory
        |
        v
CanCarryItem(trunk, reward)
        |
   +----+----+
   |         |
  yes        no
   |         |
   v         v
AddItem    keep holding
(trunk)    + notify full
   |
   v
mark pickup stolen
   |
   v
delete carry prop

Relevant ox_inventory APIs include server-side GetInventory, CanCarryItem, and AddItem, while client-side trunk opening uses a network vehicle id.

Follow the current installed ox_inventory API and Noir inventory conventions rather than hardcoding undocumented inventory ids.

20.4 Vehicle validation

Server must validate at least:

active carry record exists;

carry belongs to current contract;

carried pickup has not already been completed;

target vehicle network id resolves to a vehicle;

player is physically close to target vehicle;

player is outside the interior instance / at the expected exterior context;

trunk inventory can accept the item;

reward item comes from server config, not the client request.

Client should send only identifiers required to locate the target vehicle/pickup, never arbitrary reward data.

20.5 Vehicle ownership

Do not require the burglar to own the car.

A stolen car, friend's car, or other usable vehicle may be used.

That is intentional.

Vehicle ownership may matter later for persistence or investigation, but it is not a Tier 1 requirement.

21. House Loot Configuration

Preserve Qbox's useful data-driven approach.

Recommended Noir structure:

Config.Interiors = {
    tier1_small_01 = {
        tier = 1,
        entry = vec4(...),
        exit = vec4(...),

        loot = {
            -- searchable loot points
        },

        pickups = {
            -- physical carry props
        },

        residents = {
            -- sleeping resident definitions
        },
    }
}

And:

Config.Houses = {
    {
        id = 'tier1_01',
        tier = 1,
        interior = 'tier1_small_01',
        coords = vec3(...),
    }
}

Avoid mixing dynamic runtime state directly into immutable configuration when possible.

Prefer:

Config.Houses
+
Runtime HouseState

over constantly mutating the config table.

22. Loot Randomization

Keep the useful Qbox behavior of selecting only a subset of configured loot/pickups per robbery.

Example Tier 1 target:

Configured search points: 7
Active this robbery: 3-6

Configured physical pickups: 4
Active this robbery: 1-3

The player should not learn that every specific table always contains the same object.

Randomization must happen server-side or be server-approved.

23. Fingerprints / Evidence

The current Qbox resource already has fingerprint hooks and glove detection.

Preserve this integration if the existing evidence resource is still part of Noir.

Do not let the new burglary mechanics accidentally remove useful Qbox evidence behavior.

Potential actions that may leave evidence:

lockpicking door;

searching furniture;

handling physical props;

dropping an item;

interacting with vehicle trunk.

Do not expand evidence scope excessively in the first milestone; just preserve compatibility and make extension points obvious.

24. Cooldowns

Implement at least:

Per-house cooldown

After a contract ends, the selected house cannot immediately be assigned again.

Per-player contract cooldown

Prevent requesting contracts continuously from the burner phone.

Keep values configurable.

Example only:

Config.Cooldowns = {
    player = 15 * 60,
    house = 30 * 60,
}

Do not treat these exact numbers as final balancing values.

25. Failure / Cleanup Conditions

Handle these cases explicitly.

Player disconnects

clear active carry token;

remove/reschedule contract reservation;

return house to cooldown or available state according to config;

ensure routing bucket state cannot remain relevant after reconnect;

clean spawned client props/peds naturally on resource/player cleanup.

Player dies inside

hide noise UI;

cancel carry state;

finalize/abort contract;

restore bucket safely if necessary;

prevent duplicated physical pickup reward.

Resource restarts

UI must disappear;

held local props must be deleted;

residents must be removed;

stale server reservations must be cleared/rebuilt;

no player should remain permanently trapped in a robbery bucket.

Vehicle disappears while depositing

do not complete reward;

keep or safely cancel the carry state;

never duplicate the pickup.

Trunk full

item remains carried;

display a short notification;

player may choose another car.

26. Security Requirements

This resource handles an economy-producing activity and must assume hostile clients.

Never trust client-provided

house eligibility;

house tier;

reward item;

reward amount;

pickup completion;

loot completion;

contract ownership;

vehicle distance;

target pickup state;

cooldown status.

Server validations

All reward-producing server events must verify:

player
contract
house
state
position
bucket/context
loot/pickup id
busy/opened state
carry token
vehicle proximity when applicable

Continue following the Qbox server validation style instead of converting gameplay into client-only logic.

27. Recommended Resource Structure

noir_houserobbery/
├── fxmanifest.lua
├── LICENSE
├── README.md
│
├── config/
│   ├── shared.lua
│   ├── tiers.lua
│   ├── houses.lua
│   ├── interiors.lua
│   ├── loot.lua
│   └── residents.lua
│
├── client/
│   ├── main.lua
│   ├── entry.lua
│   ├── interior.lua
│   ├── loot.lua
│   ├── carry.lua
│   ├── noise.lua
│   ├── residents.lua
│   └── ui.lua
│
├── server/
│   ├── main.lua
│   ├── contracts.lua
│   ├── houses.lua
│   ├── loot.lua
│   ├── carry.lua
│   ├── cooldowns.lua
│   └── integrations/
│       ├── burnerphone.lua
│       └── dispatch.lua
│
├── web/
│   ├── index.html
│   ├── app.js
│   └── style.css
│
└── locales/

This is a recommended split, not a requirement to create excessive tiny files.

Prefer clear responsibilities over file count.

28. Event Namespace

Rename internal Qbox house robbery event names to the Noir namespace.

Use:

noir_houserobbery:client:...
noir_houserobbery:server:...

Do not blindly rename external integration events that belong to other resources.

For example, if the existing lockpick resource emits an external event that Qbox listens to, preserve the external compatibility contract and route it internally.

29. Suggested Internal Events / Callbacks

Names below are recommendations for consistency.

noir_houserobbery:server:requestContract
noir_houserobbery:client:contractAssigned

noir_houserobbery:server:attemptEntry
noir_houserobbery:server:enterHouse
noir_houserobbery:server:leaveHouse

noir_houserobbery:server:checkLoot
noir_houserobbery:server:finishLoot

noir_houserobbery:server:beginCarry
noir_houserobbery:server:cancelCarry
noir_houserobbery:server:storeCarryInVehicle

noir_houserobbery:client:startNoise
noir_houserobbery:client:stopNoise
noir_houserobbery:client:wakeResident

noir_houserobbery:server:residentCalledPolice

Again: these are internal naming suggestions. Do not create unnecessary network events where a local function or server callback is safer.

30. Debug Mode

Development will be much easier with a guarded debug mode.

Add:

Config.Debug = false

When enabled for authorized developers, support helpers such as:

assign specific test house
teleport to assigned exterior
enter selected interior
force resident spawn
set noise value
wake resident
spawn all configured pickups
clear house cooldown
print current contract state
print current carry state

These must not be usable by normal players in production.

Prefer ACE/admin permission or existing Noir developer permission checks.

31. Implementation Phases

Implement in this order.

Phase 1 — Fork and clean Qbox base

copy/fork qbx_houserobbery into noir_houserobbery;

preserve license;

rename internal namespace;

verify the resource still starts;

verify existing Qbox entry/loot/exit behavior before large changes.

Definition of done: stock behavior works under the new resource name.

Phase 2 — Replace house list with Tier 1 burglary locations

add six exterior locations from fivem-burglary;

add four interior templates;

map each exterior to its correct initial interior;

add tier = 1 to all houses;

verify routing buckets.

Definition of done: each of the six test houses can be entered and exited without bucket/interior issues.

Phase 3 — Burner phone contracts

inspect noir_burnerphone integration;

create burner phone adapter;

receive valid request message;

server selects/reserves one house;

send location back through burner phone;

only assigned target can be breached.

Definition of done: player can request a job through the phone and receives exactly one working target location.

Phase 4 — Noise meter

implement 0-100 Noir noise accumulator;

integrate GetPlayerCurrentStealthNoise(PlayerId());

add movement contribution;

add action spikes;

implement decay;

create minimal Noise NUI;

start/stop it with robbery lifecycle.

Definition of done: sneaking is visibly quieter than running and robbery actions visibly affect the meter.

Phase 5 — Sleeping residents

port the resident concept from fivem-burglary;

create resident config per interior;

spawn sleeping NPC;

implement wake thresholds/checks;

implement initial reaction state machine;

connect successful 911 reaction to dispatch adapter.

Definition of done: a quiet player can complete a robbery without waking the resident, while a loud player reliably risks waking them.

Phase 6 — Physical carry loot

change selected Qbox pickups so they do not immediately grant inventory rewards;

implement carry token server state;

attach configured prop to player;

apply box carry animation;

preserve carried prop through interior exit;

prevent duplicate pickup.

Definition of done: player can pick up a configured large object inside and physically walk out holding it.

Phase 7 — Any-car trunk deposit

remove Boxville/currentVan assumptions;

detect nearest valid vehicle rear/trunk;

validate network vehicle server-side;

integrate with vehicle trunk inventory;

store configured stolen item in the selected vehicle;

handle full trunk;

delete carried prop only after successful server confirmation.

Definition of done: the same stolen TV can be carried to and stored in different ordinary vehicle models without model-specific configuration.

Phase 8 — Cleanup/security pass

disconnect testing;

death testing;

resource restart testing;

event spam testing;

distance exploit testing;

duplicate pickup testing;

full trunk testing;

two players requesting same house testing;

cooldown testing.

Definition of done: no easy reward duplication and no persistent broken bucket/mission state.

32. Acceptance Criteria — Tier 1 MVP

The Tier 1 milestone is complete when all of the following are true:

Resource is named noir_houserobbery.

It is based on the Qbox resource rather than running Qbox and burglary resources together.

Qbox/GPL license requirements are preserved.

fivem-burglary attribution is preserved if its MIT code is reused.

Six initial burglary exterior locations are configured.

Four burglary-style interior templates are available.

Every initial house is explicitly tier = 1.

Player requests a robbery through noir_burnerphone.

Burner phone returns one specific house location.

Player cannot use another unassigned house as the current contract target.

House contract/reservation is server-authoritative.

Lockpick entry still works through the project's lockpick system.

Successful quiet entry does not automatically dispatch police.

Player is moved to a valid routing bucket.

Noise UI appears only while inside the robbery.

Noise responds to native stealth movement.

Robbery actions add additional noise.

Noise decays while player remains quiet.

Sleeping resident can spawn.

Resident can remain asleep during a quiet robbery.

Excessive noise can wake resident.

Resident has a configurable reaction.

Resident reaction can eventually produce police dispatch.

Small search loot still works.

Large physical loot does not immediately enter player inventory.

Player can physically carry a configured object out of the house.

Carry animation survives the interior exit transition.

No Boxville or mission-vehicle whitelist exists.

Player can approach an ordinary nearby car and store carried loot.

Server validates the target vehicle and carry token.

Car trunk capacity is respected where supported by the inventory system.

The physical prop is removed only after successful storage.

Full trunk does not destroy or duplicate the carried item.

A pickup cannot be rewarded twice.

House enters cooldown after robbery completion/failure according to config.

Player contract cooldown exists.

Disconnect cleanup works.

Death cleanup works.

Resource restart cleanup works.

33. Future Tier Hooks — Do Not Implement Yet

The Tier 1 architecture must not block later expansion.

Expected future direction:

Tier 2

Likely additions:

better houses
advanced lockpick
alarm panel
larger physical loot
safe
higher resident/security risk
higher police requirement/heat

Tier 3

Likely additions:

luxury homes / mansions
preparation/intelligence
security system
CCTV
hacking
multiple alarm layers
high-value safe
organized group gameplay

Do not implement these systems during Tier 1.

Just avoid architecture that assumes every house behaves exactly like Tier 1 forever.

34. Important Design Decisions

These decisions are intentional and should not be changed without discussing them first.

1. Qbox is the technical base

Do not replace it with the old burglary script architecture.

2. Burglary is a gameplay reference

Port useful mechanics cleanly into the Noir/Qbox architecture.

3. Burner phone assigns the target

The phone is part of the crime loop, not an optional notification layer.

4. No burglary bag yet

Small searchable loot may use inventory during the MVP.

5. Large objects are physical

They must be carried out of the house.

6. Any car can be used

There is no Boxville requirement and no mission vehicle whitelist.

7. Noise wakes residents

Noise does not directly equal police dispatch.

8. Residents create the dispatch consequence

The gameplay chain should be:

noise -> resident wakes -> resident reacts -> possible 911 -> police

9. Server owns economy state

Client animation/UI may be client-side, but contracts, pickups, rewards, cooldowns, and vehicle deposits must be validated server-side.

10. Build Tier 1 cleanly before Tier 2/3

The goal of the first iteration is to prove the burglary loop, not to implement the entire criminal progression system at once.

35. Reference Summary for the Implementing Agent

Before coding, study these specific upstream behaviors.

qbx_houserobbery

config/shared.lua

Study:

interiors;

loot points;

pickups;

house-to-interior mapping;

routing bucket configuration;

randomized setup counts.

client/main.lua

Study:

handleHousePickup;

handleHouseLoot;

setupLoot;

entrance/exit handling;

fingerprint behavior.

server/main.lua

Study:

nearest-house validation;

enterHouse;

Qbox bucket assignment;

checkLoot / lootFinished;

checkPickup / pickupFinished;

server-side position checks;

runtime loot generation.

Then change physical pickup reward semantics so pickupFinished no longer immediately puts a large object in player inventory.

fivem-burglary

burglary/houses.lua

Study:

four interior definitions;

six initial exterior doors;

pickup coordinates/models;

resident positions/models;

sleeping animation.

burglary/client.lua

Study:

GetPlayerCurrentStealthNoise(PlayerId()) usage;

spawning/removing residents;

SetPedHearingRange;

sleeping animations;

aggressive resident concept;

preserving held animation after teleporting outside.

burglary/gameplay/pickups.lua

Study:

AttachEntityToEntity pickup behavior;

anim@heists@box_carry@;

disabling weapon switching while carrying;

carry state management;

recovery/deposit concept.

Explicitly replace its currentVan/Boxville recovery logic with the Noir any-car trunk implementation.

Final Target Experience

A correct Tier 1 implementation should feel approximately like this:

Player opens burner phone.

"Need work."

A few moments later the contact replies with a location.

The player drives there in whatever vehicle they chose.
They pick the lock and quietly enter the house.

A resident is asleep in the bedroom.

NOISE  ███░░░░░░░  27

The player searches a drawer.

NOISE  ████░░░░░░  35

They walk instead of sprinting.
Noise slowly falls.

They find a television.
They physically pick it up.

NOISE  ██████░░░░  58

They walk to the exit carrying the TV.
The TV remains in their hands outside.

Their own car happens to be parked nearby, but it could have been any usable car.
They walk to the rear of the vehicle and store the television.

The item is validated by the server and stored in the vehicle cargo/trunk.

The player decides whether going back inside for another item is worth increasing the risk of waking the resident.

That risk/reward decision is the core of Noir Tier 1 house burglary.
