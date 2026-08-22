PauseMenu = {}
PauseMenu.open = false
PauseMenu.photomodeReturn = false
PauseMenu.closing = false

local function getServerInfo()
    local serverName = Config.ServerName
    if not serverName or serverName == '' then
        serverName = GlobalState.PauseMenu_ServerName or 'FiveM Server'
    end

    return {
        serverName = serverName,
        players = GlobalState.PlayerCount or 0,
        maxPlayers = GlobalState.PauseMenu_MaxPlayers or 48,
    }
end

local function sendLocale()
    SendNUIMessage({
        action = 'setLocale',
        data = Locales[Config.Locale] or Locales['en'],
    })
end

local function sendPlayerData()
    SendNUIMessage({
        action = 'updatePlayerData',
        data = Framework.GetPlayerData(),
    })
end

local function sendServerInfo()
    SendNUIMessage({
        action = 'updateServerInfo',
        data = getServerInfo(),
    })
end

local function refreshMenuData()
    sendPlayerData()
    sendServerInfo()
end

function PauseMenu.Open()
    if PauseMenu.open or Photomode.active or PauseMenu.closing then return end

    PauseMenu.open = true
    PauseMenu.photomodeReturn = false

    PauseCam.Start()
    PauseAnim.Start()

    SetNuiFocus(true, true)
    sendLocale()
    refreshMenuData()

    SendNUIMessage({ action = 'route', data = 'pausemenu' })
    SendNUIMessage({ action = 'setVisible', data = true })

    CreateThread(function()
        Wait(100)
        refreshMenuData()
    end)

    if Config.HideRadarOnPause then
        DisplayRadar(false)
    end
end

function PauseMenu.CloseImmediate()
    if not PauseMenu.open and not Photomode.active and not PauseMenu.closing then return end

    if Photomode.active then
        Photomode.Stop()
    end

    PauseMenu.FinalizeClose()
    SendNUIMessage({ action = 'setVisible', data = false })
    SendNUIMessage({ action = 'close', data = false })
end

function PauseMenu.RequestClose()
    if not PauseMenu.open or PauseMenu.closing or Photomode.active then return end

    PauseMenu.closing = true
    SendNUIMessage({ action = 'requestClose', data = true })
end

function PauseMenu.Close()
    PauseMenu.RequestClose()
end

function PauseMenu.PreparePhotomode()
    if PauseMenu.closing or Photomode.active or not PauseMenu.open then return end

    PauseMenu.open = false
    PauseMenu.closing = false
    Photomode.Start()
end

function PauseMenu.FinalizeClose()
    PauseMenu.open = false
    PauseMenu.closing = false
    PauseMenu.photomodeReturn = false

    PauseAnim.Stop()
    PauseCam.Stop()

    SetNuiFocus(false, false)

    if Config.HideRadarOnPause then
        DisplayRadar(true)
    end
end

function PauseMenu.OnCloseAnimationComplete()
    PauseMenu.FinalizeClose()
end

function PauseMenu.OpenFromPhotomode(cam, angle, distance, height)
    PauseMenu.open = true
    PauseMenu.closing = false

    if cam then
        PauseCam.StartFromPhotomode(cam, angle, distance, height)
    else
        PauseCam.Start()
    end

    PauseAnim.Start()

    SetNuiFocus(true, true)
    refreshMenuData()
    SendNUIMessage({ action = 'route', data = 'pausemenu' })
    SendNUIMessage({ action = 'setVisible', data = true })

    PauseMenu.photomodeReturn = false
end

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    if PauseMenu.open and not Photomode.active then
        sendPlayerData()
    end
end)

local function onServerInfoStateChanged()
    if PauseMenu.open and not Photomode.active then
        sendServerInfo()
    end
end

AddStateBagChangeHandler('PlayerCount', 'global', onServerInfoStateChanged)
AddStateBagChangeHandler('PauseMenu_MaxPlayers', 'global', onServerInfoStateChanged)
AddStateBagChangeHandler('PauseMenu_ServerName', 'global', onServerInfoStateChanged)

CreateThread(function()
    while true do
        SetPauseMenuActive(false)
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local wait = 500

        if PauseMenu.open and not Photomode.active and not PauseMenu.closing then
            wait = 0
            if IsControlJustPressed(0, Config.OpenKey) or IsControlJustPressed(0, 199) then
                PauseMenu.RequestClose()
            end
        end

        if Photomode.active then
            wait = 0
            if IsControlJustPressed(0, Config.OpenKey) or IsControlJustPressed(0, 199) then
                Photomode.ExitToPauseMenu()
            end
        elseif not PauseMenu.open and not PauseMenu.closing then
            wait = 0
            if IsControlJustPressed(0, Config.OpenKey) or IsControlJustPressed(0, 199) then
                PauseMenu.Open()
            end
        end

        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if PauseMenu.open and not Photomode.active then
            sendServerInfo()
            Wait(Config.PlayerCountRefreshMs)
        else
            Wait(1000)
        end
    end
end)

exports('IsPauseMenuOpen', function()
    return PauseMenu.open
end)
