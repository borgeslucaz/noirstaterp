NoirIllegal.Cache = {
    profiles = {},
    organizations = {},
    sources = {},
}

local Cache = NoirIllegal.Cache

local function fresh(entry)
    return entry and entry.expiresAt > os.time()
end

function Cache.getProfile(citizenId)
    local entry = Cache.profiles[citizenId]
    if not fresh(entry) then
        Cache.profiles[citizenId] = nil
        return nil
    end
    return NoirIllegal.Validators.copy(entry.value)
end

function Cache.setProfile(citizenId, value)
    Cache.profiles[citizenId] = {
        value = NoirIllegal.Validators.copy(value),
        loadedAt = os.time(),
        expiresAt = os.time() + NoirIllegal.Config.Cache.ttlSeconds,
    }
end

function Cache.getOrganization(organizationId)
    local entry = Cache.organizations[organizationId]
    if not fresh(entry) then
        Cache.organizations[organizationId] = nil
        return nil
    end
    return NoirIllegal.Validators.copy(entry.value)
end

function Cache.setOrganization(organizationId, value)
    Cache.organizations[organizationId] = {
        value = NoirIllegal.Validators.copy(value),
        loadedAt = os.time(),
        expiresAt = os.time() + NoirIllegal.Config.Cache.organizationTtlSeconds,
    }
end

function Cache.invalidatePlayer(citizenId)
    Cache.profiles[citizenId] = nil
end

function Cache.invalidateOrganization(organizationId)
    if organizationId then Cache.organizations[organizationId] = nil end
end

function Cache.invalidateAll()
    Cache.profiles = {}
    Cache.organizations = {}
    Cache.sources = {}
end

AddEventHandler('playerDropped', function()
    Cache.sources[source] = nil
end)
