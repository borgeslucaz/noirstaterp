local Service = {}
NoirIllegal.Services.Activity = Service

local function callerAllowed(caller, activity)
    if not caller or not NoirIllegal.Permissions.publicRecorders[caller] then return false end
    for i = 1, #(activity.callers or {}) do
        if activity.callers[i] == caller then return true end
    end
    return false
end

local function prepareRequest(source, activityKey, transactionId, options, caller)
    local activity = NoirIllegal.Activities[activityKey]
    if not activity then return nil, NoirIllegal.error('INVALID_ACTIVITY') end
    if not activity.enabled then return nil, NoirIllegal.error('ACTIVITY_DISABLED') end
    if not callerAllowed(caller, activity) then return nil, NoirIllegal.error('FORBIDDEN_CALLER') end
    if not NoirIllegal.Validators.uuid(transactionId) then
        return nil, NoirIllegal.error('INVALID_ARGUMENT', { field = 'transactionId' })
    end

    local identity = NoirIllegal.Bridges.Qbox.getIdentity(source)
    if not identity then return nil, NoirIllegal.error('INVALID_SOURCE') end
    options = options or {}
    if type(options) ~= 'table' then
        return nil, NoirIllegal.error('INVALID_ARGUMENT', { field = 'options' })
    end
    local occurredAt = NoirIllegal.Validators.occurredAt(options.occurredAt)
    if not occurredAt then
        return nil, NoirIllegal.error('INVALID_ARGUMENT', { field = 'occurredAt' })
    end
    local metadata = NoirIllegal.Validators.metadata(
        options.metadata, activity.metadata and activity.metadata.allow)
    if not metadata then
        return nil, NoirIllegal.error('INVALID_ARGUMENT', { field = 'metadata' })
    end
    local organization = NoirIllegal.Bridges.Gangs.getOrganization(source)
    if options.organizationId ~= nil
        and (not organization or options.organizationId ~= organization.id) then
        return nil, NoirIllegal.error('ORGANIZATION_MISMATCH')
    end

    return {
        source = identity.source,
        citizenId = identity.citizenId,
        organization = organization,
        activity = activity,
        activityKey = activityKey,
        transactionId = transactionId:lower(),
        callerResource = caller,
        occurredAt = occurredAt,
        metadata = metadata,
    }
end

local function ledgerData(request, status, payload)
    return {
        transactionId = request.transactionId,
        activityKey = request.activityKey,
        callerResource = request.callerResource,
        citizenId = request.citizenId,
        organizationId = request.organization and request.organization.id or nil,
        status = status,
        rejectionCode = status == 'rejected' and payload.code or nil,
        basePersonal = request.activity.personal,
        appliedPersonal = payload.applied and payload.applied.personal or {},
        baseOrganization = request.activity.organization,
        appliedOrganization = payload.applied and payload.applied.organization or {},
        baseHeat = request.activity.heat or 0,
        appliedHeat = payload.applied and payload.applied.heat or 0,
        multiplier = payload.multiplier or 1,
        metadata = request.metadata,
        resultPayload = payload,
        occurredAt = request.occurredAt,
    }
end

local function rejection(request, query, code, details)
    local payload = NoirIllegal.error(code, details)
    payload.transactionId = request.transactionId
    payload.replayed = false
    if details and details.retryAt then payload.retryAt = details.retryAt end
    if NoirIllegal.Config.AuditRejectedActivities then
        NoirIllegal.Repositories.Activity.insert(
            ledgerData(request, 'rejected', payload), query)
    end
    return payload
end

local function changedCategories(beforeValues, afterValues)
    local keys = {}
    for category, value in pairs(afterValues) do
        if value ~= (beforeValues[category] or 0) then keys[#keys + 1] = category end
    end
    table.sort(keys)
    return keys
end

local function emitCommitted(request, state)
    local common = {
        transactionId = request.transactionId,
        citizenId = request.citizenId,
        source = request.source,
        callerResource = request.callerResource,
        occurredAt = request.occurredAt,
        metadata = NoirIllegal.Validators.copy(request.metadata),
    }
    local activityPayload = NoirIllegal.Validators.copy(common)
    activityPayload.activityKey = request.activityKey
    activityPayload.applied = NoirIllegal.Validators.copy(state.applied)
    activityPayload.multiplier = state.multiplier
    activityPayload.replayed = false
    TriggerEvent('noir_illegal_core:server:activityRecorded', activityPayload)

    for _, category in ipairs(changedCategories(state.beforePersonal, state.afterPersonal)) do
        local payload = NoirIllegal.Validators.copy(common)
        payload.scope, payload.subjectId, payload.category = 'player', request.citizenId, category
        payload.before, payload.after = state.beforePersonal[category] or 0, state.afterPersonal[category]
        payload.delta, payload.reason = payload.after - payload.before, request.activityKey
        TriggerEvent('noir_illegal_core:server:reputationChanged', payload)
        if state.beforeLevels[category] ~= state.afterLevels[category] then
            local levelPayload = NoirIllegal.Validators.copy(payload)
            levelPayload.before, levelPayload.after = state.beforeLevels[category], state.afterLevels[category]
            levelPayload.delta = levelPayload.after - levelPayload.before
            TriggerEvent('noir_illegal_core:server:levelChanged', levelPayload)
        end
    end

    if request.organization then
        for _, category in ipairs(changedCategories(state.beforeOrganization, state.afterOrganization)) do
            local payload = NoirIllegal.Validators.copy(common)
            payload.scope, payload.subjectId, payload.category =
                'organization', request.organization.id, category
            payload.before = state.beforeOrganization[category] or 0
            payload.after = state.afterOrganization[category]
            payload.delta, payload.reason = payload.after - payload.before, request.activityKey
            TriggerEvent('noir_illegal_core:server:reputationChanged', payload)
            if state.beforeOrganizationLevels[category] ~= state.afterOrganizationLevels[category] then
                local levelPayload = NoirIllegal.Validators.copy(payload)
                levelPayload.before = state.beforeOrganizationLevels[category]
                levelPayload.after = state.afterOrganizationLevels[category]
                levelPayload.delta = levelPayload.after - levelPayload.before
                TriggerEvent('noir_illegal_core:server:levelChanged', levelPayload)
            end
        end
    end

    if state.beforeHeat ~= state.afterHeat then
        local payload = NoirIllegal.Validators.copy(common)
        payload.scope, payload.subjectId = 'player', request.citizenId
        payload.before, payload.after = state.beforeHeat, state.afterHeat
        payload.delta, payload.reason = state.afterHeat - state.beforeHeat, request.activityKey
        TriggerEvent('noir_illegal_core:server:heatChanged', payload)
    end

    for i = 1, #state.unlocksGranted do
        local unlock = state.unlocksGranted[i]
        local payload = NoirIllegal.Validators.copy(common)
        payload.scope, payload.subjectId = unlock.scope, unlock.subjectId
        payload.unlockKey, payload.reason = unlock.key, 'requirements_met'
        TriggerEvent('noir_illegal_core:server:unlockGranted', payload)
    end
end

function Service.record(source, activityKey, transactionId, options, caller)
    local startedAt = GetGameTimer()
    local request, requestError = prepareRequest(
        source, activityKey, transactionId, options, caller)
    if not request then return false, requestError end

    local existing = NoirIllegal.Repositories.Activity.findByTransaction(request.transactionId)
    if existing then
        return NoirIllegal.Services.Idempotency.resolve(existing, request)
    end

    local outcomeOk, outcome, committedState
    local callOk, transactionResult = pcall(function()
        return MySQL.startTransaction(function(query)
            local replay = NoirIllegal.Repositories.Activity.findByTransaction(
                request.transactionId, query, true)
            if replay then
                outcomeOk, outcome = NoirIllegal.Services.Idempotency.resolve(replay, request)
                return true
            end

            NoirIllegal.Repositories.Profile.ensure(query, request.citizenId)
            NoirIllegal.Repositories.Profile.lock(query, request.citizenId)
            NoirIllegal.Repositories.Heat.ensure(request.citizenId, query)
            local heatRow = NoirIllegal.Repositories.Heat.get(
                request.citizenId, query, true)
            local now = os.time()
            local beforeHeat = tonumber(heatRow and heatRow.value) or 0
            local decayedHeat = NoirIllegal.Services.Heat.calculate(
                beforeHeat, heatRow and heatRow.last_decay_epoch, now)
            if math.abs(beforeHeat - decayedHeat) >= NoirIllegal.Config.Heat.persistEpsilon then
                NoirIllegal.Repositories.Heat.set(request.citizenId, decayedHeat, now, query)
            end

            for category in pairs(request.activity.personal or {}) do
                NoirIllegal.Repositories.Reputation.ensureCategory(
                    'player', request.citizenId, category, query)
            end
            if request.organization then
                for category in pairs(request.activity.organization or {}) do
                    NoirIllegal.Repositories.Reputation.ensureCategory(
                        'organization', request.organization.id, category, query)
                end
            end

            local beforePersonal = NoirIllegal.Repositories.Reputation.list(
                'player', request.citizenId, query, true)
            local beforeOrganization = request.organization
                and NoirIllegal.Repositories.Reputation.list(
                    'organization', request.organization.id, query, true)
                or {}
            local unlockRows = NoirIllegal.Repositories.Unlock.list(
                'player', request.citizenId, query, true)
            local unlockMap = NoirIllegal.Services.Unlock.toMap(unlockRows)
            local eligibilityProfile = {
                citizenId = request.citizenId,
                activityKey = request.activityKey,
                reputations = beforePersonal,
                levels = NoirIllegal.Services.Level.all(beforePersonal),
                heat = decayedHeat,
                organization = request.organization,
                unlocks = unlockMap,
            }

            local eligible, detail = NoirIllegal.Services.Eligibility.evaluate(
                request.activity, eligibilityProfile, false, query)
            if not eligible then
                outcomeOk = false
                outcome = rejection(request, query, 'NOT_ELIGIBLE', detail)
                return true
            end
            local cooldownAvailable, retryAt = NoirIllegal.Services.Cooldown.check(
                request.citizenId, request.activityKey, query, true)
            if not cooldownAvailable then
                outcomeOk = false
                outcome = rejection(request, query, 'COOLDOWN_ACTIVE', { retryAt = retryAt })
                return true
            end

            local rule = request.activity.diminishingReturns
            local count = rule and NoirIllegal.Repositories.Activity.countAccepted(
                request.citizenId,
                request.organization and request.organization.id or nil,
                request.activityKey,
                rule.windowSeconds,
                rule.key,
                query
            ) or 0
            local multiplier = NoirIllegal.Services.Level.diminishingMultiplier(count, rule)
            local afterPersonal = NoirIllegal.Validators.copy(beforePersonal)
            local afterOrganization = NoirIllegal.Validators.copy(beforeOrganization)
            local appliedPersonal, appliedOrganization = {}, {}

            for category, baseDelta in pairs(request.activity.personal or {}) do
                local delta = NoirIllegal.Validators.round(baseDelta * multiplier, 4)
                appliedPersonal[category] = delta
                afterPersonal[category] = NoirIllegal.Validators.round(
                    (beforePersonal[category] or 0) + delta, 4)
                NoirIllegal.Repositories.Reputation.set(
                    'player', request.citizenId, category, afterPersonal[category], query)
            end
            if request.organization then
                for category, baseDelta in pairs(request.activity.organization or {}) do
                    local delta = NoirIllegal.Validators.round(baseDelta * multiplier, 4)
                    appliedOrganization[category] = delta
                    afterOrganization[category] = NoirIllegal.Validators.round(
                        (beforeOrganization[category] or 0) + delta, 4)
                    NoirIllegal.Repositories.Reputation.set(
                        'organization', request.organization.id, category,
                        afterOrganization[category], query)
                end
            end

            local requestedHeat = NoirIllegal.Validators.round(
                (request.activity.heat or 0) * multiplier, 4)
            local afterHeat = NoirIllegal.Validators.round(
                NoirIllegal.Validators.clamp(
                    decayedHeat + requestedHeat, 0, NoirIllegal.Config.Heat.max), 4)
            local appliedHeat = NoirIllegal.Validators.round(afterHeat - decayedHeat, 4)
            NoirIllegal.Repositories.Heat.set(request.citizenId, afterHeat, now, query)
            NoirIllegal.Services.Cooldown.apply(
                request.citizenId, request.activityKey,
                request.activity.cooldownSeconds, query)

            local beforeLevels = NoirIllegal.Services.Level.all(beforePersonal)
            local afterLevels = NoirIllegal.Services.Level.all(afterPersonal)
            local beforeOrganizationLevels = NoirIllegal.Services.Level.all(beforeOrganization)
            local afterOrganizationLevels = NoirIllegal.Services.Level.all(afterOrganization)
            local automaticProfile = {
                citizenId = request.citizenId,
                reputations = afterPersonal,
                levels = afterLevels,
                heat = afterHeat,
                organization = request.organization,
                unlocks = unlockMap,
            }
            local actor = { actorType = 'resource', actorId = request.callerResource }
            local unlocksGranted = NoirIllegal.Services.Unlock.evaluateAutomatic(
                automaticProfile, afterOrganization, query, actor)
            local unlockKeys = {}
            for i = 1, #unlocksGranted do unlockKeys[i] = unlocksGranted[i].key end

            outcome = {
                ok = true,
                transactionId = request.transactionId,
                replayed = false,
                activity = request.activityKey,
                profile = {
                    citizenId = request.citizenId,
                    organization = request.organization and {
                        id = request.organization.id,
                        label = request.organization.label,
                    } or nil,
                },
                applied = {
                    personal = appliedPersonal,
                    organization = appliedOrganization,
                    heat = appliedHeat,
                },
                levels = { before = beforeLevels, after = afterLevels },
                unlocksGranted = unlockKeys,
                multiplier = multiplier,
            }
            outcomeOk = true
            NoirIllegal.Repositories.Activity.insert(
                ledgerData(request, 'accepted', outcome), query)
            NoirIllegal.Repositories.Audit.insert({
                action = 'activity_recorded',
                actorType = 'resource',
                actorId = request.callerResource,
                targetType = 'player',
                targetId = request.citizenId,
                transactionId = request.transactionId,
                beforeState = {
                    reputation = beforePersonal,
                    organizationReputation = beforeOrganization,
                    heat = beforeHeat,
                },
                afterState = {
                    reputation = afterPersonal,
                    organizationReputation = afterOrganization,
                    heat = afterHeat,
                    unlocksGranted = unlockKeys,
                },
                metadata = { activityKey = request.activityKey, activity = request.metadata },
            }, query)
            committedState = {
                beforePersonal = beforePersonal,
                afterPersonal = afterPersonal,
                beforeOrganization = beforeOrganization,
                afterOrganization = afterOrganization,
                beforeLevels = beforeLevels,
                afterLevels = afterLevels,
                beforeOrganizationLevels = beforeOrganizationLevels,
                afterOrganizationLevels = afterOrganizationLevels,
                beforeHeat = beforeHeat,
                afterHeat = afterHeat,
                applied = outcome.applied,
                multiplier = multiplier,
                unlocksGranted = unlocksGranted,
            }
            return true
        end)
    end)

    if not callOk or transactionResult == false then
        NoirIllegal.Logger.error('record_activity_failed', {
            transactionId = request.transactionId,
            callerResource = request.callerResource,
            citizenId = request.citizenId,
            activityKey = request.activityKey,
            error = not callOk and tostring(transactionResult) or nil,
            durationMs = GetGameTimer() - startedAt,
        })
        return false, NoirIllegal.error('DATABASE_ERROR')
    end

    if outcomeOk and committedState and not outcome.replayed then
        NoirIllegal.Cache.invalidatePlayer(request.citizenId)
        NoirIllegal.Cache.invalidateOrganization(
            request.organization and request.organization.id or nil)
        emitCommitted(request, committedState)
        NoirIllegal.Logger.info('activity_recorded', {
            transactionId = request.transactionId,
            callerResource = request.callerResource,
            citizenId = request.citizenId,
            organizationId = request.organization and request.organization.id or nil,
            activityKey = request.activityKey,
            durationMs = GetGameTimer() - startedAt,
        })
    end
    return outcomeOk, outcome
end

function Service.validateConfiguration()
    NoirIllegal.Services.Level.validateConfiguration()
    for activityKey, activity in pairs(NoirIllegal.Activities) do
        assert(NoirIllegal.Validators.string(activityKey, 1, 96), 'Invalid activity key')
        assert(type(activity.enabled) == 'boolean', ('Activity %s missing enabled flag'):format(activityKey))
        for category, delta in pairs(activity.personal or {}) do
            assert(NoirIllegal.Validators.category(category), ('Unknown category %s'):format(category))
            assert(NoirIllegal.Validators.number(
                delta, 0, NoirIllegal.Config.Limits.maxActivityDelta), 'Invalid personal delta')
        end
        for category, delta in pairs(activity.organization or {}) do
            assert(NoirIllegal.Validators.category(category), ('Unknown category %s'):format(category))
            assert(NoirIllegal.Validators.number(
                delta, 0, NoirIllegal.Config.Limits.maxActivityDelta), 'Invalid organization delta')
        end
        assert(NoirIllegal.Validators.number(
            activity.cooldownSeconds or 0, 0), 'Invalid cooldown')
        assert(NoirIllegal.Validators.number(
            activity.heat or 0, 0, NoirIllegal.Config.Heat.max), 'Invalid heat delta')
        local rule = activity.diminishingReturns
        if rule then
            assert(rule.curve == 'linear', 'Only linear diminishing returns are supported')
            assert(rule.key == 'player:activity' or rule.key == 'organization:activity',
                'Unsupported diminishing returns key')
            assert(NoirIllegal.Validators.number(rule.windowSeconds, 1),
                'Invalid diminishing return window')
            assert(NoirIllegal.Validators.number(rule.softCap, 1) and rule.softCap % 1 == 0,
                'Invalid diminishing return soft cap')
            assert(NoirIllegal.Validators.number(rule.floorMultiplier, 0, 1),
                'Invalid diminishing return floor')
        end
        local seenMetadata = {}
        for i = 1, #((activity.metadata and activity.metadata.allow) or {}) do
            local key = activity.metadata.allow[i]
            assert(NoirIllegal.Validators.string(key, 1, 64) and not seenMetadata[key],
                'Invalid or duplicate metadata key')
            seenMetadata[key] = true
        end
        if activity.enabled then
            assert(#(activity.callers or {}) > 0, ('Activity %s has no callers'):format(activityKey))
            for i = 1, #activity.callers do
                assert(NoirIllegal.Permissions.publicRecorders[activity.callers[i]] == true,
                    ('Activity %s caller %s is not permitted'):format(activityKey, activity.callers[i]))
            end
        end
    end
end
