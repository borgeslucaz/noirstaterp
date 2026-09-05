-- ak4y-taxi · configuração somente do servidor
ServerConfig = {
    -- Webhook opcional para registrar tentativas suspeitas (vazio = desligado)
    Webhook = '',

    -- Limites de chamadas por jogador (ms)
    RateLimits = {
        setAvailable = 1000,
        accept = 500,
        requestPassenger = 1000,
        boarded = 1000,
        complete = 1500,
        climate = 900,
        depot = 2000,
    },

    -- Tolerâncias das validações de posição
    PickupSpawnTolerance = 60.0,    -- além de Passenger.SpawnDistance
    DropoffTolerance = 10.0,        -- além de Passenger.DropoffDistance
    ClimateMaxDeltaPerSecond = 0.6, -- variação máxima plausível de temperatura enviada pelo client
    ClimateStaleMs = 15000,         -- sem sincronização há mais que isto → conforto não muda
}
