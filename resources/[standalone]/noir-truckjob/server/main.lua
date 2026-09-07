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

RegisterNetEvent('noir-truckjob:rpc')
AddEventHandler('noir-truckjob:rpc', function(requestId, name, data)
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
    TriggerClientEvent('noir-truckjob:rpcResult', src, requestId, result)
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
    -- O schema V2 é criado exclusivamente por install/install.sql.
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

    local result = ExecuteSql('SELECT * FROM noir_truckjob_players WHERE identifier = :id', { id = identifier })
    if result and result[1] then
        local record = result[1]
        record.dailymissions    = DecodeJson(record.dailymissions, nil)
        record.level            = tonumber(record.level) or 1
        record.xp               = tonumber(record.xp) or 0
        record.totalEarnings    = tonumber(record.totalEarnings) or 0
        record.completedJobs    = tonumber(record.completedJobs) or 0
        record.failedJobs       = tonumber(record.failedJobs) or 0
        record.globalCompleted  = tonumber(record.globalCompleted) or 0
        record.globalFailed     = tonumber(record.globalFailed) or 0
        if not record.dailymissions or type(record.dailymissions) ~= 'table' or not record.dailymissions.data then
            record.dailymissions = DailyMissions.NewSet()
        end
        playerJobDataCache[identifier] = record
        return record
    end

    return false
end

function SyncPlayerDataByKey(playerId, key, value)
    TriggerClientEvent('noir-truckjob:SyncPlayerDataByKey', playerId, key, value)
end

local function ProfileProjection(profile)
    return {
        identifier = nil, -- nunca exposto
        name = profile.name,
        avatar = profile.avatar or Config.DefaultImage,
        level = profile.level,
        xp = profile.xp,
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
    TriggerClientEvent('noir-truckjob:SyncAllPlayerData', playerId, ProfileProjection(profile))
end

--- Carrega as últimas entregas do banco e envia como "history" para a NUI.
function SyncRecentDeliveries(playerId, profile)
    local rows = ExecuteSqlSafe(
        "SELECT session_id, route_id, tier, grade, score, base_payment, bonus_payment, penalty_payment, final_payment, xp_awarded, status, result_reason, UNIX_TIMESTAMP(started_at) AS started_at, UNIX_TIMESTAMP(finished_at) AS finished_at FROM noir_truckjob_deliveries WHERE identifier = ? AND status <> 'in_progress' ORDER BY id DESC LIMIT 15",
        { profile.identifier }
    ) or {}

    local history = {}
    for _, row in ipairs(rows) do
        local routeMeta = GetRoute(row.route_id)
        local _, route = ResolveCatalogRoute(row.route_id)
        history[#history + 1] = {
            sessionId = row.session_id,
            routeId = row.route_id,
            label = routeMeta and routeMeta.title or row.route_id,
            routeLabel = route and route.label or '',
            cargoType = routeMeta and routeMeta.cargoType or '',
            tier = row.tier,
            grade = row.grade,
            score = tonumber(row.score),
            basePay = tonumber(row.base_payment) or 0,
            bonus = tonumber(row.bonus_payment) or 0,
            penalty = tonumber(row.penalty_payment) or 0,
            total = tonumber(row.final_payment) or 0,
            earn = tonumber(row.final_payment) or 0,
            xp = tonumber(row.xp_awarded) or 0,
            status = row.status,
            reason = row.result_reason,
            date = tonumber(row.finished_at) or tonumber(row.started_at) or os.time(),
            completedAt = tonumber(row.finished_at),
        }
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
            ExecuteSqlAsync('UPDATE noir_truckjob_players SET `avatar` = :avatar WHERE `identifier` = :identifier', {
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
        avatar = GetDiscordAvatar(playerId),
        name = GetPlayerRPName(playerId),
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
        'INSERT IGNORE INTO noir_truckjob_players (identifier, dailymissions, xp, level, totalEarnings, completedJobs, failedJobs, globalCompleted, globalFailed, name, avatar) VALUES (:identifier, :dailymissions, :xp, :level, :totalEarnings, :completedJobs, 0, 0, 0, :name, :avatar)',
        {
            identifier = identifier,
            dailymissions = json.encode(newPlayerData.dailymissions),
            xp = 0, level = 1, totalEarnings = 0, completedJobs = 0,
            name = newPlayerData.name,
            avatar = newPlayerData.avatar or Config.DefaultImage,
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
        ExecuteSqlAsync('UPDATE noir_truckjob_players SET `name` = :name WHERE `identifier` = :id', { name = rpName, id = profile.identifier })
    end

    profile.avatar = GetDiscordAvatar(playerId)
    DailyMissions.CheckReset(playerId, profile)
    Contracts.ResolveSuspended(playerId, profile.identifier)
    SyncRecentDeliveries(playerId, profile)
    SyncAllPlayerData(playerId, profile)

    if Open and Open.OnPlayerLoaded then pcall(Open.OnPlayerLoaded, playerId) end
end

RegisterServerEvent('noir-truckjob:LoadPlayerData')
AddEventHandler('noir-truckjob:LoadPlayerData', function()
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
        local order = metric == 'global' and 'globalCompleted DESC, level DESC, xp DESC, identifier ASC' or 'level DESC, xp DESC, globalCompleted DESC, identifier ASC'
        local rows = ExecuteSqlSafe(
            'SELECT identifier, name, avatar, level, xp, globalCompleted FROM noir_truckjob_players WHERE completedJobs > 0 OR globalCompleted > 0 ORDER BY ' .. order .. ' LIMIT 8'
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
                'SELECT COUNT(*) + 1 AS pos FROM noir_truckjob_players WHERE globalCompleted > ? OR (globalCompleted = ? AND (level > ? OR (level = ? AND xp > ?)))',
                { profile.globalCompleted or 0, profile.globalCompleted or 0, profile.level or 1, profile.level or 1, profile.xp or 0 }
            )
        else
            rows = ExecuteSqlSafe(
                'SELECT COUNT(*) + 1 AS pos FROM noir_truckjob_players WHERE level > ? OR (level = ? AND xp > ?)',
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
            xp = e.xp,
            globalCompleted = e.globalCompleted,
            isMe = profile ~= nil and e.identifier == profile.identifier,
        }
    end

    return { ok = true, metric = metric, data = data, me = me }
end)

-- ============================================================
-- EVENTOS DE SESSÃO (client → server)
-- ============================================================

RegisterServerEvent('noir-truckjob:session:vehicle')
AddEventHandler('noir-truckjob:session:vehicle', function(sessionId, netId)
    local src = source
    if not Contracts.RegisterVehicle(src, sessionId, netId) then
        Peak.Utils.Debug('RegisterVehicle rejeitado para', src)
    end
end)

RegisterServerEvent('noir-truckjob:session:pickup')
AddEventHandler('noir-truckjob:session:pickup', function(sessionId)
    Contracts.ConfirmPickup(source, sessionId)
end)

RegisterServerEvent('noir-truckjob:session:destination')
AddEventHandler('noir-truckjob:session:destination', function(sessionId)
    Contracts.ConfirmDestination(source, sessionId)
end)

RegisterServerEvent('noir-truckjob:session:cancel')
AddEventHandler('noir-truckjob:session:cancel', function(sessionId, reason)
    local src = source
    Contracts.Cancel(src, sessionId, reason)
end)

RegisterServerEvent('noir-truckjob:AcceptIllegalDeal')
AddEventHandler('noir-truckjob:AcceptIllegalDeal', function()
    Contracts.AcceptIllegal(source)
end)

RegisterServerEvent('noir-truckjob:GiveIllegalItem')
AddEventHandler('noir-truckjob:GiveIllegalItem', function()
    local src = source
    local ok = Contracts.IllegalBox(src)
    if not ok then
        Peak.Utils.Debug('Caixa ilegal rejeitada para', src)
    end
end)

-- Missões diárias: apenas reset (o progresso é server-side)
RegisterServerEvent('noir-truckjob:CheckDailyMission')
AddEventHandler('noir-truckjob:CheckDailyMission', function()
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

    if (args[1] or '') == 'refresh' then
        local refreshed, err = Rotation.Refresh()
        local who = src == 0 and 'console' or (GetPlayerName(src) .. ' (' .. src .. ')')
        if not refreshed then
            print('[noir-truckjob] Refresh da rotação falhou: ' .. tostring(err))
            Peak.Utils.print(('AUDIT rotation refresh DENIED by %s — %s'):format(who, tostring(err)))
            return
        end
        print(('[noir-truckjob] Rotação %s regenerada com %d novas ofertas.'):format(refreshed.id, #refreshed.order))
        Peak.Utils.print(('AUDIT rotation refresh by %s'):format(who))
        return
    end

    local current = Rotation.Ensure()
    if not current then
        print('[noir-truckjob] Rotação indisponível (banco?).')
        return
    end
    local counts = { available = 0, in_progress = 0, completed = 0, failed = 0, failed_system = 0, expired = 0 }
    for _, off in pairs(current.offers) do
        counts[off.status] = (counts[off.status] or 0) + 1
    end
    print(('[noir-truckjob] Rotação %s expira em %ds | ofertas: %d | disponíveis %d, em andamento %d, concluídas %d, fracassadas %d | sessões ativas %d'):format(
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

    Peak.Utils.print('Noir Truck V2 — Mercado Global ativo (rotação de ' .. tostring(Config.ContractBoard.rotationMinutes) .. ' min).')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Contracts.OnResourceStop()
end)
