-- Registro das áreas de graffiti, lado servidor.
--
-- Quem escreve aqui é o noir_graffiti, e só ele: nascimento, morte e a lista inteira quando
-- um dos dois resources sobe. O servidor é o dono do registro e espelha nos clientes, para o
-- desenho de debug e para consulta local não precisar de viagem de rede.

---Em que bairro uma coordenada cai, pelo Zone Manager — que é a fonte da verdade no
---servidor. O resultado é gravado na tag e viaja com ela: contar domínio não pode custar um
---teste de polígono por tag a cada pergunta.
local function zoneAt(coords)
    if GetResourceState('zonemanager') ~= 'started' then return end
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end

    local ok, names = pcall(function()
        return exports.zonemanager:GetZonesAt(coords.x, coords.y, coords.z or 0.0)
    end)
    if not ok or type(names) ~= 'table' then return end

    -- Bairros não se sobrepõem por desenho; se sobrepuserem, o primeiro resolve e a
    -- inconsistência aparece no /territorydebug em vez de silenciosamente.
    return names[1]
end

NoirClaims.zoneAt = zoneAt

local function broadcast(action, payload)
    TriggerClientEvent('noir_territories:client:claims', -1, action, payload)
end

---Uma tag nova vale influência para a gang dela; uma tag apagada devolve a mesma quantia.
---
---A concessão acontece no evento, e não a partir da contagem de tags vivas, porque a
---influência é um livro-caixa persistido: se ela fosse derivada das tags, tudo que não é
---graffiti — venda, guerra, missão — não teria onde ficar guardado, e o pool voltaria a ser
---só o placar de quem picha mais.
---
---A consequência conhecida está do outro lado da mesma moeda: tag que nasce ou morre com o
---`noir_territories` fora do ar não move influência nenhuma, porque ninguém estava ouvindo. É
---aceitável — o contrário seria reprocessar o mundo a cada start e apagar todo o resto.
---A chave da concessão é a da própria tag: é o que liga o que foi ganho ao que será devolvido.
local function grantKey(claimType, id)
    return ('%s:%s'):format(claimType or 'graffiti', tostring(id))
end

local function grantFor(claim)
    if not claim or not claim.zone or not claim.gang then return end
    NoirInfluenceServer.grantOnce(grantKey(claim.type, claim.id), claim.zone, claim.gang, 'graffiti')
end

---@param data table { id, type?, gang, coords, zone? }
local function registerClaim(data)
    if type(data) == 'table' and data.zone == nil then
        data.zone = zoneAt(data.coords)
    end

    local claim = NoirClaims.add(data)
    if not claim then return false end
    broadcast('add', claim)
    grantFor(claim)
    return true
end

local function removeClaim(claimType, id)
    if not NoirClaims.remove(claimType, id) then return false end
    broadcast('remove', { type = claimType or 'graffiti', id = id })

    -- A devolução não precisa da tag: ela sai do que a concessão registrou, que sobrevive a
    -- restart justamente porque o registro de tags não sobrevive.
    NoirInfluenceServer.revokeOnce(grantKey(claimType, id))
    return true
end

---Lista de um tipo só. O `set` do cliente troca exatamente esse tipo, então a mensagem
---precisa dizer qual é: mandar o registro inteiro faria um tipo futuro sumir da cópia local
---toda vez que outro fosse reconstruído.
local function claimsOfType(claimType)
    local list = {}
    for _, claim in pairs(NoirClaims.list) do
        if claim.type == claimType then list[#list + 1] = claim end
    end
    return list
end

---Troca de uma vez todas as áreas de um tipo, que é como o registro é reconstruído.
---
---Não concede influência, e isso é o ponto: esta função roda a cada start dos dois resources,
---com a lista inteira de tags vivas. Conceder aqui daria 100 pontos por tag a cada restart do
---servidor, e um bairro com quatro tags viraria dominado na terceira segunda-feira. O livro-
---caixa já tem o que essas tags concederam quando nasceram.
local function setClaims(claimType, entries)
    claimType = claimType or 'graffiti'

    for i = 1, #(entries or {}) do
        local entry = entries[i]
        if type(entry) == 'table' and entry.zone == nil then
            entry.zone = zoneAt(entry.coords)
        end
    end

    NoirClaims.replace(claimType, entries)
    broadcast('set', { type = claimType, claims = claimsOfType(claimType) })
    return true
end

exports('registerClaim', registerClaim)
exports('removeClaim', removeClaim)
exports('setClaims', setClaims)

---Cliente entrando agora, ou resource dele reiniciando, pede a lista inteira.
RegisterNetEvent('noir_territories:server:request', function()
    local source = source
    local seen = {}

    for _, claim in pairs(NoirClaims.list) do
        if not seen[claim.type] then
            seen[claim.type] = true
            TriggerClientEvent('noir_territories:client:claims', source, 'set',
                { type = claim.type, claims = claimsOfType(claim.type) })
        end
    end

    -- Registro vazio também é resposta: sem isto, o cliente que reiniciou ficaria com a
    -- cópia antiga de um tipo que não existe mais.
    if not seen.graffiti then
        TriggerClientEvent('noir_territories:client:claims', source, 'set',
            { type = 'graffiti', claims = {} })
    end
end)
