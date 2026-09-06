-- ============================================================
-- SERVER MAIN — perfil, migração, RPC, ranking, eventos de sessão
-- ============================================================

Core = nil
local playerJobDataCache = {}
local discordAvatarCache = {}

-- ============================================================
-- RPC (request/response por eventos, independente de framework)
-- ============================================================

local rpcHandlers = {}

function RegisterRpc(name, handler)
    rpcHandlers[name] = handler
end

RegisterNetEvent('peak-trucking:rpc')
AddEventHandler('peak-trucking:rpc', function(requestId, name, data)
    local src = source
    local handler = rpcHandlers[name]
    local result
    if not handler then
        result = { ok = false, error = 'unknown_rpc' }
    else
        local ok, res = pcall(handler, src, data)
        if ok then
            result = res
        else
            Peak.Utils.Warn(('RPC "%s" falhou para %s: %s'):format(name, src, tostring(res)))
            result = { ok = false, error = 'internal', message = L('err_db') }
        end
    end
    TriggerClientEvent('peak-trucking:rpcResult', src, requestId, result)
end)

-- ============================================================
-- MIGRAÇÃO (idempotente, sem apagar dados)
-- ============================================================

local function ColumnExists(tableName, column)
    local rows = ExecuteSqlSafe(
        'SELECT COUNT(*) AS n FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tableName, column }
    )
    return rows and rows[1] and tonumber(rows[1].n) and tonumber(rows[1].n) > 0
end

local function HasPrimaryKey(tableName)
    local rows = ExecuteSqlSafe(
        "SELECT COUNT(*) AS n FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND CONSTRAINT_TYPE = 'PRIMARY KEY'",
        { tableName }
    )
    return rows and rows[1] and tonumber(rows[1].n) and tonumber(rows[1].n) > 0
end

local function RunMigrations()
    ExecuteSqlSafe([[
        CREATE TABLE IF NOT EXISTS `peak_trucking` (
            `identifier` VARCHAR(64) NOT NULL,
            `points` LONGTEXT DEFAULT NULL,
            `unlockedMissions` LONGTEXT DEFAULT NULL,
            `dailymissions` LONGTEXT DEFAULT NULL,
            `level` INT(11) NOT NULL DEFAULT 1,
            `xp` INT(11) NOT NULL DEFAULT 0,
            `totalEarnings` BIGINT NOT NULL DEFAULT 0,
            `completedJobs` INT(11) NOT NULL DEFAULT 0,
            `failedJobs` INT(11) NOT NULL DEFAULT 0,
            `globalCompleted` INT(11) NOT NULL DEFAULT 0,
            `globalFailed` INT(11) NOT NULL DEFAULT 0,
            `name` VARCHAR(128) DEFAULT NULL,
            `avatar` VARCHAR(512) DEFAULT NULL,
            `history` LONGTEXT DEFAULT NULL,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    ExecuteSqlSafe([[
        CREATE TABLE IF NOT EXISTS `peak_trucking_global_offers` (
            `offer_id` VARCHAR(96) NOT NULL,
            `rotation_id` VARCHAR(32) NOT NULL,
            `mission_id` INT NOT NULL,
            `route_index` INT NOT NULL,
            `tier` VARCHAR(16) NOT NULL,
            `status` VARCHAR(16) NOT NULL DEFAULT 'available',
            `driver_identifier` VARCHAR(64) NULL,
            `started_at` TIMESTAMP NULL,
            `finished_at` TIMESTAMP NULL,
            `result_reason` VARCHAR(64) NULL,
            PRIMARY KEY (`offer_id`),
            UNIQUE KEY `uq_rotation_route` (`rotation_id`, `mission_id`, `route_index`),
            UNIQUE KEY `uq_rotation_driver` (`rotation_id`, `driver_identifier`),
            KEY `ix_rotation_status` (`rotation_id`, `status`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    ExecuteSqlSafe([[
        CREATE TABLE IF NOT EXISTS `peak_trucking_deliveries` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `session_id` VARCHAR(96) NOT NULL,
            `identifier` VARCHAR(64) NOT NULL,
            `rotation_id` VARCHAR(32) NOT NULL,
            `offer_id` VARCHAR(96) NOT NULL,
            `mission_id` INT NOT NULL,
            `route_index` INT NOT NULL,
            `tier` VARCHAR(16) NOT NULL,
            `grade` CHAR(1) NULL,
            `score` DECIMAL(5,2) NULL,
            `base_payment` INT NOT NULL DEFAULT 0,
            `bonus_payment` INT NOT NULL DEFAULT 0,
            `penalty_payment` INT NOT NULL DEFAULT 0,
            `final_payment` INT NOT NULL DEFAULT 0,
            `xp_awarded` INT NOT NULL DEFAULT 0,
            `reputation_awarded` INT NOT NULL DEFAULT 0,
            `status` VARCHAR(16) NOT NULL,
            `result_reason` VARCHAR(64) NULL,
            `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `finished_at` TIMESTAMP NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_session` (`session_id`),
            KEY `ix_player_finished` (`identifier`, `finished_at`),
            KEY `ix_rotation` (`rotation_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    -- Perfil legado: novas colunas e chave primária sem apagar dados
    local newColumns = {
        { 'failedJobs',      'INT(11) NOT NULL DEFAULT 0' },
        { 'globalCompleted', 'INT(11) NOT NULL DEFAULT 0' },
        { 'globalFailed',    'INT(11) NOT NULL DEFAULT 0' },
    }
    for _, col in ipairs(newColumns) do
        if not ColumnExists('peak_trucking', col[1]) then
            ExecuteSqlSafe(('ALTER TABLE `peak_trucking` ADD COLUMN `%s` %s'):format(col[1], col[2]))
            Peak.Utils.print('Migração: coluna ' .. col[1] .. ' adicionada em peak_trucking.')
        end
    end

    if not HasPrimaryKey('peak_trucking') then
        local dup = ExecuteSqlSafe('SELECT identifier, COUNT(*) AS n FROM peak_trucking GROUP BY identifier HAVING n > 1 LIMIT 1')
        if dup and #dup == 0 then
            local ok1 = ExecuteSqlSafe('ALTER TABLE `peak_trucking` MODIFY `identifier` VARCHAR(64) NOT NULL')
            local ok2 = ok1 ~= nil and ExecuteSqlSafe('ALTER TABLE `peak_trucking` ADD PRIMARY KEY (`identifier`)') or nil
            if ok2 ~= nil then
                Peak.Utils.print('Migração: PRIMARY KEY(identifier) criada em peak_trucking.')
            else
                Peak.Utils.Warn('Migração: não foi possível criar PRIMARY KEY em peak_trucking (ver log do oxmysql).')
            end
        else
            Peak.Utils.Warn('Migração: peak_trucking possui identifiers duplicados — PRIMARY KEY não criada. Resolva manualmente.')
        end
    end
end

-- ============================================================
-- PERFIL (cache por identifier)
-- ============================================================

local function DecodeJson(value, default)
    if type(value) == 'string' then
        return Peak.Utils.JsonDecode(value) or default
    end
    return value or default
end

--- Returns the cached job data for a player (lazy loaded from DB), or false.
--- @param playerId number
--- @return table|false
function GetPlayerJobData(playerId)
    local identifier = GetIdentifier(playerId)
    if not identifier then return false end

    if playerJobDataCache[identifier] then
        return playerJobDataCache[identifier]
    end

    local result = ExecuteSql('SELECT * FROM peak_trucking WHERE identifier = :id', { id = identifier })
    if result and result[1] then
        local record = result[1]
        record.unlockedMissions = DecodeJson(record.unlockedMissions, {})
        record.dailymissions    = DecodeJson(record.dailymissions, nil)
        record.history          = DecodeJson(record.history, {})
        record.points           = DecodeJson(record.points, {})
        record.level            = tonumber(record.level) or 1
        record.xp               = tonumber(record.xp) or 0
        record.totalEarnings    = tonumber(record.totalEarnings) or 0
        record.completedJobs    = tonumber(record.completedJobs) or 0
        record.failedJobs       = tonumber(record.failedJobs) or 0
        record.globalCompleted  = tonumber(record.globalCompleted) or 0
        record.globalFailed     = tonumber(record.globalFailed) or 0
        for i = 0, 7 do
            local k = tostring(i)
            record.points[k] = tonumber(record.points[k]) or 0
        end
        if not record.dailymissions or type(record.dailymissions) ~= 'table' or not record.dailymissions.data then
            record.dailymissions = DailyMissions.NewSet()
        end
        playerJobDataCache[identifier] = record
        return record
    end

    return false
end

function SyncPlayerDataByKey(playerId, key, value)
    TriggerClientEvent('peak-trucking:SyncPlayerDataByKey', playerId, key, value)
end

local function ProfileProjection(profile)
    return {
        identifier = nil, -- nunca exposto
        name = profile.name,
        avatar = profile.avatar or Config.DefaultImage,
        level = profile.level,
        xp = profile.xp,
        points = profile.points,
        totalEarnings = profile.totalEarnings,
        completedJobs = profile.completedJobs,
        failedJobs = profile.failedJobs,
        globalCompleted = profile.globalCompleted,
        globalFailed = profile.globalFailed,
        dailymissions = DailyMissions.Project(profile.dailymissions),
        history = profile.recentDeliveries or {},
    }
end

function SyncAllPlayerData(playerId, profile)
    if not profile then return end
    TriggerClientEvent('peak-trucking:SyncAllPlayerData', playerId, ProfileProjection(profile))
end

--- Carrega as últimas entregas do banco e envia como "history" para a NUI.
function SyncRecentDeliveries(playerId, profile)
    local rows = ExecuteSqlSafe(
        "SELECT session_id, mission_id, route_index, tier, grade, score, base_payment, bonus_payment, penalty_payment, final_payment, xp_awarded, reputation_awarded, status, result_reason, UNIX_TIMESTAMP(started_at) AS started_at, UNIX_TIMESTAMP(finished_at) AS finished_at FROM peak_trucking_deliveries WHERE identifier = ? AND status <> 'in_progress' ORDER BY id DESC LIMIT 15",
        { profile.identifier }
    ) or {}

    local history = {}
    for _, row in ipairs(rows) do
        local mission, route = ResolveCatalogRoute(row.mission_id, row.route_index)
        history[#history + 1] = {
            sessionId = row.session_id,
            label = mission and mission.header or ('Mission ' .. tostring(row.mission_id)),
            routeLabel = route and route.label or '',
            company = mission and (Config.Companies[mission.companyIndex] or '') or '',
            companyIndex = mission and mission.companyIndex or nil,
            tier = row.tier,
            grade = row.grade,
            score = tonumber(row.score),
            basePay = tonumber(row.base_payment) or 0,
            bonus = tonumber(row.bonus_payment) or 0,
            penalty = tonumber(row.penalty_payment) or 0,
            total = tonumber(row.final_payment) or 0,
            earn = tonumber(row.final_payment) or 0,
            xp = tonumber(row.xp_awarded) or 0,
            reputation = tonumber(row.reputation_awarded) or 0,
            status = row.status,
            reason = row.result_reason,
            date = tonumber(row.finished_at) or tonumber(row.started_at) or os.time(),
            completedAt = tonumber(row.finished_at),
        }
    end

    -- Histórico legado (coluna JSON) entra como fallback, sem nota.
    if #history == 0 and type(profile.history) == 'table' then
        for i = #profile.history, math.max(1, #profile.history - 14), -1 do
            local entry = profile.history[i]
            if type(entry) == 'table' then
                history[#history + 1] = {
                    label = entry.label,
                    routeLabel = entry.supply or '',
                    company = '',
                    tier = nil,
                    grade = nil,
                    basePay = entry.earn or 0,
                    bonus = 0,
                    penalty = 0,
                    total = entry.earn or 0,
                    earn = entry.earn or 0,
                    status = 'completed',
                    date = entry.date or os.time(),
                    completedAt = entry.date,
                    legacy = true,
                }
            end
        end
    end

    profile.recentDeliveries = history
    SyncPlayerDataByKey(playerId, 'history', history)
end

-- ============================================================
-- DISCORD AVATAR (assíncrono)
-- ============================================================

function DiscordRequest(method, endpoint, body, cb)
    local token = ServerConfig and ServerConfig.DiscordBotToken or ''
    if token == '' then
        if cb then cb({ data = nil, code = 0, headers = {} }) end
        return
    end

    PerformHttpRequest('https://discordapp.com/api/' .. endpoint, function(code, data, headers)
        if cb then cb({ data = data, code = code, headers = headers }) end
    end, method, #body > 0 and json.encode(body) or '', {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bot ' .. token,
    })
end

function GetDiscordAvatar(playerId)
    local discordId = nil
    for _, identifier in ipairs(GetPlayerIdentifiers(playerId)) do
        if string.match(identifier, 'discord:') then
            discordId = string.gsub(identifier, 'discord:', '')
            break
        end
    end
    if not discordId then return Config.DefaultImage end

    if discordAvatarCache[discordId] ~= nil then
        return discordAvatarCache[discordId] or Config.DefaultImage
    end

    DiscordRequest('GET', ('users/%s'):format(discordId), {}, function(response)
        local avatarUrl = nil
        if response and response.code == 200 and response.data then
            local userData = json.decode(response.data)
            if userData and userData.avatar then
                local ext = userData.avatar:sub(2, 2) == '_' and '.gif' or '.png'
                avatarUrl = 'https://media.discordapp.net/avatars/' .. discordId .. '/' .. userData.avatar .. ext
            end
        end
        avatarUrl = avatarUrl or Config.DefaultImage
        discordAvatarCache[discordId] = avatarUrl

        local pData = GetPlayerJobData(playerId)
        if pData and pData.avatar ~= avatarUrl then
            pData.avatar = avatarUrl
            SyncPlayerDataByKey(playerId, 'avatar', avatarUrl)
            ExecuteSqlAsync('UPDATE peak_trucking SET `avatar` = :avatar WHERE `identifier` = :identifier', {
                avatar = avatarUrl, identifier = pData.identifier,
            })
        end
    end)

    return Config.DefaultImage
end

-- ============================================================
-- CICLO DE VIDA DO JOGADOR
-- ============================================================

function CreatePlayerData(playerId)
    local identifier = GetIdentifier(playerId)
    if not identifier then return end

    local existing = GetPlayerJobData(playerId)
    if existing then return existing end

    local companyPoints = {}
    for i = 0, 7 do companyPoints[tostring(i)] = 0 end

    local newPlayerData = {
        identifier = identifier,
        points = companyPoints,
        history = {},
        avatar = GetDiscordAvatar(playerId),
        name = GetPlayerRPName(playerId),
        unlockedMissions = {},
        dailymissions = DailyMissions.NewSet(),
        totalEarnings = 0,
        completedJobs = 0,
        failedJobs = 0,
        globalCompleted = 0,
        globalFailed = 0,
        xp = 0,
        level = 1,
    }

    local inserted = ExecuteSqlUpdate(
        'INSERT IGNORE INTO peak_trucking (identifier, points, unlockedMissions, dailymissions, xp, level, totalEarnings, completedJobs, failedJobs, globalCompleted, globalFailed, name, avatar, history) VALUES (:identifier, :points, :unlockedMissions, :dailymissions, :xp, :level, :totalEarnings, :completedJobs, 0, 0, 0, :name, :avatar, :history)',
        {
            identifier = identifier,
            points = json.encode(newPlayerData.points),
            unlockedMissions = json.encode(newPlayerData.unlockedMissions),
            dailymissions = json.encode(newPlayerData.dailymissions),
            xp = 0, level = 1, totalEarnings = 0, completedJobs = 0,
            name = newPlayerData.name,
            avatar = newPlayerData.avatar or Config.DefaultImage,
            history = '[]',
        }
    )
    if inserted == nil then
        Peak.Utils.Warn('Não foi possível criar perfil de ' .. identifier .. ' (banco indisponível).')
        return nil
    end

    playerJobDataCache[identifier] = newPlayerData
    return newPlayerData
end

function LoadPlayerData(playerId)
    local profile = GetPlayerJobData(playerId)
    if not profile then
        profile = CreatePlayerData(playerId)
        if not profile then return end
    end

    local rpName = GetPlayerRPName(playerId)
    if rpName and rpName ~= '' and profile.name ~= rpName then
        profile.name = rpName
        ExecuteSqlAsync('UPDATE peak_trucking SET `name` = :name WHERE `identifier` = :id', { name = rpName, id = profile.identifier })
    end

    profile.avatar = GetDiscordAvatar(playerId)
    DailyMissions.CheckReset(playerId, profile)
    Contracts.ResolveSuspended(playerId, profile.identifier)
    SyncRecentDeliveries(playerId, profile)
    SyncAllPlayerData(playerId, profile)

    if Open and Open.OnPlayerLoaded then pcall(Open.OnPlayerLoaded, playerId) end
end

RegisterServerEvent('peak-trucking:LoadPlayerData')
AddEventHandler('peak-trucking:LoadPlayerData', function()
    local src = source
    while not Rotation.ready do Wait(100) end
    LoadPlayerData(src)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Contracts.OnDrop(src)
    if Open and Open.OnPlayerUnloaded then pcall(Open.OnPlayerUnloaded, src) end
end)

-- ============================================================
-- RPCs DA NUI
-- ============================================================

RegisterRpc('getDispatchBoard', function(src)
    local profile = GetPlayerJobData(src)
    if not profile then return { ok = false, error = 'no_profile' } end
    DailyMissions.CheckReset(src, profile)
    return { ok = true, snapshot = Rotation.BuildSnapshot(src, profile) }
end)

RegisterRpc('startContract', function(src, data)
    return Contracts.Start(src, data)
end)

RegisterRpc('finishContract', function(src, data)
    if type(data) ~= 'table' then return { ok = false, error = 'err_invalid' } end
    return Contracts.Finish(src, data.sessionId, data.vehicleHealth)
end)

-- Ranking com cache de 60s por métrica; posição própria calculada por pedido.
local leaderboardCache = {}

RegisterRpc('getLeaderboard', function(src, data)
    local metric = (type(data) == 'table' and data.metric == 'global') and 'global' or 'level'
    local now = os.time()
    local cached = leaderboardCache[metric]

    if not cached or (now - cached.at) >= 60 then
        local order = metric == 'global' and 'globalCompleted DESC, level DESC, xp DESC' or 'level DESC, xp DESC, globalCompleted DESC'
        local rows = ExecuteSqlSafe(
            'SELECT identifier, name, avatar, level, xp, globalCompleted FROM peak_trucking WHERE completedJobs > 0 OR globalCompleted > 0 ORDER BY ' .. order .. ' LIMIT 8'
        ) or {}
        local entries = {}
        for i, row in ipairs(rows) do
            entries[#entries + 1] = {
                rank = i,
                identifier = row.identifier,
                name = row.name or 'Driver',
                avatar = row.avatar or Config.DefaultImage,
                level = tonumber(row.level) or 1,
                xp = tonumber(row.xp) or 0,
                globalCompleted = tonumber(row.globalCompleted) or 0,
            }
        end
        cached = { at = now, entries = entries }
        leaderboardCache[metric] = cached
    end

    local profile = GetPlayerJobData(src)
    local me = nil
    if profile then
        local rows
        if metric == 'global' then
            rows = ExecuteSqlSafe(
                'SELECT COUNT(*) + 1 AS pos FROM peak_trucking WHERE globalCompleted > ? OR (globalCompleted = ? AND (level > ? OR (level = ? AND xp > ?)))',
                { profile.globalCompleted or 0, profile.globalCompleted or 0, profile.level or 1, profile.level or 1, profile.xp or 0 }
            )
        else
            rows = ExecuteSqlSafe(
                'SELECT COUNT(*) + 1 AS pos FROM peak_trucking WHERE level > ? OR (level = ? AND xp > ?)',
                { profile.level or 1, profile.level or 1, profile.xp or 0 }
            )
        end
        me = {
            position = rows and rows[1] and tonumber(rows[1].pos) or nil,
            name = profile.name,
            level = profile.level,
            xp = profile.xp,
            globalCompleted = profile.globalCompleted or 0,
            ranked = (profile.completedJobs or 0) > 0 or (profile.globalCompleted or 0) > 0,
        }
    end

    local data = {}
    for _, e in ipairs(cached.entries) do
        data[#data + 1] = {
            rank = e.rank,
            name = e.name,
            avatar = e.avatar,
            level = e.level,
            globalCompleted = e.globalCompleted,
            isMe = profile ~= nil and e.identifier == profile.identifier,
        }
    end

    return { ok = true, metric = metric, data = data, me = me }
end)

-- ============================================================
-- EVENTOS DE SESSÃO (client → server)
-- ============================================================

RegisterServerEvent('peak-trucking:session:vehicle')
AddEventHandler('peak-trucking:session:vehicle', function(sessionId, netId)
    local src = source
    if not Contracts.RegisterVehicle(src, sessionId, netId) then
        Peak.Utils.Debug('RegisterVehicle rejeitado para', src)
    end
end)

RegisterServerEvent('peak-trucking:session:pickup')
AddEventHandler('peak-trucking:session:pickup', function(sessionId)
    Contracts.ConfirmPickup(source, sessionId)
end)

RegisterServerEvent('peak-trucking:session:destination')
AddEventHandler('peak-trucking:session:destination', function(sessionId)
    Contracts.ConfirmDestination(source, sessionId)
end)

RegisterServerEvent('peak-trucking:session:cancel')
AddEventHandler('peak-trucking:session:cancel', function(sessionId, reason)
    local src = source
    Contracts.Cancel(src, sessionId, reason)
end)

RegisterServerEvent('peak-trucking:AcceptIllegalDeal')
AddEventHandler('peak-trucking:AcceptIllegalDeal', function()
    Contracts.AcceptIllegal(source)
end)

RegisterServerEvent('peak-trucking:GiveIllegalItem')
AddEventHandler('peak-trucking:GiveIllegalItem', function()
    local src = source
    local ok = Contracts.IllegalBox(src)
    if not ok then
        Peak.Utils.Debug('Caixa ilegal rejeitada para', src)
    end
end)

-- Missões diárias: apenas reset (o progresso é server-side)
RegisterServerEvent('peak-trucking:CheckDailyMission')
AddEventHandler('peak-trucking:CheckDailyMission', function()
    local src = source
    local profile = GetPlayerJobData(src)
    if profile then DailyMissions.CheckReset(src, profile) end
end)

-- ============================================================
-- ADMIN: regeneração excepcional (auditada, nunca comando comum)
-- ============================================================

RegisterCommand('trucking_rotation', function(src, args)
    if src ~= 0 then
        local allowed = IsPlayerAceAllowed(src, Config.AdminAce or 'admin')
        if not allowed then return end
    end
    local current = Rotation.Ensure()
    if not current then
        print('[peak-trucking] Rotação indisponível (banco?).')
        return
    end
    local counts = { available = 0, in_progress = 0, completed = 0, failed = 0, failed_system = 0, expired = 0 }
    for _, off in pairs(current.offers) do
        counts[off.status] = (counts[off.status] or 0) + 1
    end
    print(('[peak-trucking] Rotação %s expira em %ds | ofertas: %d | disponíveis %d, em andamento %d, concluídas %d, fracassadas %d | sessões ativas %d'):format(
        current.id, current.expiresAt - os.time(), #current.order, counts.available, counts.in_progress, counts.completed,
        counts.failed + counts.failed_system, Contracts.ActiveCount()))
    Peak.Utils.print(('AUDIT rotation inspect by %s'):format(src == 0 and 'console' or (GetPlayerName(src) .. ' (' .. src .. ')')))
end, true)

-- ============================================================
-- INICIALIZAÇÃO / ENCERRAMENTO
-- ============================================================

CreateThread(function()
    while not Peak.Server.Ready do Wait(50) end
    Core = GetCore()
    Config.Framework = select(2, GetCore())

    RunMigrations()
    Contracts.ReconcileAfterStart()
    Rotation.BuildPools()
    Rotation.ready = true
    Rotation.Ensure()

    Peak.Utils.print('Noir Truck V1 — Mercado Global ativo (rotação de ' .. tostring(Config.ContractBoard.rotationMinutes) .. ' min).')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Contracts.OnResourceStop()
end)
