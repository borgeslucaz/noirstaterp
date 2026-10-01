---Objetos do porta-malas, spike strip e escudo balístico.

local Config = require 'config.shared'
local Departments = require 'shared.departments'
local Integrations = require 'client.integrations'
local Util = require 'client.util'
local Placement = require 'client.placement'

local shieldProps = {}
local holdingShield = false
local aimBeforeShield = nil

local function onDuty() return Departments.isOnDutyPolice(Integrations.getJob()) end

local function fail(result) Integrations.notify(Util.errorText(result and result.code), 'error') end

-- Objetos --------------------------------------------------------------------------

-- Alcance do posicionamento; o servidor aceita até 6 m (distance.objectPlace).
local OBJECT_RANGE = 5.5

local function placeObject(entry)
    local spot = Placement.object(entry.model, OBJECT_RANGE)
    if not spot then return end
    TaskTurnPedToFaceCoord(cache.ped, spot.x, spot.y, spot.z, 600)
    Wait(600)
    local done = lib.progressBar({
        duration = 1500,
        label = locale('progress.placing_object'),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'anim@narcotics@trash', clip = 'drop_front' },
    })
    if not done then return end
    local result = lib.callback.await('noir_police:server:placeObject', false, entry.id,
        { spot.x, spot.y, spot.z }, spot.w)
    if not result or not result.ok then return fail(result) end
end

local function openTrunkMenu()
    local options = {}
    for _, entry in ipairs(Config.objects) do
        options[#options + 1] = { title = entry.label, icon = 'fa-solid fa-road-barrier', onSelect = function() placeObject(entry) end }
    end
    lib.registerContext({ id = 'noir_police_trunk', title = locale('trunk.title'), options = options })
    lib.showContext('noir_police_trunk')
end

Integrations.addGlobalVehicle({
    {
        name = 'noir_police:equipment:trunk',
        icon = 'fa-solid fa-box-open',
        label = locale('target.trunk_objects'),
        bones = { 'boot' },
        distance = 2.0,
        canInteract = function(entity) return onDuty() and Entity(entity).state.noirPoliceFleet ~= nil end,
        onSelect = openTrunkMenu,
    },
})

local objectModels = {}
for _, entry in ipairs(Config.objects) do objectModels[#objectModels + 1] = entry.model end

Integrations.addModel(objectModels, {
    {
        name = 'noir_police:equipment:removeObject',
        icon = 'fa-solid fa-trash',
        label = locale('target.remove_object'),
        distance = 2.0,
        canInteract = function(entity) return onDuty() and Entity(entity).state.noirPoliceObject == true end,
        onSelect = function(data)
            local result = lib.callback.await('noir_police:server:removeObject', false, ObjToNet(data.entity))
            if not result or not result.ok then return fail(result) end
        end,
    },
})

-- Spike strip ----------------------------------------------------------------------

exports('useSpikestrip', function()
    if cache.vehicle then return Integrations.notify(Util.errorText('in_vehicle'), 'error') end
    local count = Integrations.itemCount(Config.items.spikestrip)
    if count < 1 then return end
    local size = 1
    if count > 1 then
        local options = {}
        for index = 1, math.min(count, Config.spikes.maxPerDeploy) do
            options[#options + 1] = { value = tostring(index), label = tostring(index) }
        end
        local input = lib.inputDialog(locale('spikes.deploy_title'), {
            { type = 'select', label = locale('spikes.size'), options = options, required = true, default = '1' },
        })
        if not input then return end
        size = tonumber(input[1]) or 1
    end

    local done = lib.progressBar({
        duration = 1000 * size,
        label = locale('progress.placing_spikes'),
        canCancel = true,
        disable = { car = true, combat = true },
        anim = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d' },
    })
    if not done then return end

    local first = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 4.15 * size - 1.0, 0.0)
    local second = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 1.0, 0.0)
    local function ground(point)
        local found, z = GetGroundZFor_3dCoord(point.x, point.y, point.z + 1.0, false)
        return { point.x, point.y, found and z or point.z }
    end
    local result = lib.callback.await('noir_police:server:deploySpikes', false, ground(first), ground(second), size)
    if not result or not result.ok then return fail(result) end
end)

Integrations.addModel(Config.spikes.model, {
    {
        name = 'noir_police:equipment:pickSpikes',
        icon = 'fa-solid fa-hand',
        label = locale('target.pick_spikes'),
        distance = 2.5,
        canInteract = function(entity) return Entity(entity).state.noirPoliceSpike == true end,
        onSelect = function(data)
            local done = lib.progressBar({
                duration = 1500,
                label = locale('progress.picking_spikes'),
                canCancel = true,
                disable = { car = true, move = true },
                anim = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d' },
            })
            if not done then return end
            local result = lib.callback.await('noir_police:server:retrieveSpikes', false, ObjToNet(data.entity))
            if not result or not result.ok then return fail(result) end
        end,
    },
})

---Estoura pneu de quem passa por cima. Roda no cliente de cada motorista perto.
local wheelBones = { [0] = 'wheel_lf', [1] = 'wheel_rf', [2] = 'wheel_lm1', [3] = 'wheel_rm1', [4] = 'wheel_lr', [5] = 'wheel_rr' }

CreateThread(function()
    while true do
        local sleep = 1000
        local vehicle = cache.vehicle
        if vehicle and cache.seat == -1 then
            sleep = 250
            local coords = GetEntityCoords(vehicle)
            local spike = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, Config.spikes.model, false, false, false)
            if spike ~= 0 and Entity(spike).state.noirPoliceSpike then
                sleep = 0
                local a = GetOffsetFromEntityInWorldCoords(spike, 0.0, -1.84, 0.0)
                local b = GetOffsetFromEntityInWorldCoords(spike, 0.0, 1.84, 0.0)
                if IsEntityTouchingEntity(vehicle, spike) then
                    for index, bone in pairs(wheelBones) do
                        local boneIndex = GetEntityBoneIndexByName(vehicle, bone)
                        if boneIndex ~= -1 and not IsVehicleTyreBurst(vehicle, index, false) then
                            local wheel = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                            local ab, aw = b - a, wheel - a
                            local t = math.max(0.0, math.min(1.0, (aw.x * ab.x + aw.y * ab.y + aw.z * ab.z) / (ab.x ^ 2 + ab.y ^ 2 + ab.z ^ 2)))
                            if #(wheel - (a + ab * t)) < 1.0 and math.random(10) > 6 then
                                SetVehicleTyreBurst(vehicle, index, false, 500.0)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Escudo balístico -----------------------------------------------------------------

-- Índices de osso crus, como no ND (não são tags de GetPedBoneIndex): as posições foram
-- afinadas para eles. 38 = costas, 62 = antebraço esquerdo.
local shieldPositions = {
    back = { bone = 38, pos = vec3(0.0, -0.25, 0.0), rot = vec3(-10.0, 90.0, 0.0), order = 1 },
    hand = { bone = 62, pos = vec3(-0.05, -0.06, -0.09), rot = vec3(-35.0, 180.0, 40.0), order = 0 },
}

local function deleteShieldProp(serverId)
    local prop = shieldProps[serverId]
    shieldProps[serverId] = nil
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, false)
        SetEntityAsMissionEntity(prop, true, true)
        DeleteObject(prop)
    end
end

local function createShieldProp(serverId, where)
    deleteShieldProp(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end
    local ped = GetPlayerPed(player)
    local position = shieldPositions[where]
    if not position or ped == 0 or not IsModelInCdimage(Config.shield.model) then return end
    if not pcall(lib.requestModel, Config.shield.model, 3000) then return end
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(Config.shield.model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(Config.shield.model)
    AttachEntityToEntity(prop, ped, position.bone, position.pos.x, position.pos.y, position.pos.z,
        position.rot.x, position.rot.y, position.rot.z, false, false, true, true, position.order, true)
    SetEntityCollision(prop, false, true)
    shieldProps[serverId] = prop
end

-- O handler só agenda; criar e apagar prop fica fora dele.
AddStateBagChangeHandler('noirPoliceShield', nil, function(bagName, _, value)
    local player = GetPlayerFromStateBagName(bagName)
    if player == 0 then return end
    local serverId = GetPlayerServerId(player)
    SetTimeout(0, function()
        if value then createShieldProp(serverId, value) else deleteShieldProp(serverId) end
    end)
end)

-- Jogador que saiu de escopo ou desconectou não dispara o state bag: varre os props.
CreateThread(function()
    while true do
        Wait(5000)
        for serverId in pairs(shieldProps) do
            if GetPlayerFromServerId(serverId) == -1 then deleteShieldProp(serverId) end
        end
    end
end)

local function setShield(where)
    LocalPlayer.state:set('noirPoliceShield', where or false, true)
    SetPlayerSprint(cache.playerId, where ~= 'hand')
end

local function lowerShield()
    holdingShield = false
    StopAnimTask(cache.ped, 'combat@gestures@gang@pistol_1h@beckon', '-90', 2.0)
    Integrations.setAimAnim(aimBeforeShield or 'default')
    aimBeforeShield = nil
    LocalPlayer.state:set('blockHandsUp', false, false)
    setShield(Integrations.itemCount(Config.items.shield) > 0 and 'back' or false)
end

local function raiseShield()
    if holdingShield then return lowerShield() end
    local hasWeapon, weapon = GetCurrentPedWeapon(cache.ped, true)
    if not hasWeapon or GetWeapontypeGroup(weapon) ~= 416676503 then
        return Integrations.notify(Util.errorText('needs_pistol'), 'error')
    end
    holdingShield = true
    LocalPlayer.state:set('blockHandsUp', true, false)
    -- Mira de uma mão (estilo "gang") pelo ND_GunAnims, como no ND: na mira normal a mão
    -- esquerda vai para a arma e larga o escudo. O ND_GunAnims replica para quem vê.
    aimBeforeShield = Integrations.getAimAnim()
    Integrations.setAimAnim('gang')
    setShield('hand')
    CreateThread(function()
        local dict = 'combat@gestures@gang@pistol_1h@beckon'
        Util.loadDict(dict)
        while holdingShield do
            DisableControlAction(0, 36, true)
            if not cache.weapon or IsDisabledControlJustPressed(0, 36) then lowerShield() break end
            if not IsEntityPlayingAnim(cache.ped, dict, '-90', 3) then
                TaskPlayAnim(cache.ped, dict, '-90', 8.0, -8.0, -1, 50, 0.0, false, false, false)
            end
            -- Andar agachado com o escudo, como no ND (sem isso o corpo gira e o escudo abre).
            if not GetPedStealthMovement(cache.ped) then
                ForcePedMotionState(cache.ped, 0x422d7a25, true, 1, false)
            end
            Wait(0)
        end
    end)
end

exports('useShield', function(data)
    Integrations.useItem(data, function(used) if used then raiseShield() end end)
end)

AddEventHandler('ox_inventory:updateInventory', function()
    if holdingShield then return end
    local hasShield = Integrations.itemCount(Config.items.shield) > 0
    local current = LocalPlayer.state.noirPoliceShield
    if hasShield and current ~= 'back' then setShield('back')
    elseif not hasShield and current then setShield(false) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if holdingShield then Integrations.setAimAnim(aimBeforeShield or 'default') end
    for serverId in pairs(shieldProps) do deleteShieldProp(serverId) end
    LocalPlayer.state:set('noirPoliceShield', false, true)
end)
