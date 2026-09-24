-- ESX Legacy Adapter

local ESX = nil

local function GetESX()
    if ESX then return ESX end
    ESX = exports['es_extended']:getSharedObject()
    return ESX
end

function Bridge.IsPlayerDead(src)
    if not src or src == 0 then return false end

    local xPlayer = GetESX().GetPlayerFromId(src)
    if not xPlayer then return false end

    -- ESX doesn't have standard metadata, use health check
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

    local xPlayer = GetESX().GetPlayerFromId(src)
    if not xPlayer then return nil end

    return xPlayer.getName()
end
