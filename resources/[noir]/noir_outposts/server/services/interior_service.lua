-- Interior do outpost: quem está dentro de qual, e o routing bucket que os separa.
--
-- O `noir_shell` cria o ambiente local e, por decisão de design dele, NÃO gerencia bucket — isso é
-- do resource de gameplay. Este arquivo é essa metade: ele decide quem entra, põe o jogador no
-- bucket do posto e garante que ninguém fique preso lá quando alguma coisa dá errado.
--
-- A planta do interior é compartilhada entre postos: o `pier` e o `docks` usam as mesmas
-- coordenadas. Quem os separa é só o bucket, e é por isso que `Security.atComputer` confere os
-- dois — bucket e distância — antes de qualquer ação presencial.
NoirOutposts = NoirOutposts or {}
NoirOutposts.Services = NoirOutposts.Services or {}

local Service = {}
NoirOutposts.Services.Interior = Service

local config = require 'config.server'
local shared = require 'config.shared'
local C = NoirOutposts.Constants
local Log = NoirOutposts.Log
local State = NoirOutposts.State
local Security = NoirOutposts.Security
local Sessions = NoirOutposts.Sessions

local DEFAULT_BUCKET = 0

---Quem está dentro de qual posto. É a presença: o servidor só considera dentro quem ele mesmo
---colocou lá. O bucket sozinho não bastaria — outro resource pode usar o mesmo número, e aí a
---coincidência viraria acesso.
---@type table<number, string>
local inside = {}

---@param source number
---@return string? outpostId
function Service.outpostOf(source)
    return inside[source]
end

---@param outpostId string
---@return table? shell
function Service.shellOf(outpostId)
    local definition = shared.outposts[outpostId]
    return definition and shared.shells[definition.shell] or nil
end

---Quem pode entrar. Enquanto o posto não tem dono, a porta é de quem chegar — é assim que uma
---organização rival alcança o terminal para tomar o lugar. Tomado, só a organização dona entra.
---
---O cartão da Exchange entra aqui na fase seguinte, substituindo a porta livre do caso sem dono.
---@param actor OutpostActor
---@param outpostId string
---@return boolean ok, string? code
function Service.canEnter(actor, outpostId)
    local entry = State.get(outpostId)
    if not entry then return false, 'unknown_outpost' end
    if entry.row.status == C.OutpostStatus.INACTIVE then return false, 'outpost_inactive' end
    if not Security.isActorAble(actor) then return false, 'player_unavailable' end

    if entry.row.owner_organization_id and not Security.isOwner(actor, entry.row) then
        return false, 'not_owner'
    end
    return true
end

---@param actor OutpostActor
---@param outpostId string
---@return table result
function Service.enter(actor, outpostId)
    local definition = shared.outposts[outpostId]
    if not definition then return { ok = false, code = 'unknown_outpost' } end

    local shell = Service.shellOf(outpostId)
    if not shell then
        Log.error('interior_shell_missing', { outpostId = outpostId, shell = definition.shell })
        return { ok = false, code = 'internal_error' }
    end

    -- A porta é no mundo, então a distância aqui mede contra `entrance` e não contra o computador,
    -- que já está do outro lado. Bucket não entra: quem está entrando ainda está do lado de fora.
    if not Security.isNear(actor.source, definition.entrance, shared.interaction.computerDistance) then
        return { ok = false, code = 'too_far' }
    end

    local allowed, code = Service.canEnter(actor, outpostId)
    if not allowed then return { ok = false, code = code } end

    SetPlayerRoutingBucket(actor.source, Security.expectedBucket(outpostId))
    inside[actor.source] = outpostId

    Log.debug('interior_entered', { source = actor.source, outpostId = outpostId })
    return { ok = true, data = { door = shell.door } }
end

---Tira o jogador do interior e o devolve à porta. Idempotente: chamado pela saída normal, pela
---queda, pela troca de organização e pela parada do resource.
---@param source number
---@param reason string
---@return boolean evicted
function Service.leave(source, reason)
    local outpostId = inside[source]
    if not outpostId then return false end
    inside[source] = nil

    SetPlayerRoutingBucket(source, DEFAULT_BUCKET)
    Sessions.closePanel(source, reason)

    -- Quem já caiu não precisa ser teleportado, e mandar evento para ele erraria. Quem continua
    -- conectado volta para a porta: deixá-lo nas coordenadas do interior, em bucket 0, é largá-lo
    -- sob o mapa em queda livre.
    if GetPlayerPed(source) ~= 0 then
        local definition = shared.outposts[outpostId]
        TriggerClientEvent(C.Events.INTERIOR_EVICT, source, {
            reason = reason,
            entrance = definition and definition.entrance or nil,
        })
    end

    Log.debug('interior_left', { source = source, outpostId = outpostId, reason = reason })
    return true
end

---Todos os ocupantes de um posto. Usado quando o posto muda de mãos ou sai do ar.
---@param outpostId string
---@param reason string
function Service.evictOutpost(outpostId, reason)
    local sources = {}
    for source, id in pairs(inside) do
        if id == outpostId then sources[#sources + 1] = source end
    end
    for index = 1, #sources do Service.leave(sources[index], reason) end
end

---Esvazia todos os interiores. Sem isto, parar o resource deixa cada ocupante num bucket sem
---shell, sob o mapa — e o shell dele morre junto com o client script.
---@param reason string
function Service.clear(reason)
    local sources = {}
    for source in pairs(inside) do sources[#sources + 1] = source end
    for index = 1, #sources do Service.leave(sources[index], reason) end
end

---Prepara os buckets de interior no start. Desliga a população ambiente: sem isto nascem
---pedestres e trânsito dentro de uma sala a oitenta metros sob o mapa.
---
---Os props NÃO são criados aqui. Eles são locais de cada client, como o shell que os cerca — uma
---decoração networked existiria no bucket mesmo com a sala vazia, e ainda exigiria uma cópia por
---posto, já que a planta é compartilhada.
function Service.configureBuckets()
    for outpostId in pairs(shared.outposts) do
        pcall(SetRoutingBucketPopulationEnabled, Security.expectedBucket(outpostId), false)
    end
end

---Contagem por posto, para o diagnóstico.
---@return table<string, integer>
function Service.occupancy()
    local counts = {}
    for _, outpostId in pairs(inside) do
        counts[outpostId] = (counts[outpostId] or 0) + 1
    end
    return counts
end

-- Reconexão. O bucket é por sessão e não sobrevive à queda, mas a presença em memória sim: sem
-- isto, um jogador que caiu dentro voltaria com o servidor achando que ele ainda está no interior.
AddEventHandler('bgrz_core:server:playerLoaded', function(source)
    if type(source) == 'number' then inside[source] = nil end
end)
