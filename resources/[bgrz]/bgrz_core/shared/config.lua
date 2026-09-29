BGRZConfig = {
    Version = '0.5.0',
    Debug = false,
    Providers = {
        inventory = 'ox_inventory',
        target = 'ox_target',
        phone = 'sky_phone',
        -- Sem MDT com chamado na base: o dispatch vai direto para o dispatchFallback.
        dispatchFallback = 'qbx_police',
        banking = 'Renewed-Banking',
        gangs = 'noir_gangs',
        vehiclekeys = 'mri_Qcarkeys',
    },
    Limits = {
        maxItemAmount = 100000,
    },
}
