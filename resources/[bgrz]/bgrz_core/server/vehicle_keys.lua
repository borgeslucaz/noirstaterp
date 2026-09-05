BGRZ = BGRZ or {}

function BGRZ.GiveVehicleKeys(source, vehicle)
    if type(source) ~= 'number' or source <= 0 then
        return false
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
    exports.qbx_vehiclekeys:SetLockState(vehicle, 'unlock')
    return true
end

exports('GiveVehicleKeys', BGRZ.GiveVehicleKeys)

RegisterNetEvent('bgrz_core:server:giveVehicleKeys', function(netId)
    local src = source
    if type(netId) ~= 'number' or netId == 0 then
        print(('[bgrz_core] giveVehicleKeys: netId inválido (%s) de src %s'):format(tostring(netId), src))
        return
    end

    -- Veículos criados no client podem levar alguns frames até existir no servidor.
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local attempts = 0
    while (vehicle == 0 or not DoesEntityExist(vehicle)) and attempts < 50 do
        attempts = attempts + 1
        Wait(100)
        vehicle = NetworkGetEntityFromNetworkId(netId)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        print(('[bgrz_core] giveVehicleKeys: veículo netId=%s não existe no servidor (src %s)'):format(netId, src))
        return
    end

    BGRZ.GiveVehicleKeys(src, vehicle)
end)
