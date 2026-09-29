BurnerPhoneConfig = {
    enabled = true,
    itemName = 'burner_phone',
    allowMovement = true,
    blockWhileDead = true,
    blockWhileSwimming = true,

    -- Optional coexistence bridge only. This item always opens its own NUI.
    phoneIntegration = {
        enabled = false,
        resource = 'sd-phone',
        customAppId = 'noir-burnerphone',
    },
}
