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

---No mundo, não no mapa: o círculo no chão e um pino no centro exato da tag. Só as áreas por
---perto, e só enquanto o debug está ligado — a thread nasce junto com ele e morre junto.
local function startDrawing()
    if drawing then return end
    drawing = true

    CreateThread(function()
        while Config.DebugTerritories do
            local coords = GetEntityCoords(cache.ped)

            for _, claim in pairs(NoirClaims.list) do
                local dx, dy = coords.x - claim.coords.x, coords.y - claim.coords.y
                local reach = claim.radius + 200.0
                if (dx * dx + dy * dy) <= (reach * reach) then
                    local color = gangColor(claim.gang)

                    DrawMarker(1, claim.coords.x, claim.coords.y, claim.coords.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        claim.radius * 2.0, claim.radius * 2.0, 0.6,
                        color.r, color.g, color.b, 60, false, false, 2, false, nil, nil, false)

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
    print(('[noir_territories] debug no mundo %s | aqui: %s%s'):format(
        Config.DebugTerritories and 'LIGADO' or 'DESLIGADO',
        territory.state,
        territory.gang and (' (%s)'):format(territory.gang)
            or territory.gangs and (' (%s)'):format(table.concat(territory.gangs, ', ')) or ''))
end, false)
