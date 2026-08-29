local Service = {}
NoirIllegal.Services.Profile = Service

local function ensureProfile(citizenId)
    return MySQL.transaction.await({
        { query = 'INSERT IGNORE INTO noir_illegal_profiles (citizenid) VALUES (?)', values = { citizenId } },
        { query = 'INSERT IGNORE INTO noir_illegal_player_heat (citizenid, value, last_decay_at) VALUES (?, 0, UTC_TIMESTAMP())', values = { citizenId } },
    })
end

local function baseProfile(identity)
    local cached = NoirIllegal.Cache.getProfile(identity.citizenId)
    if cached then return cached end

    if not ensureProfile(identity.citizenId) then return nil end
    local reputations = NoirIllegal.Repositories.Reputation.list('player', identity.citizenId)
    local unlockRows = NoirIllegal.Repositories.Unlock.list('player', identity.citizenId)
    local profile = {
        citizenId = identity.citizenId,
        reputations = reputations,
        levels = NoirIllegal.Services.Level.all(reputations),
        unlocks = NoirIllegal.Services.Unlock.toMap(unlockRows),
    }
    NoirIllegal.Cache.setProfile(identity.citizenId, profile)
    return profile
end

function Service.organizationReputations(organizationId)
    if not organizationId then return {} end
    local cached = NoirIllegal.Cache.getOrganization(organizationId)
    if cached then return cached end
    local result = NoirIllegal.Repositories.Reputation.list('organization', organizationId)
    NoirIllegal.Cache.setOrganization(organizationId, result)
    return result
end

function Service.getBySource(source)
    local identity = NoirIllegal.Bridges.Qbox.getIdentity(source)
    if not identity then return nil, NoirIllegal.error('INVALID_SOURCE') end

    local profile = baseProfile(identity)
    if not profile then return nil, NoirIllegal.error('DATABASE_ERROR') end
    profile.heat = NoirIllegal.Services.Heat.read(identity.citizenId, source)
    if profile.heat == nil then return nil, NoirIllegal.error('DATABASE_ERROR') end

    local organization = NoirIllegal.Bridges.Gangs.getOrganization(source)
    if organization then
        organization.reputations = Service.organizationReputations(organization.id)
        organization.levels = NoirIllegal.Services.Level.all(organization.reputations)
    end
    profile.organization = organization
    return NoirIllegal.Validators.copy(profile)
end
