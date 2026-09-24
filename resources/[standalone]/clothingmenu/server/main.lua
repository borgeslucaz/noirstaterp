local allowedItems = { clothing = true }
local allowedSlots = {}

for _, item in ipairs(Config.Clothing or {}) do
    if item.itemName then
        allowedItems[item.itemName] = true
    end

    if item.type and item.component then
        allowedSlots[('%s:%s'):format(item.type, item.component)] = true
    end
end

local function ResolveItemName(itemName)
    itemName = tostring(itemName or 'clothing')
    if allowedItems[itemName] then return itemName end
    return 'clothing'
end

local function ValidClothingSlot(metadata)
    if metadata.component ~= nil then
        return allowedSlots[('component:%s'):format(metadata.component)] == true
    end

    if metadata.prop ~= nil then
        return allowedSlots[('prop:%s'):format(metadata.prop)] == true
    end

    return false
end

local function ValidMetadata(metadata)
    if type(metadata) ~= 'table' then return false end
    if type(metadata.drawable) ~= 'number' or type(metadata.texture) ~= 'number' then return false end
    if metadata.component ~= nil and type(metadata.component) == 'number' then return ValidClothingSlot(metadata) end
    if metadata.prop ~= nil and type(metadata.prop) == 'number' then return ValidClothingSlot(metadata) end
    return false
end

local function IsPlayerEligibleTarget(targetSrc)
    if Config.TestingMode then return true end
    if not Config.ItemSystem then return true end

    return Bridge.IsPlayerDead(targetSrc) or Bridge.IsPlayerHandcuffed(targetSrc)
end

local function IsTargetNearSource(src, targetSrc)
    if src == targetSrc then return true end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)
    if not srcPed or not targetPed or srcPed == 0 or targetPed == 0 then return false end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local maxDistance = (Config.MaxTargetDistance or 5.0) + 1.0

    return #(srcCoords - targetCoords) <= maxDistance
end

local function SanitizeMetadata(metadata, src, targetSrc)
    local drawable = tonumber(metadata.drawable)
    local texture = tonumber(metadata.texture) or 0
    local component = metadata.component and tonumber(metadata.component) or nil
    local prop = metadata.prop and tonumber(metadata.prop) or nil

    if not drawable or drawable < 0 then
        drawable = 0
    end

    local clean = {
        label = tostring(metadata.label or 'Roupa'),
        description = tostring(metadata.description or ('Drawable %s / Texture %s'):format(drawable, texture)),
        texture = texture,
        source = 'clothingmenu',
        itemName = metadata.itemName,
        targetServerId = targetSrc ~= src and targetSrc or nil,
        component = component,
        prop = prop,
        drawable = drawable
    }
    return clean
end

local function GetDropCoords(targetSrc)
    local ped = GetPlayerPed(targetSrc)
    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    return vec3(coords.x, coords.y, coords.z - 0.2)
end

local function AddClothingToInventoryOrDrop(targetSrc, itemName, metadata)
    local cleanMeta = {
        label = tostring(metadata.label or 'Roupa'),
        description = tostring(metadata.description or ''),
        texture = tonumber(metadata.texture) or 0,
        source = tostring(metadata.source or 'clothingmenu'),
        itemName = tostring(metadata.itemName or 'clothing'),
        targetServerId = metadata.targetServerId,
        component = metadata.component and tonumber(metadata.component) or nil,
        prop = metadata.prop and tonumber(metadata.prop) or nil,
        drawable = tonumber(metadata.drawable) or 0
    }

    if exports.ox_inventory:CanCarryItem(targetSrc, itemName, 1, cleanMeta) then
        local added = exports.ox_inventory:AddItem(targetSrc, itemName, 1, cleanMeta)
        if added then
            return true, 'inventory'
        end
    end

    local coords = GetDropCoords(targetSrc)
    if not coords then return false, 'failed' end

    local dropId = exports.ox_inventory:CustomDrop(
        'Roupas',
        {
            { itemName, 1, metadata }
        },
        coords,
        1,
        10000
    )

    return dropId ~= nil, dropId and 'drop' or 'failed'
end

RegisterNetEvent('clothingmenu:server:addClothingItem', function(metadata)
    local src = source

    if not Config.ItemSystem then return end
    if not ValidMetadata(metadata) then return end

    local targetSrc = tonumber(metadata.targetServerId) or src
    if targetSrc ~= src then
        if not Bridge.GetPlayerName(targetSrc) then return end
        if not IsTargetNearSource(src, targetSrc) then return end
        if not IsPlayerEligibleTarget(targetSrc) then return end
    end

    local itemName = ResolveItemName(metadata.itemName)
    local cleanMetadata = SanitizeMetadata(metadata, src, targetSrc)
    local added, destination = AddClothingToInventoryOrDrop(targetSrc, itemName, cleanMetadata)

    if added then
        local movedToDrop = destination == 'drop'

        if targetSrc ~= src then
            TriggerClientEvent('ox_lib:notify', src, {
                type = movedToDrop and 'warning' or 'success',
                description = movedToDrop
                    and ('%s foi deixado perto de %s porque o inventário está cheio'):format(cleanMetadata.label, Bridge.GetPlayerName(targetSrc) or 'jogador')
                    or ('%s foi adicionado ao inventário de %s'):format(cleanMetadata.label, Bridge.GetPlayerName(targetSrc) or 'jogador')
            })
            TriggerClientEvent('ox_lib:notify', targetSrc, {
                type = movedToDrop and 'warning' or 'info',
                description = movedToDrop
                    and ('%s foi removido e deixado perto de você porque seu inventário está cheio'):format(cleanMetadata.label)
                    or ('%s foi removido e adicionado ao seu inventário'):format(cleanMetadata.label)
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                type = movedToDrop and 'warning' or 'success',
                description = movedToDrop
                    and ('%s foi deixado perto de você porque seu inventário está cheio'):format(cleanMetadata.label)
                    or ('%s foi adicionado ao inventário'):format(cleanMetadata.label)
            })
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'A roupa foi removida, mas não pôde ser adicionada ao inventário nem deixada no chão.'
        })
    end
end)

RegisterNetEvent('clothingmenu:server:removeUsedClothingItem', function(itemName, slot, metadata)
    local src = source

    if not Config.ItemSystem then return end

    slot = tonumber(slot)
    if not slot then return end

    local slotData = exports.ox_inventory:GetSlot(src, slot)
    if not slotData or not allowedItems[slotData.name] then return end

    local slotMetadata = slotData.metadata or metadata
    if not ValidMetadata(slotMetadata) then return end

    local resolvedItem = ResolveItemName(itemName or slotData.name)
    if resolvedItem ~= slotData.name then return end

    local removed = exports.ox_inventory:RemoveItem(src, slotData.name, 1, nil, slot)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'A roupa foi vestida, mas o item não pôde ser removido do inventário.'
        })
    end
end)

RegisterNetEvent('clothingmenu:server:syncClothingState', function(targetSrc, index, state, itemData)
    local src = source
    targetSrc = tonumber(targetSrc)
    index = tonumber(index)

    if not targetSrc or not index then return end
    if not IsTargetNearSource(src, targetSrc) then return end
    if not IsPlayerEligibleTarget(targetSrc) then return end

    TriggerClientEvent('clothingmenu:client:syncClothingState', targetSrc, index, state == true, itemData)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
end)
