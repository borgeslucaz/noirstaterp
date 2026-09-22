-- Cópia local da influência.
--
-- Só recebe. O cliente nunca escreve aqui: quem concede é o servidor, e o que chega é o
-- resultado, não o pedido. Serve para o mapa desenhar a fatia de cada gang e para
-- `getTerritoryAt` responder sem viagem de rede.

RegisterNetEvent('noir_territories:client:influence', function(action, payload)
    if action == 'set' then
        NoirInfluence.replaceAll(payload)
    elseif action == 'patch' and type(payload) == 'table' then
        -- Só o que mudou, bairro a bairro: um ponto de influência não pode custar o registro
        -- inteiro na rede a cada tag pichada no servidor.
        for gang, points in pairs(payload.changes or {}) do
            NoirInfluence.set(payload.zone, gang, points)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    TriggerServerEvent('noir_territories:server:requestInfluence')
end)
