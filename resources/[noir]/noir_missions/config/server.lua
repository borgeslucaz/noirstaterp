-- Só servidor. Não está em files{}, não vai para o jogador.
return {
    adminAce = 'noir.missions',

    -- Registra no console cada decisão da missão (gatilho, chance, passo, reforço,
    -- perseguição). Ligado enquanto o servidor está em teste; desligar em produção.
    logEvents = true,

    storage = {
        -- 'json': um arquivo por missão em missions/. A interface de server/persistence
        -- não muda se trocar por banco.
        driver = 'json',
        directory = 'missions',
    },

    -- Laço por instância: zonas, grupos, veículos, perseguição.
    tickMs = 1000,

    maxInstances = 8,
    offerTimeoutSeconds = 30,

    distances = {
        interactionSlack = 2.5,  -- folga sobre a distância da interação, contra lag
        cargoPickup = 4.0,
        vehicleLoad = 6.0,
        missionArea = 400.0,     -- tiro conta para hostilidade só dentro disto de algum grupo
    },

    rateLimits = {
        interact = 800,
        cargo = 600,
        shot = 1500,
        editor = 250,
        offer = 1000,
    },

    -- Menor duração aceita de uma interação, em fração da configurada. O servidor mede o
    -- tempo entre começar e terminar; menos que isso é recusado (§17.4).
    minInteractionFraction = 0.6,

    chase = {
        retrySeconds = 5,
        retryLimit = 6,
        despawnDistance = 300.0,
    },

    -- Entidades de missão terminada que ainda estão perto de alguém somem depois disto.
    cleanupGraceSeconds = 0,

    sms = {
        -- 'phone': SMS anônimo pelo telefone (bgrz_core). Sem telefone = notificação.
        provider = 'phone',
    },

    rewards = {
        moneyReason = 'noir_missions:reward',
    },
}
