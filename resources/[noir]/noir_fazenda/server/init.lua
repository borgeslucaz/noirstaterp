NoirFazenda = NoirFazenda or {}
NoirFazenda.Ready = false

local requiredTables = {
    'noir_fazenda_schema_migrations',
    'noir_fazenda_ledger',
    'noir_fazenda_assessments',
    'noir_fazenda_payments',
}

local function checkSchema()
    for i = 1, #requiredTables do
        local exists = MySQL.scalar.await([[
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = ? LIMIT 1
        ]], { requiredTables[i] })
        if not exists then
            error(('Tabela ausente: %s. Rode migrations/001_initial.sql.'):format(
                requiredTables[i]))
        end
    end
    local applied = MySQL.scalar.await(
        'SELECT 1 FROM noir_fazenda_schema_migrations WHERE version = ? LIMIT 1',
        { '001_initial' })
    if not applied then error('Migration 001_initial não está registrada.') end
end

-- A config é lida uma vez no start e precisa fazer sentido, porque um erro aqui
-- só apareceria semanas depois, na forma de imposto errado cobrado de alguém.
local function validateConfig()
    local tax = NoirFazenda.Config.Tax
    if type(tax.brackets) ~= 'table' or #tax.brackets == 0 then
        error('Tax.brackets vazio: sem faixas não há imposto a calcular.')
    end

    local previousCap = 0
    for i = 1, #tax.brackets do
        local bracket = tax.brackets[i]
        local rate = tonumber(bracket.rate)
        if not rate or rate < 0 or rate > 1 then
            error(('Tax.brackets[%d].rate precisa estar entre 0 e 1.'):format(i))
        end

        local cap = bracket.upTo
        if cap == false or cap == nil then
            if i ~= #tax.brackets then
                error(('Tax.brackets[%d] não tem teto mas não é a última faixa.'):format(i))
            end
        else
            cap = tonumber(cap)
            if not cap or cap <= previousCap then
                error(('Tax.brackets[%d].upTo precisa ser maior que a faixa anterior.'):format(i))
            end
            previousCap = cap
        end
    end

    local mode = NoirFazenda.Config.Period.mode
    if mode ~= 'weekly' and mode ~= 'daily' then
        error(("Period.mode precisa ser 'weekly' ou 'daily'."))
    end
end

MySQL.ready(function()
    local ok, startupError = pcall(function()
        validateConfig()
        NoirFazenda.Migrations.run()
        checkSchema()
    end)
    if not ok then
        NoirFazenda.Logger.error('startup_failed', { error = tostring(startupError) })
        StopResource(GetCurrentResourceName())
        return
    end

    NoirFazenda.Ready = true
    -- A conta da Receita NÃO é criada aqui. Neste ponto o banco publicou o start
    -- mas ainda não carregou as contas, e criar nessa janela dá Duplicate entry.
    -- Quem cria é o handler de `bgrz_core:bankingReady`.
    NoirFazenda.Services.Assessment.refreshOverdue()

    local retention = NoirFazenda.Config.Ledger.retentionDays
    if retention and retention > 0 then
        local pruned = NoirFazenda.Storage.pruneLedger(retention)
        if pruned > 0 then
            NoirFazenda.Logger.info('ledger_pruned', { removed = pruned, days = retention })
        end
    end

    -- O cron só é registrado quando o fechamento automático está ligado. Registrar
    -- um job que não deve rodar é como se cria surpresa às 4 da manhã.
    if NoirFazenda.Config.Assessment.autoClose then
        lib.cron.new(NoirFazenda.Config.Assessment.cron, function()
            NoirFazenda.Services.Assessment.closePeriod()
            NoirFazenda.Services.Assessment.refreshOverdue()
        end)
        NoirFazenda.Logger.info('cron_registered', {
            expression = NoirFazenda.Config.Assessment.cron,
        })
    end

    NoirFazenda.Logger.info('ready', {
        version = NoirFazenda.Config.Version,
        period = NoirFazenda.Rules.periodKey(os.time(), NoirFazenda.Config),
        collectionEnabled = NoirFazenda.Config.Tax.collectionEnabled == true,
        autoClose = NoirFazenda.Config.Assessment.autoClose == true,
    })
end)
