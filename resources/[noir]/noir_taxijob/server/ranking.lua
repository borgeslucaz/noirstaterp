-- Ranking geral por Confiança: consulta lazy, cache global com TTL, rebuild único sob concorrência.
Ranking = {}

local R = ServerConfig.Ranking

local cache = nil        ---@type { generatedAt: number, entries: table[], byCitizen: table<string, number> }|nil
local cacheAt = 0        -- GetGameTimer() da última rebuild
local dirty = true
local rebuilding = false
local selfCache = {}     ---@type table<string, table> posição do solicitante dentro do snapshot atual

function Ranking.markDirty()
    dirty = true
end

local function rebuild()
    if rebuilding then
        while rebuilding do Wait(50) end
        return
    end
    rebuilding = true
    local started = GetGameTimer()
    local ok, rows = pcall(MySQL.query.await, [[
        SELECT citizenid, display_name, confidence, completed_rides
        FROM noir_taxi_profiles
        WHERE completed_rides >= ?
        ORDER BY confidence DESC, completed_rides DESC, confidence_reached_at ASC, citizenid ASC
        LIMIT ?
    ]], { R.MinCompletedRides, R.TopSize })
    if ok and rows then
        local entries, byCitizen = {}, {}
        for i, row in ipairs(rows) do
            local confidence = math.floor(tonumber(row.confidence) or 0)
            entries[i] = {
                position = i,
                displayName = Security.sanitizeName(row.display_name),
                confidence = confidence,
                level = Progression.levelFor(confidence).level,
                completedRides = math.floor(tonumber(row.completed_rides) or 0),
            }
            byCitizen[row.citizenid] = i
        end
        cache = { generatedAt = os.time(), entries = entries, byCitizen = byCitizen }
        cacheAt = GetGameTimer()
        dirty = false
        selfCache = {}
        Sessions.debug('ranking_cache rebuilt entries=%d durationMs=%d', #entries, GetGameTimer() - started)
    else
        print(('[noir_taxijob] ranking rebuild falhou: %s'):format(tostring(rows)))
    end
    rebuilding = false
end

---@param citizenid string
---@return table|nil self
local function selfPosition(citizenid)
    if not cache then return nil end
    if selfCache[citizenid] ~= nil then return selfCache[citizenid] or nil end

    local ok, row = pcall(MySQL.single.await, [[
        SELECT p.display_name, p.confidence, p.completed_rides,
            (SELECT COUNT(*) FROM noir_taxi_profiles o
              WHERE o.completed_rides >= ?
                AND (o.confidence > p.confidence
                  OR (o.confidence = p.confidence AND o.completed_rides > p.completed_rides)
                  OR (o.confidence = p.confidence AND o.completed_rides = p.completed_rides AND o.confidence_reached_at < p.confidence_reached_at)
                  OR (o.confidence = p.confidence AND o.completed_rides = p.completed_rides AND o.confidence_reached_at = p.confidence_reached_at AND o.citizenid < p.citizenid))
            ) + 1 AS position
        FROM noir_taxi_profiles p WHERE p.citizenid = ?
    ]], { R.MinCompletedRides, citizenid })
    if not ok or not row then
        selfCache[citizenid] = false
        return nil
    end
    local rides = math.floor(tonumber(row.completed_rides) or 0)
    local confidence = math.floor(tonumber(row.confidence) or 0)
    local entry = {
        position = rides >= R.MinCompletedRides and math.floor(tonumber(row.position) or 0) or nil,
        displayName = Security.sanitizeName(row.display_name),
        confidence = confidence,
        level = Progression.levelFor(confidence).level,
        completedRides = rides,
    }
    selfCache[citizenid] = entry
    return entry
end

---Snapshot cacheado (Top N + posição do solicitante). Nunca expõe citizenid ou identificadores.
---@param citizenid string
---@return table|nil
function Ranking.snapshot(citizenid)
    if not Progression.ready then return nil end
    local now = GetGameTimer()
    if not cache or (dirty and (now - cacheAt) >= R.CacheTtlMs) or (now - cacheAt) >= R.CacheTtlMs * 10 then
        rebuild()
    end
    if not cache then return nil end
    return {
        generatedAt = cache.generatedAt,
        entries = cache.entries,
        self = selfPosition(citizenid),
    }
end
