-- QBX Core Adapter

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

    return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
end
