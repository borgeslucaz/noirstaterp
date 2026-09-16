-- Bairros do Zone Manager, do lado do cliente.
--
-- Este arquivo só recebe e guarda. Quem desenha é a tela do /territorymap.
--
-- Já houve pintura no mapa do jogo aqui: círculos, depois retângulos, depois retângulos com
-- resolução por distância. Saiu tudo. O mapa nativo só tem blip, blip só tem círculo e
-- retângulo, e aproximar polígono com eles produz escada — além de consumir um pool de blips
-- que é compartilhado com o servidor inteiro. Desenhar polígono de verdade exigiria injeção
-- em scaleform, que não executa neste build (testado com duas técnicas e dois .gfx, um deles
-- convertido para Enhanced). Território agora vive na tela, onde a fronteira é exata e não
-- custa blip nenhum.

NoirZones = {}

local zones = {}

---Os bairros como vieram do Zone Manager, para a tela desenhar o polígono de verdade.
function NoirZones.list()
    return zones
end

---Cruzamentos de raio: ímpar está dentro, par está fora.
local function inside(points, x, y)
    local isInside, n = false, #points
    local j = n

    for i = 1, n do
        local a, b = points[i], points[j]
        if ((a.y > y) ~= (b.y > y))
            and (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) then
            isInside = not isInside
        end
        j = i
    end

    return isInside
end

---Em que bairro uma coordenada cai. No servidor quem responde é o Zone Manager; aqui é o
---polígono que já chegou, para a consulta não precisar de viagem de rede.
---@return string? nome do bairro
function NoirZones.zoneAt(coords)
    if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return end
    local x, y = tonumber(coords.x), tonumber(coords.y)
    if not x or not y then return end

    for i = 1, #zones do
        local zone = zones[i]
        local points = zone.points

        if type(points) == 'table' and #points >= 3 and inside(points, x, y) then
            return zone.name
        end
    end
end

NoirClaims.zoneAt = NoirZones.zoneAt

RegisterNetEvent('noir_territories:client:zones', function(list)
    zones = type(list) == 'table' and list or {}
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    TriggerServerEvent('noir_territories:server:requestZones')
end)

---Sai no F8 e no console do servidor ao mesmo tempo: qual dos dois a pessoa está olhando não
---deveria decidir se o diagnóstico existe.
local function say(line)
    print(line)
    TriggerServerEvent('noir_territories:server:log', line)
end

---Chamado pelo /territorydebug, que mora em client/claims.lua. Se este arquivo não carregar,
---`NoirZones` fica nil, e a ausência já é resposta.
function NoirZones.report()
    say(('[noir_territories] bairros recebidos do servidor: %d'):format(#zones))

    for i = 1, #zones do
        local zone = zones[i]
        say(('    %-14s kind=%-6s pontos=%d  cor=%s'):format(
            tostring(zone.name), tostring(zone.kind),
            type(zone.points) == 'table' and #zone.points or 0,
            tostring(zone.color)))
    end

    if #zones == 0 then
        say('  -> o servidor nao mandou bairro nenhum. Zone Manager parado, ou zones.json vazio.')
    end
end
