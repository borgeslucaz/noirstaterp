---Servicos do menu do carro. Todos passam pelo guiche (GetGarageAtAccessPoint) e conferem o dono
---no banco: o cliente so manda o id do carro.

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return GarageConfig? garage, PlayerVehicle? playerVehicle, table? player
local function getOwnedVehicleAtGarage(source, vehicleId, garageName, accessPointIndex)
    local garage, _, player = GetGarageAtAccessPoint(source, garageName, accessPointIndex)
    if not garage or not player then return end
    if not IsInteger(vehicleId) then return end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not playerVehicle or playerVehicle.citizenid ~= player.PlayerData.citizenid then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    return garage, playerVehicle, player
end

---@param garage GarageConfig
---@param garageName string
---@param playerVehicle PlayerVehicle
---@return boolean
local function isGaragedHere(garage, garageName, playerVehicle)
    return playerVehicle.state == VehicleState.GARAGED and (garage.skipGarageCheck or playerVehicle.garage == garageName)
end

---Servico de chave (item do mri_Qcarkeys) no menu do carro: so o dono, no guiche, com o carro guardado
---nesta garagem ou fora (listado no patio -- quem perdeu a chave com o carro na rua). Cobra em
---dinheiro e depois no banco, como a taxa do patio, e devolve se a entrega falhar.
---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@param price integer
---@param reason string
---@param deliver fun(plate: string): boolean
---@param successLocale string
---@param logLocale string
---@return boolean
local function sellKeyService(source, vehicleId, garageName, accessPointIndex, price, reason, deliver, successLocale, logLocale)
    local garage, playerVehicle, player = getOwnedVehicleAtGarage(source, vehicleId, garageName, accessPointIndex)
    if not garage or not playerVehicle or not player then return false end

    local outAtDepot = garage.type == GarageType.DEPOT and playerVehicle.state == VehicleState.OUT
    if not isGaragedHere(garage, garageName, playerVehicle) and not outAtDepot then return false end

    if GetResourceState('mri_Qcarkeys') ~= 'started' then
        exports.qbx_core:Notify(source, locale('error.key_copy_unavailable'), 'error')
        return false
    end

    local account = ChargePlayer(player, price, reason)
    if not account then
        exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
        return false
    end

    local plate = playerVehicle.props.plate
    if not deliver(plate) then
        player.Functions.AddMoney(account, price, reason .. '-refund')
        exports.qbx_core:Notify(source, locale('error.key_copy_unavailable'), 'error')
        return false
    end

    exports.qbx_core:Notify(source, locale(successLocale, plate), 'success')
    AddVehicleLog(vehicleId, locale(logLocale, lib.math.groupdigits(price)))
    return true
end

lib.callback.register('noir_garage:server:buyKeyCopy', function(source, vehicleId, garageName, accessPointIndex)
    return sellKeyService(source, vehicleId, garageName, accessPointIndex, Config.keyCopyPrice, 'garage-key-copy', function(plate)
        return exports.mri_Qcarkeys:GivePermanentKey(source, plate, true)
    end, 'success.key_copy', 'logs.key_copy')
end)

lib.callback.register('noir_garage:server:changeLock', function(source, vehicleId, garageName, accessPointIndex)
    return sellKeyService(source, vehicleId, garageName, accessPointIndex, Config.lockChangePrice, 'garage-lock-change', function(plate)
        return exports.mri_Qcarkeys:ChangeLock(source, plate)
    end, 'success.lock_changed', 'logs.lock_changed')
end)

---Apelido: texto simples, sem quebra de linha nem marcacao.
---@param name any
---@return string?
local function sanitizeNickname(name)
    if type(name) ~= 'string' then return end
    name = name:gsub('[%c<>]', ''):gsub('%s+', ' ')
    name = qbx.string.trim(name)
    if name == '' or #name > Config.rename.maxLength then return end
    return name
end

lib.callback.register('noir_garage:server:renameVehicle', function(source, vehicleId, garageName, accessPointIndex, newName)
    if not Config.rename.enabled then return false end
    local garage, playerVehicle = getOwnedVehicleAtGarage(source, vehicleId, garageName, accessPointIndex)
    if not garage or not playerVehicle then return false end

    local nickname = sanitizeNickname(newName)
    if not nickname then
        exports.qbx_core:Notify(source, locale('error.invalid_name', Config.rename.maxLength), 'error')
        return false
    end

    Storage.setNickname(vehicleId, nickname)
    AddVehicleLog(vehicleId, locale('logs.renamed', nickname))
    return nickname
end)

---@param player table
---@param fromGarage GarageConfig
---@param fromName string
---@param playerVehicle PlayerVehicle
---@return {value: string, label: string}[]
local function getTransferTargets(player, fromGarage, fromName, playerVehicle)
    local targets = {}
    local vehicleType = GetVehicleType(playerVehicle)
    for name, garage in pairs(Garages) do
        if name ~= fromName and name ~= playerVehicle.garage
            and garage.type ~= GarageType.DEPOT
            and garage.vehicleType == vehicleType
            and CanAccessGarage(player, garage) then
            targets[#targets + 1] = { value = name, label = garage.label }
        end
    end
    table.sort(targets, function(a, b) return a.label < b.label end)
    return targets
end

lib.callback.register('noir_garage:server:getTransferTargets', function(source, vehicleId, garageName, accessPointIndex)
    if not Config.transfer.enabled then return {} end
    local garage, playerVehicle, player = getOwnedVehicleAtGarage(source, vehicleId, garageName, accessPointIndex)
    if not garage or not playerVehicle or not player then return {} end
    if not isGaragedHere(garage, garageName, playerVehicle) then return {} end
    return getTransferTargets(player, garage, garageName, playerVehicle)
end)

lib.callback.register('noir_garage:server:transferVehicle', function(source, vehicleId, garageName, accessPointIndex, targetName)
    if not Config.transfer.enabled then return false end
    local garage, playerVehicle, player = getOwnedVehicleAtGarage(source, vehicleId, garageName, accessPointIndex)
    if not garage or not playerVehicle or not player then return false end
    if not isGaragedHere(garage, garageName, playerVehicle) then return false end

    local target = type(targetName) == 'string' and Garages[targetName]
    local allowed = false
    if target then
        for _, option in ipairs(getTransferTargets(player, garage, garageName, playerVehicle)) do
            if option.value == targetName then allowed = true break end
        end
    end
    if not target or not allowed then
        exports.qbx_core:Notify(source, locale('error.transfer_invalid'), 'error')
        return false
    end

    local price = Config.transfer.price
    local account = ChargePlayer(player, price, 'garage-transfer')
    if not account then
        exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
        return false
    end

    if Storage.moveGaragedVehicle(vehicleId, playerVehicle.garage, targetName) == 0 then
        if price > 0 then player.Functions.AddMoney(account, price, 'garage-transfer-refund') end
        exports.qbx_core:Notify(source, locale('error.transfer_invalid'), 'error')
        return false
    end

    local fromLabel = Garages[playerVehicle.garage]?.label or playerVehicle.garage
    exports.qbx_core:Notify(source, locale('success.transferred', target.label), 'success')
    AddVehicleLog(vehicleId, locale('logs.transferred', fromLabel, target.label))
    return true
end)

lib.callback.register('noir_garage:server:getVehicleLogs', function(source, vehicleId, garageName, accessPointIndex)
    local garage, playerVehicle = getOwnedVehicleAtGarage(source, vehicleId, garageName, accessPointIndex)
    if not garage or not playerVehicle then return {} end
    return Storage.getLogs(vehicleId)
end)
