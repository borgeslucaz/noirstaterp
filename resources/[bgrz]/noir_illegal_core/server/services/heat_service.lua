local Service = {}
NoirIllegal.Services.Heat = Service

function Service.calculate(value, lastDecayAt, now)
    value = tonumber(value) or 0
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
            after = Service.calculate(before, row and row.last_decay_epoch, now)
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
