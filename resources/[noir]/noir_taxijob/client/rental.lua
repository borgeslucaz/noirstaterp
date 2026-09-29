-- Aluguel no client: atendente da central (ox_target), resolução do veículo alugado por net ID e devolução.
-- A entidade é criada e registrada pelo servidor; aqui só se resolve e apresenta.
Rental = { netId = nil, vehicleId = nil }
Depot = { ped = 0, blip = nil }

local D = Config.Depot

---@return number vehicle (0 se não existir localmente)
function Rental.vehicle()
    if not Rental.netId or not NetworkDoesEntityExistWithNetworkId(Rental.netId) then return 0 end
    local veh = NetToVeh(Rental.netId)
    if veh == 0 or not DoesEntityExist(veh) then return 0 end
    return veh
end

---@param veh number
---@return boolean
function Rental.isRentalVehicle(veh)
    if not Rental.netId or not veh or veh == 0 then return false end
    if not NetworkGetEntityIsNetworked(veh) then return false end
    return NetworkGetNetworkIdFromEntity(veh) == Rental.netId
end

---@return boolean
function Rental.active()
    return Rental.netId ~= nil
end

function Rental.clear()
    Rental.netId = nil
    Rental.vehicleId = nil
end

---Resposta de sucesso do servidor: guarda o vínculo e resolve a entidade com timeout limitado.
---@param res { netId: number, vehicleId: string }
function Rental.onRented(res)
    Rental.netId = res.netId
    Rental.vehicleId = res.vehicleId
    CreateThread(function()
        local ok = pcall(lib.waitFor, function()
            if NetworkDoesEntityExistWithNetworkId(res.netId) then return true end
        end, 'rental vehicle did not stream in', 8000)
        if Rental.netId ~= res.netId then return end
        if ok then
            Notify('notify.rental_taken', 'success')
        else
            -- O servidor mantém a autoridade; o veículo pode aparecer em seguida ou ser limpo na varredura.
            Notify('notify.rental_resolve_failed', 'error')
        end
    end)
end

local returnErrors = {
    not_near = 'notify.rental_not_near',
    not_yours = 'notify.rental_not_yours',
}

function Rental.returnVehicle()
    local veh = Rental.vehicle()
    if veh == 0 then
        Notify('notify.rental_not_near', 'error')
        return
    end
    local res = lib.callback.await('noir_taxijob:server:returnVehicle', false, Rental.netId)
    if not res or not res.ok then
        local key = res and returnErrors[res.code]
        if key then Notify(key, 'error') end
        if res and res.code == 'not_yours' then Rental.clear() end
        return
    end
    Rental.clear()
    Notify('notify.rental_returned', 'success')
end

local function hasVehicleNearby()
    local veh = Rental.vehicle()
    if veh == 0 then return false end
    return #(GetEntityCoords(cache.ped) - GetEntityCoords(veh)) <= 10.0
end

RegisterNetEvent('noir_taxijob:client:rentalEnded', function(reason)
    Rental.clear()
    if not Taxi.is(TAXI_STATE.HIDDEN) then Taxi.deactivateLocal(reason) end
    if reason == 'vehicle_lost' then Notify('notify.rental_lost', 'error') end
end)

AddEventHandler('bgrz_core:client:playerUnloaded', function()
    Rental.clear()
end)

-- ───────────────────────── atendente, blip e target ─────────────────────────

CreateThread(function()
    lib.requestModel(D.pedModel, 10000)
    local ped = CreatePed(4, joaat(D.pedModel), D.coords.x, D.coords.y, D.coords.z - 1.0, D.coords.w, false, true)
    SetModelAsNoLongerNeeded(joaat(D.pedModel))
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
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
            name = 'noir_taxijob_central',
            icon = 'fa-solid fa-taxi',
            label = locale('target.open_central'),
            distance = 3.0,
            canInteract = function()
                -- Visível para qualquer personagem: o Taxi V2 não depende de emprego ou duty.
                return not cache.vehicle and not Central.isOpen()
            end,
            onSelect = function() Central.open() end,
        },
        {
            name = 'noir_taxijob_return',
            icon = 'fa-solid fa-square-parking',
            label = locale('target.return_taxi'),
            distance = 3.0,
            canInteract = function()
                return not cache.vehicle and not Central.isOpen() and hasVehicleNearby()
            end,
            onSelect = function() Rental.returnVehicle() end,
        },
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if Depot.ped ~= 0 and DoesEntityExist(Depot.ped) then DeleteEntity(Depot.ped) end
    if Depot.blip then RemoveBlip(Depot.blip) end
end)
