return {
    -- Tabela pública de policiamento: quantos policiais em serviço cada crime exige.
    -- É a fonte única. Cada crime confere no servidor por `exports.noir_scoreboard:CheckPolice`,
    -- e o placar mostra estes mesmos números para quem está numa gang.
    --
    -- `key` é o nome que os crimes usam para perguntar e para marcar "em andamento"
    -- (`SetActivityBusy`). `bankrobbery`, `paleto`, `pacific` e `jewellery` são os nomes
    -- que o qbx_bankrobbery e o qbx_jewelery já mandam; não renomear.
    crimes = {
        { key = 'storerobbery', label = 'Loja de conveniência', minimumPolice = 2 },
        { key = 'houserobbery', label = 'Roubo de casa', minimumPolice = 2 },
        { key = 'outpost', label = 'Tomada de outpost', minimumPolice = 2 },
        { key = 'jewellery', label = 'Joalheria', minimumPolice = 2 },
        { key = 'truckrobbery', label = 'Carro-forte', minimumPolice = 3 },
        { key = 'bankrobbery', label = 'Banco Fleeca', minimumPolice = 3 },
        { key = 'paleto', label = 'Banco de Paleto', minimumPolice = 4 },
        { key = 'pacific', label = 'Pacific Standard', minimumPolice = 5 },
    },

    -- Intervalo mínimo entre duas aberturas do placar pelo mesmo jogador.
    openCooldownMs = 1000,
}
