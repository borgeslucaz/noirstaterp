RegisterNuiCallback('hideFrame', function(_, cb)
    cancelActiveDrugDeal()
    cb(true)
end)

RegisterNUICallback('languageConfirmation', function(_, cb)
    cb(true)
    isUiLanguageLoaded = true
end)

RegisterNUICallback('drugSell', function(data, cb)
    cb(true)
    sellDrugForPedFinalize(data.name, data.price)
end)
