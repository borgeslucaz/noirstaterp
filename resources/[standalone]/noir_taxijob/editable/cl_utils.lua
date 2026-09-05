-- Central de táxi: ped com ox_target para pegar/devolver o táxi. Fora do veículo, sem NUI própria.
Depot = { netId = nil, ped = 0, blip = nil }

local D = Config.Depot

local function depotVehicle()
    if not Depot.netId or not NetworkDoesEntityExistWithNetworkId(Depot.netId) then return 0 end
    local veh = NetToVeh(Depot.netId)
    if veh == 0 or not DoesEntityExist(veh) then return 0 end
    return veh
end

local function hasVehicleNearby()
    local veh = depotVehicle()
    if veh == 0 then return false end
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) <= 10.0
end

local depotErrors = {
    already = 'notify.depot_already',
    no_space = 'notify.depot_no_space',
    duty = 'notify.off_duty',
    job = 'notify.not_taxi_job',
    failed = 'notify.depot_failed',
    not_near = 'notify.depot_not_near',
    not_yours = 'notify.depot_not_yours',
}

function Depot.take()
    if not Taxi.canWork() then
        local job = Taxi.getJob()
        Notify((job and job.name == Config.Job) and 'notify.off_duty' or 'notify.not_taxi_job', 'error')
        return
    end
    local res = lib.callback.await('ak4y-taxi:server:takeVehicle', false)
    if not res or not res.ok then
        local key = res and depotErrors[res.reason]
        if key then Notify(key, 'error') end
        return
    end
    Depot.netId = res.netId
    Notify('notify.depot_taken', 'success')
end

function Depot.returnVehicle()
    local veh = depotVehicle()
    if veh == 0 then
        Notify('notify.depot_not_near', 'error')
        return
    end
    local res = lib.callback.await('ak4y-taxi:server:returnVehicle', false, Depot.netId)
    if not res or not res.ok then
        local key = res and depotErrors[res.reason]
        if key then Notify(key, 'error') end
        return
    end
    Depot.netId = nil
    Notify('notify.depot_returned', 'success')
end

CreateThread(function()
    lib.requestModel(D.pedModel, 10000)
    local ped = CreatePed(4, joaat(D.pedModel), D.coords.x, D.coords.y, D.coords.z - 1.0, D.coords.w, false, true)
    SetModelAsNoLongerNeeded(joaat(D.pedModel))
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeTargetted(ped, false)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    Depot.ped = ped

    if D.blip then
        local blip = AddBlipForCoord(D.coords.x, D.coords.y, D.coords.z)
        SetBlipSprite(blip, D.blip.sprite)
        SetBlipColour(blip, D.blip.color)
        SetBlipScale(blip, D.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(D.blip.label)
        EndTextCommandSetBlipName(blip)
        Depot.blip = blip
    end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'ak4y_taxi_take',
            icon = 'fa-solid fa-taxi',
            label = locale('target.take_taxi'),
            distance = 3.0,
            canInteract = function()
                return Taxi.canWork() and not cache.vehicle and depotVehicle() == 0
            end,
            onSelect = Depot.take,
        },
        {
            name = 'ak4y_taxi_return',
            icon = 'fa-solid fa-square-parking',
            label = locale('target.return_taxi'),
            distance = 3.0,
            canInteract = function()
                return not cache.vehicle and hasVehicleNearby()
            end,
            onSelect = Depot.returnVehicle,
        },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Depot.ped ~= 0 and DoesEntityExist(Depot.ped) then DeleteEntity(Depot.ped) end
    if Depot.blip then RemoveBlip(Depot.blip) end
end)
