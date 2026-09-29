NoirIllegal.Bridges = NoirIllegal.Bridges or {}
NoirIllegal.Bridges.Qbox = {}

function NoirIllegal.Bridges.Qbox.getPlayer(source)
    source = tonumber(source)
    if not source or source <= 0 then return nil end
    return exports.qbx_core:GetPlayer(source)
end

function NoirIllegal.Bridges.Qbox.getIdentity(source)
    local player = NoirIllegal.Bridges.Qbox.getPlayer(source)
    local data = player and player.PlayerData
    if not data or not NoirIllegal.Validators.string(data.citizenid, 1, 64) then return nil end
    return {
        source = tonumber(source),
        citizenId = data.citizenid,
    }
end

function NoirIllegal.Bridges.Qbox.findSourceByCitizenId(citizenId)
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenId)
    return player and player.PlayerData and player.PlayerData.source or nil
end
