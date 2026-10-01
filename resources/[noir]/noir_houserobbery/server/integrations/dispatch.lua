NoirHouseDispatch = {}

---Alerta de invasão para a polícia, pelo dispatch do bgrz_core (MDT ou fallback).
function NoirHouseDispatch.alert(source, message)
    if GetResourceState('bgrz_core') ~= 'started' then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local ok = exports.bgrz_core:SendDispatch({
        code = '10-31',
        title = 'Invasão residencial',
        message = message or 'Possível invasão residencial',
        coords = GetEntityCoords(ped),
        priority = 2,
    })
    return ok == true
end
