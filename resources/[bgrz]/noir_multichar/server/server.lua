


RegisterNetEvent('Exit:Game', function()
    DropPlayer(source, 'Quit Game')
end)

RegisterNetEvent('qbx:Logout', function ()
    exports.qbx_core:Logout(source)
end)


lib.callback.register('IV:UpdateSlot', function(source, data)
	if not IsPlayerAceAllowed(source, 'command') then return false end
	if type(data) ~= 'table' or type(data.slot) ~= 'number' or data.slot < 0 or data.slot > 20 then return false end

    local identifier = GetIdentifier(source)

    local response = MySQL.prepare.await('SELECT * FROM `multicharacter_slots` WHERE `identifier` = ?',
        { identifier })

    if response then
        local response = MySQL.update.await('UPDATE multicharacter_slots SET slots = ? WHERE identifier = ?',
            { data.slot, identifier })
    else
        local insert = MySQL.insert.await('INSERT INTO `multicharacter_slots` (identifier, slots) VALUES (?, ?)',
            { identifier, data.slot })
    end

    return true
end)




function GetIdentifier(source)
    local identifier = GetPlayerIdentifierByType(source, Config.Identifier)
    return identifier and identifier:gsub(Config.Identifier .. ":", "")
end


lib.callback.register('IV:GetExtraSlots', function (source,user)
    local identifier = user == 'src' and GetIdentifier(source) or user
    local slots = MySQL.scalar.await("SELECT slots FROM multicharacter_slots WHERE identifier = ?", { identifier }) or 0
    return slots
end)


RegisterNetEvent('Update:RoutingBucket', function (bucket)
    SetPlayerRoutingBucket(source,bucket)
end)
