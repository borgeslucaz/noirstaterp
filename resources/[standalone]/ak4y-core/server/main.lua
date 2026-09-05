local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

exports('GetCitizenId', function(src)
    local player = getPlayer(src)
    if not player then return nil end
    return player.PlayerData.citizenid
end)

exports('GetFirstName', function(src)
    local player = getPlayer(src)
    if not player then return nil end
    return player.PlayerData.charinfo.firstname
end)

exports('GetLastName', function(src)
    local player = getPlayer(src)
    if not player then return nil end
    return player.PlayerData.charinfo.lastname
end)

exports('GetPlayerAvatar', function(src)
    return ''
end)

exports('GetPlayerJob', function(src)
    local player = getPlayer(src)
    if not player then return nil end
    return player.PlayerData.job.name
end)

exports('AddPlayerMoney', function(src, amount, account)
    local player = getPlayer(src)
    if not player then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    return player.Functions.AddMoney(account or 'cash', amount, 'ak4y')
end)

exports('RemovePlayerMoney', function(src, amount, account)
    local player = getPlayer(src)
    if not player then return false end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    account = account or 'cash'
    if (player.PlayerData.money[account] or 0) >= amount then
        return player.Functions.RemoveMoney(account, amount, 'ak4y')
    end
    if account == 'cash' and (player.PlayerData.money.bank or 0) >= amount then
        return player.Functions.RemoveMoney('bank', amount, 'ak4y')
    end
    return false
end)

exports('Register', function(name, fn)
    lib.callback.register(name, function(source, ...)
        local ok, result = pcall(fn, source, ...)
        if not ok then
            print(('^1[ak4y-core]^0 callback "%s" failed: %s'):format(tostring(name), tostring(result)))
            return nil
        end
        return result
    end)
end)

exports('ExecuteSql', function(query)
    return MySQL.query.await(query) or {}
end)
