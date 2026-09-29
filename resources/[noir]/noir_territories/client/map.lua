-- Tela de territórios.
--
-- O mapa do jogo só desenha blip, e blip não faz polígono; a injeção em scaleform que faria
-- isso não executa neste build (contado no cabeçalho de client/zones.lua). Então o mapa de
-- território é uma página: Leaflet sobre os tiles do GTA, com a fronteira real de cada bairro
-- e a cor da gang dona.
--
-- O desenho não é mais exclusivo desta página: o menu do `noir_gangs` mostra o mesmo mapa.
-- Por isso o que os dois precisam sai daqui por `GetTerritoryMap`, e não por cópia da
-- geometria e das constantes de projeção do outro lado.

local open = false

---Cor de uma gang em hexadecimal, para a página. A escolhida no config, ou uma estável tirada
---do nome quando a gang não tem cor definida.
local fallbackOrder = {}
for name in pairs(Config.Colors) do fallbackOrder[#fallbackOrder + 1] = name end
table.sort(fallbackOrder)

---A cor da gang é dela, não do mapa: quem manda é o `noir_gangs`, onde ela é escolhida no
---`/gangsetup` e guardada junto da gang. A lista local ficou como último recurso, para o
---mapa continuar desenhando quando aquele resource estiver fora do ar.
local function gangHex(gang)
    if GetResourceState('noir_gangs') == 'started' then
        local ok, hex = pcall(function() return exports.noir_gangs:GetGangColor(gang) end)
        if ok and type(hex) == 'string' and hex ~= '' then return hex end
    end

    local named = Config.GangColors[gang]
    local color = named and Config.Colors[named]

    if not color then
        local hash = 0
        for i = 1, #gang do hash = (hash * 31 + gang:byte(i)) % 0xFFFFFF end
        color = Config.Colors[fallbackOrder[hash % #fallbackOrder + 1]]
    end

    return ('#%02X%02X%02X'):format(color.r, color.g, color.b)
end

---Bairro com dono sai na cor da gang; sem dono, na cor cinza do próprio Zone Manager. Em
---disputa, a página desenha diferente — o estado vai junto para ela decidir, e com ele a
---flag que diz se o bairro é conquistável ou fixo: sem ela a tela prometeria uma disputa
---que não existe, contando tags para um bairro que nunca muda de mão.
---
---`now` viaja junto com a trava porque a página não pode perguntar as horas: o relógio aqui é o
---do servidor, recebido junto do espelho da placa (`client/ownership.lua`). Zero significa "a
---placa ainda não chegou", e a tela mostra a trava sem contagem em vez de um número inventado.
local function payload()
    local list = {}

    for _, zone in ipairs(NoirZones and NoirZones.list() or {}) do
        local status = NoirClaims.getZoneStatus(zone.name)

        list[#list + 1] = {
            name = zone.name,
            kind = zone.kind,
            radius = zone.radius,
            points = zone.points,
            state = status.state,
            gang = status.gang,
            gangs = status.gangs,
            influence = status.influence,
            neutral = status.neutral,
            total = status.total,
            required = status.required,
            counts = status.counts,
            tags = status.tags,
            challenger = status.challenger,
            lockedUntil = status.lockedUntil,
            now = NoirOwnership.now(),
            conquerable = status.conquerable,
            color = status.gang and gangHex(status.gang)
                or status.gangs and gangHex(status.gangs[1])
                or zone.color,
        }
    end

    return list
end

---A projeção vai para a página em vez de ficar escrita nela: os tiles e as constantes
---andam juntos, e o caminho é resolvido aqui porque só em jogo se sabe o nome real do
---resource.
local function mapConfig()
    return {
        tiles = ('nui://%s/%s'):format(cache.resource, Config.Map.tilesPath),
        maxZoom = Config.Map.maxZoom,
        maxNativeZoom = Config.Map.maxNativeZoom,
        maxResolution = Config.Map.maxResolution,
        centerLat = Config.Map.centerLat,
        centerLng = Config.Map.centerLng,
        offset = Config.Map.offset,
    }
end

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function show()
    if open then return end

    local zones = payload()
    if #zones == 0 then
        return lib.notify({ description = 'Nenhum bairro mapeado ainda.', type = 'inform' })
    end

    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', zones = zones, map = mapConfig() })
end

RegisterNUICallback('territoryMap:close', function(_, cb)
    cb('ok')
    close()
end)

RegisterCommand('territorymap', show, false)

---Sem isto, um erro no meio do fluxo ou um restart deixaria o jogador com o foco preso na
---página e sem teclado no jogo.
AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then close() end
end)

---Tudo que uma tela precisa para desenhar o mapa: os bairros com fronteira e dono, e a
---projeção dos tiles. Quem consome não recopia geometria nem constante — e, no dia em que
---os tiles mudarem, as duas telas mudam juntas.
---@return table { zones: table[], map: table }
exports('GetTerritoryMap', function()
    return { zones = payload(), map = mapConfig() }
end)
