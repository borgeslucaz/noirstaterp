local cooldown = {}

-- Fallback used when the slasher cannot take network control of the vehicle
-- (mostly when another player is driving it). The request is relayed to the
-- entity owner, who is the only client able to replicate the tyre burst.
RegisterNetEvent('noir_tireslash:slash', function(netId, tyreIndex)
    local source = source

    if type(netId) ~= 'number' or not Config.validTyreIndex[tyreIndex] then return end

    local now = GetGameTimer()

    if cooldown[source] and now < cooldown[source] then return end

    cooldown[source] = now + Config.cooldown

    local vehicle = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or GetEntityType(vehicle) ~= 2 then return end

    local ped = GetPlayerPed(source)

    if ped == 0 then return end

    if #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > Config.maxDistance then return end

    local owner = NetworkGetEntityOwner(vehicle)

    if owner <= 0 then return end

    TriggerClientEvent('noir_tireslash:burst', owner, netId, tyreIndex)
end)

AddEventHandler('playerDropped', function()
    cooldown[source] = nil
end)
