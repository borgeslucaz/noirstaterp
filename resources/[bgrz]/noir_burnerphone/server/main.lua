local function sendContactMessage(source, message, location)
    if type(source) ~= 'number' or type(message) ~= 'string' then return false end
    TriggerClientEvent('noir_burnerphone:client:contactMessage', source, {
        from = BurnerPhoneConfig.houseRobberyContact.number,
        name = BurnerPhoneConfig.houseRobberyContact.name,
        message = message:sub(1, 240),
        location = location,
        timestamp = os.time(),
    })
    return true
end

exports('sendContactMessage', sendContactMessage)

RegisterNetEvent('noir_burnerphone:server:sendHouseMessage', function(message)
    local src = source
    if not BurnerPhoneConfig.enabled or not BurnerPhoneConfig.activities.contracts then return end
    if type(message) ~= 'string' or #message > 120 then return end
    local normalized = message:lower():gsub('^%s+', ''):gsub('%s+$', '')
    local expected = BurnerPhoneConfig.houseRobberyContact.requestText:lower()
    if normalized ~= expected then
        sendContactMessage(src, 'Não entendi. Diga exatamente: "' .. BurnerPhoneConfig.houseRobberyContact.requestText .. '"')
        return
    end
    if GetResourceState('noir_houserobbery') ~= 'started' then
        sendContactMessage(src, 'Esse canal está silencioso agora.')
        return
    end
    exports.noir_houserobbery:RequestHouseContract(src)
end)
