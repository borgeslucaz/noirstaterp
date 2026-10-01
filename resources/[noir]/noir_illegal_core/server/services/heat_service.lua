local Service = {}
NoirIllegal.Services.Heat = Service

-- O heat decai por hora JOGADA: enquanto o personagem está offline, o relógio dele para. No
-- login o `last_decay_at` vai para agora (o tempo fora não conta); no logout o decaimento até
-- ali é gravado. Assim sumir do servidor não esfria ninguém.
local online = {} ---@type table<string, boolean> citizenId -> online
local citizenBySource = {} ---@type table<integer, string>

---@param citizenId string
---@return boolean
function Service.isOnline(citizenId)
    return online[citizenId] == true
end

---@param value number
---@param lastDecayAt integer?
---@param now integer
---@param isOnline boolean? false: personagem offline, nada decai
function Service.calculate(value, lastDecayAt, now, isOnline)
    value = tonumber(value) or 0
    if isOnline == false then return NoirIllegal.Validators.round(value, 4), 0 end
    lastDecayAt = tonumber(lastDecayAt) or now
    local elapsed = math.max(0, now - lastDecayAt)
    local nextValue = NoirIllegal.Validators.clamp(
        value - elapsed * NoirIllegal.Config.Heat.decayPerSecond,
        0,
        NoirIllegal.Config.Heat.max
    )
    return NoirIllegal.Validators.round(nextValue, 4), elapsed
end

function Service.read(citizenId, source)
    local before, after, transactionId
    local ok, success = pcall(function()
        return MySQL.startTransaction(function(query)
            NoirIllegal.Repositories.Heat.ensure(citizenId, query)
            local row = NoirIllegal.Repositories.Heat.get(citizenId, query, true)
            local now = os.time()
            before = tonumber(row and row.value) or 0
            after = Service.calculate(before, row and row.last_decay_epoch, now, Service.isOnline(citizenId))
            if math.abs(before - after) >= NoirIllegal.Config.Heat.persistEpsilon then
                NoirIllegal.Repositories.Heat.set(citizenId, after, now, query)
                transactionId = NoirIllegal.Validators.randomUuid()
            end
            return true
        end)
    end)
    if not ok or success == false then
        NoirIllegal.Logger.error('heat_read_failed', { citizenId = citizenId, error = tostring(success) })
        return nil, NoirIllegal.error('DATABASE_ERROR')
    end

    if transactionId then
        TriggerEvent('noir_illegal_core:server:heatChanged', {
            transactionId = transactionId,
            citizenId = citizenId,
            source = source,
            callerResource = 'noir_illegal_core',
            occurredAt = os.time(),
            metadata = {},
            scope = 'player',
            subjectId = citizenId,
            before = before,
            after = after,
            delta = NoirIllegal.Validators.round(after - before, 4),
            reason = 'decay',
        })
    end
    return after
end

---Login do personagem: o decaimento recomeça agora.
function Service.startSession(source, citizenId)
    citizenBySource[source] = citizenId
    -- Já online (o evento de login veio de novo): o tempo até aqui foi jogado e decai.
    if online[citizenId] then
        Service.read(citizenId, source)
        return
    end
    online[citizenId] = true
    local ok, err = pcall(function()
        NoirIllegal.Repositories.Heat.ensure(citizenId)
        NoirIllegal.Repositories.Heat.touch(citizenId, os.time())
    end)
    if not ok then NoirIllegal.Logger.error('heat_session_start_failed', { citizenId = citizenId, error = tostring(err) }) end
end

---Restart do core com o personagem já dentro: segue decaindo de onde parou, sem zerar o relógio.
function Service.resumeSession(source, citizenId)
    citizenBySource[source] = citizenId
    online[citizenId] = true
end

---Logout: grava o decaimento até agora e para o relógio.
function Service.endSession(source)
    local citizenId = citizenBySource[source]
    if not citizenId then return end
    citizenBySource[source] = nil
    Service.read(citizenId, source)
    online[citizenId] = nil
end
