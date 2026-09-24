-- Compatibilidade com qbx_vehiclekeys: scripts do Qbox que chamam exports.qbx_vehiclekeys:*
-- passam a usar o mri_Qcarkeys (junto com o `provide 'qbx_vehiclekeys'` do fxmanifest).

-- O FiveM guarda o export pelo nome provido (qbx_vehiclekeys) e so limpa esse cache quando para um
-- resource com esse nome. Num restart a quente os outros resources continuariam chamando a instancia
-- morta (msgpack_unpack ... got nil); avisa a parada pelo nome provido para buscarem de novo.
TriggerEvent('onServerResourceStop', 'qbx_vehiclekeys')

local function exportHandler(name, fn)
    AddEventHandler(('__cfx_export_qbx_vehiclekeys_%s'):format(name), function(setCB)
        setCB(fn)
    end)
end

---Aceita a entidade do veículo ou a placa (alguns scripts antigos passam a placa)
---@param vehicle number|string
---@return string?
local function getPlate(vehicle)
    if type(vehicle) == 'string' then return vehicle end
    if vehicle and DoesEntityExist(vehicle) then
        return GetVehicleNumberPlateText(vehicle)
    end
end

-- Mesma regra dos eventos: carro de jogador -> definitiva so para o dono; sem dono -> temporaria.
exportHandler('GiveKeys', function(source, vehicle)
    local plate = getPlate(vehicle)
    if not plate then return false end
    return GrantVehicleKeyTrusted(source, plate)
end)

exportHandler('RemoveKeys', function(source, vehicle)
    local plate = getPlate(vehicle)
    if not plate then return false end
    RemoveTempKeys(source, plate)
    return true
end)

-- Responde com o que o servidor sabe (lista temporaria + item no inventario), sem perguntar ao
-- cliente: o callback original deixava o cliente decidir e travava quem chamava se ele nao respondesse.
exportHandler('HasKeys', function(source, vehicle)
    local plate = getPlate(vehicle)
    if not plate then return false end
    plate = NormalizePlate(plate)
    return HasTempKeyForPlate(source, plate) or HasKeyItemForPlate(source, plate)
end)

exportHandler('SetLockState', function(vehicle, state)
    if type(state) ~= 'string' or not DoesEntityExist(vehicle) then return end
    SetVehicleDoorsLocked(vehicle, state == 'lock' and 2 or 1)
end)
