-- Compatibilidade com qbx_vehiclekeys: scripts do Qbox que chamam exports.qbx_vehiclekeys:HasKeys
-- passam a usar o mri_Qcarkeys (junto com o `provide 'qbx_vehiclekeys'` do fxmanifest).

-- O FiveM guarda o export pelo nome provido (qbx_vehiclekeys) e so limpa esse cache quando para um
-- resource com esse nome. Num restart a quente os outros resources continuariam chamando a instancia
-- morta (msgpack_unpack ... got nil); avisa a parada pelo nome provido para buscarem de novo.
TriggerEvent('onClientResourceStop', 'qbx_vehiclekeys')

local VehicleKeys = require 'client.interface'
local Utils = require 'client.modules.utils'

AddEventHandler('__cfx_export_qbx_vehiclekeys_HasKeys', function(setCB)
    setCB(function(vehicle)
        if not vehicle or not DoesEntityExist(vehicle) then return false end
        local plate = Utils:RemoveSpecialCharacter(GetVehicleNumberPlateText(vehicle))
        return lib.table.contains(VehicleKeys.playerTempKeys, plate) or lib.table.contains(VehicleKeys.playerKeys, plate)
    end)
end)
