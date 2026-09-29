-- Aluguel de veículos da central: validação server-side por ID do catálogo, mutex por jogador, spawn e devolução.
Rental = {}

local RL = ServerConfig.RateLimits
local CC = ServerConfig.Central
local D = Config.Depot

local pending = {} ---@type table<number, boolean> mutex por source durante VALIDATING/SPAWNING

local function findFreeSpawnPoint(bucket)
    local vehicles = GetAllVehicles()
    for _, point in ipairs(D.spawnPoints) do
        local free = true
        for _, veh in ipairs(vehicles) do
            if GetEntityRoutingBucket(veh) == bucket and #(GetEntityCoords(veh) - vec3(point.x, point.y, point.z)) < 2.5 then
                free = false
                break
            end
        end
        if free then return point end
    end
    return nil
end

local function refund(src, amount)
    if amount > 0 then
        exports.bgrz_core:AddMoney(src, CC.RentalAccount, amount, 'taxi-rental-refund')
    end
end

local function deleteNet(netId)
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh ~= 0 and DoesEntityExist(veh) then DeleteEntity(veh) end
end

---@param src number
---@param token any
---@param vehicleId any
---@return table
local function doRent(src, token, vehicleId)
    local session, code = Central.validateSession(src, token)
    if not session then return { ok = false, code = code } end

    local character = Central.identity(src)
    if not character or character.citizenId ~= session.citizenid then return { ok = false, code = 'not_loaded' } end
    if Central.isRestricted(character) then return { ok = false, code = 'activity_restricted' } end
    if not Security.isOnFoot(src) then return { ok = false, code = 'activity_restricted' } end
    if not Central.isNearDepot(src) then
        Security.report(src, 'rentVehicle', 'not_near_depot')
        return { ok = false, code = 'not_near' }
    end

    local id = Security.sanitizeString(vehicleId, 32)
    local entry = id and Config.GetRentalVehicle(id)
    if not entry then
        Security.report(src, 'rentVehicle', 'invalid_vehicle', { vehicleId = tostring(vehicleId):sub(1, 32) })
        return { ok = false, code = 'invalid_vehicle' }
    end
    if entry.enabled == false or not Config.IsAllowedVehicle(entry.model) then
        return { ok = false, code = 'invalid_vehicle' }
    end

    local existing = ActiveRentals[src]
    if existing then
        local veh = NetworkGetEntityFromNetworkId(existing.netId or 0)
        if existing.state ~= 'active' or (veh ~= 0 and DoesEntityExist(veh)) then
            return { ok = false, code = 'already_rented' }
        end
        ActiveRentals[src] = nil
    end

    -- Nível recalculado a partir da Confiança persistida; nunca do client.
    local row = Progression.getProfile(character.citizenId, Security.sanitizeName(character.name and character.name.full))
    if not row then return { ok = false, code = 'internal_error' } end
    local level = Progression.levelFor(row.confidence).level
    if level < entry.requiredLevel then
        Security.report(src, 'rentVehicle', 'vehicle_locked', { vehicleId = id, level = level, required = entry.requiredLevel })
        return { ok = false, code = 'vehicle_locked', requiredLevel = entry.requiredLevel }
    end

    -- Revalidação após o await do banco.
    if not Central.validateSession(src, token) then return { ok = false, code = 'session_expired' } end
    if GetPlayerPed(src) == 0 then return { ok = false, code = 'not_loaded' } end
    if not Security.isOnFoot(src) or not Central.isNearDepot(src) then return { ok = false, code = 'not_near' } end
    if ActiveRentals[src] then return { ok = false, code = 'already_rented' } end

    local bucket = GetPlayerRoutingBucket(src)
    local point = findFreeSpawnPoint(bucket)
    if not point then return { ok = false, code = 'no_spawn_space' } end

    local fee = math.max(0, math.floor(tonumber(entry.rentalFee) or 0))
    if fee > 0 then
        local balance = character.money and character.money[CC.RentalAccount] or 0
        if balance < fee then return { ok = false, code = 'insufficient_funds' } end
        if not exports.bgrz_core:RemoveMoney(src, CC.RentalAccount, fee, 'taxi-rental-fee') then
            return { ok = false, code = 'insufficient_funds' }
        end
    end

    local plate = ('TAXI%04d'):format(math.random(0, 9999))
    ---@type TaxiRental
    local rental = {
        source = src,
        citizenid = character.citizenId,
        vehicleId = id,
        netId = 0,
        plate = plate,
        state = 'spawning',
        createdAt = Sessions.now(),
    }
    ActiveRentals[src] = rental
    Sessions.debug('rental_started src=%s vehicleId=%s fee=%s', src, id, fee)

    local netId = exports.bgrz_core:SpawnVehicle(src, entry.model, point, D.warpIntoVehicle, plate)
    local veh = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if not netId or veh == 0 or not DoesEntityExist(veh) then
        ActiveRentals[src] = nil
        refund(src, fee)
        Security.report(src, 'rentVehicle', 'spawn_failed', { vehicleId = id })
        return { ok = false, code = 'spawn_failed' }
    end

    -- Jogador caiu durante o spawn: compensa e limpa a entidade parcial.
    if GetPlayerPed(src) == 0 or ActiveRentals[src] ~= rental then
        DeleteEntity(veh)
        ActiveRentals[src] = nil
        refund(src, fee)
        return { ok = false, code = 'internal_error' }
    end

    SetEntityRoutingBucket(veh, bucket)
    local state = Entity(veh).state
    state:set('noirTaxi:rental', true, true)
    state:set('noirTaxi:owner', src, true)
    state:set('noirTaxi:vehicleId', id, true)

    rental.netId = netId
    rental.state = 'active'
    Central.invalidate(src)
    Sessions.debug('rental_ready src=%s netId=%s level=%s', src, netId, level)

    return { ok = true, netId = netId, vehicleId = id, plate = plate, fee = fee }
end

lib.callback.register('noir_taxijob:server:rentVehicle', function(src, token, vehicleId)
    if not Security.rateLimit(src, 'rent', RL.rent) then return { ok = false, code = 'rate_limited' } end
    if pending[src] then return { ok = false, code = 'request_in_progress' } end
    pending[src] = true
    local ok, result = pcall(doRent, src, token, vehicleId)
    pending[src] = nil
    if not ok then
        print(('[noir_taxijob] rentVehicle erro interno src=%s: %s'):format(src, tostring(result)))
        return { ok = false, code = 'internal_error' }
    end
    return result
end)

lib.callback.register('noir_taxijob:server:returnVehicle', function(src, vehicleNetId)
    if not Security.rateLimit(src, 'returnVehicle', RL.returnVehicle) then return { ok = false, code = 'rate_limited' } end
    local netId = Security.sanitizeInt(vehicleNetId, 1)
    local rental = ActiveRentals[src]
    if not netId or not rental or rental.state ~= 'active' or rental.netId ~= netId then
        return { ok = false, code = 'not_yours' }
    end
    if not Security.isNearCoords(src, D.coords, D.returnRadius) then return { ok = false, code = 'not_near' } end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then
        Rental.cleanup(src, 'vehicle_lost')
        return { ok = false, code = 'not_yours' }
    end
    local coords = Security.getCoords(src)
    -- O táxi precisa estar na área da central (o jogador já foi validado dentro de returnRadius).
    if not coords or #(GetEntityCoords(veh) - vec3(D.coords.x, D.coords.y, D.coords.z)) > (D.returnRadius + 10.0) then return { ok = false, code = 'not_near' } end

    rental.state = 'returning'
    Sessions.removeDriver(src, 'vehicle_returned')
    DeleteEntity(veh)
    ActiveRentals[src] = nil
    Sessions.debug('rental_returned src=%s netId=%s', src, netId)
    return { ok = true }
end)

-- ───────────────────────── cleanup ─────────────────────────

---Idempotente: encerra sessão de trabalho, remove o veículo do aluguel e invalida a central.
---@param src number
---@param reason string
function Rental.cleanup(src, reason)
    Sessions.removeDriver(src, reason)
    Central.invalidate(src)
    local rental = ActiveRentals[src]
    if not rental then return end
    ActiveRentals[src] = nil
    deleteNet(rental.netId)
    Sessions.debug('rental_cleanup src=%s reason=%s', src, reason)
end

function Rental.cleanupAll()
    for src, rental in pairs(ActiveRentals) do
        ActiveRentals[src] = nil
        deleteNet(rental.netId)
    end
    pending = {}
end

-- Um único loop lento: sessões expiradas da central e alugueis cujo veículo deixou de existir ou quebrou.
CreateThread(function()
    while true do
        Wait(CC.SweepIntervalMs)
        local now = Sessions.now()
        for src, session in pairs(CentralSessions) do
            if now > session.expiresAt then CentralSessions[src] = nil end
        end
        for src, rental in pairs(ActiveRentals) do
            if rental.state == 'active' then
                local veh = NetworkGetEntityFromNetworkId(rental.netId)
                local gone = veh == 0 or not DoesEntityExist(veh)
                local broken = not gone and (GetEntityHealth(veh) <= 0 or GetVehicleEngineHealth(veh) <= 0)
                if gone or broken then
                    ActiveRentals[src] = nil
                    Sessions.removeDriver(src, 'vehicle_lost')
                    TriggerClientEvent('noir_taxijob:client:rentalEnded', src, 'vehicle_lost')
                end
            end
        end
    end
end)

---Avisa o servidor que o veículo quebrou (motor morto) ou foi destruído, detectado no client.
---Encerra o trabalho: cancela a corrida, desativa o duty e limpa o aluguel.
RegisterNetEvent('noir_taxijob:server:vehicleBroken', function()
    local src = source
    if not Security.rateLimit(src, 'vehicleBroken', ServerConfig.RateLimits.vehicleBroken) then return end
    local rental = ActiveRentals[src]
    if not rental or rental.state ~= 'active' then return end
    Rental.cleanup(src, 'vehicle_lost')
    TriggerClientEvent('noir_taxijob:client:rentalEnded', src, 'vehicle_lost')
end)
