local wheelBones = {}
local boneByTyreIndex = {}

for bone, index in pairs(Config.wheelBones) do
    wheelBones[#wheelBones + 1] = bone
    boneByTyreIndex[index] = bone
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

---A fumaca e enfeite: asset ausente neste build trava o request para sempre, entao
---o pedido tem prazo e o corte segue sem efeito. Mesma regra do noir_graffiti.
---@param asset string
---@return boolean
local function loadPtfxAsset(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end

    RequestNamedPtfxAsset(asset)
    local timeout = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < timeout do Wait(0) end

    if not HasNamedPtfxAssetLoaded(asset) then
        print(('[noir_tireslash] efeito de particula ausente neste build: %s'):format(asset))
        return false
    end

    return true
end

---O jato nasce no osso da roda, e nao no veiculo: preso ali ele acompanha o carro
---sozinho se alguem sair dirigindo com o pneu murcho. Cada offset da lista e um
---emissor proprio, que e o unico jeito de engrossar a nuvem.
---@param vehicle number
---@param tyreIndex number
local function playSlashFx(vehicle, tyreIndex)
    local ptfx = Config.ptfx

    if not ptfx then return end

    local bone = boneByTyreIndex[tyreIndex]

    if not bone then return end

    local boneId = GetEntityBoneIndexByName(vehicle, bone)

    if boneId == -1 then return end
    if not loadPtfxAsset(ptfx.asset) then return end

    -- Em rede o efeito nasce para todo mundo por perto; fora dela, so para quem o cria.
    local networked = NetworkGetEntityIsNetworked(vehicle)
    local start = networked and StartNetworkedParticleFxLoopedOnEntityBone or StartParticleFxLoopedOnEntityBone
    local handles = {}

    for i = 1, #ptfx.emitters do
        local offset = ptfx.emitters[i]

        UseParticleFxAssetNextCall(ptfx.asset)

        local fx = start(ptfx.effect, vehicle,
            offset.x, offset.y, offset.z,
            ptfx.rotation.x, ptfx.rotation.y, ptfx.rotation.z,
            boneId, ptfx.scale, false, false, false)

        if fx and fx ~= 0 then
            handles[#handles + 1] = fx
        end
    end

    if #handles == 0 then return end

    SetTimeout(ptfx.duration, function()
        for i = 1, #handles do
            if DoesParticleFxLoopedExist(handles[i]) then
                StopParticleFxLooped(handles[i], false)
            end
        end
    end)
end

---@param vehicle number
---@param tyreIndex number
---@param silent boolean? o servidor ja cuidou do som (caminho do dono do veiculo)
local function burstAndSmoke(vehicle, tyreIndex, silent)
    SetVehicleTyreBurst(vehicle, tyreIndex, Config.burstOnRim, 1000.0)
    playSlashFx(vehicle, tyreIndex)

    if silent or not Config.sound then return end

    -- O som sai do veiculo para todos por perto, e quem faz isso e o servidor. Sem
    -- rede nao ha ninguem para ouvir alem de mim, entao toco local e pronto.
    if NetworkGetEntityIsNetworked(vehicle) then
        TriggerServerEvent('noir_tireslash:sound', NetworkGetNetworkIdFromEntity(vehicle))
    elseif GetResourceState('mana_audio') == 'started' then
        exports.mana_audio:PlaySoundFromEntity({
            audioBank = Config.sound.audioBank,
            audioName = Config.sound.audioName,
            audioRef = Config.sound.audioRef,
            entity = vehicle,
        })
    end
end

---@param vehicle number
---@param tyreIndex number
local function burstTyre(vehicle, tyreIndex)
    -- The tyre natives only replicate from the client that owns the entity, so
    -- either we take control of it or we ask the owner (through the server) to
    -- do it for us. Taking control fails on vehicles a player is driving.
    if not NetworkGetEntityIsNetworked(vehicle) or NetworkGetEntityOwner(vehicle) == cache.playerId then
        return burstAndSmoke(vehicle, tyreIndex)
    end

    for _ = 1, 10 do
        NetworkRequestControlOfEntity(vehicle)

        if NetworkHasControlOfEntity(vehicle) then
            return burstAndSmoke(vehicle, tyreIndex)
        end

        Wait(50)
    end

    TriggerServerEvent('noir_tireslash:slash', NetworkGetNetworkIdFromEntity(vehicle), tyreIndex)
end

---A facada tem de sair na direcao da roda, e nao do centro do carro: de costas para
---ela o golpe ia para o vazio. O giro precisa acabar ANTES da progress comecar, porque
---o TaskPlayAnim dela toma a tarefa do ped e corta a virada no meio.
---@param coords vector3 posicao do osso da roda
local function faceWheel(coords)
    local ped = cache.ped
    local pedCoords = GetEntityCoords(ped)
    local target = GetHeadingFromVector_2d(coords.x - pedCoords.x, coords.y - pedCoords.y)

    TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, Config.turnDuration)

    -- Solta assim que estiver de frente, para nao segurar o corte pelo prazo inteiro.
    local deadline = GetGameTimer() + Config.turnDuration

    while GetGameTimer() < deadline do
        if math.abs((GetEntityHeading(ped) - target + 180) % 360 - 180) < 10.0 then return end

        Wait(0)
    end
end

---@param vehicle number
---@param coords vector3
local function slashTyre(vehicle, coords)
    local tyreIndex, boneCoords = getClosestWheel(vehicle, coords)

    if not tyreIndex then return end

    if IsVehicleTyreBurst(vehicle, tyreIndex, false) then
        return lib.notify({ type = 'error', description = locale('already_slashed') })
    end

    faceWheel(boneCoords)

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

    burstAndSmoke(vehicle, tyreIndex, true)

    if cache.vehicle == vehicle then
        lib.notify({ type = 'inform', description = locale('car_slashed') })
    end
end)
