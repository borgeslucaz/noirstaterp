---Ofertas de missão: a "ligação" com ACEITAR/RECUSAR. Chegam por export (outro resource
---decide quando ligar), por comando de admin, pelo NPC de início ou pela zona de início.
local Config = require 'config.server'
local Repository = require 'server.missions.repository'
local Starter = require 'server.instances.starter'
local Security = require 'server.security'

local Offers = {}

---@type table<string, { missionId: string, source: integer, expiresAt: integer }>
local offers = {}
---@type table<integer, string> source -> offerId
local byPlayer = {}
local counter = 0

local function now() return os.time() end

---@param source integer
function Offers.forget(source)
    local offerId = byPlayer[source]
    if offerId then offers[offerId] = nil end
    byPlayer[source] = nil
end

---@param missionId string
---@param source integer
---@return boolean ok
---@return string? code
function Offers.offer(missionId, source)
    if type(source) ~= 'number' or not GetPlayerName(source) then return false, 'invalid_player' end
    if byPlayer[source] then return false, 'busy' end
    local def, code = Starter.check(missionId, source)
    if not def then return false, code end

    counter = counter + 1
    local offerId = ('%d-%d'):format(counter, math.random(100000, 999999))
    offers[offerId] = { missionId = missionId, source = source, expiresAt = now() + Config.offerTimeoutSeconds }
    byPlayer[source] = offerId
    TriggerClientEvent('noir_missions:client:offer', source, {
        offerId = offerId,
        caller = def.start.caller or 'Desconhecido',
        title = def.name,
        text = def.start.text or def.description or '',
        seconds = Config.offerTimeoutSeconds,
    })
    SetTimeout(Config.offerTimeoutSeconds * 1000 + 2000, function()
        if offers[offerId] then
            offers[offerId] = nil
            if byPlayer[source] == offerId then byPlayer[source] = nil end
            TriggerClientEvent('noir_missions:client:offerClose', source, offerId)
        end
    end)
    return true
end

lib.callback.register('noir_missions:server:offerAnswer', function(source, offerId, accept)
    if not Security.consume(source, 'offer') then return { ok = false, code = 'rate_limited' } end
    if type(offerId) ~= 'string' then return { ok = false, code = 'invalid_id' } end
    local offer = offers[offerId]
    if not offer or offer.source ~= source then return { ok = false, code = 'expired' } end
    offers[offerId] = nil
    byPlayer[source] = nil
    if offer.expiresAt < now() then return { ok = false, code = 'expired' } end
    if accept ~= true then return { ok = true, declined = true } end

    local inst, code = Starter.start(offer.missionId, { source = source, origin = 'offer' })
    if not inst then return { ok = false, code = code } end
    return { ok = true, instanceId = inst.id }
end)

-- NPC e zona de início: o cliente conhece só posição e modelo; o servidor confere de novo
-- que a missão começa assim e que a pessoa está lá.
lib.callback.register('noir_missions:server:starterRequest', function(source, missionId)
    if not Security.consume(source, 'offer', 3000) then return { ok = false, code = 'rate_limited' } end
    if not Security.isKey(missionId, 48) then return { ok = false, code = 'invalid_id' } end
    local record = Repository.get(missionId)
    local def = record and record.status == 'published' and record.published or nil
    if not def then return { ok = false, code = 'mission_disabled' } end
    local start = def.start
    if start.type == 'npc' and start.npcCoords then
        if not Security.isNear(source, start.npcCoords, 6.0) then return { ok = false, code = 'too_far' } end
    elseif start.type == 'zone' and start.zoneCoords then
        if not Security.isNear(source, start.zoneCoords, (start.zoneRadius or 10) + 5.0) then return { ok = false, code = 'too_far' } end
    else
        return { ok = false, code = 'mission_disabled' }
    end
    local ok, code = Offers.offer(missionId, source)
    return { ok = ok, code = code }
end)

lib.callback.register('noir_missions:server:starters', function()
    return Repository.publicStarters()
end)

function Offers.broadcastStarters()
    TriggerClientEvent('noir_missions:client:starters', -1, Repository.publicStarters())
end

return Offers
