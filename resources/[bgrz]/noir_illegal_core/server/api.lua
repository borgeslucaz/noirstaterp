local function ready()
    if NoirIllegal.Ready then return true end
    return false, NoirIllegal.error('INTERNAL_ERROR', { reason = 'resource_not_ready' })
end

local function privileged(operation)
    local caller = GetInvokingResource()
    local permission = caller and NoirIllegal.Permissions.privileged[caller]
    if permission and permission[operation] == true then
        return {
            actorType = 'resource',
            actorId = caller,
        }
    end
    return nil
end

local function safe(name, callback)
    local ok, first, second = pcall(callback)
    if ok then return first, second end
    NoirIllegal.Logger.error('api_exception', {
        api = name,
        callerResource = GetInvokingResource(),
        error = tostring(first),
    })
    return false, NoirIllegal.error('INTERNAL_ERROR')
end

exports('RecordActivity', function(source, activityKey, transactionId, options)
    return safe('RecordActivity', function()
        local isReady, readyError = ready()
        if not isReady then return false, readyError end
        return NoirIllegal.Services.Activity.record(
            source, activityKey, transactionId, options, GetInvokingResource())
    end)
end)

exports('RecordOrganizationActivity', function(organizationId, activityKey, transactionId, options)
    return safe('RecordOrganizationActivity', function()
        local isReady, readyError = ready()
        if not isReady then return false, readyError end
        return NoirIllegal.Services.Activity.recordOrganization(
            organizationId, activityKey, transactionId, options, GetInvokingResource())
    end)
end)

exports('GetProfile', function(source)
    return safe('GetProfile', function()
        local isReady, readyError = ready()
        if not isReady then return false, readyError end
        local profile, profileError = NoirIllegal.Services.Profile.getBySource(source)
        if not profile then return false, profileError end
        return true, profile
    end)
end)

exports('GetReputation', function(source, category)
    return safe('GetReputation', function()
        if not NoirIllegal.Validators.category(category) then
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'category' })
        end
        local profile, profileError = NoirIllegal.Services.Profile.getBySource(source)
        if not profile then return false, profileError end
        return true, profile.reputations[category] or 0
    end)
end)

exports('GetLevel', function(source, category)
    return safe('GetLevel', function()
        if not NoirIllegal.Validators.category(category) then
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'category' })
        end
        local profile, profileError = NoirIllegal.Services.Profile.getBySource(source)
        if not profile then return false, profileError end
        return true, profile.levels[category] or 0
    end)
end)

exports('GetHeat', function(source)
    return safe('GetHeat', function()
        local identity = NoirIllegal.Bridges.Qbox.getIdentity(source)
        if not identity then return false, NoirIllegal.error('INVALID_SOURCE') end
        local heat, heatError = NoirIllegal.Services.Heat.read(identity.citizenId, source)
        if heat == nil then return false, heatError end
        return true, heat
    end)
end)

---Responde pelo escopo do unlock: `contact_coke` é da gang, então a pergunta é se a gang de
---quem está ali tem, não se aquela pessoa tem. Jogador sem gang nunca tem unlock de gang.
exports('HasUnlock', function(source, unlockKey)
    return safe('HasUnlock', function()
        local definition = NoirIllegal.Unlocks[unlockKey]
        if not definition then
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'unlockKey' })
        end
        local profile, profileError = NoirIllegal.Services.Profile.getBySource(source)
        if not profile then return false, profileError end
        if definition.scope == 'organization' then
            local organization = profile.organization
            return true, organization ~= nil and organization.unlocks[unlockKey] == true
        end
        return true, profile.unlocks[unlockKey] == true
    end)
end)

exports('IsEligible', function(source, activityKey, options)
    return safe('IsEligible', function()
        local activity = NoirIllegal.Activities[activityKey]
        if not activity then return false, NoirIllegal.error('INVALID_ACTIVITY') end
        if not activity.enabled then return false, NoirIllegal.error('ACTIVITY_DISABLED') end
        local profile, profileError = NoirIllegal.Services.Profile.getBySource(source)
        if not profile then return false, profileError end
        options = options or {}
        if options.organizationId
            and (not profile.organization or options.organizationId ~= profile.organization.id) then
            return false, NoirIllegal.error('ORGANIZATION_MISMATCH')
        end
        profile.activityKey = activityKey
        local eligible, detail = NoirIllegal.Services.Eligibility.evaluate(
            activity, profile, true)
        if not eligible then
            if detail and detail.cooldown then
                local err = NoirIllegal.error('COOLDOWN_ACTIVE', detail)
                err.retryAt = detail.retryAt
                return false, err
            end
            return false, NoirIllegal.error('NOT_ELIGIBLE', detail)
        end
        return true, { ok = true, eligible = true }
    end)
end)

exports('GetOrganization', function(source)
    return safe('GetOrganization', function()
        if not NoirIllegal.Bridges.Qbox.getIdentity(source) then
            return false, NoirIllegal.error('INVALID_SOURCE')
        end
        return true, NoirIllegal.Bridges.Gangs.getOrganization(source)
    end)
end)

exports('GetOrganizationReputation', function(source, category)
    return safe('GetOrganizationReputation', function()
        if not NoirIllegal.Validators.category(category) then
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'category' })
        end
        if not NoirIllegal.Bridges.Qbox.getIdentity(source) then
            return false, NoirIllegal.error('INVALID_SOURCE')
        end
        local organization = NoirIllegal.Bridges.Gangs.getOrganization(source)
        if not organization then return false, NoirIllegal.error('NOT_FOUND') end
        local reputations = NoirIllegal.Services.Profile.organizationReputations(organization.id)
        return true, reputations[category] or 0
    end)
end)

---Progresso da gang em todas as categorias, pelo id da organização (o nome da gang). É o que
---o painel do noir_gangs mostra: ele não guarda reputação própria, lê daqui.
---@return boolean ok
---@return table|table progress [{ category, label, product, reputation, level, levelFloor, nextLevelAt }]
exports('GetOrganizationProgress', function(organizationId)
    return safe('GetOrganizationProgress', function()
        if not NoirIllegal.Validators.string(organizationId, 1, 64) then
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'organizationId' })
        end
        local reputations = NoirIllegal.Services.Profile.organizationReputations(organizationId)
        local progress = {}
        for category, definition in pairs(NoirIllegal.Config.Categories) do
            local reputation = reputations[category] or 0
            local level = NoirIllegal.Services.Level.get(category, reputation)
            local floor, nextAt = 0, nil
            for _, row in ipairs(NoirIllegal.Levels[category]) do
                if row.level == level then floor = row.minReputation end
                if row.level == level + 1 then nextAt = row.minReputation end
            end
            progress[#progress + 1] = {
                category = category, label = definition.label or category, product = definition.product,
                reputation = reputation, level = level, levelFloor = floor, nextLevelAt = nextAt,
            }
        end
        table.sort(progress, function(a, b) return a.category < b.category end)
        return true, progress
    end)
end)

---Nível da gang de quem está ali, numa categoria. Jogador sem gang responde nível 0.
exports('GetOrganizationLevel', function(source, category)
    return safe('GetOrganizationLevel', function()
        if not NoirIllegal.Validators.category(category) then
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'category' })
        end
        if not NoirIllegal.Bridges.Qbox.getIdentity(source) then
            return false, NoirIllegal.error('INVALID_SOURCE')
        end
        local organization = NoirIllegal.Bridges.Gangs.getOrganization(source)
        if not organization then return true, 0 end
        local reputations = NoirIllegal.Services.Profile.organizationReputations(organization.id)
        return true, NoirIllegal.Services.Level.get(category, reputations[category] or 0)
    end)
end)

---O que um editor de outro resource precisa para oferecer escolhas válidas: categorias, o
---nível mais alto de cada uma, os unlocks de gang e o teto do prêmio da coleta.
exports('GetCatalog', function()
    return safe('GetCatalog', function()
        local categories, unlocks = {}, {}
        for category, definition in pairs(NoirIllegal.Config.Categories) do
            local thresholds = NoirIllegal.Levels[category]
            categories[#categories + 1] = { id = category, label = definition.label or category,
                product = definition.product, maxLevel = thresholds[#thresholds].level }
        end
        table.sort(categories, function(a, b) return a.label < b.label end)
        for key, definition in pairs(NoirIllegal.Unlocks) do
            if definition.scope == 'organization' then unlocks[#unlocks + 1] = key end
        end
        table.sort(unlocks)
        local gathering = NoirIllegal.Activities.gathering_delivery
        return true, { categories = categories, unlocks = unlocks,
            gatheringRewardCap = gathering and gathering.enabled and gathering.variable.organization or 0 }
    end)
end)

exports('GrantUnlock', function(subject, unlockKey, reason, metadata)
    return safe('GrantUnlock', function()
        local actor = privileged('grantUnlock')
        if not actor then return false, NoirIllegal.error('FORBIDDEN_CALLER') end
        subject = NoirIllegal.Validators.subject(subject)
        if not subject then return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'subject' }) end
        return NoirIllegal.Services.Admin.setUnlock(
            subject, unlockKey, true, reason, metadata, actor)
    end)
end)

exports('RevokeUnlock', function(subject, unlockKey, reason, metadata)
    return safe('RevokeUnlock', function()
        local actor = privileged('revokeUnlock')
        if not actor then return false, NoirIllegal.error('FORBIDDEN_CALLER') end
        subject = NoirIllegal.Validators.subject(subject)
        if not subject then return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'subject' }) end
        return NoirIllegal.Services.Admin.setUnlock(
            subject, unlockKey, false, reason, metadata, actor)
    end)
end)

exports('AdjustReputation', function(subject, category, delta, reason, transactionId)
    return safe('AdjustReputation', function()
        local actor = privileged('adjustReputation')
        if not actor then return false, NoirIllegal.error('FORBIDDEN_CALLER') end
        subject = NoirIllegal.Validators.subject(subject)
        if not subject then return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'subject' }) end
        return NoirIllegal.Services.Admin.adjustReputation(
            subject, category, delta, reason, transactionId, actor)
    end)
end)

exports('SetHeat', function(citizenId, value, reason, transactionId)
    return safe('SetHeat', function()
        local actor = privileged('adjustHeat')
        if not actor then return false, NoirIllegal.error('FORBIDDEN_CALLER') end
        return NoirIllegal.Services.Admin.changeHeat(
            citizenId, value, 'set', reason, transactionId, actor)
    end)
end)

exports('AdjustHeat', function(citizenId, delta, reason, transactionId)
    return safe('AdjustHeat', function()
        local actor = privileged('adjustHeat')
        if not actor then return false, NoirIllegal.error('FORBIDDEN_CALLER') end
        return NoirIllegal.Services.Admin.changeHeat(
            citizenId, delta, 'add', reason, transactionId, actor)
    end)
end)

exports('InvalidateCache', function(citizenId)
    return safe('InvalidateCache', function()
        local actor = privileged('invalidateCache')
        if not actor then return false, NoirIllegal.error('FORBIDDEN_CALLER') end
        if citizenId == nil then
            NoirIllegal.Cache.invalidateAll()
        elseif NoirIllegal.Validators.string(citizenId, 1, 64) then
            NoirIllegal.Cache.invalidatePlayer(citizenId)
        else
            return false, NoirIllegal.error('INVALID_ARGUMENT', { field = 'citizenId' })
        end
        return true, { ok = true }
    end)
end)
