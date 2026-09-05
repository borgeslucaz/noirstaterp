local function safeRequestModel(model, timeout)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    timeout = timeout or 10000
    local deadline = GetGameTimer() + timeout
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

exports('SafeRequestModel', function(model, timeout)
    return safeRequestModel(model, timeout)
end)

exports('Trigger', function(name, ...)
    return lib.callback.await(name, false, ...)
end)

exports('GetPlayerJob', function()
    local job = QBX.PlayerData.job
    return job and job.name or false
end)

exports('SpawnVehicle', function(model, cb, coords, networked, persist)
    local hash = type(model) == 'string' and joaat(model) or model
    if not safeRequestModel(hash, 15000) then
        if cb then cb(0) end
        return
    end

    local ped = PlayerPedId()
    local x, y, z, w
    if coords then
        x, y, z, w = coords.x, coords.y, coords.z, coords.w or 0.0
    else
        local pcoords = GetEntityCoords(ped)
        x, y, z, w = pcoords.x, pcoords.y, pcoords.z, GetEntityHeading(ped)
    end

    local veh = CreateVehicle(hash, x, y, z, w, networked ~= false, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'TAXI' .. math.random(10000, 99999))
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetModelAsNoLongerNeeded(hash)

    if cb then cb(veh) end
end)
