---Smash & Grab — configuração que o cliente NÃO recebe.
---
---Este arquivo não está em `files{}` do manifest, então ele nunca é enviado ao
---jogador. É onde ficam as coisas que o §19.1 do SCRIPT_GOOD_PRACTICES manda manter
---fora do shared: recompensa real, regra anti-exploit e limite de rate limit.
---
---Se você acrescentar aqui algo de que o client precisa para desenhar, vai faltar
---do outro lado — e é esse o ponto. O client desenha prop, assento e janela; o que
---vem dentro do objeto ele descobre quando o servidor entrega.

return {
    -- Fração dos veículos ELEGÍVEIS que carregam algum objeto.
    --
    -- Não é a fração dos carros que você vê na rua: os filtros de elegibilidade
    -- (parado, desocupado, inteiro, não é de jogador, classe/modelo permitidos)
    -- rodam ANTES desta rolagem. Numa rua com 20 carros parados e vazios ao
    -- alcance do jogador, 0.80 dá uns 16 com objeto.
    --
    -- Mora aqui e não no config compartilhado porque só o servidor decide spawn.
    -- Na versão determinística antiga os dois lados precisavam do número; hoje o
    -- client nunca calcula nada, então mandá-lo era vestígio.
    spawnChance = 0.80,

    -- Multiplicadores por classe de veículo (GTA). Desligado, nada disto é tocado
    -- e o servidor nem consulta a classe.
    classMultipliers = {
        enabled = false,
        -- Multiplica a chance de spawn.
        spawn = {
            [0] = 0.8,  -- compactos
            [1] = 1.0,  -- sedans
            [2] = 1.1,  -- SUVs
            [6] = 1.3,  -- esportivos
            [7] = 1.8,  -- super
        },
        default = 1.0,
    },

    -- Alarme do veículo. Quem rola é o servidor, no momento em que a quebra é
    -- autorizada, e a duração vai junto no evento — o client não lê nada disto.
    alarm = {
        enabled = true,
        -- Chance de o alarme disparar quando o vidro é quebrado.
        chance = 0.65,
        -- Quanto tempo o alarme toca (ms).
        duration = 15000,
    },

    -- Espera mínima entre duas quebras de vidro do mesmo jogador (ms).
    --
    -- Acompanha o `breakDuration`: o pedido só sai DEPOIS da animação, então uma
    -- espera maior que ela recusaria a segunda quebra de quem foi direto para o
    -- carro do lado — e o jogador leria "calma, espere um pouco" sem ter feito
    -- nada de errado. Com a animação curta, é ela que serve de freio.
    -- O piso real é o `rateLimit.default` de config/server.lua (750ms).
    breakCooldown = 750,

    -- Espera mínima entre dois roubos do mesmo jogador (ms).
    playerCooldown = 8000,

    -- Quanto tempo uma reserva sobrevive sem confirmação (ms). Cobre o jogador que
    -- desconecta ou trava no meio da animação. Deixe acima de `duration`.
    reservationTimeout = 15000,

    -- Fração de `duration` que precisa ter passado entre reservar e entregar.
    --
    -- Sem isto, quem chama os eventos à mão reserva e entrega no mesmo instante,
    -- pulando a animação inteira. 0.8 dá folga para lag e para o arredondamento do
    -- progresso, sem deixar o roubo virar um clique.
    minElapsedFactor = 0.8,

    dispatch = {
        chance = 0.25,
        code = '10-35',
        -- Quando o alerta sai:
        --   'reserved' = quando o jogador enfia o braço (o momento suspeito)
        --   'claimed'  = só depois de levar o objeto
        --   'both'     = nos dois, cada um com sua rolagem
        -- Quebrar o vidro NÃO é gatilho: o servidor não tem como verificar o
        -- estado do vidro, e um gatilho que o client dispara sozinho vira spam
        -- de polícia. O alarme, que é local e não custa nada a ninguém, cobre
        -- esse momento.
        trigger = 'reserved',
    },

    -- Testemunhas: estrutura pronta, comportamento desligado. Ligada, o número de
    -- NPCs que viram a cena entra como multiplicador da chance de dispatch. Quem
    -- preencher isso precisa resolver a contagem no servidor — contagem vinda do
    -- client é palpite do client.
    witnesses = {
        enabled = false,
        bonusPerWitness = 0.05,
        maxBonus = 0.30,
    },

    -- Multiplica o dinheiro do saque por classe de veículo. Não entra na semente
    -- determinística, então vive só aqui e não precisa de par no client.
    classLootMultipliers = {
        [0] = 0.8,
        [1] = 1.0,
        [2] = 1.1,
        [6] = 1.3,
        [7] = 1.8,
        default = 1.0,
    },

    -- =======================================================================
    -- Loot tables — LIDAS SÓ NO SERVIDOR
    -- =======================================================================
    --
    -- `rolls` = quantos sorteios. Cada sorteio escolhe UMA entrada, com `chance`
    -- valendo como peso em 100. Se as chances somam menos de 100, a diferença é
    -- a chance de o sorteio sair vazio — é assim que se afina "quase sempre vem
    -- pouca coisa" sem inventar outro campo.
    --
    -- `money = 'cash'|'bank'` entrega dinheiro; `item = '<nome>'` entrega item.
    -- Todos os itens abaixo existem no ox_inventory deste servidor. O sketch
    -- original pedia `cash` e `headphones`: nenhum dos dois existe aqui, então
    -- viraram `money` e eletrônicos reais.

    lootTables = {
        cheap = {
            rolls = { min = 1, max = 2 },
            items = {
                { money = 'cash', min = 5,  max = 35, chance = 30 },
                { item = 'sandwich',   min = 1, max = 2, chance = 22 },
                { item = 'beer',       min = 1, max = 2, chance = 15 },
                { item = 'bandage',    min = 1, max = 2, chance = 13 },
                { item = 'vodka',      min = 1, max = 1, chance = 8 },
                -- soma 88: 12% de cada sorteio sair vazio
            },
        },

        common = {
            rolls = { min = 1, max = 2 },
            items = {
                { money = 'cash', min = 20, max = 110, chance = 28 },
                { item = 'phone',      min = 1, max = 1, chance = 16 },
                { item = 'bandage',    min = 1, max = 2, chance = 12 },
                { item = 'screwdriver',min = 1, max = 1, chance = 10 },
                { item = 'id_card',    min = 1, max = 1, chance = 8 },
                { item = 'radio',      min = 1, max = 1, chance = 7 },
                { item = 'goldchain',  min = 1, max = 1, chance = 5 },
                -- soma 86
            },
        },

        variable = {
            rolls = { min = 1, max = 3 },
            items = {
                { money = 'cash', min = 10, max = 90, chance = 24 },
                { item = 'screwdriver', min = 1, max = 1, chance = 14 },
                { item = 'lockpick',    min = 1, max = 2, chance = 12 },
                { item = 'bandage',     min = 1, max = 3, chance = 12 },
                { item = 'beer',        min = 1, max = 3, chance = 10 },
                { item = 'binoculars',  min = 1, max = 1, chance = 6 },
                { item = 'armour',      min = 1, max = 1, chance = 4 },
                -- soma 82
            },
        },

        electronics = {
            rolls = { min = 1, max = 2 },
            items = {
                { item = 'phone',       min = 1, max = 1, chance = 26 },
                { item = 'tablet',      min = 1, max = 1, chance = 20 },
                { item = 'laptop',      min = 1, max = 1, chance = 14 },
                { money = 'cash', min = 30, max = 150, chance = 14 },
                { item = 'burner_phone',min = 1, max = 1, chance = 10 },
                { item = 'cryptostick', min = 1, max = 1, chance = 4 },
                -- soma 88
            },
        },

        valuable = {
            rolls = { min = 1, max = 2 },
            items = {
                { money = 'cash', min = 80, max = 320, chance = 26 },
                { item = 'rolex',        min = 1, max = 1, chance = 16 },
                { item = 'goldchain',    min = 1, max = 1, chance = 14 },
                { item = 'laptop',       min = 1, max = 1, chance = 12 },
                { item = 'diamond_ring', min = 1, max = 1, chance = 8 },
                { item = 'cryptostick',  min = 1, max = 1, chance = 6 },
                -- soma 82
            },
        },
    },

    -- Chave da activity no noir_illegal_core (só com progression ligada).
    progressionActivity = 'petty_smashgrab',
}
