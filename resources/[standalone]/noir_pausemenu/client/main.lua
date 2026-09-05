PauseMenu = {}
PauseMenu.open = false
PauseMenu.photomodeReturn = false
PauseMenu.closing = false
PauseMenu.frontendActive = false
PauseMenu.hudStateCaptured = false
PauseMenu.savedHudVisible = nil

local HUD_RESOURCE = 'noir_hud'

local function isHudAvailable()
    return GetResourceState(HUD_RESOURCE) == 'started'
end

function PauseMenu.CaptureAndHideHud()
    if PauseMenu.hudStateCaptured or not isHudAvailable() then return end

    local ok, visible = pcall(function()
        return exports[HUD_RESOURCE]:isHudVisible()
    end)
    if not ok or type(visible) ~= 'boolean' then return end

    PauseMenu.hudStateCaptured = true
    PauseMenu.savedHudVisible = visible

    pcall(function() exports[HUD_RESOURCE]:setPauseVisibilityManaged(true) end)
    pcall(function() exports[HUD_RESOURCE]:setHudVisible(false) end)
end

function PauseMenu.RestoreHud()
    if not PauseMenu.hudStateCaptured then return end

    local visible = PauseMenu.savedHudVisible
    PauseMenu.hudStateCaptured = false
    PauseMenu.savedHudVisible = nil

    if not isHudAvailable() then return end

    pcall(function() exports[HUD_RESOURCE]:setHudVisible(visible) end)
    pcall(function() exports[HUD_RESOURCE]:setPauseVisibilityManaged(false) end)
end

local function getServerInfo()
    local serverName = Config.ServerName
    if not serverName or serverName == '' then
        serverName = GlobalState.PauseMenu_ServerName or 'FiveM Server'
    end

    return {
        serverName = serverName,
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
    if PauseMenu.open or Photomode.active or PauseMenu.closing or PauseMenu.frontendActive then return end

    PauseMenu.CaptureAndHideHud()
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

function PauseMenu.CloseImmediate(keepHudHidden)
    if not PauseMenu.open and not Photomode.active and not PauseMenu.closing then return end

    if Photomode.active then
        Photomode.Stop()
    end

    PauseMenu.FinalizeClose(keepHudHidden)
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

function PauseMenu.OpenFrontendMenu(menuHash)
    if not PauseMenu.open or PauseMenu.closing or Photomode.active or PauseMenu.frontendActive then return end

    PauseMenu.CloseImmediate(true)

    ActivateFrontendMenu(menuHash, false, -1)

    PauseMenu.frontendActive = true
end

function PauseMenu.CloseFrontendMenu()
    PauseMenu.frontendActive = false

    SetFrontendActive(false)
    SetPauseMenuActive(false)

    CreateThread(function()
        Wait(0)
        SetFrontendActive(false)
        SetPauseMenuActive(false)
        PauseMenu.RestoreHud()
    end)
end

function PauseMenu.PreparePhotomode()
    if PauseMenu.closing or Photomode.active or not PauseMenu.open then return end

    PauseMenu.open = false
    PauseMenu.closing = false
    Photomode.Start()
end

function PauseMenu.FinalizeClose(keepHudHidden)
    PauseMenu.open = false
    PauseMenu.closing = false
    PauseMenu.photomodeReturn = false

    PauseAnim.Stop()
    PauseCam.Stop()

    SetNuiFocus(false, false)

    if Config.HideRadarOnPause then
        DisplayRadar(true)
    end

    if not keepHudHidden then
        PauseMenu.RestoreHud()
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

AddStateBagChangeHandler('PauseMenu_ServerName', 'global', onServerInfoStateChanged)

local function disablePauseControls()
    DisableControlAction(0, Config.OpenKey, true)
    DisableControlAction(0, 199, true)
    DisableControlAction(2, Config.OpenKey, true)
    DisableControlAction(2, 199, true)
end

local function isPauseControlPressed()
    return IsDisabledControlJustPressed(0, Config.OpenKey)
        or IsDisabledControlJustPressed(0, 199)
        or IsDisabledControlJustPressed(2, Config.OpenKey)
        or IsDisabledControlJustPressed(2, 199)
end

local lastExternalNuiFocusAt

local function externalNuiRecentlyFocused(now, nuiFocused)
    if nuiFocused then
        lastExternalNuiFocusAt = now
        return true
    end

    if not lastExternalNuiFocusAt then return false end

    local elapsed = now - lastExternalNuiFocusAt
    return elapsed >= 0 and elapsed <= Config.ExternalNuiCloseGraceMs
end

CreateThread(function()
    while true do
        disablePauseControls()

        if not PauseMenu.frontendActive then
            -- Enhanced can activate the GTA frontend before the pause controls are
            -- observed by scripts. Block its render path and close any activation
            -- that was not explicitly requested by this resource.
            DisableFrontendThisFrame()
            if IsPauseMenuActive() then
                SetFrontendActive(false)
            end
            SetPauseMenuActive(false)
        end

        local now = GetGameTimer()
        local nuiFocused = IsNuiFocused()
        local externalNuiBlocked = false

        if not PauseMenu.open and not Photomode.active and not PauseMenu.frontendActive then
            externalNuiBlocked = externalNuiRecentlyFocused(now, nuiFocused)
        end

        local pressed = isPauseControlPressed()

        if pressed then
            if PauseMenu.frontendActive then
                PauseMenu.CloseFrontendMenu()
            elseif Photomode.active then
                Photomode.ExitToPauseMenu()
            elseif PauseMenu.open and not PauseMenu.closing then
                PauseMenu.RequestClose()
            -- Keep the ESC that closed another NUI from opening this menu in
            -- the same input cycle, even if that NUI already released focus.
            elseif not PauseMenu.closing and not externalNuiBlocked then
                PauseMenu.Open()
            end
        end

        Wait(0)
    end
end)

exports('IsPauseMenuOpen', function()
    return PauseMenu.open
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PauseMenu.RestoreHud()
    end
end)
