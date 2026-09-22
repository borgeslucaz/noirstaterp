-- Cópia local da placa de domínio.
--
-- Só recebe. Quem decide de quem é o bairro é o servidor; aqui a placa serve para o mapa
-- desenhar o dono, o desafiante e a trava sem viagem de rede.

-- A hora do servidor, e o `GetGameTimer()` do instante em que ela chegou.
--
-- O cliente não tem a biblioteca `os`, e o relógio da máquina de quem joga não serviria nem se
-- tivesse: ele pode estar horas fora, e "faltam 2h para a trava cair" é a informação que decide
-- se a gang se organiza agora ou amanhã. Então a hora vem do servidor, junto de cada espelho, e
-- daí para a frente quem conta é o relógio do jogo — que anda no mesmo passo nos dois lados.
local syncedNow, syncedAt = 0, 0

local function sync(now)
    now = tonumber(now)
    if not now then return end
    syncedNow, syncedAt = now, GetGameTimer()
end

NoirOwnership.now = function()
    if syncedNow == 0 then return 0 end
    return syncedNow + math.floor((GetGameTimer() - syncedAt) / 1000)
end

RegisterNetEvent('noir_territories:client:ownership', function(action, payload)
    if type(payload) ~= 'table' then return end
    sync(payload.now)

    if action == 'set' then
        NoirOwnership.replaceAll(payload.zones)
    elseif action == 'patch' then
        NoirOwnership.set(payload.zone, payload.owner, payload.takenAt)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= cache.resource then return end
    TriggerServerEvent('noir_territories:server:requestOwnership')
end)
