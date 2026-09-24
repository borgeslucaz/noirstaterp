Bridge = {}

local detectedFramework = nil
local esxVersion = nil

local function DetectFramework()
    if detectedFramework then return detectedFramework end

    local forced = Config and Config.framework
    if forced and forced ~= 'auto' then
        detectedFramework = forced
        return detectedFramework
    end

    if GetResourceState('qbx_core') == 'started' then
        detectedFramework = 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        detectedFramework = 'qbcore'
    elseif GetResourceState('es_extended') == 'started' then
        detectedFramework = 'esx'
        esxVersion = 'es_extended'
    elseif GetResourceState('esx-legacy') == 'started' then
        detectedFramework = 'esx'
        esxVersion = 'esx-legacy'
    else
        detectedFramework = 'standalone'
    end

    return detectedFramework
end

-- QBX Core Adapter
local function InitQBX()
    function Bridge.IsPlayerDead(src)
        if not src or src == 0 then return false end
        local player = exports.qbx_core:GetPlayer(src)
        if not player then return false end
        local metadata = player.PlayerData and player.PlayerData.metadata
        if not metadata then return false end
        return metadata.isdead == true or metadata.inlaststand == true
    end

    function Bridge.IsPlayerHandcuffed(src)
        if not src or src == 0 then return false end
        local player = exports.qbx_core:GetPlayer(src)
        if not player then return false end
        local metadata = player.PlayerData and player.PlayerData.metadata
        if not metadata then return false end
        return metadata.ishandcuffed == true
    end

    function Bridge.GetPlayerName(src)
        if not src or src == 0 then return nil end
        local player = exports.qbx_core:GetPlayer(src)
        if not player then return nil end
        local charinfo = player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end
end

-- QBCore Legacy Adapter
local function InitQBCore()
    local QBCore = exports['qb-core']:GetCoreObject()

    function Bridge.IsPlayerDead(src)
        if not src or src == 0 then return false end
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        local metadata = Player.PlayerData and Player.PlayerData.metadata
        if not metadata then return false end
        return metadata.isdead == true or metadata.inlaststand == true
    end

    function Bridge.IsPlayerHandcuffed(src)
        if not src or src == 0 then return false end
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        local metadata = Player.PlayerData and Player.PlayerData.metadata
        if not metadata then return false end
        return metadata.ishandcuffed == true
    end

    function Bridge.GetPlayerName(src)
        if not src or src == 0 then return nil end
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return nil end
        local charinfo = Player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end
end

-- ESX Adapter (supports es_extended and esx-legacy)
local function InitESX()
    local ESX = nil

    if esxVersion == 'esx-legacy' then
        ESX = exports['esx-legacy']:getSharedObject()
    else
        ESX = exports['es_extended']:getSharedObject()
    end

    function Bridge.IsPlayerDead(src)
        if not src or src == 0 then return false end

        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return false end

        -- Check for metadata if available (newer ESX versions)
        if xPlayer.get and type(xPlayer.get) == 'function' then
            local isDead = xPlayer.get('isDead')
            if isDead ~= nil then return isDead end
        end

        -- Fallback to health check
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false end
        return IsEntityDead(ped) or GetEntityHealth(ped) <= 100
    end

    function Bridge.IsPlayerHandcuffed(src)
        if not src or src == 0 then return false end

        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false end

        return IsPedCuffed(ped)
    end

    function Bridge.GetPlayerName(src)
        if not src or src == 0 then return nil end

        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return nil end

        -- Try different name methods based on ESX version
        if xPlayer.getName and type(xPlayer.getName) == 'function' then
            return xPlayer.getName()
        elseif xPlayer.name then
            return xPlayer.name
        elseif xPlayer.PlayerData and xPlayer.PlayerData.charinfo then
            local charinfo = xPlayer.PlayerData.charinfo
            return (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        end

        return GetPlayerName(src)
    end
end

-- Standalone Adapter
local function InitStandalone()
    function Bridge.IsPlayerDead(src)
        if not src or src == 0 then return false end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false end
        return IsEntityDead(ped) or GetEntityHealth(ped) <= 100
    end

    function Bridge.IsPlayerHandcuffed(src)
        if not src or src == 0 then return false end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return false end
        return IsPedCuffed(ped)
    end

    function Bridge.GetPlayerName(src)
        if not src or src == 0 then return nil end
        return GetPlayerName(src)
    end
end

function Bridge.GetFramework()
    return detectedFramework or DetectFramework()
end

function Bridge.GetESXVersion()
    return esxVersion
end

local function Init()
    local framework = DetectFramework()

    if framework == 'qbx' then
        InitQBX()
    elseif framework == 'qbcore' then
        InitQBCore()
    elseif framework == 'esx' then
        InitESX()
    else
        InitStandalone()
    end

    print(('[clothingmenu] Framework loaded: %s%s'):format(framework, esxVersion and (' (' .. esxVersion .. ')') or ''))
end

Init()
