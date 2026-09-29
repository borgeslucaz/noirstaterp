-- Administração de território.
--
-- Todos os comandos agem sobre o bairro em que quem digitou está parado. É de propósito: o que
-- se testa é o bairro onde se está, e um argumento de nome a mais seria um erro de digitação a
-- mais entre a ideia e o resultado.
--
-- Existem porque o sistema é lento por desenho — 510 pontos são 7 tags ou 51 vendas, e a trava
-- de domínio leva quatro horas. Sem isto, verificar uma regra custa uma tarde; com isto, custa
-- dez segundos. Nada aqui é jogo: é bancada de teste, atrás de ACE.
--
-- O que muda o mundo passa pelas MESMAS funções que o jogo usa. `/territoryactivity` chama o
-- `grantInfluence` de verdade, com bônus de azarão e trava; se ele mentisse, testar com ele não
-- provaria nada sobre o jogo.

local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, Config.AdminAce)
end

local function say(source, ...)
    TriggerClientEvent('noir_territories:client:adminSay', source, { ... })
end

---O bairro em que a pessoa está.
---@return string? zone
local function zoneOf(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local ok, names = pcall(function()
        return exports.zonemanager:GetZonesAt(coords.x, coords.y, coords.z)
    end)
    if not ok or type(names) ~= 'table' then return end
    return names[1]
end

---Guarda comum de todos os comandos: permissão, bairro, e o aviso de qual é o bairro.
---@return string? zone
local function ready(source)
    if not isAdmin(source) then
        say(source, 'Acesso negado.')
        return
    end

    local zone = zoneOf(source)
    if not zone then
        say(source, 'Você não está dentro de nenhum bairro mapeado.')
        return
    end

    return zone
end

local function gangArg(args, index)
    local gang = args[index]
    if type(gang) ~= 'string' or gang == '' then return end
    return gang:lower()
end

-- ---------------------------------------------------------------------------
-- Leitura
-- ---------------------------------------------------------------------------

RegisterCommand('territoryinfo', function(source)
    local zone = ready(source)
    if not zone then return end

    local status = NoirClaims.getZoneStatus(zone)
    local lines = { ('=== %s ==='):format(zone) }

    if not status.conquerable then
        lines[#lines + 1] = ('FIXO no config%s'):format(
            status.gang and (' — de ' .. status.gang) or ' — de ninguém')
    end

    lines[#lines + 1] = ('dono: %s | limiar: %d de %d'):format(
        status.gang or 'ninguém', status.required, status.total)

    local owner, takenAt = NoirOwnership.get(zone)
    if owner then
        local left = (NoirOwnership.lockedUntil(zone) or 0) - os.time()
        lines[#lines + 1] = ('tomado em %s | trava: %s'):format(
            os.date('%d/%m %H:%M:%S', takenAt),
            left > 0 and ('%d min %d s restantes'):format(math.floor(left / 60), left % 60)
                or 'caída')
    end

    if status.challenger then
        lines[#lines + 1] = ('desafiante pronto: %s'):format(status.challenger)
    end

    lines[#lines + 1] = ('neutro: %d'):format(status.neutral)

    local gangs = {}
    for gang, points in pairs(status.influence) do
        gangs[#gangs + 1] = ('  %-14s %4d  (%d%%)'):format(
            gang, points, math.floor(points * 100 / status.total))
    end
    table.sort(gangs)
    for i = 1, #gangs do lines[#lines + 1] = gangs[i] end
    if #gangs == 0 then lines[#lines + 1] = '  (nenhuma gang tem influência aqui)' end

    local idle = NoirDecay and NoirDecay.idleFor(zone)
    if idle then
        local falta = Config.Decay.AfterSeconds - idle
        lines[#lines + 1] = ('parado ha %d min | esfriamento: %s'):format(
            math.floor(idle / 60),
            not Config.Decay.Enable and 'desligado'
                or falta > 0 and ('comeca em %d min'):format(math.ceil(falta / 60))
                or ('a cada %d min, -%d%% de cada gang'):format(
                    math.floor(Config.Decay.EverySeconds / 60), Config.Decay.Percent))
    end

    lines[#lines + 1] = ('tags de graffiti: %d'):format(status.tags)
    say(source, table.unpack(lines))
end, false)

-- ---------------------------------------------------------------------------
-- Escrita
-- ---------------------------------------------------------------------------

---Escreve a fatia sem tirar de ninguém. É o comando de montar cenário: `/territoryset ballas
---800` põe o bairro no estado que se quer testar, sem simular as vendas que levariam até ele.
RegisterCommand('territoryset', function(source, args)
    local zone = ready(source)
    if not zone then return end

    local gang, points = gangArg(args, 1), tonumber(args[2])
    if not gang or not points then
        return say(source, 'uso: /territoryset <gang> <pontos>')
    end

    NoirInfluenceServer.set(zone, gang, points)
    say(source, ('%s = %d em %s'):format(gang, NoirInfluence.get(zone, gang), zone))
end, false)

---Transferência de verdade, pelo caminho do jogo: tira do neutro e das outras gangs na
---proporção do que cada uma tem, e respeita a trava.
RegisterCommand('territorygive', function(source, args)
    local zone = ready(source)
    if not zone then return end

    local gang, points = gangArg(args, 1), tonumber(args[2])
    if not gang or not points then
        return say(source, 'uso: /territorygive <gang> <pontos>  (negativo devolve ao neutro)')
    end

    local ok, applied, refusal = NoirInfluenceServer.add(zone, gang, points, 'admin')
    say(source, ok
        and ('%s %+d em %s — agora tem %d'):format(gang, applied, zone, NoirInfluence.get(zone, gang))
        or ('recusado: %s'):format(refusal or 'nada se moveu'))
end, false)

---Simula um fato do mundo. É o comando que prova o jogo: passa pela taxa do config, pelo bônus
---de azarão e pela trava, exatamente como a venda de droga e a tag passam.
RegisterCommand('territoryactivity', function(source, args)
    local zone = ready(source)
    if not zone then return end

    local gang, reason = gangArg(args, 1), args[2]
    if not gang or not reason or not Config.Influence.Rates[reason] then
        local known = {}
        for key in pairs(Config.Influence.Rates) do known[#known + 1] = key end
        table.sort(known)
        return say(source, ('uso: /territoryactivity <gang> <%s>'):format(table.concat(known, '|')))
    end

    local base = Config.Influence.Rates[reason]
    local worth = NoirInfluence.effective(zone, gang, base)
    local ok, applied, refusal = NoirInfluenceServer.grant(zone, gang, reason)

    say(source, ('%s fez %s em %s: base %d, vale %d%s'):format(
        gang, reason, zone, base, worth,
        worth > base and (' (bônus de azarão ×%.2f)'):format(worth / base) or ''))
    say(source, ok
        and ('  entrou %+d — %s agora tem %d'):format(applied, gang, NoirInfluence.get(zone, gang))
        or ('  recusado: %s'):format(refusal or 'nada se moveu'))
end, false)

---Carimba a placa na mão. `none` tira o dono.
RegisterCommand('territoryowner', function(source, args)
    local zone = ready(source)
    if not zone then return end

    local gang = gangArg(args, 1)
    if not gang then return say(source, 'uso: /territoryowner <gang|none>') end

    NoirOwnershipServer.force(zone, gang ~= 'none' and gang or nil)
    say(source, ('%s: dono agora é %s (trava reiniciada)'):format(
        zone, NoirOwnership.get(zone) or 'ninguém'))
end, false)

---Reescreve a HORA da tomada para que a trava tenha N minutos pela frente. `0` faz ela cair
---agora — é o comando que transforma um teste de quatro horas num de dez segundos.
RegisterCommand('territorylock', function(source, args)
    local zone = ready(source)
    if not zone then return end

    local minutes = tonumber(args[1])
    if not minutes then return say(source, 'uso: /territorylock <minutos>  (0 = derruba agora)') end

    local owner = NoirOwnership.get(zone)
    if not owner then return say(source, ('%s não tem dono: não há trava.'):format(zone)) end

    -- A trava é `takenAt + OwnershipLockSeconds`. Para ela terminar daqui a N minutos, a tomada
    -- precisa ter acontecido nesse tanto antes do fim.
    local takenAt = os.time() + (minutes * 60) - Config.OwnershipLockSeconds
    NoirOwnershipServer.force(zone, owner, takenAt)

    say(source, minutes > 0
        and ('%s: trava de %s cai em %d min'):format(zone, owner, minutes)
        or ('%s: trava derrubada — a placa é reavaliada em até 60 s'):format(zone))

    -- Sem esperar o relógio de 60 s: derrubar a trava e ver o efeito na hora é metade da graça.
    NoirOwnershipServer.refresh(zone)
end, false)

---Devolve o bairro ao 1000 neutro: influência, placa, concessões e dívidas.
RegisterCommand('territoryreset', function(source)
    local zone = ready(source)
    if not zone then return end

    local cleared = NoirInfluenceServer.clearZone(zone)
    NoirOwnershipServer.force(zone, nil)
    say(source, ('%s zerado: %d gang(s) apagada(s), sem dono, 1000 de neutro.'):format(zone, cleared))
end, false)

---Força um passo de esfriamento agora, sem esperar o bairro ficar parado o tempo todo.
RegisterCommand('territorydecay', function(source)
    local zone = ready(source)
    if not zone then return end

    local before = {}
    for gang, points in pairs(NoirInfluence.of(zone)) do before[gang] = points end

    if not NoirDecay.force(zone) then
        return say(source, ('%s nao esfriou: bairro fixo, travado, ou sem influencia nenhuma.')
            :format(zone))
    end

    local lines = { ('%s esfriou um passo (-%d%% de cada gang):'):format(zone, Config.Decay.Percent) }
    local rows = {}
    for gang, antes in pairs(before) do
        rows[#rows + 1] = ('  %-14s %4d -> %4d'):format(gang, antes, NoirInfluence.get(zone, gang))
    end
    table.sort(rows)
    for i = 1, #rows do lines[#lines + 1] = rows[i] end

    local _, neutro = NoirInfluence.sumOf(zone)
    lines[#lines + 1] = ('  neutro agora %d'):format(neutro)
    say(source, table.unpack(lines))
end, false)
