-- Apresentação local. Nada aqui é autoritativo.
return {
    debug = false,

    blips = {
        enabled = true,
        showInactive = false,
    },

    -- Distância para renderizar/rearmar cenário dos dealers e para o loop leve de manutenção.
    dealerScenario = 'WORLD_HUMAN_DRUG_DEALER',
    dealerMaintenanceIntervalMs = 5000,

    animations = {
        claim = { dict = 'anim@heists@ornate_bank@hack', clip = 'hack_loop', flag = 1 },
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

    target = {
        icons = {
            computer = 'fa-solid fa-computer',
            inspect = 'fa-solid fa-circle-info',
            stock = 'fa-solid fa-box',
            robbery = 'fa-solid fa-mask',
        },
    },

    ui = {
        closeTimeoutMs = 1200,
    },
}
