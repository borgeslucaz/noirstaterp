NoirIllegal.Config = {
    Version = '0.1.0',
    -- Categorias de reputação. Fora `street`, que é a rua em geral, cada uma é um produto do
    -- noir_gangs (`product`): é por ele que o painel da gang sabe qual progresso mostrar. O id
    -- `drug` fica no singular porque já tem linha gravada com ele; o produto é `drugs`.
    Categories = {
        street = { label = 'Rua' },
        drug = { label = 'Drogas', product = 'drugs' },
        weapons = { label = 'Armas', product = 'weapons' },
        items = { label = 'Itens', product = 'items' },
        ammo = { label = 'Munições', product = 'ammo' },
        attachments = { label = 'Acessórios de arma', product = 'attachments' },
    },
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
