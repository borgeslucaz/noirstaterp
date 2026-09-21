NoirFazenda = NoirFazenda or {}

NoirFazenda.Config = {
    Version = '0.1.0',
    Debug = false,

    Ledger = {
        -- Registrar também o que não é tributável (saídas, depósito próprio).
        -- Custa linhas, mas é o que permite conferir uma apuração contestada:
        -- sem as saídas, o extrato da Receita não bate com o extrato do banco e
        -- qualquer discussão vira "acredite em mim".
        recordNonTaxable = true,

        -- Contas de organização entram no ledger, mas hoje nascem sempre com
        -- taxable = 0. É o gancho para imposto sobre empresa mais tarde, sem
        -- precisar de migration nova nem de retroatividade.
        recordOrganizations = true,

        -- Movimento abaixo disto é ignorado. Evita que troco de $1 vire linha.
        minimumAmount = 1,

        -- Teto de sanidade. Nenhum movimento legítimo chega perto disso; o que
        -- chega é bug de quem chamou `RecordIncome` ou exploit. Sem teto, um
        -- número absurdo entraria na base e viraria imposto absurdo -- e a
        -- apuração, uma vez fechada, não é reinterpretada.
        maximumAmount = 100000000,

        -- Purga de lançamentos antigos. 0 desliga.
        retentionDays = 120,
    },

    Period = {
        -- 'weekly' fecha toda segunda; 'daily' fecha todo dia.
        mode = 'weekly',
        -- O servidor roda em UTC. Isto é o fuso em que o jogador pensa, e é o que
        -- define onde a semana começa. -3 = horário de Brasília.
        timezoneOffsetHours = -3,
    },

    Tax = {
        -- =====================================================================
        -- A COBRANÇA NASCE DESLIGADA.
        --
        -- Com `collectionEnabled = false` o resource faz tudo menos tirar dinheiro
        -- de alguém: mede a movimentação, fecha o período e calcula o imposto
        -- devido, gravando a apuração com status 'simulated'. É assim que dá para
        -- ver o número real de algumas semanas de jogo ANTES de escolher alíquota.
        --
        -- Ligar isso é uma decisão econômica, não técnica. Ver README.
        -- =====================================================================
        collectionEnabled = false,

        -- Fechar período e calcular (sem cobrar) pode ficar ligado desde já.
        assessmentEnabled = true,

        -- Faixas progressivas sobre a base do período, aplicadas na margem, como
        -- IR de verdade: quem tem base de 30k paga 0% sobre os primeiros 25k e 5%
        -- só sobre os 5k que passaram.
        --
        -- A primeira faixa com rate 0 É a faixa de isenção. Não existe outro
        -- parâmetro de isenção de propósito: dois jeitos de dizer a mesma coisa
        -- é como se cria divergência entre config e comportamento.
        --
        -- `upTo = false` marca a última faixa (sem teto).
        brackets = {
            { upTo = 25000,  rate = 0.00 },
            { upTo = 100000, rate = 0.05 },
            { upTo = false,  rate = 0.12 },
        },

        -- Imposto apurado abaixo disto é dispensado. Cobrar $7 de alguém gera
        -- mais atrito de RP do que receita.
        minAssessment = 50,

        -- Prazo para pagar depois do fechamento.
        dueAfterHours = 72,
    },

    Treasury = {
        -- Conta de organização que recebe a arrecadação. É criada pelo próprio
        -- resource via bridge, então não precisa existir job de governo no
        -- qbx_core nem editar core nenhum.
        accountId = 'fazenda',
        accountLabel = 'Receita de San Andreas',
        creditCollections = true,
    },

    Assessment = {
        -- Fechamento automático. Desligado enquanto o sistema está em observação:
        -- com `false`, quem fecha é o comando de admin, e dá para olhar o
        -- resultado antes de deixar rodar sozinho.
        autoClose = false,
        -- Segunda-feira, 04:05 UTC. Só é lido quando autoClose é true.
        cron = '5 4 * * 1',
    },

    Commands = {
        enabled = true,
        ace = 'noir.fazenda.admin',
    },
}
