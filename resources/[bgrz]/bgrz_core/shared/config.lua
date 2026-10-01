BGRZConfig = {
    Version = '0.5.0',
    Debug = false,
    Providers = {
        inventory = 'ox_inventory',
        target = 'ox_target',
        phone = 'sky_phone',
        -- MDT que recebe o chamado (export mdtCreateCall). O aviso com blip para quem está na rua
        -- sai sempre pelo dispatchFallback, com ou sem MDT.
        dispatch = 'ps-mdt',
        dispatchFallback = 'noir_police',
        banking = 'Renewed-Banking',
        gangs = 'noir_gangs',
        vehiclekeys = 'mri_Qcarkeys',
    },
    Limits = {
        maxItemAmount = 100000,
    },
}
