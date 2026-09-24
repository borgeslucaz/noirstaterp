local function bone(id, x, y, z)
    return { id = id, offset = vector3(x, y, z) }
end

local function withOff(data, maleDrawable, femaleDrawable, maleTexture, femaleTexture)
    data.off_drawable = { male = maleDrawable, female = femaleDrawable }
    data.off_texture = { male = maleTexture or 0, female = femaleTexture or maleTexture or 0 }
    return data
end

Config = {
    command = 'clothingmenu',
    defaultKey = 'F9',

    -- Framework: 'auto' | 'qbx' | 'qbcore' | 'esx' | 'standalone'
    -- 'auto' detects: QBX > QBCore > ESX (es_extended/esx-legacy) > Standalone
    framework = 'auto',

    -- Sistema de itens: true = remover→inventário→vestir; false = alternância livre
    itemSystem = true,

    ui = {
        colors = {
            primary = '#00ff88',
            secondary = 'rgba(0, 14, 22, 0.5)',
            accent = '#00d4ff',
            text = '#e8f6ff',
            danger = '#ff4d6d'
        }
    },

    performance = {
        positionWait = 0,
        positionThreshold = 0.03
    },

    cursor = {
        command = 'clothingcursor',
        key = 'LMENU',
        notify = true
    },

    progress = {
        removeDuration = 1500,
        wearDuration = 1200,
        removeLabel = 'Removendo roupa...',
        targetRemoveLabel = 'Removendo roupa do jogador...',
        wearLabel = 'Vestindo roupa...',
        canCancel = true,
        disable = { car = true, combat = true },
        wearAnim = { dict = 'clothingshirt', name = 'try_shirt_positive_d', flag = 49 },
        targetRemoveAnim = { dict = 'pickup_object', name = 'pickup_low' }
    },

    target = {
        enabled = true,
        testingMode = false,
        allowDead = true,
        allowHandcuffed = true,
        interactionDistance = 2.5,
        maxDistance = 5.0,
        icon = 'fa-solid fa-shirt',
        label = 'Remover roupa',
        -- Unicas pecas que se tira de outro jogador (pelo itemName). Vale tambem para a
        -- revista do ox_inventory (modules/equipment/shared.lua, campo stealable).
        removable = { 'clothing_vest', 'clothing_glasses', 'clothing_watch' }
    },

    emptyDrawables = {
        prop = {
            ['Óculos'] = { [0] = true },
            ['Relógio'] = { [0] = true }
        },
        component = {
            ['Máscara'] = { [0] = true },
            ['Mochila'] = { [0] = true },
            ['Colete'] = { [0] = true },
            ['Colar'] = { [0] = true }
        }
    },

    -- Appearance sync functions
    -- Default: illenium-appearance exports
    -- Customize for your clothing script (see examples below)
    sync = {
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

        saveAppearance = function(appearance)
            if GetResourceState('illenium-appearance') == 'started' then
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            end
        end
    },

    clothing = {
        withOff({
            label = 'Máscara',
            icon = 'entypo:mask',
            component = 1,
            type = 'component',
            itemName = 'clothing_mask',
            bone = bone(31086, 0.10, 0.05, -0.22),
            size = 50,
            anim = { dict = 'mp_masks@on_foot', name = 'put_on_mask' },
            removeAnim = { dict = 'mp_masks@on_foot', name = 'take_off_mask' }
        }, 0, 0),
        withOff({
            label = 'Chapéu',
            icon = 'fa6-solid:hat-cowboy',
            component = 0,
            type = 'prop',
            itemName = 'clothing_hat',
            bone = bone(31086, 0.38, 0.0, 0.0),
            size = 50,
            anim = { dict = 'clothingshirt', name = 'try_shirt_positive_d' },
            removeAnim = { dict = 'clothingshirt', name = 'try_shirt_positive_d' }
        }, -1, -1),
        withOff({
            label = 'Óculos',
            icon = 'mdi:glasses',
            component = 1,
            type = 'prop',
            itemName = 'clothing_glasses',
            bone = bone(31086, 0.10, 0.05, 0.22),
            size = 50,
            anim = { dict = 'clothingspecs', name = 'take_off' }
        }, -1, -1),
        withOff({
            label = 'Jaqueta',
            icon = 'ion:shirt',
            component = 11,
            type = 'component',
            itemName = 'clothing_jacket',
            bone = bone(24817, 0.0, 0.25, 0.0),
            anim = { dict = 'clothingtie', name = 'try_tie_neutral_a' }
        }, 15, 15),
        withOff({
            label = 'Calça',
            icon = 'ph:pants-fill',
            component = 4,
            type = 'component',
            itemName = 'clothing_pants',
            bone = bone(11816, 0.0, 0.25, 0.0),
            anim = { dict = 're@construction', name = 'out_of_breath' }
        }, 21, 15),
        withOff({
            label = 'Sapatos',
            icon = 'mingcute:shoe-fill',
            component = 6,
            type = 'component',
            itemName = 'clothing_shoes',
            bone = bone(14201, 0.0, 0.1, 0.0),
            anim = { dict = 'random@domestic', name = 'pickup_low' }
        }, 34, 35),
        withOff({
            label = 'Mochila',
            icon = 'bxs:backpack',
            component = 5,
            type = 'component',
            itemName = 'clothing_bag',
            bone = bone(24817, 0.0, 0.1, -0.25),
            anim = { dict = 'anim@heists@ornate_bank@grab_cash', name = 'grab_block' }
        }, 0, 0),
        withOff({
            label = 'Colete',
            icon = 'mingcute:vest-fill',
            component = 9,
            type = 'component',
            itemName = 'clothing_vest',
            bone = bone(24818, 0.0, 0.1, 0.25),
            anim = { dict = 'clothingtie', name = 'try_tie_neutral_a' }
        }, 0, 0),
        withOff({
            label = 'Relógio',
            icon = 'mingcute:watch-fill',
            component = 6,
            type = 'prop',
            itemName = 'clothing_watch',
            bone = bone(18905, 0.05, 0.05, 0.0),
            anim = { dict = 'nmt_3_rcm-10', name = 'p_watch_01_s' }
        }, -1, -1),
        withOff({
            label = 'Colar',
            icon = 'mdi:necklace',
            component = 7,
            type = 'component',
            itemName = 'clothing_necklace',
            bone = bone(39317, 0.0, 0.1, 0.0),
            size = 50,
            anim = { dict = 'clothingtie', name = 'try_tie_neutral_a' }
        }, 0, 0)
    }
}

-- Compatibility aliases for existing client/server code and third-party snippets.
Config.Command = Config.command
Config.DefaultKey = Config.defaultKey
Config.Colors = Config.ui.colors
Config.Clothing = Config.clothing
Config.EmptyDrawables = Config.emptyDrawables
Config.Performance = Config.performance
Config.Cursor = Config.cursor
Config.CursorCommand = Config.cursor.command
Config.CursorKey = Config.cursor.key
Config.Progress = Config.progress
Config.EnableTargetPlayer = Config.target.enabled
Config.TestingMode = Config.target.testingMode
Config.AllowDead = Config.target.allowDead
Config.AllowHandcuffed = Config.target.allowHandcuffed
Config.TargetDistance = Config.target.interactionDistance
Config.MaxTargetDistance = Config.target.maxDistance
Config.TargetIcon = Config.target.icon
Config.TargetLabel = Config.target.label

local targetRemovable = {}
for _, itemName in ipairs(Config.target.removable or {}) do targetRemovable[itemName] = true end

---Se a peca pode ser tirada de outro jogador.
function Config.IsTargetRemovable(item)
    return item ~= nil and targetRemovable[item.itemName] == true
end
Config.ItemSystem = Config.itemSystem
Config.Sync = Config.sync
