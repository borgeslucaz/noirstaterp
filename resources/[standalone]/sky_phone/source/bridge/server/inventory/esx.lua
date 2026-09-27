if Bridge.Inventory.Name ~= "esx" and Bridge.Inventory.Name ~= "hex" then
    return
end

if GetResourceState("es_extended") ~= "started" then
    error("[sky_phone] The ESX inventory adapter requires es_extended to be started.")
end
if Bridge.Inventory.Name == "hex" and GetResourceState("hex_4_inventory") ~= "started" then
    error("[sky_phone] hex_4_inventory is configured, but the resource is not started.")
end

local ESX = exports["es_extended"]:getSharedObject()

local function get_player(source)
    return ESX.GetPlayerFromId(source)
end

local function get_item(source, item_name)
    local player = get_player(source)
    local item = player and player.getInventoryItem(item_name) or nil
    local count = item and tonumber(item.count) or 0
    if count < 1 then
        return nil
    end

    return {
        name = item_name,
        slot = item_name,
        count = count,
        amount = count,
        metadata = {},
    }
end

local function has_metadata(metadata)
    return type(metadata) == "table" and next(metadata) ~= nil
end

function Bridge.Inventory.GetResourceName()
    return Bridge.Inventory.Name == "hex" and "hex_4_inventory" or "es_extended"
end

function Bridge.Inventory.GetSlot(source, slot_id)
    return get_item(source, tostring(slot_id))
end

function Bridge.Inventory.GetSlotsWithItem(source, item_name, metadata)
    local item = get_item(source, item_name)
    if not item or has_metadata(metadata) then
        return {}
    end
    return { item }
end

function Bridge.Inventory.SetSlotMetadata()
    return false
end

function Bridge.Inventory.CanCarryItem(source, item_name, count, metadata)
    if has_metadata(metadata) then
        return false
    end
    local player = get_player(source)
    return player and player.canCarryItem(item_name, count) or false
end

function Bridge.Inventory.AddItem(source, item_name, count, _, metadata)
    if not Bridge.Inventory.CanCarryItem(source, item_name, count, metadata) then
        return false
    end

    local player = get_player(source)
    local before = player.getInventoryItem(item_name)
    local before_count = before and tonumber(before.count) or 0
    player.addInventoryItem(item_name, count)
    local after = player.getInventoryItem(item_name)
    return (after and tonumber(after.count) or 0) - before_count == count
end

function Bridge.Inventory.RemoveItem(source, item_name, count, _, metadata)
    if has_metadata(metadata) then
        return 0
    end

    local player = get_player(source)
    local before = player and player.getInventoryItem(item_name) or nil
    local before_count = before and tonumber(before.count) or 0
    if not player or before_count < count then
        return 0
    end

    player.removeInventoryItem(item_name, count)
    local after = player.getInventoryItem(item_name)
    return before_count - (after and tonumber(after.count) or 0)
end

function Bridge.Inventory.RegisterUsableItem(item_name, callback)
    ESX.RegisterUsableItem(item_name, function(source)
        local item = get_item(source, item_name)
        if not item then
            Bridge.Debug(
                "warn",
                "[sky_phone] ESX usable callback could not resolve item '%s' for source %s.",
                item_name,
                tostring(source)
            )
            return
        end
        callback(source, item)
    end)
    return true
end
