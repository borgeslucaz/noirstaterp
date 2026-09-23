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

---Reputação e unlocks da gang, no mesmo cache: os dois mudam juntos quando uma atividade
---passa, e é a mesma invalidação que limpa os dois.
function Service.organization(organizationId)
    if not organizationId then return { reputations = {}, unlocks = {} } end
    local cached = NoirIllegal.Cache.getOrganization(organizationId)
    if cached then return cached end
    local result = {
        reputations = NoirIllegal.Repositories.Reputation.list('organization', organizationId),
        unlocks = NoirIllegal.Services.Unlock.toMap(
            NoirIllegal.Repositories.Unlock.list('organization', organizationId)),
    }
    NoirIllegal.Cache.setOrganization(organizationId, result)
    return result
end

function Service.organizationReputations(organizationId)
    return Service.organization(organizationId).reputations
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
        local state = Service.organization(organization.id)
        organization.reputations = state.reputations
        organization.levels = NoirIllegal.Services.Level.all(state.reputations)
        organization.unlocks = state.unlocks
    end
    profile.organization = organization
    return NoirIllegal.Validators.copy(profile)
end
