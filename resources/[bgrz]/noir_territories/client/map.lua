-- Tela de territórios.
--
-- O mapa do jogo só desenha blip, e blip não faz polígono; a injeção em scaleform que faria
-- isso não executa neste build (contado no cabeçalho de client/zones.lua). Então o mapa de
-- território é uma página: Leaflet sobre os tiles do GTA, com a fronteira real de cada bairro
-- e a cor da gang dona.

local open = false

---Cor de uma gang em hexadecimal, para a página. A escolhida no config, ou uma estável tirada
---do nome quando a gang não tem cor definida.
local fallbackOrder = {}
for name in pairs(Config.Colors) do fallbackOrder[#fallbackOrder + 1] = name end
table.sort(fallbackOrder)

local function gangHex(gang)
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
---disputa, a página desenha diferente — o estado vai junto para ela decidir.
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
            counts = status.counts,
            total = status.total,
            required = status.required,
            color = status.gang and gangHex(status.gang)
                or status.gangs and gangHex(status.gangs[1])
                or zone.color,
        }
    end

    return list
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
    SendNUIMessage({ action = 'open', zones = zones })
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
