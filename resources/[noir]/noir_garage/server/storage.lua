---Apelido e historico ficam numa tabela propria (o rhd_garage criava colunas no player_vehicles).
local function ensureSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `noir_garage_vehicles` (
            `vehicle_id` INT NOT NULL,
            `nickname` VARCHAR(32) NULL DEFAULT NULL,
            `logs` LONGTEXT NULL DEFAULT NULL,
            PRIMARY KEY (`vehicle_id`)
        )
    ]])
end

---@async
local function moveOutVehiclesIntoGarages()
    MySQL.update('UPDATE player_vehicles SET state = ? WHERE state = ?', {VehicleState.GARAGED, VehicleState.OUT})
end

---@param vehicleId integer
---@param garageName string
---@param state VehicleState
---@return integer numRowsAffected
local function setVehicleGarage(vehicleId, garageName, state)
    return MySQL.update.await('UPDATE player_vehicles SET garage = ?, state = ? WHERE id = ?', {
        garageName,
        state,
        vehicleId
    })
end

---Muda de garagem so se o carro ainda estiver guardado na garagem de origem (evita corrida com retirar).
---@param vehicleId integer
---@param fromGarage string
---@param toGarage string
---@return integer numRowsAffected
local function moveGaragedVehicle(vehicleId, fromGarage, toGarage)
    return MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE id = ? AND garage = ? AND state = ?', {
        toGarage,
        vehicleId,
        fromGarage,
        VehicleState.GARAGED
    })
end

---@param vehicleId integer
---@param depotPrice integer
---@return integer numRowsAffected
local function setVehicleDepotPrice(vehicleId, depotPrice)
    return MySQL.update.await('UPDATE player_vehicles SET depotPrice = ? WHERE id = ? AND state != ?', {
        depotPrice,
        vehicleId,
        VehicleState.GARAGED
    })
end

---@param vehicleIds integer[]
---@return table<integer, string> nicknames
local function getNicknames(vehicleIds)
    local nicknames = {}
    if #vehicleIds == 0 then return nicknames end

    local placeholders = string.rep('?,', #vehicleIds):sub(1, -2)
    local rows = MySQL.query.await(
        ('SELECT vehicle_id, nickname FROM noir_garage_vehicles WHERE nickname IS NOT NULL AND vehicle_id IN (%s)'):format(placeholders),
        vehicleIds
    )
    for i = 1, #(rows or {}) do
        nicknames[rows[i].vehicle_id] = rows[i].nickname
    end
    return nicknames
end

---@param vehicleId integer
---@param nickname string?
local function setNickname(vehicleId, nickname)
    MySQL.prepare.await([[
        INSERT INTO noir_garage_vehicles (vehicle_id, nickname) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE nickname = VALUES(nickname)
    ]], { vehicleId, nickname })
end

---@param vehicleId integer
---@return {date: string, message: string}[]
local function getLogs(vehicleId)
    local raw = MySQL.scalar.await('SELECT logs FROM noir_garage_vehicles WHERE vehicle_id = ?', { vehicleId })
    local logs = raw and json.decode(raw)
    return type(logs) == 'table' and logs or {}
end

---@param vehicleId integer
---@param logs {date: string, message: string}[]
local function setLogs(vehicleId, logs)
    MySQL.prepare.await([[
        INSERT INTO noir_garage_vehicles (vehicle_id, logs) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE logs = VALUES(logs)
    ]], { vehicleId, json.encode(logs) })
end

return {
    ensureSchema = ensureSchema,
    moveOutVehiclesIntoGarages = moveOutVehiclesIntoGarages,
    setVehicleGarage = setVehicleGarage,
    moveGaragedVehicle = moveGaragedVehicle,
    setVehicleDepotPrice = setVehicleDepotPrice,
    getNicknames = getNicknames,
    setNickname = setNickname,
    getLogs = getLogs,
    setLogs = setLogs,
}
