local Service = {}
NoirIllegal.Services.Cooldown = Service

function Service.check(citizenId, activityKey, query, forUpdate)
    local row = NoirIllegal.Repositories.Cooldown.get(
        'player', citizenId, activityKey, query, forUpdate)
    local expiresAt = tonumber(row and row.expires_at_epoch)
    if expiresAt and expiresAt > os.time() then
        return false, expiresAt
    end
    return true
end

function Service.apply(citizenId, activityKey, seconds, query)
    if not seconds or seconds <= 0 then return nil end
    local expiresAt = os.time() + seconds
    NoirIllegal.Repositories.Cooldown.set(
        'player', citizenId, activityKey, expiresAt, query)
    return expiresAt
end
