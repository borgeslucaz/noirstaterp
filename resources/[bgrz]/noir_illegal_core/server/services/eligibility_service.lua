local Service = {}
NoirIllegal.Services.Eligibility = Service

local function requirementsSatisfied(requirements, profile)
    requirements = requirements or {}
    for category, minimum in pairs(requirements.reputation or {}) do
        if (profile.reputations[category] or 0) < minimum then
            return false, { requirement = 'reputation', category = category, minimum = minimum }
        end
    end
    for category, minimum in pairs(requirements.minLevel or {}) do
        if (profile.levels[category] or 0) < minimum then
            return false, { requirement = 'level', category = category, minimum = minimum }
        end
    end
    if requirements.maxHeat and profile.heat > requirements.maxHeat then
        return false, { requirement = 'maxHeat', maximum = requirements.maxHeat }
    end
    if requirements.organization == true and not profile.organization then
        return false, { requirement = 'organization' }
    end
    for i = 1, #(requirements.unlocks or {}) do
        local key = requirements.unlocks[i]
        if not profile.unlocks[key] then
            return false, { requirement = 'unlock', unlockKey = key }
        end
    end
    return true
end

function Service.evaluate(activity, profile, checkCooldown, query)
    local eligible, detail = requirementsSatisfied(activity.requirements, profile)
    if not eligible then return false, detail end
    if checkCooldown then
        local available, retryAt = NoirIllegal.Services.Cooldown.check(
            profile.citizenId, profile.activityKey, query, query ~= nil)
        if not available then return false, { cooldown = true, retryAt = retryAt } end
    end
    return true
end

function Service.unlockRequirements(definition, profile)
    return requirementsSatisfied(definition.requirements, profile)
end
