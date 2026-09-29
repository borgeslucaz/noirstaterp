local config = require 'config.client'
local sharedConfig = require 'config.shared'
local WEAPONS = exports.qbx_core:GetWeapons()
local allowRespawn = true
local plyState = LocalPlayer.state

local function playDeadAnimation()
    local deadAnimDict = 'dead'
    local playerData = QBX.PlayerData
    local metadata = playerData and playerData.metadata
    local deadAnim = metadata and metadata.ishandcuffed and 'dead_f' or 'dead_a'

    local deadVehAnimDict = 'veh@low@front_ps@idle_duck'
    local deadVehAnim = 'sit'

    if cache.vehicle then
        if not IsEntityPlayingAnim(cache.ped, deadVehAnimDict, deadVehAnim, 3) then
            lib.playAnim(cache.ped, deadVehAnimDict, deadVehAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
        end
    elseif not IsEntityPlayingAnim(cache.ped, deadAnimDict, deadAnim, 3) then
        lib.playAnim(cache.ped, deadAnimDict, deadAnim, 8.0, 1.0, -1, 1, 0, false, false, false)
    end
end

exports('PlayDeadAnimation', playDeadAnimation)

---put player in death animation and make invincible
function OnDeath(attacker, weapon)
    SetDeathState(sharedConfig.deathState.DEAD)
    WaitForPlayerToStopMoving()

    CreateThread(function()
        while DeathState == sharedConfig.deathState.DEAD do
            DisableControls()
            SetCurrentPedWeapon(cache.ped, `WEAPON_UNARMED`, true)
            Wait(0)
        end
    end)
    plyState.invBusy = true

    lib.requestAnimDict('dead')
    lib.requestAnimDict('veh@low@front_ps@idle_duck')
    ResurrectPlayer()
    playDeadAnimation()
    SetEntityInvincible(cache.ped, true)
    SetEntityHealth(cache.ped, GetEntityMaxHealth(cache.ped))
    -- Establish the downed pose before other resources handle the death.
    TriggerEvent('qbx_medical:client:onPlayerDied', attacker, weapon)
    TriggerServerEvent('qbx_medical:server:onPlayerDied', attacker, weapon)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
    CheckForRespawn()
end

exports('KillPlayer', OnDeath)

local respawnRequested = false

local function respawn()
    respawnRequested = false
    local success = lib.callback.await('qbx_medical:server:respawn')
    if not success then return end
    if QBX.PlayerData.metadata.ishandcuffed then
        TriggerEvent('police:client:GetCuffed', -1)
    end
    TriggerEvent('police:client:DeEscort')
    plyState.invBusy = false
    TriggerEvent('qbx_medical:client:onPlayerRespawned')
end

---Pede o respawn no hospital por fora da tecla E (tela de morte em NUI prende o teclado).
---O loop de CheckForRespawn executa no proximo segundo, entao nao corre junto com o automatico.
---@return boolean accepted
exports('RequestRespawn', function()
    if DeathState ~= sharedConfig.deathState.DEAD or not allowRespawn then return false end
    respawnRequested = true
    return true
end)

---Allow player to respawn
function CheckForRespawn()
    RespawnHoldTime = 5
    while DeathState == sharedConfig.deathState.DEAD do
        if respawnRequested and allowRespawn then
            respawn()
            return
        end
        if IsControlPressed(0, 38) and RespawnHoldTime <= 1 and allowRespawn then
            respawn()
            return
        end
        if IsControlPressed(0, 38) then
            RespawnHoldTime -= 1
        end
        if IsControlReleased(0, 38) then
            RespawnHoldTime = 5
        end
        if RespawnHoldTime <= 0 then
            RespawnHoldTime = 0
        end
        DeathTime -= 1
        if DeathTime <= 0 and allowRespawn then
            respawn()
            return
        end
        Wait(1000)
    end
end

function AllowRespawn()
    allowRespawn = true
end

exports('AllowRespawn', AllowRespawn)

exports('DisableRespawn', function()
    allowRespawn = false
end)

---log the death of a player along with the attacker and the weapon used.
---@param victim number ped
---@param attacker number ped
---@param weapon string weapon hash
local function logDeath(victim, attacker, weapon)
    local playerId = NetworkGetPlayerIndexFromPed(victim)
    local playerName = (' %s (%d)'):format(GetPlayerName(playerId), GetPlayerServerId(playerId)) or locale('info.self_death')
    local killerId = NetworkGetPlayerIndexFromPed(attacker)
    local killerName = killerId ~= -1 and ('%s (%d)'):format(GetPlayerName(killerId), GetPlayerServerId(killerId)) or locale('info.self_death')
    local weaponLabel = WEAPONS[weapon]?.label or 'Unknown'
    local weaponName = WEAPONS[weapon]?.name or 'Unknown'
    local message = locale('logs.death_log_message', killerName, playerName, weaponLabel, weaponName)

    lib.callback.await('qbx_medical:server:log', false, 'logDeath', message)
end

---when player dies, set last stand mode, or if already in last stand mode, set player to dead mode.
---Polls the ped instead of listening to `gameEventTriggered`: on GTA V Enhanced that event never
---fires for the local player, so deaths went unhandled and the ped stayed in native death.
---After SetPlayerModel (illenium on login, clothing shops) cache.ped keeps the deleted ped for up to
---100 ms and IsEntityDead on a handle that no longer exists returns true: only trust the current ped.
CreateThread(function()
    while true do
        if plyState.isLoggedIn and PlayerPedId() == cache.ped and IsEntityDead(cache.ped) then
            local attacker, weapon = GetPedSourceOfDeath(cache.ped), GetPedCauseOfDeath(cache.ped)
            if DeathState == sharedConfig.deathState.ALIVE then
                StartLastStand(attacker, weapon)
            elseif DeathState == sharedConfig.deathState.LAST_STAND then
                EndLastStand()
                logDeath(cache.ped, attacker, weapon)
                DeathTime = config.deathTime
                OnDeath(attacker, weapon)
            end
        end
        Wait(250)
    end
end)

function DisableControls()
    DisableAllControlActions(0)
    EnableControlAction(0, 1, true)
    EnableControlAction(0, 2, true)
    EnableControlAction(0, 245, true)
    EnableControlAction(0, 38, true)
    EnableControlAction(0, 0, true)
    EnableControlAction(0, 322, true)
    EnableControlAction(0, 288, true)
    EnableControlAction(0, 213, true)
    EnableControlAction(0, 249, true)
    EnableControlAction(0, 46, true)
    EnableControlAction(0, 47, true)
end
