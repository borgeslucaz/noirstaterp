-- Progressão de Confiança: schema, níveis, perfil, ledger idempotente e agregados diários.
-- A tabela própria do Taxi V2 é a única fonte de verdade; metadata do Qbox não é lido nem escrito.
Progression = { ready = false }

local PG = ServerConfig.Progression
local MG = ServerConfig.Migration

local schema = {
    [[
CREATE TABLE IF NOT EXISTS `noir_taxi_profiles` (
    `citizenid` VARCHAR(50) NOT NULL,
    `display_name` VARCHAR(48) NOT NULL DEFAULT '',
    `confidence` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `completed_rides` INT UNSIGNED NOT NULL DEFAULT 0,
    `total_earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `confidence_reached_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `schema_version` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    `migrated_from` VARCHAR(32) NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`),
    INDEX `idx_noir_taxi_ranking` (`completed_rides`, `confidence` DESC, `confidence_reached_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
CREATE TABLE IF NOT EXISTS `noir_taxi_daily_stats` (
    `citizenid` VARCHAR(50) NOT NULL,
    `day_key` CHAR(10) NOT NULL,
    `earned` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `completed_rides` INT UNSIGNED NOT NULL DEFAULT 0,
    `confidence_earned` INT UNSIGNED NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`, `day_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
CREATE TABLE IF NOT EXISTS `noir_taxi_fare_results` (
    `fare_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `fare_amount` INT UNSIGNED NOT NULL DEFAULT 0,
    `confidence_delta` INT UNSIGNED NOT NULL DEFAULT 0,
    `distance_meters` INT UNSIGNED NOT NULL DEFAULT 0,
    `satisfaction` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `day_key` CHAR(10) NOT NULL,
    `completed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`fare_id`),
    INDEX `idx_noir_taxi_fare_citizen` (`citizenid`, `day_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
}

local function log(fmt, ...)
    print(('[noir_taxijob] ' .. fmt):format(...))
end

-- ───────────────────────── níveis ─────────────────────────

local levels = {}
do
    for _, l in ipairs(PG.Levels) do levels[#levels + 1] = { level = l.level, min = l.min, label = l.label } end
    table.sort(levels, function(a, b) return a.min < b.min end)
    for i = 2, #levels do
        if levels[i].min <= levels[i - 1].min then
            error(('[noir_taxijob] Progression.Levels inválido: nível %s não é maior que o anterior'):format(levels[i].level))
        end
    end
    if #levels == 0 or levels[1].min ~= 0 then
        error('[noir_taxijob] Progression.Levels precisa começar em 0')
    end
end

---O nível é o maior cuja confiança mínima seja ≤ à Confiança do jogador.
---@param confidence number
---@return table view { level, levelLabel, levelStart, nextLevelAt, nextLevelLabel, confidenceRemaining, progressPercent, maxLevel }
function Progression.levelFor(confidence)
    confidence = math.max(0, math.floor(tonumber(confidence) or 0))
    local idx = 1
    for i = 1, #levels do
        if confidence >= levels[i].min then idx = i else break end
    end
    local cur, nxt = levels[idx], levels[idx + 1]
    if not nxt then
        return {
            level = cur.level, levelLabel = cur.label, levelStart = cur.min,
            nextLevelAt = nil, nextLevelLabel = nil, confidenceRemaining = 0, progressPercent = 100, maxLevel = true,
        }
    end
    local span = nxt.min - cur.min
    local pct = span > 0 and math.floor(((confidence - cur.min) / span) * 100 + 0.5) or 100
    return {
        level = cur.level, levelLabel = cur.label, levelStart = cur.min,
        nextLevelAt = nxt.min, nextLevelLabel = nxt.label, confidenceRemaining = math.max(0, nxt.min - confidence),
        progressPercent = math.max(0, math.min(100, pct)), maxLevel = false,
    }
end

function Progression.maxLevel()
    return levels[#levels].level
end

---Confiança concedida por uma corrida validada, a partir da satisfação calculada pelo servidor.
---@param satisfaction number
---@return number
function Progression.confidenceFor(satisfaction)
    local C = Config.Climate
    local delta = PG.BasePerFare
    if satisfaction >= C.SatisfiedThreshold then
        delta = delta + PG.SatisfiedBonus
    elseif satisfaction > C.UnhappyThreshold then
        delta = delta + PG.NeutralBonus
    else
        delta = delta + PG.UnhappyBonus
    end
    return math.max(0, math.floor(delta))
end

-- ───────────────────────── dia canônico ─────────────────────────

---@param epoch? number
---@return string dayKey `YYYY-MM-DD`
function Progression.dayKey(epoch)
    local shifted = (epoch or os.time()) + (PG.DayUtcOffsetMinutes * 60) - (PG.DayResetHour * 3600)
    return os.date('!%Y-%m-%d', shifted)
end

-- ───────────────────────── migração legada ─────────────────────────

-- Statements fixos por tabela legada: nenhum identifier é concatenado a partir de entrada externa.
local legacyQueries = {
    ak4y_taxi = 'SELECT `xp`, `completedroutes`, `earnedmoney` FROM `ak4y_taxi` WHERE `identifier` = ? LIMIT 1',
    noir_taxijob = 'SELECT `xp`, `completedroutes`, `earnedmoney` FROM `noir_taxijob` WHERE `identifier` = ? LIMIT 1',
}
local legacyAvailable = {} ---@type table<string, boolean>
local migrationReport = { imported = 0, rejected = 0, none = 0 }

local function detectLegacyTables()
    for _, name in ipairs(MG.Sources) do
        if legacyQueries[name] then
            local ok, count = pcall(MySQL.scalar.await,
                'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
            legacyAvailable[name] = ok and tonumber(count) == 1
            if legacyAvailable[name] then log('migração: tabela legada `%s` disponível', name) end
        end
    end
end

---@param citizenid string
---@return table|nil { confidence, rides, earned, source }
local function readLegacy(citizenid)
    if not MG.Enabled then return nil end
    for _, name in ipairs(MG.Sources) do
        if legacyAvailable[name] then
            local ok, row = pcall(MySQL.single.await, legacyQueries[name], { citizenid })
            if ok and row then
                local xp = Security.sanitizeInt(row.xp, 0, MG.MaxLegacyXp)
                if not xp then
                    migrationReport.rejected = migrationReport.rejected + 1
                    return nil
                end
                local rides = 0
                if type(row.completedroutes) == 'string' and #row.completedroutes > 0 then
                    local okJson, routes = pcall(json.decode, row.completedroutes)
                    if okJson and type(routes) == 'table' then
                        rides = math.min(#routes, MG.MaxLegacyRoutes)
                    end
                end
                local earned = Security.sanitizeInt(row.earnedmoney, 0) or 0
                return {
                    confidence = math.floor(xp * MG.XpConversionFactor),
                    rides = rides,
                    earned = earned,
                    source = name,
                }
            end
        end
    end
    return nil
end

-- ───────────────────────── perfil ─────────────────────────

---@param row table linha de noir_taxi_profiles
---@param earnedToday number
---@return table profile projeção enviada à NUI
function Progression.view(row, earnedToday)
    local confidence = math.floor(tonumber(row.confidence) or 0)
    local lv = Progression.levelFor(confidence)
    return {
        displayName = row.display_name,
        confidence = confidence,
        level = lv.level,
        levelLabel = lv.levelLabel,
        levelStart = lv.levelStart,
        nextLevelAt = lv.nextLevelAt,
        nextLevelLabel = lv.nextLevelLabel,
        confidenceRemaining = lv.confidenceRemaining,
        progressPercent = lv.progressPercent,
        maxLevel = lv.maxLevel,
        earnedToday = math.floor(tonumber(earnedToday) or 0),
        completedRides = math.floor(tonumber(row.completed_rides) or 0),
    }
end

---Carrega (ou cria com Confiança zero) o perfil do personagem.
---@param citizenid string
---@param displayName string já sanitizado
---@return table|nil row
function Progression.getProfile(citizenid, displayName)
    if not Progression.ready then return nil end
    local ok, row = pcall(MySQL.single.await,
        'SELECT citizenid, display_name, confidence, completed_rides, total_earned FROM noir_taxi_profiles WHERE citizenid = ?',
        { citizenid })
    if not ok then
        log('getProfile falhou (select): %s', tostring(row))
        return nil
    end
    if row then
        if displayName and row.display_name ~= displayName then
            pcall(MySQL.update.await, 'UPDATE noir_taxi_profiles SET display_name = ? WHERE citizenid = ?', { displayName, citizenid })
            row.display_name = displayName
        end
        return row
    end

    local legacy = readLegacy(citizenid)
    local confidence, rides, earned, from = 0, 0, 0, nil
    if legacy then
        confidence, rides, earned, from = legacy.confidence, legacy.rides, legacy.earned, legacy.source
    end
    local okIns, err = pcall(MySQL.insert.await, [[
        INSERT INTO noir_taxi_profiles (citizenid, display_name, confidence, completed_rides, total_earned, schema_version, migrated_from)
        VALUES (?, ?, ?, ?, ?, 1, ?)
        ON DUPLICATE KEY UPDATE display_name = VALUES(display_name)
    ]], { citizenid, displayName or 'Motorista', confidence, rides, earned, from })
    if not okIns then
        log('getProfile falhou (insert): %s', tostring(err))
        return nil
    end
    if legacy then
        migrationReport.imported = migrationReport.imported + 1
        log('migração: perfil importado de `%s` (confiança=%s corridas=%s)', from, confidence, rides)
    else
        migrationReport.none = migrationReport.none + 1
    end
    return {
        citizenid = citizenid, display_name = displayName or 'Motorista',
        confidence = confidence, completed_rides = rides, total_earned = earned,
    }
end

---@param citizenid string
---@param dayKey? string
---@return number earnedToday
function Progression.earnedToday(citizenid, dayKey)
    if not Progression.ready then return 0 end
    local ok, earned = pcall(MySQL.scalar.await,
        'SELECT earned FROM noir_taxi_daily_stats WHERE citizenid = ? AND day_key = ?',
        { citizenid, dayKey or Progression.dayKey() })
    if not ok then return 0 end
    return math.floor(tonumber(earned) or 0)
end

---Resultado persistente de uma corrida: ledger + perfil + diário em uma transação.
---Repetir o mesmo `fareKey` não pontua novamente (chave primária do ledger).
---@param citizenid string
---@param fareKey string
---@param amount number
---@param confidenceDelta number
---@param distance number
---@param satisfaction number
---@return boolean persisted
---@return table|nil row perfil atualizado
function Progression.recordFare(citizenid, fareKey, amount, confidenceDelta, distance, satisfaction)
    if not Progression.ready then return false end
    local dayKey = Progression.dayKey()
    amount = math.max(0, math.floor(amount))
    confidenceDelta = math.max(0, math.floor(confidenceDelta))

    local okDup, exists = pcall(MySQL.scalar.await, 'SELECT 1 FROM noir_taxi_fare_results WHERE fare_id = ?', { fareKey })
    if okDup and exists then
        log('recordFare: fareKey %s já registrado; ignorando repetição', fareKey)
        return false
    end

    local ok, result = pcall(MySQL.transaction.await, {
        {
            query = [[INSERT INTO noir_taxi_fare_results
                (fare_id, citizenid, fare_amount, confidence_delta, distance_meters, satisfaction, day_key)
                VALUES (?, ?, ?, ?, ?, ?, ?)]],
            values = { fareKey, citizenid, amount, confidenceDelta, math.floor(distance), math.floor(satisfaction), dayKey },
        },
        {
            query = [[UPDATE noir_taxi_profiles SET
                confidence = LEAST(confidence + ?, ?),
                completed_rides = completed_rides + 1,
                total_earned = total_earned + ?,
                confidence_reached_at = IF(? > 0, CURRENT_TIMESTAMP, confidence_reached_at)
                WHERE citizenid = ?]],
            values = { confidenceDelta, PG.MaxConfidence, amount, confidenceDelta, citizenid },
        },
        {
            query = [[INSERT INTO noir_taxi_daily_stats (citizenid, day_key, earned, completed_rides, confidence_earned)
                VALUES (?, ?, ?, 1, ?)
                ON DUPLICATE KEY UPDATE
                    earned = earned + VALUES(earned),
                    completed_rides = completed_rides + 1,
                    confidence_earned = confidence_earned + VALUES(confidence_earned)]],
            values = { citizenid, dayKey, amount, confidenceDelta },
        },
    })
    if not ok or not result then
        log('recordFare falhou: %s', tostring(result))
        return false
    end

    Ranking.markDirty()

    local okRow, row = pcall(MySQL.single.await,
        'SELECT citizenid, display_name, confidence, completed_rides, total_earned FROM noir_taxi_profiles WHERE citizenid = ?',
        { citizenid })
    return true, okRow and row or nil
end

function Progression.report()
    return migrationReport
end

MySQL.ready(function()
    for _, stmt in ipairs(schema) do
        local ok, err = pcall(MySQL.query.await, stmt)
        if not ok then
            log('falha ao criar schema: %s', tostring(err))
            return
        end
    end
    if MG.Enabled then detectLegacyTables() end
    Progression.ready = true
    Sessions.debug('progression ready (níveis=%d, max=%d)', #levels, Progression.maxLevel())
end)
