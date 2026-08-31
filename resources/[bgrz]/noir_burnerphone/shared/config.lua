BurnerPhoneConfig = {
    enabled = false,
    itemName = 'burner_phone',

    -- O burner phone usa uma UI própria. O sd-phone continua disponível como
    -- possível ponte futura para chamadas/SIM, mas não é aberto por este item.
    phoneIntegration = {
        enabled = false,
        resource = 'sd-phone',
        customAppId = 'noir-burnerphone',
    },

    activities = {
        drugSales = false,
        deliveries = false,
        contracts = false,
        blackMarket = false,
    },
}
