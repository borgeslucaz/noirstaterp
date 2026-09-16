local wheelBones = {}

for bone in pairs(Config.wheelBones) do
    wheelBones[#wheelBones + 1] = bone
end

---Finds the wheel bone closest to the point the player is aiming at.
---@param vehicle number
---@param coords vector3 raycast hit position given by ox_target
---@return number? tyreIndex
---@return vector3? bonePosition
local function getClosestWheel(vehicle, coords)
    local closestIndex, closestCoords, closestDistance

    for i = 1, #wheelBones do
        local bone = wheelBones[i]
        local boneId = GetEntityBoneIndexByName(vehicle, bone)

        if boneId ~= -1 then
            local bonePos = GetEntityBonePosition_2(vehicle, boneId)
            local distance = #(coords - bonePos)

            if distance <= (closestDistance or 1.0) then
                closestIndex = Config.wheelBones[bone]
                closestCoords = bonePos
                closestDistance = distance
            end
        end
    end

    return closestIndex, closestCoords
end

---@param vehicle number
---@param tyreIndex number
local function burstTyre(vehicle, tyreIndex)
    -- The tyre natives only replicate from the client that owns the entity, so
    -- either we take control of it or we ask the owner (through the server) to
    -- do it for us. Taking control fails on vehicles a player is driving.
    if not NetworkGetEntityIsNetworked(vehicle) or NetworkGetEntityOwner(vehicle) == cache.playerId then
        return SetVehicleTyreBurst(vehicle, tyreIndex, Config.burstOnRim, 1000.0)
    end

    for _ = 1, 10 do
        NetworkRequestControlOfEntity(vehicle)

        if NetworkHasControlOfEntity(vehicle) then
            return SetVehicleTyreBurst(vehicle, tyreIndex, Config.burstOnRim, 1000.0)
        end

        Wait(50)
    end

    TriggerServerEvent('noir_tireslash:slash', NetworkGetNetworkIdFromEntity(vehicle), tyreIndex)
end

---@param vehicle number
---@param coords vector3
local function slashTyre(vehicle, coords)
    local tyreIndex, boneCoords = getClosestWheel(vehicle, coords)

    if not tyreIndex then return end

    if IsVehicleTyreBurst(vehicle, tyreIndex, false) then
        return lib.notify({ type = 'error', description = locale('already_slashed') })
    end

    TaskTurnPedToFaceEntity(cache.ped, vehicle, Config.slashDuration)

    local completed = lib.progressCircle({
        label = locale('slashing'),
        duration = Config.slashDuration,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = Config.anim,
    })

    if not completed then return end

    -- The vehicle can be gone or driven off while the animation plays.
    if not DoesEntityExist(vehicle) or #(GetEntityCoords(cache.ped) - boneCoords) > 2.5 then return end

    burstTyre(vehicle, tyreIndex)
end

exports.ox_target:addGlobalVehicle({
    {
        name = 'noir_tireslash:slash',
        icon = 'fas fa-screwdriver',
        label = locale('slash_tire'),
        bones = wheelBones,
        distance = Config.targetDistance,
        canInteract = function(entity, _, coords)
            if cache.vehicle or lib.progressActive() then return false end
            if not Config.allowedWeapons[GetSelectedPedWeapon(cache.ped)] then return false end
            if Config.respectBulletproofTyres and not GetVehicleTyresCanBurst(entity) then return false end

            local tyreIndex = getClosestWheel(entity, coords)

            return tyreIndex ~= nil and not IsVehicleTyreBurst(entity, tyreIndex, false)
        end,
        onSelect = function(data)
            slashTyre(data.entity, data.coords)
        end,
    },
})

-- Fired by the server on the client that owns the vehicle, so the burst replicates.
RegisterNetEvent('noir_tireslash:burst', function(netId, tyreIndex)
    local vehicle = NetToVeh(netId)

    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SetVehicleTyreBurst(vehicle, tyreIndex, Config.burstOnRim, 1000.0)

    if cache.vehicle == vehicle then
        lib.notify({ type = 'inform', description = locale('car_slashed') })
    end
end)
