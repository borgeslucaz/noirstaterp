-- A placa do bairro, lado servidor: quem decide e quem escreve.
--
-- A decisão em si é pura e mora em `shared/ownership.lua`. Este arquivo faz o resto: compara o
-- que ela devolve com o que está guardado, persiste a troca, espelha nos clientes e avisa o
-- servidor. Nenhum evento de cliente chega aqui.

NoirOwnershipServer = {}

-- O relógio da trava é o do servidor, e é ele que viaja para o cliente junto de cada espelho.
NoirOwnership.now = os.time

local ready = false

local function load()
    local zones = {}

    for _, row in ipairs(MySQL.query.await('SELECT zone, owner, taken_at FROM noir_territory_ownership') or {}) do
        zones[row.zone] = { owner = row.owner, takenAt = row.taken_at }
    end

    NoirOwnership.replaceAll(zones)
end

local function persist(zone, owner, takenAt)
    if owner then
        MySQL.query.await(
            'INSERT INTO noir_territory_ownership (zone, owner, taken_at) VALUES (?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE owner = VALUES(owner), taken_at = VALUES(taken_at)',
            { zone, owner, takenAt })
    else
        MySQL.query.await('DELETE FROM noir_territory_ownership WHERE zone = ?', { zone })
    end
end

local function broadcast(zone)
    local owner, takenAt = NoirOwnership.get(zone)
    TriggerClientEvent('noir_territories:client:ownership', -1, 'patch',
        { zone = zone, owner = owner, takenAt = takenAt, now = os.time() })
end

---Recalcula a placa de um bairro e aplica a troca, se houver.
---
---É chamada depois de toda mudança de influência e pelo relógio que vigia a queda da trava. É
---idempotente de propósito: chamar duas vezes seguidas não troca nada na segunda.
---@return boolean changed
function NoirOwnershipServer.refresh(zone)
    if not ready or type(zone) ~= 'string' then return false end

    -- Bairro fixo tem dono de config e não participa disto. Deixar a placa correr nele criaria
    -- duas respostas para a mesma pergunta, e a do banco perderia em silêncio para a do config.
    if not NoirClaims.isConquerable(zone) then return false end

    local current = NoirOwnership.get(zone)
    local now = os.time()
    local desired = NoirOwnership.desiredOwner(zone, now)
    if desired == current then return false end

    NoirOwnership.set(zone, desired, now)
    persist(zone, desired, now)
    broadcast(zone)

    -- Evento local: quem quiser reagir a uma troca de dono — aviso no celular, log, recompensa —
    -- escuta aqui em vez de ficar perguntando de tempos em tempos de quem é o bairro.
    TriggerEvent('noir_territories:server:ownerChanged', zone, desired, current)

    print(('[noir_territories] %s: %s -> %s'):format(
        zone, current or 'sem dono', desired or 'sem dono'))

    return true
end

---Escreve a placa na mão, sem passar pela decisão. É ferramenta de administração e de teste:
---montar "ballas é dona há três horas e cinquenta" é o único jeito de exercitar a queda da
---trava sem esperar quatro horas de relógio.
---@param takenAt? number quando a tomada conta como tendo acontecido; o padrão é agora
function NoirOwnershipServer.force(zone, owner, takenAt)
    if not ready or type(zone) ~= 'string' then return false end

    local previous = NoirOwnership.get(zone)
    NoirOwnership.set(zone, owner, takenAt or os.time())

    local current, stamp = NoirOwnership.get(zone)
    persist(zone, current, stamp)
    broadcast(zone)

    if current ~= previous then
        TriggerEvent('noir_territories:server:ownerChanged', zone, current, previous)
    end

    return true
end

exports('getTerritoryOwner', function(zone) return NoirOwnership.get(zone) end)
exports('getOwnershipLock', function(zone)
    local owner, takenAt = NoirOwnership.get(zone)
    if not owner then return end
    return { owner = owner, takenAt = takenAt, until_ = NoirOwnership.lockedUntil(zone),
        locked = NoirOwnership.isLocked(zone), challenger = NoirOwnership.challengerOf(zone) }
end)

RegisterNetEvent('noir_territories:server:requestOwnership', function()
    local source = source
    if not ready then return end
    TriggerClientEvent('noir_territories:client:ownership', source, 'set',
        { zones = NoirOwnership.zones, now = os.time() })
end)

---A trava cai sozinha, sem ninguém fazer nada: quem alcançou o limiar e esperou não pode
---depender de uma venda nova acontecer para a placa mudar. Um minuto de resolução numa trava de
---quatro horas é folga de sobra, e o laço só olha bairro que tem dono.
CreateThread(function()
    while true do
        Wait(60000)
        if ready then
            for zone in pairs(NoirOwnership.zones) do NoirOwnershipServer.refresh(zone) end
        end
    end
end)

CreateThread(function()
    -- Atrás da influência: a placa se decide a partir dela, e recalcular antes de ela carregar
    -- tiraria o bairro de todo mundo por um instante — e gravaria isso.
    while not NoirInfluenceServer.ready() do Wait(100) end

    load()
    ready = true

    -- Um passe inicial: o servidor pode ter ficado fora do ar enquanto uma trava caía.
    for zone in pairs(NoirInfluence.zones) do NoirOwnershipServer.refresh(zone) end

    TriggerClientEvent('noir_territories:client:ownership', -1, 'set',
        { zones = NoirOwnership.zones, now = os.time() })
end)
