BGRZConfig = {
    Version = '0.5.0',
    Debug = false,
    Providers = {
        inventory = 'ox_inventory',
        target = 'ox_target',
        phone = 'sd-phone',
        dispatch = 'sd-phone',
        dispatchFallback = 'qbx_police',
        banking = 'Renewed-Banking',
        gangs = 'noir_gangs',
    },
    Limits = {
        maxItemAmount = 100000,
    },
}
