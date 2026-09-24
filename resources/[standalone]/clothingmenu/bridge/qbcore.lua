-- QBCore Legacy Adapter

local QBCore = nil

local function GetQBCore()
    if QBCore then return QBCore end
    QBCore = exports['qb-core']:GetCoreObject()
    return QBCore
end

function Bridge.IsPlayerDead(src)
    if not src or src == 0 then return false end

    local Player = GetQBCore().Functions.GetPlayer(src)
    if not Player then return false end

    local metadata = Player.PlayerData and Player.PlayerData.metadata
    if not metadata then return false end

    return metadata.isdead == true or metadata.inlaststand == true
end

function Bridge.IsPlayerHandcuffed(src)
    if not src or src == 0 then return false end

    local Player = GetQBCore().Functions.GetPlayer(src)
    if not Player then return false end

    local metadata = Player.PlayerData and Player.PlayerData.metadata
    if not metadata then return false end

    return metadata.ishandcuffed == true
end

function Bridge.GetPlayerName(src)
    if not src or src == 0 then return nil end

    local Player = GetQBCore().Functions.GetPlayer(src)
    if not Player then return nil end

    local charinfo = Player.PlayerData.charinfo
    return charinfo.firstname .. ' ' .. charinfo.lastname
end
