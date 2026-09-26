# DRS Vehicle Shop

`drs_vehicleshop` is the DRS-maintained, server-authoritative multi-shop vehicle
seller based on QR Development's `qr-vehicleshop`. It supports Qbox and QB, integrates
first with `drs_garages`, and retains a `lunar_garage` fallback for legacy installations.
It includes auto, boat, and aircraft dealerships plus the reworked ox_lib-style NUI.

The runtime resource name must be exactly `drs_vehicleshop`. Its event and callback
namespace is `drs_vehicleshop:*`.

Do not run `drs_vehicleshop` and `qr-vehicleshop` together. Both resources would create
the same dealership interactions and operate on the same owned-vehicle and purchase data.

For a transition period, the client accepts the legacy
`qr-vehicleshop:client:openShop` entry point and reads the two legacy QR state-bag keys
when recovering an entity. All DRS-owned calls and newly written state use the
`drs_vehicleshop` namespace. Financial server callbacks are not exposed under legacy
aliases.

## What changed in 1.0.1-drs.9

- Added police `polmav` aircraft and `predator` watercraft to the police society
  fleet catalogue.
- Added ambulance `frogger` aircraft and `seashark2` watercraft to the ambulance
  society fleet catalogue.
- Restricted the police aircraft and watercraft definitions to the police group
  when they are exposed through public shop browsing.
- Passes the journaled vehicle type to DRS Garages for independent validation
  against the selected car, boat, or aircraft fleet garage.

No database migration is required for this release.

## Purchase and delivery architecture

The client submits configured option ids, a bounded optional prefix, shop id, and model
name to request a short-lived quote. The server resolves all color/plate indexes,
prices, access policy, dealership distance, garage, final plate, and spawn location
from trusted configuration. Purchase accepts the quote id rather than client-supplied
props or totals, then revalidates the complete quote before payment.

A successful purchase follows this sequence:

1. Atomically reserve a unique plate and create a durable
   `drs_vehicle_shop_orders` journal entry containing the exact options and total.
2. Debit the configured account using a stable character identity.
3. Create the owned `player_vehicles` row in a stored state with trusted initial props.
4. Create the delivery entity on the server and journal its network id.
5. Commit `stored = 0` and `state = 0`, then register the exact entity with the garage.
6. Persist through `qbx_vehicles`, issue keys, and return a one-use handoff token.
7. Mark the order delivered only after the client proves that it received the expected
   model, plate, entity control, and driver seat.

Blocked spawns, failed garage registration, failed persistence, failed keys, handoff
timeouts, disconnects, and resource stops converge to the owned vehicle being stored.
The server independently creates, tracks, expires, geofences, and removes test-drive
vehicles. No public client event can grant keys, choose a plate, upload ownership props,
or create an owned vehicle.

Money exports and SQL cannot participate in one atomic transaction. The journal uses
claimed refund states to prevent duplicate automatic credits. A crash while a payment
or refund export is executing is deliberately moved to `payment_review` or
`refund_review`; staff should verify the framework transaction history before changing
those rows. Never blindly replay a review-state order.

## Requirements and start order

OneSync is required. For Qbox, use:

```cfg
ensure oxmysql
ensure ox_lib
ensure qbx_core
ensure qbx_vehicles
ensure qbx_vehiclekeys
ensure ox_target
ensure drs_garages
ensure drs_vehicleshop
```

For QB, start `qb-core`, your configured target, and `qb-vehiclekeys` instead of the
Qbox equivalents. The integration prefers `drs_garages` whenever it is started and
falls back to `lunar_garage` for existing installations. Do not run both garage
resources together. `Config.GarageIntegration = 'drs'` requires a compatible garage:
it fails delivery closed when neither compatible garage is available and safely leaves
the purchase stored. Use `ensure lunar_garage` in the start order only for the legacy
resource.

`drs_vehicleshop` also exposes `ResolveVehiclePresentation` on the client. Companion
resources can use it to obtain the configured vehicle name, brand, and ordered image
candidates without copying this resource's vehicle artwork. The export is presentation
only and does not grant access to purchase or ownership actions.

## Society fleet checkout

Version `1.0.1-drs.7` adds an opt-in-by-job, Qbox-first society purchase service for
the DRS Garages fleet manager. `Config.Fleet.Enabled` is true in the supplied
configuration, but every request fails closed unless all of the following are true:

- the framework resolves to Qbox;
- the fleet journal migrated and reconciled successfully;
- `drs_garages` (or the explicitly configured replacement) is started and its
  fleet journal reports ready through `GetJobFleetServiceStatus`;
- Renewed Banking or QB Banking resolves through `Config.Fleet.BankProvider`;
- the caller resource is present in `Config.Fleet.AllowedCallers`;
- the acting player still has the exact requested job, is its boss, meets the
  configured grade, and is on duty when `RequireOnDuty` is enabled; and
- the requested model is in that exact job's `Config.Fleet.Catalogs` allowlist.

The included `police` and `ambulance` rules deliberately contain only a small stock
vehicle set. Add add-on models explicitly, or add a category only when every model in
that category should be purchasable by that job. Prices always come from
`Config.Vehicles`; the calling resource cannot supply an amount, plate, hash, vehicle
properties, society account, or banking provider.

The service has no public client callback. The trusted DRS Garages server integration
uses these exports:

```lua
local catalog = exports.drs_vehicleshop:GetFleetCatalog({
    actorSource = source,
    job = 'police'
})

local purchase = exports.drs_vehicleshop:PurchaseFleetVehicle({
    requestId = durableRequestId, -- 8-64 safe characters; reuse it for every retry
    actorSource = source,
    action = 'society_purchase',
    job = 'police',
    model = 'police3',
    garageIndex = 1              -- one-based Config.Garages index in drs_garages
})
```

`GetFleetCatalog` returns only server-resolved models, display fields, prices, the
current society balance, and provider. `PurchaseFleetVehicle` journals the immutable
authority/model/destination fingerprint and its optional audit reason, confirms the
society debit, and then calls DRS Garages'
idempotent `CreateJobFleetVehicle` export. A committed result is authoritative even
when the garage also reports that one of its final journal writes needs review.

After a restart or an uncertain garage response, the catalogue may include
`recovery = { requestId, model, garageIndex, status, retryable = true }`. This covers
an interrupted pre-debit order, a confirmed debit awaiting creation, and retryable
creation-review states. DRS Garages binds the new server-side purchase session to that
original request and model, allowing the creation export to replay without charging
the society a second time. A recovery catalogue for an already-debited order remains
available even if the original banking provider is temporarily down.

`GetFleetServiceStatus` is available to allowlisted callers so DRS Garages Doctor can
verify the fleet journal, garage creation bridge, and society banking provider instead
of treating a merely started shop resource as a healthy paid-checkout service. It also
reports unresolved/review order counts and whether the selected bank durably
acknowledges society balance mutations. Idempotency binds the stable Qbox `citizenid`,
so the same authorized boss can resume a journaled request after reconnecting with a
different ephemeral server ID without a second society debit.

`auto` prefers `qb-banking` when it is available because its current balance-mutation
exports return oxmysql's awaited affected-row result. Renewed-Banking is supported for
Qbox servers, but its current exports return success before their asynchronous database
update is durably confirmed; Doctor reports that provider as a best-effort warning.

The separate `drs_vehicle_shop_fleet_orders` journal prevents ownerless job purchases
from entering the personal-purchase recovery path, which assumes a player
`citizenid`. A crash during a society debit becomes `payment_review`; a confirmed
debit recorded before creation can be safely refunded; a crash while the garage export
is running becomes `creation_review` and is replayed with the same request id; and a
crash during a refund becomes `refund_review`. Never manually refund a review-state
order without checking the banking history and the matching DRS Garages fleet
operation first. Admin grants do not use this paid service and remain protected by the
DRS Garages ACE policy.

## Database

Database setup is automatic. On startup, the resource waits for oxmysql and then:

- creates `player_vehicles` only when the framework has not already created it;
- adds missing Qbox/QB garage compatibility columns without rebuilding the table;
- renames the completed QR build's journal tables and named indexes to the DRS names;
- creates or upgrades the purchase journal and plate-reservation table;
- creates and verifies the separate durable society fleet-purchase journal;
- aligns both purchase-journal tables to the charset/collation used by
  `player_vehicles.plate`;
- verifies the required InnoDB engines, indexes, and global plate uniqueness; and
- reconciles interrupted orders before enabling checkout.

Back up an established database and stop both vehicle-shop resources before the first
startup with this version. The one-time identity migration renames
`qr_vehicle_shop_orders` to `drs_vehicle_shop_orders` and
`qr_vehicle_shop_plate_reservations` to `drs_vehicle_shop_plate_reservations` in place,
preserving every pending payment, refund, ownership, and delivery record. It then renames
the QR-owned indexes. If an old and new table both exist, the resource disables purchases
and asks for manual reconciliation; it never guesses, merges, or deletes financial data.

The database account used by oxmysql needs `CREATE`, `ALTER`, `INDEX`, `DROP`, and
`INSERT` privileges for the first DRS upgrade. Those extra privileges can be removed
after one successful restart. If the runtime account intentionally lacks schema
privileges, an administrator must first verify that the DRS table names do not already
exist, run this one-time rename, and then run `qbox_drs_vehicle_columns.sql`:

```sql
RENAME TABLE
    `qr_vehicle_shop_orders` TO `drs_vehicle_shop_orders`,
    `qr_vehicle_shop_plate_reservations` TO `drs_vehicle_shop_plate_reservations`;
```

Do not run that statement when any DRS-named destination table already exists. The
runtime migrator also renames the legacy index names and verifies their definitions;
the MariaDB fallback creates the matching DRS indexes before removing the old QR-named
indexes. Before using that fallback, review `SHOW INDEX` for both journal tables and
confirm that any existing DRS-named index has the uniqueness and column order declared
in the file; `IF NOT EXISTS` checks names, not definitions. `drs_vehicleshop.sql` is a
fresh-install reference schema, not an upgrade script. Do not import either SQL file
over an existing production database without reviewing its current schema.

Other automatic upgrades remain repeatable: they do not replace existing foreign keys,
delete vehicles, or guess how duplicate plates should be repaired. Duplicate legacy
plates or incompatible schemas keep purchases disabled and produce an actionable server
log instead.

Plate reservation and order creation share one transaction. Reservations remain in
place through ambiguous payment, refund, or ownership states and are released only
after verified ownership or a conclusive pre-ownership terminal.

## Important configuration

Main settings live in `config.lua`:

```lua
Config.Framework = 'auto'                  -- auto, qbox, qb
Config.Target = 'auto'                     -- auto, ox_target, qb-target
Config.KeySystem = 'auto'                  -- auto, qbx_vehiclekeys, qb-vehiclekeys, none
Config.GarageIntegration = 'drs'           -- drs (DRS/legacy interface), auto, none
Config.PaymentAccount = 'cash'
Config.DeliverPurchasedVehicles = true
Config.DeliveryAcknowledgementTimeout = 25000
Config.HandoffTransition = {
    enabled = true,
    fadeOut = 350,
    fadeIn = 650,
    settle = 400,
    collisionTimeout = 2500,
    maxBlackout = 22000,
    spinner = true
}
Config.DefaultGarages = {
    car = 'pillboxgarage',
    boat = 'lsymcboathouse',
    air = 'airporthangar'
}
```

Set `Config.DeliverPurchasedVehicles = false` to stage every purchase directly in its
garage. The DRS/Lunar garage config contains matching `pillboxgarage`,
`lsymcboathouse`, and `airporthangar` locations.

`Config.HandoffTransition` controls the client-side fade used while a test-drive or
drive-away vehicle streams, receives its trusted properties, and seats the player.
Every wait is bounded; failures fade back in and use the existing safe cleanup or
garage fallback. Keep `DeliveryAcknowledgementTimeout` and
`Config.TestDrive.handoffTimeout` long enough to cover the configured transition.
For an active test drive, the client owns the normal faded return;
`Config.TestDrive.returnFallbackTimeout` is the delayed server safety teleport used
only when that return does not complete.

### Factory checkout

`Config.Checkout` controls the checkout catalogue and fees. Its `colors`,
`plateStyles`, and `deliveryModes` entries use stable `id` values for NUI requests;
their GTA `index` and `price` values are resolved only on the server. The included
defaults provide ten curated colors (premium paint is `$1,500`–`$2,500`), a `$7,500`
custom prefix, three optional `$1,000` plate styles, and free drive-away/garage
delivery. `featuredColorIds` chooses the five finishes presented as swatches without
removing the remaining colors from the server allowlist. Change these amounts and
featured ids to fit your economy.

Prefixes accept one to three uppercase letters or numbers and are available only to
road vehicles. `platePrefix.blocked` contains exact reserved prefixes. Boats and
aircraft retain server-generated registrations and do not expose road plate styles.
The final plate is never chosen by the client.

`quoteLifetime` controls how long a quote can be submitted, `quoteCooldown` limits NUI
quote spam, and `resultLifetime` keeps durable purchase results idempotent for retries.
Changing a model, option, permission, delivery capability, or price after a quote was
created causes purchase to fail and require a fresh quote. `driveaway` is automatically
removed when direct delivery is disabled or the shop has no spawn location; `garage`
must remain configured as the safe fallback.

`Config.Shops` defines each dealership's trusted categories, ped, blip, interaction,
test-drive, delivery, and garage locations. Each shop's `defaultCategory` controls its
initial catalogue class; a valid last-viewed/test-driven vehicle takes precedence and
reopens its own class. The ordered `categories` list also controls the category order
shown in the UI. `config.lua` is the sole authoritative settings file and contains the
vanilla GTA catalogue. The subsequently loaded `config-addons.lua` contains only custom
spawn names and safely merges models that are not already registered, so it cannot
overwrite active settings or vanilla entries.
Vanilla/add-on classification was checked against the current Cfx.re Vehicle Models
reference and current dumped game metadata, including official DLC models omitted
from the documentation index.

Version `1.0.1-drs.8` exposes the emergency catalogue in the public auto shop. The server
allows only members of the exact `police` group at grade 0 or higher to quote, purchase,
or test drive those vehicles:

```lua
Config.CategoryAccess = {
    emergency = { groups = { police = 0 } }
}
```

Category visibility is controlled separately by each shop's `categories` list, so other
players can browse the emergency catalogue but receive a server authorization error if
they attempt a protected action. These are personal purchases; department-owned society
fleet purchases continue through the protected DRS Garages integration described above.
The service category remains unexposed until it is added to a shop and given an access
rule appropriate for that server.

## Vehicle imagery

Vanilla vehicles use the official Cfx render for their lowercase spawn model and then
fall back to a bundled file. Add-on vehicles prefer a bundled image, then try the Cfx
render, and finally show a styled unavailable-render state instead of a broken image.
The catalogue probes and caches each candidate and only hydrates cards near the visible
scroll area.

Save new custom renders as:

```text
html/assets/vehicles/<lowercase-spawn-model>.webp
```

Use a consistent `960 x 536` WebP canvas. No config edit is needed when the filename
matches the spawn model. An explicit `image = 'another-name.webp'` remains available
for a verified alias.

The current image audit found valid official renders for every vanilla entry and valid
local renders for 347 of 398 add-ons. These 51 add-on models still need an exact
in-game capture:

```text
dilet, panto2, vorstand, algoschafter, df8, eaglesedan, onx_buffalostx8,
pmp900, vors, granger3, onx_granger, onx_scoutc, ametista, libraw,
onx_domgtcoupe, turmalina, turmalina2, gstsulbe1, stardust, vs2301,
vzr1501, vzr3501, vzr3801, bjxlr, burritopw, onx_guardian,
onx_guardian2, onx_guardian3, onx_guardian4, onx_verus, l35l, l35r,
l35s, onx_sandking4, onx_sandstorm, yosemite3step, windsor3,
gbemsbisonstx, gbpolstarlight, gbpoltahomagt, gbpolturismogt,
onx_polcoq3, onx_poldorado2, onx_polgrang, onx_polguard,
onx_polguard2, onx_polguard3, onx_polguard4, onx_polkandra,
onx_poltulip, onx_snowsandk
```

Accurate generation requires those vehicle packs to be started in a development FiveM
server. Capture them from a fixed camera, lighting, rotation, and paint setup; an
ACE-restricted development command can save WebPs with `screenshot-basic`. Do not use
AI approximations for sale inventory because they can misrepresent the actual add-on
model. Neither the custom model packs nor `screenshot-basic` are included in this
workspace.

## Restart behavior

DRS Vehicle Shop journals every in-progress delivery. On startup it restores interrupted owned
vehicles to stored state and removes only a matching journaled entity. DRS Garages
rebuilds its active cache by matching live world entities against trusted plate/model
rows, so a garage-only restart does not blanket-mark still-live vehicles stored.

For deployment, back up the database and restart the resources in the order above.
DRS Vehicle Shop applies and verifies its migration before accepting quotes or purchases.
Only servers whose oxmysql account lacks schema-alter privileges need the manual SQL fallback.
Review any personal `payment_review`, `refund_review`, `ownership_review`, or
`delivery_review` rows and any fleet `payment_review`, `creation_review`, or
`refund_review` rows with the corresponding server logs before changing journal state
or issuing money manually.

## Attribution and license

This is a modified fork of [QR Development's `qr-vehicleshop`](https://github.com/QRDevelopment/qr-vehicleshop).
DRS maintains the Qbox/QB compatibility, DRS Garages integration, secure checkout and
delivery workflow, purchase recovery, multi-shop configuration, interface changes, and
the `drs_vehicleshop` runtime namespace.

The original MIT license and RaySist copyright notice are retained in `LICENSE`. See
`NOTICE.md` for the fork notice. The unused QR Development logo from the source package
was removed because it does not represent DRS releases.
