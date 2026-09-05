BGRZ = BGRZ or {}

exports('GiveVehicleKeys', function(vehicle)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
        local attempts = 0
        while not NetworkGetEntityIsNetworked(vehicle) and attempts < 50 do
            attempts = attempts + 1
            Wait(20)
        end
        if not NetworkGetEntityIsNetworked(vehicle) then
            print(('[bgrz_core] GiveVehicleKeys: veículo %s não está em rede, chave não enviada'):format(vehicle))
            return
        end
    end

    TriggerServerEvent('bgrz_core:server:giveVehicleKeys', NetworkGetNetworkIdFromEntity(vehicle))
end)
