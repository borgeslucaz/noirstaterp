local function refreshServerState()
    if Config.ServerName and Config.ServerName ~= '' then
        GlobalState.PauseMenu_ServerName = Config.ServerName
    else
        GlobalState.PauseMenu_ServerName = GetConvar('sv_hostname', 'FiveM Server')
    end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    refreshServerState()
end)

RegisterNetEvent('rome_pausemenu:exitServer', function()
    local src = source
    DropPlayer(src, 'You left the server.')
end)
