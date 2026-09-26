# citgo_dealership

A premium vehicle dealership resource for QBCore & QBox FiveM servers. Features a glassmorphic UI with vehicle browsing, photo thumbnails, color customization, custom license plates, vehicle financing with credit score tiers, and automatic repossession.

## Features

- **Glassmorphic UI** - Modern dark glass-panel design with smooth animations
- **Vehicle Thumbnails** - Automatic vehicle photos via uz_AutoShot integration
- **Category Browsing** - Filter vehicles by class (Compacts, Sedans, SUVs, Sports, Super, etc.)
- **Search & Sort** - Find vehicles by name, brand, or model; sort by price or name
- **Color Customization** - Pick from 112 GTA vehicle colors for primary and secondary paint
- **Custom License Plates** - Choose your own plate (up to 8 characters) with real-time availability checking
- **Vehicle Financing** - Credit score-based loan system powered by tgg-banking
- **Auto Repossession** - Vehicles automatically repossessed after missed loan payments
- **Multi-Dealership** - Configure multiple dealership locations with separate inventories
- **NPC Dealers** - Optional NPC shopkeepers at each location
- **3D Preview** - Full orbit camera with rotate, zoom, and height controls
- **Dual Framework** - Automatic QBCore / QBox (qbx_core) detection
- **Flexible Interaction** - core_focus context menus (default), ox_target sphere zones, or ox_lib radial menu

## Dependencies

| Resource | Required | Notes |
|----------|----------|-------|
| [qb-core](https://github.com/qbcore-framework/qb-core) or [qbx_core](https://github.com/Qbox-project/qbx_core) | Yes | Auto-detected at runtime |
| [oxmysql](https://github.com/overextended/oxmysql) | Yes | Database queries |
| [ox_lib](https://github.com/overextended/ox_lib) | Yes | Shared utilities |
| [uz_AutoShot](https://uz-scripts.com/) | Yes | Vehicle photo thumbnails |
| [tgg-banking](https://tgg.gg/) | Optional | Required only if financing is enabled |
| [core_focus](https://github.com/DotzDev/core_focus) | Optional | Default interaction method |
| [ox_target](https://github.com/overextended/ox_target) | Optional | Alternative interaction |

## Installation

1. Drop `citgo_dealership` into your resources folder
2. Import `vehshop.sql` into your database:
   ```sql
   mysql -u root -p your_database < vehshop.sql
   ```
3. Add to your `server.cfg`:
   ```cfg
   ensure oxmysql
   ensure ox_lib
   ensure uz_AutoShot
   ensure citgo_dealership
   ```
4. Configure dealership locations in `config.lua`

## Setting Up Vehicle Photos (uz_AutoShot)

citgo_dealership uses **uz_AutoShot** to display vehicle thumbnail photos in the browsing UI. Without these photos, vehicles will show placeholder cards.

### Step-by-Step Photo Setup

1. **Install uz_AutoShot** - Drop it into your resources folder and ensure `screenshot-basic` starts before it:
   ```cfg
   ensure screenshot-basic
   ensure uz_AutoShot
   ```

2. **Open the capture studio** - Join your server and run:
   ```
   /shotmaker
   ```
   This teleports you to an underground studio with a chroma key background.

3. **Select the Vehicles tab** - In the capture UI, switch to the vehicle capture tab. uz_AutoShot will auto-detect all loaded vehicle models on your server.

4. **Adjust the camera** (optional) - Use mouse controls to set your preferred angle:
   | Key | Action |
   |-----|--------|
   | Left Mouse | Rotate around vehicle |
   | Scroll Wheel | Zoom in/out |
   | W / S | Adjust height |
   | Q / E | Adjust field of view |
   | C | Save camera angle |

5. **Start the capture** - Click Start. uz_AutoShot will iterate through every vehicle model, take a screenshot, remove the background, and save a transparent PNG.

6. **Restart uz_AutoShot** after capture completes so FiveM indexes the new files:
   ```
   ensure uz_AutoShot
   ```

7. **Verify** - Open a dealership. Vehicle cards should now display photo thumbnails.

### Quick Capture (Single Vehicle)

To capture or re-capture a single vehicle:
```
/shotcar adder
```

### How It Works

The dealership calls this export to get each vehicle's photo URL:
```lua
exports['uz_AutoShot']:getVehiclePhotoURL('adder')
-- Returns: 'https://cfx-nui-uz_AutoShot/shots/vehicles/adder.png'
```

Photos are served via FiveM's built-in `cfx-nui` protocol. No port forwarding or external hosting needed.

### Troubleshooting Photos

| Problem | Solution |
|---------|----------|
| No thumbnails showing | Run `/shotmaker` and capture vehicles first |
| Black/blank images | Make sure `screenshot-basic` starts before `uz_AutoShot` |
| Some vehicles missing | Run `/shotcar modelname` for specific models |
| Photos not updating | Restart `uz_AutoShot` after new captures |

## Configuration

### General Settings

```lua
Config.UseOxTarget = false       -- Use ox_target sphere zones instead of core_focus
Config.UseOxRadial = false       -- Use ox_lib radial menu instead of core_focus
Config.DefaultGarage = 'pillboxgarage'  -- Default garage for purchased vehicles (QBCore only)
Config.SecondaryColorPrice = 2000       -- Extra cost for secondary paint color
Config.PreviewPoint = vec4(...)         -- Underground preview location (don't change unless needed)
```

### Dealership Locations

Each dealership has its own inventory, spawn point, NPC, and blip:

```lua
Config.Dealerships = {
    pdm = {
        label      = 'Premium Deluxe Motorsport',   -- Display name
        shopKey    = 'pdm',                          -- Matches shop field in qb-core vehicles.lua
        location   = vec4(-30.85, -1087.37, 26.65, 164.48),  -- NPC/interaction location
        spawnPoint = vec4(-51.66, -1095.82, 26.48, 154.87),  -- Where purchased cars spawn
        npc        = { model = 's_m_m_autoshop_01', heading = 164.48 },
        categories = {
            'compacts', 'sedans', 'suvs', 'coupes', 'sports',
            'sportsclassic', 'super', 'muscle', 'offroad', 'vans',
            'motorcycles', 'openwheel',
        },
        blip = { sprite = 326, color = 3, scale = 0.7, label = 'Car Dealer' },
    },

    luxury = {
        label      = 'Luxury Autos',
        shopKey    = 'luxury',
        location   = vec4(-1260.17, -356.47, 36.91, 204.0),
        spawnPoint = vec4(-1246.15, -348.34, 36.91, 204.0),
        npc        = { model = 's_m_m_autoshop_01', heading = 204.0 },
        categories = { 'super', 'sports', 'sportsclassic', 'coupes', 'sedans' },
        blip       = { sprite = 326, color = 5, scale = 0.7, label = 'Luxury Autos' },
    },
}
```

### Adding a New Dealership

1. Add a new entry to `Config.Dealerships` with a unique key
2. Set the `shopKey` to match vehicle `shop` fields in your framework's shared vehicles
3. Pick a `location` (where the NPC stands / interaction triggers)
4. Pick a `spawnPoint` (where purchased vehicles appear)
5. List which vehicle `categories` this dealership sells

### Vehicle Financing

Financing requires [tgg-banking](https://tgg.gg/). Set `Config.Finance.enabled = false` to disable.

```lua
Config.Finance = {
    enabled           = true,
    loanDuration      = 30,           -- Loan length in days
    paymentFrequency  = 'daily',      -- 'daily' or 'weekly'
    autoPayment       = true,         -- Auto-deduct from bank account
    maxMissedPayments = 4,            -- Repo vehicle after this many missed payments
    repoCheckInterval = 60,           -- Seconds between repo checks

    tiers = {
        { minScore = 800, maxPrice = math.huge, rate = 3.5,  label = 'Excellent' },
        { minScore = 700, maxPrice = math.huge, rate = 7.0,  label = 'Good' },
        { minScore = 600, maxPrice = 250000,    rate = 12.0, label = 'Fair' },
        { minScore = 500, maxPrice = 100000,    rate = 18.0, label = 'Poor' },
        { minScore = 300, maxPrice = 50000,     rate = 24.0, label = 'Bad' },
        { minScore = 0,   maxPrice = 25000,     rate = 30.0, label = 'Very Bad' },
    },
}
```

**How credit tiers work:**
- Player's credit score determines which tier they qualify for
- Higher scores unlock more expensive vehicles and lower interest rates
- `maxPrice` limits the total vehicle price (base + secondary color surcharge)
- `rate` is the interest percentage added to the vehicle price
- Total owed is split into equal daily (or weekly) payments over `loanDuration` days

### Interaction Modes

| Mode | Config | Requires |
|------|--------|----------|
| core_focus (default) | Both `false` | core_focus |
| ox_target | `Config.UseOxTarget = true` | ox_target |
| ox_lib radial | `Config.UseOxRadial = true` | ox_lib |

When any ox option is enabled, core_focus is automatically disabled.

## Framework Compatibility

### QBCore

Vehicles are pulled from `QBCore.Shared.Vehicles`. Each dealership filters by the `shop` field on each vehicle entry. Make sure your vehicles in `qb-core/shared/vehicles.lua` have the correct `shop` value matching your dealership's `shopKey`.

Example vehicle entry in `qb-core/shared/vehicles.lua`:
```lua
['adder'] = {
    name = 'Adder',
    brand = 'Truffade',
    model = 'adder',
    price = 280000,
    category = 'super',
    shop = 'pdm',           -- Must match Config.Dealerships.pdm.shopKey
    -- ...
},
```

### QBox (qbx_core)

Vehicles are pulled from `exports.qbx_core:GetVehiclesByName()`. QBox vehicles don't have a `shop` field, so the dealership filters by `category` instead using the `categories` list in each dealership config.

The database schema differs slightly: QBox's `player_vehicles` table does not have a `garage` column. The resource automatically detects which framework is running and adjusts the INSERT query accordingly.

**No configuration changes needed** - framework detection is automatic via `GetResourceState('qbx_core')`.

## Database

Import `vehshop.sql` before starting the resource. It creates two tables:

### player_vehicles
Standard QBCore vehicle ownership table. If your server already has this table (most do), the `CREATE TABLE IF NOT EXISTS` will skip it.

### dealership_loans
Tracks financed vehicles for the repossession system:
```sql
CREATE TABLE IF NOT EXISTS `dealership_loans` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `citizenid` VARCHAR(50) NOT NULL,
  `loan_id` INT NOT NULL,
  `vehicle` VARCHAR(50) NOT NULL,
  `plate` VARCHAR(8) NOT NULL,
  `financed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `repossessed` TINYINT NOT NULL DEFAULT 0
);
```

## Developer Reference

### Server Callbacks

These are QBCore callbacks triggered from the client via `QBCore.Functions.TriggerCallback`.

#### `citgo_dealership:getVehicles`
Returns the vehicle list for a dealership.

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `shopKey` | string | The dealership's shop key (e.g. `'pdm'`) |
| `shopCategories` | table | List of category strings (used by QBox filtering) |

**Returns:** Array of vehicle objects:
```lua
{
    model    = 'adder',
    name     = 'Adder',
    brand    = 'Truffade',
    price    = 280000,
    category = 'super',
    type     = 'automobile',
}
```

#### `citgo_dealership:checkPlate`
Checks if a license plate is available.

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `plate` | string | Desired plate text (max 8 chars) |

**Returns:** `true` if available, `false` if taken.

#### `citgo_dealership:getFinanceInfo`
Gets financing details for a vehicle based on player's credit score.

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `data.model` | string | Vehicle model name |
| `data.surcharge` | number | Additional cost (e.g. secondary color) |

**Returns:**
```lua
{
    available    = true,
    score        = 750,
    tier         = 'Good',
    rate         = 7.0,
    totalOwed    = 299600,
    interest     = 19600,
    duration     = 30,
    dailyPayment = 9987,
    maxPrice     = math.huge,
}
```

#### `citgo_dealership:purchaseVehicle`
Processes a full cash purchase.

**Parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `data.model` | string | Vehicle model name |
| `data.color` | table | `{ r, g, b }` primary color |
| `data.secondaryColor` | table/nil | `{ r, g, b }` secondary color (adds surcharge) |
| `data.plate` | string/nil | Requested plate (auto-generated if nil or taken) |

**Returns:**
```lua
{ success = true, plate = 'ABC12345', price = 282000 }
-- or
{ success = false, message = 'Not enough money' }
```

#### `citgo_dealership:financeVehicle`
Processes a financed purchase via tgg-banking.

**Parameters:** Same as `purchaseVehicle`.

**Returns:**
```lua
{
    success      = true,
    plate        = 'XYZ98765',
    loanId       = 42,
    totalOwed    = 299600,
    dailyPayment = 9987,
    rate         = 7.0,
}
```

### NUI Callbacks

These are registered via `RegisterNUICallback` and called from the React UI via `fetch`.

| Callback | Purpose | Data |
|----------|---------|------|
| `previewVehicle` | Spawn/remove preview vehicle | `{ model, color, secondaryColor, plate }` |
| `exitPreview` | Exit preview mode | - |
| `changePrimaryColor` | Update primary paint | `{ color: { r, g, b } }` |
| `changeSecondaryColor` | Update secondary paint | `{ color: { r, g, b } }` |
| `changePlate` | Update plate text on preview | `{ plate }` |
| `checkPlate` | Check plate availability | `{ plate }` |
| `camRotate` | Orbit camera rotation | `{ dx }` |
| `camZoom` | Camera zoom | `{ direction: 1 or -1 }` |
| `camHeight` | Camera height | `{ delta }` |
| `purchaseVehicle` | Buy vehicle (cash) | `{ model, color, secondaryColor, plate }` |
| `getFinanceInfo` | Get finance details | `{ model, surcharge }` |
| `financeVehicle` | Buy vehicle (finance) | `{ model, color, secondaryColor, plate }` |
| `closeUI` | Close dealership | - |

### Server Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `citgo_dealership:enterBucket` | Client -> Server | Move player to private routing bucket for preview |
| `citgo_dealership:exitBucket` | Client -> Server | Return player to default routing bucket |

### Data Flow

1. Player approaches dealership NPC -> interaction triggers `openDealership(shopId)`
2. Client requests vehicle list via `citgo_dealership:getVehicles` callback
3. Client fetches photo URLs from uz_AutoShot for each vehicle
4. NUI opens with vehicle grid, categories, and search
5. Player selects vehicle -> `previewVehicle` spawns it in a private routing bucket
6. Player customizes colors/plate -> live updates on preview vehicle
7. Player clicks Buy -> `purchaseVehicle` callback deducts money, creates DB record
8. Vehicle spawns at dealership spawn point with chosen colors and plate

### Repossession System

When financing is enabled, a server thread runs every `repoCheckInterval` seconds:
1. Queries all active (non-repossessed) loans from `dealership_loans`
2. Joins with `tgg_banking_loans` to check `missedPayments`
3. If `missedPayments >= maxMissedPayments`:
   - Deletes the vehicle from `player_vehicles`
   - Marks the loan as repossessed in `dealership_loans`
   - Notifies the player if they're online

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/dealership [shopId]` | `/dealership pdm` | Open a dealership by ID (dev/testing) |

## Tech Stack

- **Client:** Lua (FiveM client-side)
- **Server:** Lua + oxmysql
- **UI:** React + Vite (pre-built in `html/build/`)
- **Photos:** uz_AutoShot (cfx-nui protocol)
- **Banking:** tgg-banking (optional, for financing)

## License

MIT
