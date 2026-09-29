
Nuimessage = function (type,data)
    SendNUIMessage({
        action = type,
        data = data
    })
end

Nuicontrol = function (state)
    SetNuiFocus(state, state)
end


loadModel = function(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

GetPlayerMaxSlots = function(user)
    local extraslots = lib.callback.await('IV:GetExtraSlots', false,user)
    local slots = Config.Maxslots
    pcall(function ()
        slots = slots + extraslots
    end)

    return slots
end

local function decodePosition(position)
    if type(position) == 'table' then return position end
    if type(position) == 'string' and position ~= '' then
        local ok, decoded = pcall(json.decode, position)
        if ok and type(decoded) == 'table' then return decoded end
    end
end

GetLastSeenLabel = function(position)
    local coords = decodePosition(position)
    local x = coords and tonumber(coords.x)
    local y = coords and tonumber(coords.y)
    if not x or not y then return 'DESCONHECIDO' end

    local z = tonumber(coords.z) or 0.0
    local zoneCode = GetNameOfZone(x, y, z)
    if zoneCode and zoneCode ~= '' then
        local zoneLabel = GetLabelText(zoneCode)
        if zoneLabel and zoneLabel ~= '' and zoneLabel ~= 'NULL' then
            return string.upper(zoneLabel)
        end
    end

    local streetHash = GetStreetNameAtCoord(x, y, z)
    if streetHash and streetHash ~= 0 then
        local streetName = GetStreetNameFromHashKey(streetHash)
        if streetName and streetName ~= '' then return string.upper(streetName) end
    end

    return 'DESCONHECIDO'
end


DisableWeatherSync = function ()
    TriggerEvent('qb-weathersync:client:DisableSync')
end

EnableWeatherSync = function ()
    TriggerEvent('qb-weathersync:client:EnableSync')
end
