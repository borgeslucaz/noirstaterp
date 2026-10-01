NoirIllegal.Config = {
    Version = '0.1.0',
    -- Categorias de reputação. Fora `street`, que é a rua em geral, cada uma é um produto do
    -- noir_gangs (`product`): é por ele que o painel da gang sabe qual progresso mostrar. O id
    -- `drug` fica no singular porque já tem linha gravada com ele; o produto é `drugs`.
    -- `gang` é a reputação da organização: uma só, qualquer que seja o produto. Só ela recebe
    -- valor de gang (`organization` nas activities); as outras categorias são pessoais.
    Categories = {
        gang = { label = 'Reputação', organization = true },
        street = { label = 'Rua' },
        drug = { label = 'Drogas', product = 'drugs' },
        weapons = { label = 'Armas', product = 'weapons' },
        items = { label = 'Itens', product = 'items' },
        ammo = { label = 'Munições', product = 'ammo' },
        attachments = { label = 'Acessórios de arma', product = 'attachments' },
    },
    -- Teto do que a gang ganha (soma dos ganhos positivos em `gang`) numa janela móvel de 24h,
    -- somando todas as fontes. Cada activity de gang pode ter o seu (`dailyCap`) por baixo deste.
    Organization = {
        dailyCap = 50,
        windowSeconds = 86400,
    },
    -- Peso da venda de rua na reputação PESSOAL: grau (os mesmos multiplicadores de preço do
    -- noir_drugselling) × peso da droga. Vender melhor sobe mais rápido do que vender mais.
    SaleWeight = {
        grades = { C = 0.8, B = 1.0, A = 1.25, S = 1.5 },
        defaultGrade = 'B',
        -- Pelo nome do item: o primeiro padrão que casa vale.
        drugs = {
            { pattern = '_brick$', weight = 4.0 },
            { pattern = '^cokebaggy$', weight = 2.0 },
            { pattern = '^meth$', weight = 1.5 },
            { pattern = '_baggy$', weight = 1.0 },
        },
        defaultDrug = 1.0,
    },
    -- Tomar outpost não rende para a gang se o mesmo posto foi dela nesta janela.
    OutpostRetakeSeconds = 7 * 86400,
    -- Bairro segurado só paga se a gang agiu nele (venda, pichação) nesta janela.
    TerritoryActivitySeconds = 86400,
    Heat = {
        max = 100.0,
        decayPerSecond = 0.0025,
        persistEpsilon = 0.01,
    },
    Cache = {
        ttlSeconds = 60,
        sourceTtlSeconds = 15,
        organizationTtlSeconds = 60,
    },
    Limits = {
        maxActivityDelta = 1000.0,
        maxAdminDelta = 100000.0,
        maxMetadataKeys = 16,
        maxMetadataStringLength = 256,
        maxOccurredAtPastSeconds = 86400,
        maxOccurredAtFutureSeconds = 60,
    },
    AuditRejectedActivities = true,
    -- Bairro dominado paga uma vez por período, para a gang que estiver com a placa quando o
    -- laço passar. O período é o dia do relógio do servidor, não "24h desde a tomada": o id da
    -- transação sai de bairro + gang + período, então restart não paga duas vezes.
    Territories = {
        heldPeriodSeconds = 86400,
        checkSeconds = 600,
    },
    Commands = {
        enabled = true,
        developmentActivityCommand = true,
    },
    Debug = false,
}
