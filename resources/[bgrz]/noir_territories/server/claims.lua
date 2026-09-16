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

---@param data table { id, type?, gang, coords, radius? }
local function registerClaim(data)
    if type(data) == 'table' and data.zone == nil then
        data.zone = zoneAt(data.coords)
    end

    local claim = NoirClaims.add(data)
    if not claim then return false end
    broadcast('add', claim)
    return true
end

local function removeClaim(claimType, id)
    if not NoirClaims.remove(claimType, id) then return false end
    broadcast('remove', { type = claimType or 'graffiti', id = id })
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
