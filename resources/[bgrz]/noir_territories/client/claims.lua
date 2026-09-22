-- Cópia local das áreas reivindicadas por graffiti.
--
-- Serve para responder `getTerritoryAt` e companhia sem viagem de rede, e para o desenho de
-- diagnóstico no mundo. Nada daqui vai para o mapa: território se olha pelo /territorymap.

local drawing = false

---Ordem estável para o sorteio de quem não tem cor escolhida. `pairs` não garante ordem, e
---sem ordenar a mesma gang sairia de uma cor em cada cliente.
local fallbackOrder = {}
for name in pairs(Config.Colors) do fallbackOrder[#fallbackOrder + 1] = name end
table.sort(fallbackOrder)

---Cor da gang: a escolhida no config, ou uma estável tirada do nome quando não há escolha.
local function gangColor(gang)
    local named = Config.GangColors[gang]
    local color = named and Config.Colors[named]
    if color then return color end

    local hash = 0
    for i = 1, #gang do hash = (hash * 31 + gang:byte(i)) % 0xFFFFFF end
    return Config.Colors[fallbackOrder[hash % #fallbackOrder + 1]]
end

-- Até onde o diagnóstico desenha. O que está além disso não se enxerga, e percorrer o registro
-- inteiro a cada frame para desenhar um pino invisível é trabalho jogado fora.
local DRAW_DISTANCE = 200.0

---No mundo, não no mapa: um pino no centro exato de cada tag por perto, e só enquanto o debug
---está ligado — a thread nasce junto com ele e morre junto.
---
---Já houve um círculo no chão aqui, do tamanho do raio de domínio de cada tag. Ele saiu junto
---com o raio: domínio passou a ser por bairro, `normalize` parou de produzir `radius`, e o
---desenho ficou lendo um campo que não existe mais — crash na primeira vez que alguém ligou o
---debug com tag por perto. Não há raio para inventar no lugar: o que a tag tem de verdade é
---uma coordenada, e é isso que o pino mostra. A fronteira do domínio se olha no /territorymap,
---onde ela é o polígono do bairro.
local function startDrawing()
    if drawing then return end
    drawing = true

    CreateThread(function()
        while Config.DebugTerritories do
            local coords = GetEntityCoords(cache.ped)

            for _, claim in pairs(NoirClaims.list) do
                local dx, dy = coords.x - claim.coords.x, coords.y - claim.coords.y
                if (dx * dx + dy * dy) <= (DRAW_DISTANCE * DRAW_DISTANCE) then
                    local color = gangColor(claim.gang)

                    DrawMarker(0, claim.coords.x, claim.coords.y, claim.coords.z + 1.2,
                        0.0, 0.0, 0.0, 180.0, 0.0, 0.0,
                        0.5, 0.5, 0.5,
                        color.r, color.g, color.b, 180, false, false, 2, false, nil, nil, false)
                end
            end

            Wait(0)
        end

        drawing = false
    end)
end

RegisterNetEvent('noir_territories:client:claims', function(action, payload)
    if action == 'set' then
        NoirClaims.replace(payload and payload.type, payload and payload.claims)
    elseif action == 'add' then
        NoirClaims.add(payload)
    elseif action == 'remove' then
        NoirClaims.remove(payload and payload.type, payload and payload.id)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    TriggerServerEvent('noir_territories:server:request')
end)

RegisterCommand('territorydebug', function()
    -- O relatório dos bairros mora em client/zones.lua. Se aquele arquivo não carregar,
    -- `NoirZones` fica nil — e a ausência do aviso já diz que ele está de pé.
    if NoirZones then
        NoirZones.report()
    else
        print('[noir_territories] client/zones.lua NAO carregou')
    end

    Config.DebugTerritories = not Config.DebugTerritories
    if Config.DebugTerritories then startDrawing() end

    local territory = NoirClaims.getTerritoryAt(GetEntityCoords(cache.ped))
    print(('[noir_territories] debug no mundo %s | aqui: %s%s%s'):format(
        Config.DebugTerritories and 'LIGADO' or 'DESLIGADO',
        territory.state,
        territory.gang and (' (%s)'):format(territory.gang)
            or territory.gangs and (' (%s)'):format(table.concat(territory.gangs, ', ')) or '',
        territory.conquerable == false and ' [fixo]' or ''))

    -- O placar do bairro em que a pessoa está. É a pergunta seguinte a "de quem é isto aqui",
    -- e sem ela a única forma de ver influência é abrir o banco.
    if territory.zone then
        local ordered = {}
        for gang, points in pairs(territory.influence or {}) do
            ordered[#ordered + 1] = ('%s %d'):format(gang, points)
        end
        table.sort(ordered)
        print(('    influencia em %s: neutro %d/%d%s'):format(
            territory.zone, territory.neutral or 0, territory.total or 0,
            #ordered > 0 and (' | ' .. table.concat(ordered, ', ')) or ''))
    end
end, false)
