NoirHouseDispatch = {}

function NoirHouseDispatch.alert(source, message)
    if GetResourceState('qbx_police') ~= 'started' then return false end
    TriggerEvent('police:server:policeAlert', message or 'Possível invasão residencial', nil, source)
    return true
end
