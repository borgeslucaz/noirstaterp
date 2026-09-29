local Service = {}
NoirIllegal.Services.Admin = Service

local function txError(event, context)
    NoirIllegal.Logger.error(event, context)
    return false, NoirIllegal.error('DATABASE_ERROR')
end

function Service.setUnlock(subject, unlockKey, grant, reason, metadata, actor)
    if not NoirIllegal.Unlocks[unlockKey] then
        return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'unlockKey' })
    end
    if not NoirIllegal.Validators.string(reason, 1, 255) then
        return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'reason' })
    end
    metadata = NoirIllegal.Validators.auditMetadata(metadata)
    if not metadata then
        return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'metadata' })
    end
    local beforeState, changed
    local state = grant and 'granted' or 'revoked'
    local callOk, txResult = pcall(function()
        return MySQL.startTransaction(function(query)
            local current = NoirIllegal.Repositories.Unlock.find(
                subject.type, subject.id, unlockKey, query, true)
            beforeState = current and current.state or nil
            changed = beforeState ~= state
            if not changed then return true end
            NoirIllegal.Repositories.Unlock.upsert(
                subject.type, subject.id, unlockKey, state, 'manual',
                actor.actorId, reason, metadata, query)
            NoirIllegal.Repositories.Audit.insert({
                action = grant and 'unlock_granted' or 'unlock_revoked',
                actorType = actor.actorType,
                actorId = actor.actorId,
                targetType = subject.type,
                targetId = subject.id,
                beforeState = { state = beforeState },
                afterState = { state = state },
                metadata = { reason = reason, data = metadata },
            }, query)
            return true
        end)
    end)
    if not callOk or txResult == false then
        return txError('unlock_mutation_failed', {
            actorId = actor.actorId, targetId = subject.id, unlockKey = unlockKey,
        })
    end

    if changed then
        if subject.type == 'player' then
            NoirIllegal.Cache.invalidatePlayer(subject.id)
        else
            NoirIllegal.Cache.invalidateOrganization(subject.id)
        end
        if grant then
            TriggerEvent('noir_illegal_core:server:unlockGranted', {
                transactionId = NoirIllegal.Validators.randomUuid(),
                citizenId = subject.type == 'player' and subject.id or nil,
                source = subject.type == 'player'
                    and NoirIllegal.Bridges.Qbox.findSourceByCitizenId(subject.id) or nil,
                callerResource = actor.actorId,
                occurredAt = os.time(),
                metadata = metadata,
                scope = subject.type,
                subjectId = subject.id,
                unlockKey = unlockKey,
                reason = reason,
            })
        end
    end
    return true, {
        ok = true,
        changed = changed,
        subject = NoirIllegal.Validators.copy(subject),
        unlockKey = unlockKey,
        state = state,
    }
end

function Service.adjustReputation(subject, category, delta, reason, transactionId, actor)
    if not NoirIllegal.Validators.category(category)
        or not NoirIllegal.Validators.number(
            delta,
            -NoirIllegal.Config.Limits.maxAdminDelta,
            NoirIllegal.Config.Limits.maxAdminDelta)
        or not NoirIllegal.Validators.uuid(transactionId)
        or not NoirIllegal.Validators.string(reason, 1, 255) then
        return false, NoirIllegal.error('INVALID_ARGUMENT')
    end

    local activityKey = ('admin_rep:%s:%s'):format(subject.type, category)
    local identity = {
        activityKey = activityKey,
        callerResource = actor.actorId,
        citizenId = subject.id,
    }
    local existing = NoirIllegal.Repositories.Activity.findByTransaction(transactionId)
    if existing then return NoirIllegal.Services.Idempotency.resolve(existing, identity) end

    local before, after, oldLevel, newLevel, outcome
    local callOk, txResult = pcall(function()
        return MySQL.startTransaction(function(query)
            local replay = NoirIllegal.Repositories.Activity.findByTransaction(
                transactionId, query, true)
            if replay then
                local _, resolved = NoirIllegal.Services.Idempotency.resolve(replay, identity)
                outcome = resolved
                return true
            end
            if subject.type == 'player' then
                NoirIllegal.Repositories.Profile.ensure(query, subject.id)
                NoirIllegal.Repositories.Profile.lock(query, subject.id)
            end
            NoirIllegal.Repositories.Reputation.ensureCategory(
                subject.type, subject.id, category, query)
            local reputations = NoirIllegal.Repositories.Reputation.list(
                subject.type, subject.id, query, true)
            before = reputations[category] or 0
            after = NoirIllegal.Validators.round(math.max(0, before + delta), 4)
            oldLevel = NoirIllegal.Services.Level.get(category, before)
            newLevel = NoirIllegal.Services.Level.get(category, after)
            NoirIllegal.Repositories.Reputation.set(
                subject.type, subject.id, category, after, query)
            outcome = {
                ok = true,
                transactionId = transactionId,
                replayed = false,
                subject = NoirIllegal.Validators.copy(subject),
                category = category,
                before = before,
                after = after,
                appliedDelta = after - before,
            }
            NoirIllegal.Repositories.Activity.insert({
                transactionId = transactionId,
                activityKey = activityKey,
                callerResource = actor.actorId,
                citizenId = subject.id,
                organizationId = subject.type == 'organization' and subject.id or nil,
                status = 'accepted',
                basePersonal = subject.type == 'player' and { [category] = delta } or {},
                appliedPersonal = subject.type == 'player' and { [category] = after - before } or {},
                baseOrganization = subject.type == 'organization' and { [category] = delta } or {},
                appliedOrganization = subject.type == 'organization' and { [category] = after - before } or {},
                metadata = { reason = reason },
                resultPayload = outcome,
                occurredAt = os.time(),
            }, query)
            NoirIllegal.Repositories.Audit.insert({
                action = 'reputation_adjusted',
                actorType = actor.actorType,
                actorId = actor.actorId,
                targetType = subject.type,
                targetId = subject.id,
                transactionId = transactionId,
                beforeState = { category = category, value = before, level = oldLevel },
                afterState = { category = category, value = after, level = newLevel },
                metadata = { reason = reason, requestedDelta = delta },
            }, query)
            return true
        end)
    end)
    if not callOk or txResult == false then
        return txError('reputation_adjustment_failed', {
            transactionId = transactionId, actorId = actor.actorId, targetId = subject.id,
        })
    end
    if not outcome.replayed then
        if subject.type == 'player' then
            NoirIllegal.Cache.invalidatePlayer(subject.id)
        else
            NoirIllegal.Cache.invalidateOrganization(subject.id)
        end
        local common = {
            transactionId = transactionId,
            citizenId = subject.type == 'player' and subject.id or nil,
            source = subject.type == 'player'
                and NoirIllegal.Bridges.Qbox.findSourceByCitizenId(subject.id) or nil,
            callerResource = actor.actorId,
            occurredAt = os.time(),
            metadata = { reason = reason },
            scope = subject.type,
            subjectId = subject.id,
            category = category,
            before = before,
            after = after,
            delta = after - before,
            reason = reason,
        }
        TriggerEvent('noir_illegal_core:server:reputationChanged', common)
        if oldLevel ~= newLevel then
            local levelEvent = NoirIllegal.Validators.copy(common)
            levelEvent.before, levelEvent.after = oldLevel, newLevel
            levelEvent.delta = newLevel - oldLevel
            TriggerEvent('noir_illegal_core:server:levelChanged', levelEvent)
        end
    end
    return true, outcome
end

function Service.changeHeat(citizenId, value, mode, reason, transactionId, actor)
    if not NoirIllegal.Validators.string(citizenId, 1, 64)
        or not NoirIllegal.Validators.number(
            value,
            -NoirIllegal.Config.Limits.maxAdminDelta,
            NoirIllegal.Config.Limits.maxAdminDelta)
        or (mode ~= 'set' and mode ~= 'add')
        or not NoirIllegal.Validators.uuid(transactionId)
        or not NoirIllegal.Validators.string(reason, 1, 255) then
        return false, NoirIllegal.error('INVALID_ARGUMENT')
    end
    local activityKey = 'admin_heat:' .. mode
    local identity = {
        activityKey = activityKey,
        callerResource = actor.actorId,
        citizenId = citizenId,
    }
    local existing = NoirIllegal.Repositories.Activity.findByTransaction(transactionId)
    if existing then return NoirIllegal.Services.Idempotency.resolve(existing, identity) end

    local before, after, outcome
    local callOk, txResult = pcall(function()
        return MySQL.startTransaction(function(query)
            local replay = NoirIllegal.Repositories.Activity.findByTransaction(
                transactionId, query, true)
            if replay then
                local _, resolved = NoirIllegal.Services.Idempotency.resolve(replay, identity)
                outcome = resolved
                return true
            end
            NoirIllegal.Repositories.Profile.ensure(query, citizenId)
            NoirIllegal.Repositories.Profile.lock(query, citizenId)
            NoirIllegal.Repositories.Heat.ensure(citizenId, query)
            local row = NoirIllegal.Repositories.Heat.get(citizenId, query, true)
            local now = os.time()
            before = NoirIllegal.Services.Heat.calculate(
                row and row.value, row and row.last_decay_epoch, now)
            after = mode == 'set' and value or before + value
            after = NoirIllegal.Validators.round(
                NoirIllegal.Validators.clamp(after, 0, NoirIllegal.Config.Heat.max), 4)
            NoirIllegal.Repositories.Heat.set(citizenId, after, now, query)
            outcome = {
                ok = true,
                transactionId = transactionId,
                replayed = false,
                citizenId = citizenId,
                before = before,
                after = after,
                appliedDelta = after - before,
            }
            NoirIllegal.Repositories.Activity.insert({
                transactionId = transactionId,
                activityKey = activityKey,
                callerResource = actor.actorId,
                citizenId = citizenId,
                status = 'accepted',
                baseHeat = mode == 'add' and value or after - before,
                appliedHeat = after - before,
                metadata = { reason = reason, mode = mode },
                resultPayload = outcome,
                occurredAt = os.time(),
            }, query)
            NoirIllegal.Repositories.Audit.insert({
                action = 'heat_adjusted',
                actorType = actor.actorType,
                actorId = actor.actorId,
                targetType = 'player',
                targetId = citizenId,
                transactionId = transactionId,
                beforeState = { heat = before },
                afterState = { heat = after },
                metadata = { reason = reason, mode = mode, requestedValue = value },
            }, query)
            return true
        end)
    end)
    if not callOk or txResult == false then
        return txError('heat_adjustment_failed', {
            transactionId = transactionId, actorId = actor.actorId, citizenId = citizenId,
        })
    end
    if not outcome.replayed then
        NoirIllegal.Cache.invalidatePlayer(citizenId)
        TriggerEvent('noir_illegal_core:server:heatChanged', {
            transactionId = transactionId,
            citizenId = citizenId,
            source = NoirIllegal.Bridges.Qbox.findSourceByCitizenId(citizenId),
            callerResource = actor.actorId,
            occurredAt = os.time(),
            metadata = { reason = reason },
            scope = 'player',
            subjectId = citizenId,
            before = before,
            after = after,
            delta = after - before,
            reason = reason,
        })
    end
    return true, outcome
end
