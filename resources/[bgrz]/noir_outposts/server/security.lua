-- Validação server-side: rate limit, ator, permissões, distância, payload e request IDs.
NoirOutposts = NoirOutposts or {}

local Security = {}
NoirOutposts.Security = Security

local config = require 'config.server'
local shared = require 'config.shared'
local V = NoirOutposts.Validators
local C = NoirOutposts.Constants
local Integration = NoirOutposts.Integration

local nextAllowedAt = {}
local recentRequests = {}
local profileByKey = {}
local productById = {}

for index = 1, #shared.dealerProfiles do
    local profile = shared.dealerProfiles[index]
    profileByKey[profile.key] = profile
end

for index = 1, #shared.products do
    local product = shared.products[index]
    if config.products[product.id] then productById[product.id] = product end
end

-- Rate limit ---------------------------------------------------------------------

---@param source number
---@param action string
---@return boolean allowed
function Security.consumeRateLimit(source, action)
    local interval = config.rateLimits[action] or 1000
    local now = GetGameTimer()
    local byAction = nextAllowedAt[source]
    if not byAction then
        byAction = {}
        nextAllowedAt[source] = byAction
    end
    if (byAction[action] or 0) > now then return false end
    byAction[action] = now + interval
    return true
end

-- Request IDs (idempotência de curto prazo) ---------------------------------------------

---@param citizenId string
---@param requestId string
---@return 'new'|'duplicate'
function Security.claimRequestId(citizenId, requestId)
    local now = os.time()
    local key = citizenId .. ':' .. requestId
    local entry = recentRequests[key]
    if entry and entry.expiresAt > now then return 'duplicate' end
    recentRequests[key] = { expiresAt = now + config.sessions.requestIdTtlSeconds }
    return 'new'
end

function Security.pruneRequestIds()
    local now = os.time()
    for key, entry in pairs(recentRequests) do
        if entry.expiresAt <= now then recentRequests[key] = nil end
    end
end

-- Ator -------------------------------------------------------------------------

---@class OutpostActor
---@field source number
---@field citizenId string
---@field character table
---@field organization table?

---@param source number
---@return OutpostActor? actor, string? code
function Security.resolveActor(source)
    if type(source) ~= 'number' or source <= 0 then return nil, 'invalid_player' end
    local character = Integration.getCharacter(source)
    if not character then return nil, 'invalid_player' end
    return {
        source = source,
        citizenId = character.citizenId,
        character = character,
        organization = Integration.organizationFrom(character),
    }
end

---@param actor OutpostActor
---@return boolean
function Security.isActorAble(actor)
    local status = actor.character.status or {}
    if status.dead or status.handcuffed then return false end
    if (status.jailTime or 0) > 0 then return false end
    return true
end

---@param actor OutpostActor
---@param action string
---@return boolean ok, string? code
function Security.requirePermission(actor, action)
    if not actor.organization then return false, 'no_organization' end
    if not V.hasGrade(actor.organization.grade, config.permissions, action) then
        return false, 'insufficient_grade'
    end
    return true
end

---@param actor OutpostActor
---@param outpost table
---@return boolean
function Security.isOwner(actor, outpost)
    return actor.organization ~= nil
        and outpost.owner_organization_id ~= nil
        and actor.organization.id == outpost.owner_organization_id
end

---@param actor OutpostActor
---@return table<string, boolean>
function Security.permissionMap(actor)
    local grade = actor.organization and actor.organization.grade or nil
    if not actor.organization then
        local map = {}
        for index = 1, #C.PermissionKeys do map[C.PermissionKeys[index]] = false end
        return map
    end
    return V.permissionMap(grade, config.permissions, C.PermissionKeys)
end

-- Distância e entidades ------------------------------------------------------------

---@param source number
---@param coords vector3|vector4|table
---@param maxDistance number
---@return boolean
function Security.isNear(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local position = GetEntityCoords(ped)
    local target = vector3(coords.x, coords.y, coords.z)
    return #(position - target) <= (maxDistance + config.validation.maxDistanceTolerance)
end

---@param source number
---@param entity number
---@param maxDistance number
---@return boolean
function Security.isNearEntity(source, entity, maxDistance)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    return Security.isNear(source, GetEntityCoords(entity), maxDistance)
end

---@param source number
---@param entity number
---@return boolean
function Security.sameBucket(source, entity)
    if not entity or entity == 0 then return false end
    return GetPlayerRoutingBucket(source) == GetEntityRoutingBucket(entity)
end

-- Payload -------------------------------------------------------------------------

---@param value any
---@return string? outpostId
function Security.outpostId(value)
    if not V.isIdentifier(value) then return nil end
    if not shared.outposts[value] then return nil end
    return value
end

---@param value any
---@return table? profile
function Security.profile(value)
    if not V.isIdentifier(value) then return nil end
    return profileByKey[value]
end

---@param value any
---@return table? product
function Security.product(value)
    if not V.isIdentifier(value, 64) then return nil end
    return productById[value]
end

---@param value any
---@return integer? dealerId
function Security.dealerId(value)
    if not V.isPositiveInteger(value, 2 ^ 40) then return nil end
    return math.floor(value)
end

---@param value any
---@param maximum integer
---@return integer? amount
function Security.amount(value, maximum)
    if not V.isPositiveInteger(value, maximum) then return nil end
    return math.floor(value)
end

---@param value any
---@return integer? netId
function Security.netId(value)
    if not V.isPositiveInteger(value, 2 ^ 31) then return nil end
    return math.floor(value)
end

---@param value any
---@return string? requestId
function Security.requestId(value)
    if not V.isRequestId(value) then return nil end
    return value
end

---@param value any
---@return string? sessionId
function Security.sessionId(value)
    if type(value) ~= 'string' or #value < 8 or #value > C.Limits.maxSessionIdLength then return nil end
    if not value:match('^[%w%-]+$') then return nil end
    return value
end

---@param source number
---@return boolean
function Security.isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, config.adminAce)
end

function Security.cleanupSource(source)
    nextAllowedAt[source] = nil
end

AddEventHandler('playerDropped', function()
    Security.cleanupSource(source)
end)
