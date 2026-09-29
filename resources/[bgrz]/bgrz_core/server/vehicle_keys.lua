BGRZ = BGRZ or {}

---Chave temporária de um veículo criado por script (emprego, missão, aluguel) e destranca.
---
---O provider é o `mri_Qcarkeys`, chamado pelo nome dele: o `qbx_vehiclekeys` não existe mais
---aqui, e o `provide` do mri não substitui chamar o resource real.
---
---A placa pode vir de quem chama. Quem acabou de trocar a placa no servidor (o
---`SpawnVehicle` faz isso) não pode confiar no `GetVehicleNumberPlateText` logo em seguida:
---a leitura ainda pode devolver a placa antiga, e a chave sairia para outro veículo.
---@param source number
---@param vehicle number
---@param plate? string
---@return boolean
function BGRZ.GiveVehicleKeys(source, vehicle, plate)
    if type(source) ~= 'number' or source <= 0 then
        return false
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    if not BGRZ.Provider.isAvailable('vehiclekeys') then return false end
    plate = type(plate) == 'string' and plate ~= '' and plate or GetVehicleNumberPlateText(vehicle)
    local provider = BGRZ.Provider.name('vehiclekeys')
    local called = pcall(function() exports[provider]:GiveTempKeys(source, plate) end)
    if not called then return false end
    SetVehicleDoorsLocked(vehicle, 1)
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
