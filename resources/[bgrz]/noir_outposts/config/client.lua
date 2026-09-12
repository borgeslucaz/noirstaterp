-- Apresentação local. Nada aqui é autoritativo.
return {
    debug = false,

    blips = {
        enabled = true,
        showInactive = false,
    },

    -- Distância para renderizar/rearmar cenário dos dealers e para o loop leve de manutenção.
    dealerScenario = 'WORLD_HUMAN_DRUG_DEALER',
    -- Corredor fora de serviço: abalado da abordagem ou em recuperação de assalto. Fica agachado
    -- com medo, que é o que diz ao jogador, sem texto nenhum, que ali não há o que tirar agora.
    cowerScenario = 'WORLD_HUMAN_COWER',
    dealerMaintenanceIntervalMs = 5000,

    animations = {
        -- Conversa com o operador, não invasão de computador: a tomada passa por ele agora.
        -- Dicionário atestado no scully_emotemenu deste servidor, e é loop.
        claim = { dict = 'misscarsteal4@actor', clip = 'actor_berating_loop', flag = 1 },
        deposit = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
        robbery = { dict = 'oddjobs@shop_robbery@rob_till', clip = 'loop', flag = 1 },
        collect = { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
    },

    holdup = {
        -- Frequência da checagem de mira quando há corredor por perto.
        aimCheckIntervalMs = 250,
        -- Exige arma sacada, não punho.
        requireWeapon = true,
        surrenderAnim = { dict = 'random@mugging3', clip = 'handsup_standing_base' },
        -- Por quanto tempo a reação recebida por evento tem precedência sobre o state bag.
        -- Cobre só o atraso de replicação do bag; passado isso o bag é quem manda.
        reactionGraceMs = 3000,
    },

    progress = {
        depositDurationMs = 2500,
        collectDurationMs = 2500,
    },

    minigames = {
        claim = {
            -- Quantidade de letras e prazo do desafio que antecede a tomada.
            typewriterCount = 5,
            typewriterTimeMs = 5000,
        },
    },

    target = {
        icons = {
            -- O terminal é um NPC, não um objeto: o alvo é a pessoa.
            operator = 'fa-solid fa-user-tie',
            inspect = 'fa-solid fa-circle-info',
            stock = 'fa-solid fa-box',
            robbery = 'fa-solid fa-mask',
        },
    },

    ui = {
        closeTimeoutMs = 1200,
    },
}
