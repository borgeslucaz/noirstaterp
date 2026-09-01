BurnerPhoneConfig = {
    enabled = true,
    itemName = 'burner_phone',
    allowMovement = true,
    blockWhileDead = true,
    blockWhileSwimming = true,

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
        contracts = true,
        blackMarket = false,
    },

    houseRobberyContact = {
        number = '404-0199',
        name = 'Ninguém',
        requestText = 'Preciso de trabalho.',
    },
}
