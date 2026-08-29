local Service = {}
NoirIllegal.Services.Unlock = Service

function Service.toMap(rows)
    local result = {}
    for i = 1, #rows do
        if rows[i].state == 'granted' then result[rows[i].unlock_key] = true end
    end
    return result
end

function Service.evaluateAutomatic(profile, organizationReputations, query, actor)
    local granted = {}
    for unlockKey, definition in pairs(NoirIllegal.Unlocks) do
        if definition.automatic then
            local scope = definition.scope
            local subjectId = scope == 'organization'
                and profile.organization and profile.organization.id
                or scope == 'player' and profile.citizenId
                or nil
            if subjectId then
                local existing = NoirIllegal.Repositories.Unlock.find(
                    scope, subjectId, unlockKey, query, true)
                if not existing or existing.state ~= 'granted' then
                    local candidate = {
                        citizenId = profile.citizenId,
                        reputations = scope == 'organization'
                            and (organizationReputations or {}) or profile.reputations,
                        levels = NoirIllegal.Services.Level.all(
                            scope == 'organization' and (organizationReputations or {}) or profile.reputations),
                        heat = profile.heat,
                        organization = profile.organization,
                        unlocks = profile.unlocks,
                    }
                    local eligible = NoirIllegal.Services.Eligibility.unlockRequirements(definition, candidate)
                    if eligible then
                        NoirIllegal.Repositories.Unlock.upsert(
                            scope, subjectId, unlockKey, 'granted', 'automatic',
                            actor.actorId, 'requirements_met', {}, query)
                        granted[#granted + 1] = {
                            key = unlockKey,
                            scope = scope,
                            subjectId = subjectId,
                        }
                        if scope == 'player' then profile.unlocks[unlockKey] = true end
                    end
                end
            end
        end
    end
    return granted
end
