-- Esfriamento de bairro parado.
--
-- Bairro em que ninguém trabalha devolve influência ao neutro, aos poucos, até voltar a ser de
-- ninguém. É o vencimento do domínio: sem ele, quem tomou uma vez é dono para sempre, porque
-- perder território exige alguém disposto a tomá-lo.
--
-- Transferência, nunca apagamento: cada ponto que sai de uma gang entra no neutro, e o bairro
-- continua somando 1000 em qualquer instante.

NoirDecay = {}

local ready = false
local lastActivity = {}    -- zone -> segundos

---Quantos passos um bairro pode recuperar de uma vez. O servidor pode ter ficado dias fora do
---ar, e sem teto o primeiro laço depois de voltar descontaria a semana inteira de uma vez, em
---silêncio. Com teto, ele recupera aos poucos e a queda aparece.
local MAX_CATCH_UP = 6

local function load()
    for _, row in ipairs(MySQL.query.await('SELECT zone, last_activity FROM noir_territory_activity') or {}) do
        lastActivity[row.zone] = row.last_activity
    end
end

local function persist(zone)
    MySQL.query.await(
        'INSERT INTO noir_territory_activity (zone, last_activity) VALUES (?, ?) '
        .. 'ON DUPLICATE KEY UPDATE last_activity = VALUES(last_activity)',
        { zone, lastActivity[zone] })
end

---Alguma coisa aconteceu neste bairro: o relógio do abandono volta a zero.
---
---Chamado pelo `addInfluence` em toda mudança que não seja o próprio esfriamento. Vale para
---qualquer gang: bairro sob disputa não está abandonado, mesmo que o dono nunca apareça.
function NoirDecay.touch(zone)
    if not ready or type(zone) ~= 'string' then return end
    lastActivity[zone] = os.time()
    persist(zone)
end

---Um passo de esfriamento. Passa pelo `addInfluence` como qualquer outra mudança, para
---persistir, espelhar nos clientes e reavaliar a placa pelo mesmo caminho de sempre — um dono
---que esfria até zero perde o bairro ali, sem código próprio para isso.
---@return boolean moveu alguma coisa
local function step(zone)
    local losses = NoirInfluence.decayStep(zone, Config.Decay.Percent)
    local moved = false

    for gang, loss in pairs(losses) do
        local ok = NoirInfluenceServer.add(zone, gang, -loss, 'decay')
        moved = moved or ok
    end

    return moved
end

---Bairros que podem esfriar agora.
---
---Fica de fora o que não está em jogo (bairro fixo), o que está congelado (trava de domínio
---correndo) e o que não tem influência nenhuma — esfriar terra de ninguém não é nada.
local function canDecay(zone)
    if not NoirClaims.isConquerable(zone) then return false end
    if NoirOwnership.isLocked(zone) then return false end
    return next(NoirInfluence.of(zone)) ~= nil
end

---Um passe por todos os bairros com relógio.
---
---O passo consome tempo ocioso em vez de usar um segundo carimbo: ao esfriar, o relógio do
---bairro avança `EverySeconds`. Assim o próximo passo acontece exatamente esse tanto depois, e o
---estado inteiro do esfriamento cabe num número por bairro.
local function sweep()
    if not Config.Decay.Enable then return end

    local now = os.time()

    for zone, since in pairs(lastActivity) do
        if canDecay(zone) then
            local steps = 0

            while (now - since) >= Config.Decay.AfterSeconds and steps < MAX_CATCH_UP do
                if not step(zone) then break end
                since = since + Config.Decay.EverySeconds
                steps = steps + 1
            end

            if steps > 0 then
                lastActivity[zone] = since
                persist(zone)

                if Config.DebugTerritories then
                    print(('[noir_territories] %s esfriou %d passo(s)'):format(zone, steps))
                end
            end
        end
    end
end

---Há quanto tempo nada acontece num bairro, em segundos. `nil` quando nunca houve nada.
function NoirDecay.idleFor(zone)
    local since = lastActivity[zone]
    if not since then return end
    return os.time() - since
end

---Força um passo agora, ignorando o relógio. Só a bancada de teste usa: esperar uma hora de
---abandono para conferir a regra é o mesmo problema da trava de quatro horas.
function NoirDecay.force(zone)
    if not ready or not canDecay(zone) then return false end
    return step(zone)
end

CreateThread(function()
    while not NoirInfluenceServer.ready() do Wait(100) end

    load()

    -- Bairro que já tem influência e nunca foi carimbado — o que existia antes desta tabela —
    -- começa a contar a partir de agora, e não do epoch: senão a primeira varredura descontaria
    -- décadas de abandono de uma vez.
    for zone in pairs(NoirInfluence.zones) do
        if lastActivity[zone] == nil then
            lastActivity[zone] = os.time()
            persist(zone)
        end
    end

    ready = true

    while true do
        Wait(60000)
        sweep()
    end
end)
