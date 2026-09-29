---Único ponto de SQL do resource. Só toca as tabelas `busjob_*` criadas pelas migrations.

local Storage = {}

local MIGRATIONS = { 'migrations/001_initial.sql', 'migrations/002_editor.sql', 'migrations/003_traces.sql' }
local ready = false

---Roda as migrations. Só `CREATE TABLE IF NOT EXISTS` é aceito: migration destrutiva não
---roda sozinha no boot.
function Storage.migrate()
    local executed = 0
    for _, path in ipairs(MIGRATIONS) do
        local sql = LoadResourceFile(GetCurrentResourceName(), path)
        if not sql or sql == '' then error(('%s não encontrada'):format(path)) end
        for raw in sql:gmatch('([^;]+);') do
            local statement = raw:match('^%s*(.-)%s*$')
            if statement ~= '' then
                if not statement:upper():match('^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+') then
                    error(('comando não permitido em %s: %s'):format(path, statement:sub(1, 80)))
                end
                MySQL.query.await(statement)
                executed = executed + 1
            end
        end
    end
    ready = true
    return executed
end

---@return boolean
function Storage.isReady()
    return ready
end

-- Catálogo ----------------------------------------------------------------------------

---@return { stops: table[], routes: table[], vehicles: table[], settings: table[] }
function Storage.loadCatalog()
    return {
        stops = MySQL.query.await('SELECT id, data FROM busjob_stops ORDER BY id') or {},
        routes = MySQL.query.await('SELECT id, data FROM busjob_routes ORDER BY id') or {},
        vehicles = MySQL.query.await('SELECT model, data FROM busjob_vehicles ORDER BY model') or {},
        settings = MySQL.query.await('SELECT `key`, data FROM busjob_settings') or {},
    }
end

---Tabelas do editor vazias = primeiro boot da versão com editor.
---@return boolean
function Storage.catalogEmpty()
    local count = MySQL.scalar.await('SELECT (SELECT COUNT(*) FROM busjob_stops) + (SELECT COUNT(*) FROM busjob_settings)')
    return (tonumber(count) or 0) == 0
end

---Grava o catálogo inicial numa transação só: ou entra tudo, ou nada.
---@param rows { stops: table[], routes: table[], vehicles: table[], settings: table[] } dados já em JSON
---@return boolean
function Storage.seed(rows)
    local queries = {}
    for _, row in ipairs(rows.settings) do
        queries[#queries + 1] = { query = 'INSERT INTO busjob_settings (`key`, data) VALUES (?, ?)', values = { row.key, row.data } }
    end
    for _, row in ipairs(rows.vehicles) do
        queries[#queries + 1] = { query = 'INSERT INTO busjob_vehicles (model, data) VALUES (?, ?)', values = { row.model, row.data } }
    end
    for _, row in ipairs(rows.stops) do
        queries[#queries + 1] = { query = 'INSERT INTO busjob_stops (id, data) VALUES (?, ?)', values = { row.id, row.data } }
    end
    for _, row in ipairs(rows.routes) do
        queries[#queries + 1] = { query = 'INSERT INTO busjob_routes (id, data) VALUES (?, ?)', values = { row.id, row.data } }
    end
    return MySQL.transaction.await(queries) == true
end

---@param id integer? nil = parada nova
---@param data string json
---@return integer? id
function Storage.saveStop(id, data)
    if id then
        local ok = pcall(MySQL.update.await, 'UPDATE busjob_stops SET data = ? WHERE id = ?', { data, id })
        return ok and id or nil
    end
    local ok, newId = pcall(MySQL.insert.await, 'INSERT INTO busjob_stops (data) VALUES (?)', { data })
    return ok and tonumber(newId) or nil
end

---@return boolean
function Storage.deleteStop(id)
    return (pcall(MySQL.query.await, 'DELETE FROM busjob_stops WHERE id = ?', { id }))
end

---@return boolean
function Storage.saveRoute(id, data)
    return (pcall(MySQL.query.await, 'INSERT INTO busjob_routes (id, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { id, data }))
end

---@return boolean
function Storage.deleteRoute(id)
    return (pcall(MySQL.query.await, 'DELETE FROM busjob_routes WHERE id = ?', { id }))
end

---@return boolean
function Storage.saveVehicle(model, data)
    return (pcall(MySQL.query.await, 'INSERT INTO busjob_vehicles (model, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { model, data }))
end

---@return boolean
function Storage.deleteVehicle(model)
    return (pcall(MySQL.query.await, 'DELETE FROM busjob_vehicles WHERE model = ?', { model }))
end

---@return boolean
function Storage.saveSetting(key, data)
    return (pcall(MySQL.query.await, 'INSERT INTO busjob_settings (`key`, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)', { key, data }))
end

---Registro de auditoria do editor. Falha aqui não desfaz a edição, só vira aviso.
function Storage.log(citizenId, playerName, action, entity, entityId, data)
    local ok = pcall(MySQL.insert.await,
        'INSERT INTO busjob_editor_log (citizenid, player_name, action, entity, entity_id, data) VALUES (?, ?, ?, ?, ?, ?)',
        { citizenId, playerName, action, entity, tostring(entityId), data })
    if not ok then lib.print.warn(('registro do editor falhou (%s %s %s)'):format(action, entity, tostring(entityId))) end
end

-- Traçados pela estrada (/onibusrota ... save) ----------------------------------------

---@return table[]
function Storage.loadTraces()
    return MySQL.query.await('SELECT route_id, signature, road_meters, straight_meters, failed_legs, points, traced_by, updated_at FROM busjob_route_traces') or {}
end

---@return boolean
function Storage.saveTrace(entry)
    return (pcall(MySQL.query.await, [[INSERT INTO busjob_route_traces (route_id, signature, road_meters, straight_meters, failed_legs, points, traced_by)
        VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE signature = VALUES(signature), road_meters = VALUES(road_meters),
        straight_meters = VALUES(straight_meters), failed_legs = VALUES(failed_legs), points = VALUES(points), traced_by = VALUES(traced_by)]],
        { entry.routeId, entry.signature, entry.roadMeters, entry.straightMeters, entry.failedLegs, entry.points, entry.tracedBy }))
end

-- Jogadores ---------------------------------------------------------------------------

---@return table? row
function Storage.profile(citizenId)
    return MySQL.single.await('SELECT * FROM busjob_driver_profiles WHERE citizenid = ?', { citizenId })
end

function Storage.createProfile(citizenId, name)
    MySQL.insert.await('INSERT IGNORE INTO busjob_driver_profiles (citizenid, last_known_name) VALUES (?, ?)', { citizenId, name })
end

function Storage.renameProfile(citizenId, name)
    MySQL.update.await('UPDATE busjob_driver_profiles SET last_known_name = ? WHERE citizenid = ?', { name, citizenId })
end

---@return integer?
function Storage.profileXp(citizenId)
    return tonumber(MySQL.scalar.await('SELECT xp_total FROM busjob_driver_profiles WHERE citizenid = ?', { citizenId }))
end

---@return table[]
function Storage.leaderboard()
    return MySQL.query.await([[SELECT last_known_name, level, xp_total, routes_completed, score_sum / NULLIF(routes_completed, 0) average_score
        FROM busjob_driver_profiles ORDER BY xp_total DESC, routes_completed DESC, average_score DESC, passengers_transported DESC LIMIT 50]]) or {}
end

---@return integer
function Storage.rankOf(citizenId)
    return tonumber(MySQL.scalar.await([[SELECT COUNT(*) + 1 FROM busjob_driver_profiles o JOIN busjob_driver_profiles p ON p.citizenid = ?
        WHERE o.xp_total > p.xp_total OR (o.xp_total = p.xp_total AND o.routes_completed > p.routes_completed)
        OR (o.xp_total = p.xp_total AND o.routes_completed = p.routes_completed AND (o.score_sum / NULLIF(o.routes_completed, 0)) > (p.score_sum / NULLIF(p.routes_completed, 0)))]], { citizenId })) or 1
end

---Fecha a volta: perfil e histórico na mesma transação.
---@return boolean
function Storage.completeRoute(entry)
    return MySQL.transaction.await({
        {
            query = [[UPDATE busjob_driver_profiles SET xp_total = ?, level = ?, routes_completed = routes_completed + 1,
                stops_completed = stops_completed + ?, passengers_transported = passengers_transported + ?, perfect_stops = perfect_stops + ?,
                total_earned = total_earned + ?, distance_meters = distance_meters + ?, score_sum = score_sum + ?, best_score = GREATEST(best_score, ?),
                last_route_id = ?, last_route_at = NOW() WHERE citizenid = ?]],
            values = { entry.xpTotal, entry.level, entry.stops, entry.passengers, entry.perfectStops, entry.pay, entry.distance,
                entry.finalScore, entry.finalScore, entry.routeId, entry.citizenId },
        },
        {
            query = [[INSERT INTO busjob_route_history (citizenid, route_id, vehicle_model, started_at, completed_at, duration_seconds,
                stops_completed, passengers_transported, stop_score, safety_score, punctuality_score, service_score, final_score, payout, xp_earned)
                VALUES (?, ?, ?, FROM_UNIXTIME(?), NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            values = { entry.citizenId, entry.routeId, entry.vehicleModel, entry.startedAt, entry.duration, entry.stops, entry.passengers,
                entry.stopScore, entry.safetyScore, entry.punctualityScore, entry.serviceScore, entry.finalScore, entry.pay, entry.xp },
        },
    }) == true
end

return Storage
