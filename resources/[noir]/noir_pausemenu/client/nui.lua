RegisterNUICallback('close', function(_, cb)
    PauseMenu.RequestClose()
    cb('ok')
end)

RegisterNUICallback('closeComplete', function(_, cb)
    PauseMenu.OnCloseAnimationComplete()
    cb('ok')
end)

RegisterNUICallback('openSettings', function(_, cb)
    if PauseMenu.open and not PauseMenu.closing and not Photomode.active then
        PauseMenu.OpenFrontendMenu(GetHashKey('FE_MENU_VERSION_LANDING_MENU'))
    end
    cb('ok')
end)

RegisterNUICallback('openMap', function(_, cb)
    if PauseMenu.open and not PauseMenu.closing and not Photomode.active then
        PauseMenu.OpenFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'))
    end
    cb('ok')
end)

RegisterNUICallback('enterPhotomode', function(_, cb)
    PauseMenu.PreparePhotomode()
    cb('ok')
end)

RegisterNUICallback('exitPhotomode', function(_, cb)
    Photomode.ExitToPauseMenu()
    cb('ok')
end)

RegisterNUICallback('rotateCamera', function(data, cb)
    if data and data.direction then
        Photomode.Rotate(data.direction)
    end
    cb('ok')
end)

RegisterNUICallback('cycleFilter', function(data, cb)
    if data and data.direction then
        Photomode.CycleFilter(data.direction)
    end
    cb('ok')
end)

RegisterNUICallback('setFilterIndex', function(data, cb)
    if data and data.index ~= nil then
        Photomode.SetFilterIndex(data.index)
    end
    cb('ok')
end)

RegisterNUICallback('photomodeDrag', function(data, cb)
    if data then
        Photomode.ApplyDrag(data.deltaX or 0, data.deltaY or 0)
    end
    cb('ok')
end)

RegisterNUICallback('photomodeZoom', function(data, cb)
    if data then
        Photomode.ApplyZoom(data.delta or 0)
    end
    cb('ok')
end)

RegisterNUICallback('toggleBlur', function(_, cb)
    Photomode.ToggleBlur()
    cb('ok')
end)

RegisterNUICallback('exitServer', function(_, cb)
    TriggerServerEvent('noir_pausemenu:exitServer')
    cb('ok')
end)
