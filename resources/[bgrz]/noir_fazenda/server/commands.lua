NoirFazenda = NoirFazenda or {}

local Constants = NoirFazenda.Constants
local Rules = NoirFazenda.Rules
local Services = NoirFazenda.Services

local function respond(source, payload)
    local message = type(payload) == 'string' and payload or json.encode(payload)
    if source == 0 then
        print(('[noir_fazenda] %s'):format(message))
    else
        TriggerClientEvent('chat:addMessage', source, {
            color = { 140, 200, 160 },
            args = { 'fazenda', message },
        })
    end
end

-- Permissão por ACE, não por job nem por hierarquia implícita. Novo comando
-- administrativo usa ACE/ox_lib; os exports de permissão antigos do Qbox estão
-- depreciados (§4.6).
local function authorized(source)
    return source == 0
        or IsPlayerAceAllowed(source, NoirFazenda.Config.Commands.ace)
end

local function money(value)
    return ('$%s'):format(tostring(math.floor(tonumber(value) or 0)))
end

local function usage()
    return 'uso: /fazenda status | extrato <citizenid> | apurar [periodo] | devendo <citizenid> | periodo'
end

RegisterCommand('fazenda', function(source, args)
    if not NoirFazenda.Config.Commands.enabled then return end
    if not authorized(source) then
        return respond(source, NoirFazenda.error(Constants.errors.forbidden))
    end
    if not NoirFazenda.Ready then
        return respond(source, NoirFazenda.error(Constants.errors.notReady))
    end

    local action = args[1]

    if action == 'status' then
        local stats = NoirFazenda.Storage.stats()
        stats.periodoCorrente = Rules.periodKey(os.time(), NoirFazenda.Config)
        stats.cobrancaLigada = NoirFazenda.Config.Tax.collectionEnabled == true
        stats.fechamentoAutomatico = NoirFazenda.Config.Assessment.autoClose == true
        stats.contaReceita = NoirFazenda.Config.Treasury.accountId
        stats.saldoReceita = Services.Treasury.balance()
        stats.bancoDisponivel = NoirFazenda.Bridges.Banking.isAvailable()
        stats.bancoPronto = NoirFazenda.Bridges.Banking.isReady()
        stats.contaCriada = NoirFazenda.Services.Treasury.isEnsured()
        return respond(source, stats)
    end

    if action == 'periodo' then
        local currentKey = Rules.periodKey(os.time(), NoirFazenda.Config)
        local startTimestamp, endTimestamp = Rules.periodBounds(currentKey, NoirFazenda.Config)
        return respond(source, ('período %s | de %s até %s (UTC) | anterior: %s'):format(
            currentKey,
            os.date('!%d/%m %H:%M', startTimestamp),
            os.date('!%d/%m %H:%M', endTimestamp),
            Rules.previousPeriodKey(os.time(), NoirFazenda.Config)))
    end

    if action == 'extrato' then
        local citizenId = args[2]
        if not citizenId then return respond(source, usage()) end
        local totals = Services.Ledger.totals(Constants.subject.player, citizenId, args[3])
        local simulated = Rules.computeTax(totals.taxableBase, NoirFazenda.Config)
        return respond(source, ('%s | %s | tributável %s | isento %s | saídas %s | %d lançamentos | imposto se fechasse agora: %s'):format(
            citizenId, totals.periodKey,
            money(totals.taxableBase), money(totals.exemptBase),
            money(totals.outflow), totals.entryCount, money(simulated)))
    end

    if action == 'devendo' then
        local citizenId = args[2]
        if not citizenId then return respond(source, usage()) end
        return respond(source, Services.Assessment.outstanding(citizenId))
    end

    if action == 'apurar' then
        return respond(source, Services.Assessment.closePeriod(args[2]))
    end

    return respond(source, usage())
end, false)
