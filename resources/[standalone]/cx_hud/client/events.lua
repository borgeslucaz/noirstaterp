return function(State, Utils, Minimap, Status, Vehicle, isReady, Config)
    RegisterCommand(Config.MenuCommand or 'hud', function()
        if not isReady() then return end
        State.menuIsOpen = true
        SetNuiFocus(true, true)
        Utils.sendNui('openMenu', {})
    end, false)

    RegisterNetEvent('atlas_core:Client:OnPlayerLoaded', function()
        Status.fetchPlayerData()
        State.coreLoaded    = true
        State.playerSpawned = true
        CreateThread(function() Wait(1500); SetBigmapActive(false, false); Status.tryShowHud() end)
    end)

    RegisterNetEvent('atlas_core:Client:OnPlayerUnload', function()
        State.coreLoaded = false; State.playerSpawned = false; State.seatbeltOn = false
        Status.showHud(false); DisplayRadar(false)
    end)

    AddEventHandler('playerSpawned', function()
        if not State.coreLoaded then return end
        State.playerSpawned = true; Status.fetchPlayerData()
        CreateThread(function() Wait(1500); SetBigmapActive(false, false); Status.tryShowHud() end)
    end)

    AddEventHandler('onResourceStart', function(res)
        if res ~= GetCurrentResourceName() then return end
        Status.fetchPlayerData()
        if LocalPlayer.state.isLoggedIn then
            State.coreLoaded = true
            if NetworkIsPlayerActive(cache.playerId) and DoesEntityExist(cache.ped) then
                State.playerSpawned = true
            end
            CreateThread(function() Wait(1000); SetBigmapActive(false, false); Status.tryShowHud() end)
        else
            Status.showHud(false)
        end
    end)

    -- atlas_core fires Player:SetPlayerData on every PlayerData change
    -- (job, money, metadata, etc.) — single hook covers what QBCore
    -- splits into SetPlayerData / OnJobUpdate / OnMoneyChange.
    RegisterNetEvent('atlas_core:Player:SetPlayerData', function(playerData)
        State.playerData = playerData or {}
        Status.refreshStaticCache()
        Status.refreshMoneyCache()
        if State.hudShowing then Status.pushStatus(true) end
    end)

    -- atlas_mgmt fires this with the org row whenever /setorg lands
    -- or duty toggles. Refresh the cached job label even if SetPlayerData
    -- hasn't propagated yet (state-bag tier is the canonical source).
    RegisterNetEvent('atlas_core:Client:OnJobUpdate', function()
        Status.refreshStaticCache()
        if State.hudShowing then Status.pushStatus(false) end
    end)

    RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
        State.playerData.metadata        = State.playerData.metadata or {}
        State.playerData.metadata.hunger = hunger
        State.playerData.metadata.thirst = thirst
        if State.hudShowing then Status.pushStatus(false) end
    end)

    RegisterNetEvent('pma-voice:setTalkingMode', function(mode)
        local modes = { [1] = 'Whisper', [2] = 'Normal', [3] = 'Shout' }
        State.voiceLabel = modes[mode] or Config.DefaultVoice
        if State.hudShowing then Status.pushStatus(false) end
    end)

    RegisterNetEvent('cx-hud:versionResult', function(current, latest, outdated)
        Utils.sendNui('versionInfo', { current = current, latest = latest, outdated = outdated })
    end)
end