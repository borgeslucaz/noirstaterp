-- Central do táxi (NUI): abertura validada, sessão curta por jogador, bootstrap de perfil/catálogo e ranking.
Central = {}

local RL = ServerConfig.RateLimits
local CC = ServerConfig.Central
local D = Config.Depot

-- Catálogo ordenado por requiredLevel e, dentro do mesmo nível, pela ordem configurada.
local catalog = {}
do
    for i, v in ipairs(Config.RentalVehicles) do
        catalog[#catalog + 1] = { index = i, entry = v }
    end
    table.sort(catalog, function(a, b)
        if a.entry.requiredLevel ~= b.entry.requiredLevel then
            return a.entry.requiredLevel < b.entry.requiredLevel
        end
        return a.index < b.index
    end)
end

---@param src number
---@return table|nil character { citizenId, name.full, job.name, money }
function Central.identity(src)
    local character = exports.bgrz_core:GetCharacter(src)
    if not character or not character.citizenId then return nil end
    return character
end

---Denylist explícita e opcional por emprego (desligada por padrão). O emprego nunca é alterado.
---@param character table
---@return boolean
function Central.isRestricted(character)
    if not CC.DenylistEnabled then return false end
    local jobName = character.job and character.job.name
    return jobName ~= nil and CC.Denylist[jobName] == true
end

---@param src number
---@return boolean
function Central.isNearDepot(src)
    if not Security.isNearCoords(src, D.coords, D.interactDistance + 5.0) then return false end
    if GetPlayerRoutingBucket(src) ~= D.routingBucket then return false end
    return true
end

---@param level number
---@return table[] vehicles projeção para a NUI (o status é só apresentação; o aluguel recalcula tudo)
function Central.catalogView(level)
    local list = {}
    for _, item in ipairs(catalog) do
        local v = item.entry
        local status = 'available'
        if v.enabled == false then
            status = 'unavailable'
        elseif level < v.requiredLevel then
            status = 'locked'
        end
        list[#list + 1] = {
            id = v.id,
            label = v.label,
            description = v.description,
            requiredLevel = v.requiredLevel,
            rentalFee = math.max(0, math.floor(tonumber(v.rentalFee) or 0)),
            image = v.image,
            status = status,
        }
    end
    return list
end

---Monta o payload de bootstrap (perfil + catálogo) a partir da persistência.
---@param src number
---@param character table
---@return table|nil data
function Central.bootstrap(src, character)
    local displayName = Security.sanitizeName(character.name and character.name.full)
    local row = Progression.getProfile(character.citizenId, displayName)
    if not row then return nil end
    local profile = Progression.view(row, Progression.earnedToday(character.citizenId))

    local rental = ActiveRentals[src]
    local activeRental = nil
    if rental and rental.state == 'active' then
        local veh = NetworkGetEntityFromNetworkId(rental.netId)
        if veh ~= 0 and DoesEntityExist(veh) then activeRental = rental.vehicleId end
    end

    local vehicles = Central.catalogView(profile.level)
    if activeRental then
        for _, v in ipairs(vehicles) do
            if v.id == activeRental then v.status = 'in_use' end
        end
    end

    return {
        serverTime = os.time(),
        header = D.header,
        profile = profile,
        vehicles = vehicles,
        activeRental = activeRental,
        maxLevel = Progression.maxLevel(),
    }
end

---@param src number
---@param token any
---@return CentralSession|nil session
---@return string|nil code
function Central.validateSession(src, token)
    local session = CentralSessions[src]
    if not session then return nil, 'invalid_session' end
    local t = Security.sanitizeString(token, 64)
    if not t or t ~= session.token or session.source ~= src then return nil, 'invalid_session' end
    if Sessions.now() > session.expiresAt then
        CentralSessions[src] = nil
        return nil, 'session_expired'
    end
    return session
end

function Central.invalidate(src)
    CentralSessions[src] = nil
end

-- ───────────────────────── callbacks ─────────────────────────

lib.callback.register('noir_taxijob:server:openCentral', function(src)
    if not Security.rateLimit(src, 'openCentral', RL.openCentral) then return { ok = false, code = 'rate_limited' } end
    local character = Central.identity(src)
    if not character then return { ok = false, code = 'not_loaded' } end
    if not Security.isOnFoot(src) then return { ok = false, code = 'activity_restricted' } end
    if not Central.isNearDepot(src) then
        Security.report(src, 'openCentral', 'not_near_depot')
        return { ok = false, code = 'not_near' }
    end
    if Central.isRestricted(character) then return { ok = false, code = 'activity_restricted' } end
    if not Progression.ready then return { ok = false, code = 'internal_error' } end

    local data = Central.bootstrap(src, character)
    if not data then return { ok = false, code = 'internal_error' } end

    -- Revalida a presença após o acesso ao banco.
    if not Central.identity(src) or not Central.isNearDepot(src) then return { ok = false, code = 'not_near' } end

    local session = {
        source = src,
        token = Security.token(),
        citizenid = character.citizenId,
        expiresAt = Sessions.now() + CC.SessionTtlMs,
    }
    CentralSessions[src] = session
    Sessions.debug('central_open src=%s activity=allowed level=%s', src, data.profile.level)

    data.ok = true
    data.sessionId = session.token
    data.ttl = CC.SessionTtlMs
    return data
end)

lib.callback.register('noir_taxijob:server:retryBootstrap', function(src, token)
    if not Security.rateLimit(src, 'retryBootstrap', RL.retryBootstrap) then return { ok = false, code = 'rate_limited' } end
    local session, code = Central.validateSession(src, token)
    if not session then return { ok = false, code = code } end
    local character = Central.identity(src)
    if not character or character.citizenId ~= session.citizenid then return { ok = false, code = 'not_loaded' } end
    if not Central.isNearDepot(src) then return { ok = false, code = 'not_near' } end

    local data = Central.bootstrap(src, character)
    if not data then return { ok = false, code = 'internal_error' } end
    data.ok = true
    data.sessionId = session.token
    return data
end)

lib.callback.register('noir_taxijob:server:getRanking', function(src, token)
    if not Security.rateLimit(src, 'ranking', RL.ranking) then return { ok = false, code = 'rate_limited' } end
    local session, code = Central.validateSession(src, token)
    if not session then return { ok = false, code = code } end
    local snapshot = Ranking.snapshot(session.citizenid)
    if not snapshot then return { ok = false, code = 'internal_error' } end
    return { ok = true, data = snapshot }
end)

RegisterNetEvent('noir_taxijob:server:closeCentral', function()
    Central.invalidate(source)
end)
