# clothingmenu

Advanced 3D Floating UI Clothing Menu for FiveM (QBX / QBCore / ESX / Standalone)

A modern, immersive clothing interaction menu that projects a **3D Floating UI** directly onto the player's character. Icons are anchored to specific body parts (bones), creating an intuitive experience for toggling clothing items.

## Features

- **3D Floating Interface** - Menu items track the character's body parts in real-time
- **Multi-Framework Support** - Works with QBX, QBCore, ESX, and Standalone
- **Item System Toggle** - Free toggle mode (no items) or inventory-based mode
- **Clothing Script Sync** - Configurable sync functions for any clothing script
- **Target Player Support** - Remove clothing from dead/handcuffed players via ox_target
- **Gender Auto-Detect** - Automatically detects Male/Female characters
- **Immersive Animations** - Plays realistic animations when equipping/unequipping
- **Modern UI** - Sleek glassmorphism design with hover effects
- **Optimized** - ~0.02ms idle

## Installation

1. Place `clothingmenu` folder in your server's `resources` directory
2. Ensure dependencies in `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure clothingmenu
   ```
3. Restart server or run `ensure clothingmenu`

## Dependencies

| Resource | Purpose | Required |
|----------|---------|----------|
| `ox_lib` | Progress bars, notifications | Yes |
| `ox_target` | Target dead/handcuffed players | Yes |
| `ox_inventory` | Clothing item storage | Only when `itemSystem = true` |
| `illenium-appearance` | Appearance sync (default) | Optional (auto-detected) |

## Configuration

### Framework Detection

Edit `config.lua`:

```lua
Config = {
    -- 'auto' = auto-detect (QBX > QBCore > ESX > Standalone)
    -- 'qbx' | 'qbcore' | 'esx' | 'standalone' = force specific framework
    framework = 'auto',

    -- true = remove clothing → inventory item → use item to re-apply
    -- false = free toggle on/off (no inventory items needed)
    itemSystem = true,
}
```

### Item System Modes

| Mode | Behavior |
|------|----------|
| `itemSystem = true` | Remove clothing creates inventory item, use item to re-apply |
| `itemSystem = false` | Free toggle - click to turn on/off, no items needed |

### Clothing Script Sync

Default sync uses `illenium-appearance`. Customize for your clothing script:

```lua
Config = {
    sync = {
        -- Get appearance from ped
        getAppearance = function(ped)
            if GetResourceState('illenium-appearance') == 'started' then
                return exports['illenium-appearance']:getPedAppearance(ped)
            end
            -- Fallback: native functions
            local appearance = {}
            for i = 0, 11 do
                appearance['component_' .. i] = {
                    drawable = GetPedDrawableVariation(ped, i),
                    texture = GetPedTextureVariation(ped, i)
                }
            end
            for i = 0, 7 do
                appearance['prop_' .. i] = {
                    drawable = GetPedPropIndex(ped, i),
                    texture = GetPedPropTextureIndex(ped, i)
                }
            end
            return appearance
        end,

        -- Apply appearance to ped
        applyAppearance = function(ped, appearance)
            if GetResourceState('illenium-appearance') == 'started' then
                exports['illenium-appearance']:setPedAppearance(ped, appearance)
                return
            end
            -- Fallback: native functions
            for k, v in pairs(appearance) do
                local typ, index = k:match('^(%w+)_(%d+)$')
                index = tonumber(index)
                if typ == 'component' then
                    SetPedComponentVariation(ped, index, v.drawable, v.texture, 0)
                elseif typ == 'prop' then
                    if v.drawable == -1 then
                        ClearPedProp(ped, index)
                    else
                        SetPedPropIndex(ped, index, v.drawable, v.texture, true)
                    end
                end
            end
        end,

        -- Save appearance (optional)
        saveAppearance = function(appearance)
            if GetResourceState('illenium-appearance') == 'started' then
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            end
        end
    }
}
```

### Sync Examples for Other Scripts

### esx_skin / skinchanger (ESX Legacy / es_extended)

```lua
sync = {
    getAppearance = function(ped)
        return {
            tshirt_1 = GetPedDrawableVariation(ped, 8),
            tshirt_2 = GetPedTextureVariation(ped, 8),
            torso_1 = GetPedDrawableVariation(ped, 11),
            torso_2 = GetPedTextureVariation(ped, 11),
            pants_1 = GetPedDrawableVariation(ped, 4),
            pants_2 = GetPedTextureVariation(ped, 4),
            shoes_1 = GetPedDrawableVariation(ped, 6),
            shoes_2 = GetPedTextureVariation(ped, 6),
            mask_1 = GetPedDrawableVariation(ped, 1),
            mask_2 = GetPedTextureVariation(ped, 1),
            -- ... etc
        }
    end,
    applyAppearance = function(ped, skin)
        TriggerEvent('skinchanger:loadSkin', skin)
    end,
    saveAppearance = function(skin)
        TriggerServerEvent('esx_skin:save', skin)
    end
}
```

#### qb-clothing (QBCore Legacy)

```lua
sync = {
    getAppearance = function(ped)
        return {
            ['t-shirt'] = { item = GetPedDrawableVariation(ped, 8), texture = GetPedTextureVariation(ped, 8) },
            torso2 = { item = GetPedDrawableVariation(ped, 11), texture = GetPedTextureVariation(ped, 11) },
            pants = { item = GetPedDrawableVariation(ped, 4), texture = GetPedTextureVariation(ped, 4) },
            shoes = { item = GetPedDrawableVariation(ped, 6), texture = GetPedTextureVariation(ped, 6) },
            mask = { item = GetPedDrawableVariation(ped, 1), texture = GetPedTextureVariation(ped, 1) },
            -- ... etc
        }
    end,
    applyAppearance = function(ped, data)
        TriggerEvent('qb-clothing:client:loadPlayerClothing', data, ped)
    end,
    saveAppearance = function(data)
        local model = GetEntityModel(PlayerPedId())
        TriggerServerEvent('qb-clothing:saveSkin', model, json.encode(data))
    end
}
```

#### fivem-appearance (Standalone)

```lua
sync = {
    getAppearance = function(ped)
        return exports['fivem-appearance']:getPedAppearance(ped)
    end,
    applyAppearance = function(ped, appearance)
        exports['fivem-appearance']:setPedAppearance(ped, appearance)
    end,
    saveAppearance = function(appearance)
        TriggerServerEvent('myScript:saveAppearance', appearance)
    end
}
```

## Framework Bridge

The resource auto-detects your framework and loads the appropriate adapter:

| Framework | Detection | Player Data |
|-----------|-----------|-------------|
| QBX | `qbx_core` resource started | `exports.qbx_core:GetPlayer(src).PlayerData.metadata` |
| QBCore | `qb-core` resource started | `exports['qb-core']:GetCore().Functions.GetPlayer(src)` |
| ESX | `es_extended` or `esx-legacy` started | `exports.es_extended:getSharedObject().GetPlayer(src)` |
| Standalone | Fallback | Server ID only |

## Target Player System

Menu can target other players when they are:
- **Dead** (framework-specific metadata or health check)
- **Handcuffed** (framework-specific metadata or ped state)

```lua
target = {
    enabled = true,
    testingMode = false,   -- true = allow targeting any player
    allowDead = true,
    allowHandcuffed = true,
    interactionDistance = 2.5,
    maxDistance = 5.0,
    icon = 'fa-solid fa-shirt',
    label = 'Remove Clothing'
}
```

## Commands

| Command | Description |
|---------|-------------|
| `/clothingmenu` | Open self clothing menu |
| `/clothingtarget [serverId]` | Open target player's menu |
| `/clothingcursor` | Toggle mouse cursor in menu |

## Usage

| Action | Default Key / Command |
|--------|----------------------|
| Open Self Menu | `F9` / `/clothingmenu` |
| Open Target Menu | `/clothingtarget [serverId]` |
| Toggle Cursor | `Left Alt` / `/clothingcursor` |
| Target Player | Look at dead/handcuffed player via ox_target |

## ox_inventory Items

Only needed when `itemSystem = true`. Add to `ox_inventory/data/items.lua`:

```lua
['clothing_mask'] = { label = 'Mask', weight = 50, stack = false, close = true, consume = 0 },
['clothing_hat'] = { label = 'Hat', weight = 100, stack = false, close = true, consume = 0 },
['clothing_glasses'] = { label = 'Glasses', weight = 30, stack = false, close = true, consume = 0 },
['clothing_jacket'] = { label = 'Jacket', weight = 500, stack = false, close = true, consume = 0 },
['clothing_pants'] = { label = 'Pants', weight = 400, stack = false, close = true, consume = 0 },
['clothing_shoes'] = { label = 'Shoes', weight = 300, stack = false, close = true, consume = 0 },
['clothing_bag'] = { label = 'Bag', weight = 600, stack = false, close = true, consume = 0 },
['clothing_vest'] = { label = 'Vest', weight = 450, stack = false, close = true, consume = 0 },
['clothing_watch'] = { label = 'Watch', weight = 80, stack = false, close = true, consume = 0 },
['clothing_necklace'] = { label = 'Necklace', weight = 50, stack = false, close = true, consume = 0 },
```

## Preview

![Clothing Menu](https://cdn.aifazi.net/de9d85xkd/image/upload/v1781016946/media/i8clwfbyqdak74vku44q.png)

![Target Menu](https://cdn.aifazi.net/de9d85xkd/image/upload/v1781016945/media/fwtt32708ct4fj7mte3j.png)

Video: https://streamable.com/e/alf4xg
Video: https://streamable.com/e/tuungx

## License

MIT License - Feel free to use, modify, and distribute.
