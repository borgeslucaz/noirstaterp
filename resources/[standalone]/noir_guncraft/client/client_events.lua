-- Framework detection
local function GetFramework()
    if GetResourceState('qbx_core') == 'started' then
        return 'qbox', exports.qbx_core
    elseif GetResourceState('qb-core') == 'started' then
        return 'qbcore', exports['qb-core']:GetCoreObject()
    end
end

local frameworkType, Framework = GetFramework()

-- benchData: tudo que o servidor conhece. benchEntities: só o que virou objeto
-- aqui perto. O upstream criava um CreateObject para toda bancada do servidor,
-- em todo cliente, para sempre.
local benchData = {}
local benchEntities = {}

currentBench = nil
currentBenchEntity = nil

-- Global variables for UI handlers
currentProp = nil
currentWeaponProp = nil
previewProp = nil
previewRotationX = 0.0
previewRotationZ = 0.0
attachmentMarkerActive = false
selectedWeapon = nil
weaponObjectsToCleanup = {}

---Notificação única do recurso. Sempre passa pelo framework (funciona com a UI
---fechada) e espelha na NUI quando a bancada está aberta.
local function notify(message, kind)
    if frameworkType == 'qbox' then
        Framework:Notify(message, kind)
    elseif frameworkType == 'qbcore' then
        TriggerEvent('QBCore:Notify', message, kind)
    end

    if currentBench then
        SendNUIMessage({ action = 'showNotification', data = { message = message, type = kind or 'info' } })
    end
end

---Carrega um modelo com teto de tempo. O upstream tinha
---`while not HasModelLoaded(h) do Wait(0) end` solto: modelo inválido numa
---receita travava a thread para sempre, a 0 ms.
---@param hash number
---@param timeout? number
---@return boolean
function RequestModelTimed(hash, timeout)
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

-- Limpeza dos objetos que este recurso criou.
--
-- O upstream varria GetGamePool('CObject') e apagava *qualquer* objeto a menos
-- de 2 m da bancada: prop do mapa, sacola de item dropado, objeto de outro
-- script. Os handles já são rastreados, então basta usá-los.
function ForceCleanupWeaponObjects()
    for _, obj in pairs({ currentProp, currentWeaponProp, previewProp }) do
        if obj and DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end

    for obj in pairs(weaponObjectsToCleanup) do
        if DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    weaponObjectsToCleanup = {}

    currentProp, currentWeaponProp, previewProp = nil, nil, nil
end

-- UI cleanup
function HandleCloseUI()
    SetNuiFocus(false, false)

    if CameraManager and CameraManager.stopWorkbenchView then
        CameraManager.stopWorkbenchView()
    end

    attachmentMarkerActive = false

    ForceCleanupWeaponObjects()

    selectedWeapon, currentBench, currentBenchEntity = nil, nil, nil
    previewRotationX, previewRotationZ = 0.0, 0.0
end

-- ESC handler (only when UI active)
local escThread = nil
local function startEscHandler()
    if escThread then return end
    escThread = CreateThread(function()
        while currentBench do
            if IsControlJustPressed(0, 322) then
                HandleCloseUI()
                break
            end
            Wait(0)
        end
        escThread = nil
    end)
end

-- Place bench using object_gizmo
RegisterNetEvent('crafting:placeBench', function()
    notify('G=Toggle Cursor, W=Move, R=Rotate, ENTER=Confirm (ESC not supported)', 'primary')

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local offset = coords + GetEntityForwardVector(playerPed) * 2

    local modelHash = GetHashKey(Config.BenchModel)
    if not RequestModelTimed(modelHash) then
        notify('Failed to load bench model', 'error')
        return
    end

    local obj = CreateObject(modelHash, offset.x, offset.y, offset.z, false, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not obj or not DoesEntityExist(obj) then
        notify('Failed to create bench', 'error')
        return
    end

    local data = exports.object_gizmo:useGizmo(obj)

    if DoesEntityExist(obj) then
        DeleteObject(obj)
    end

    if not data or not data.position then
        notify('Bench placement cancelled', 'error')
        return
    end

    -- O serial e o consumo do item são resolvidos no servidor; mandar o slot
    -- daqui era o que permitia colocar bancada sem gastar item.
    TriggerServerEvent('crafting:saveBench',
        data.position.x, data.position.y, data.position.z, (data.rotation and data.rotation.z) or 0.0)
end)

-- Streaming das bancadas
local function despawnBench(id)
    local entity = benchEntities[id]
    if not entity then return end
    if DoesEntityExist(entity) then
        RemoveTargetFromEntity(entity, id)
        DeleteObject(entity)
    end
    benchEntities[id] = nil
end

local function spawnBench(id, data)
    local hash = GetHashKey(data.model)
    if not RequestModelTimed(hash) then return end

    local object = CreateObject(hash, data.x, data.y, data.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not object or not DoesEntityExist(object) then return end

    SetEntityHeading(object, data.heading)
    FreezeEntityPosition(object, true)

    benchEntities[id] = object
    AddTargetToEntity(object, id)
end

RegisterNetEvent('crafting:loadBenches', function(rows)
    local seen = {}

    for _, data in pairs(rows or {}) do
        seen[data.id] = true
        local existing = benchData[data.id]
        if existing and benchEntities[data.id]
            and (existing.x ~= data.x or existing.y ~= data.y or existing.z ~= data.z or existing.heading ~= data.heading) then
            despawnBench(data.id)
        end
        benchData[data.id] = data
    end

    for id in pairs(benchData) do
        if not seen[id] then
            despawnBench(id)
            benchData[id] = nil
        end
    end
end)

CreateThread(function()
    local far = Config.StreamDistance + 25.0
    while true do
        local coords = GetEntityCoords(PlayerPedId())

        for id, data in pairs(benchData) do
            local distance = #(coords - vector3(data.x, data.y, data.z))
            if distance <= Config.StreamDistance then
                if not benchEntities[id] then spawnBench(id, data) end
            elseif distance > far and benchEntities[id] then
                despawnBench(id)
            end
        end

        Wait(1500)
    end
end)

-- Event handlers
RegisterNetEvent('crafting:openMaterials', function()
    local benchId = GetClosestBenchId()
    if benchId then
        TriggerServerEvent('crafting:openStash', benchId, 'materials')
    end
end)

RegisterNetEvent('crafting:openBlueprints', function()
    local benchId = GetClosestBenchId()
    if benchId then
        TriggerServerEvent('crafting:openStash', benchId, 'blueprints')
    end
end)

RegisterNetEvent('crafting:openStorage', function()
    local benchId = GetClosestBenchId()
    if benchId then
        TriggerServerEvent('crafting:openStash', benchId, 'storage')
    end
end)

RegisterNetEvent('crafting:openCrafting', function()
    local benchId = GetClosestBenchId()
    if not benchId then return end

    currentBench = benchId
    currentBenchEntity = benchEntities[benchId]
    startEscHandler()

    if CameraManager and CameraManager.startWorkbenchView then
        if CameraManager.startWorkbenchView(currentBenchEntity) then
            Wait(Config.WorkbenchCamera.transitionTime or 1000)
        end
    end

    SetNuiFocus(true, true)
    TriggerServerEvent('crafting:getCraftingData', benchId)
end)

-- Handle crafting data from server
RegisterNetEvent('crafting:showCrafting', function(data)
    SendNUIMessage({ action = 'showCrafting', data = data })
end)

RegisterNetEvent('noir_guncraft:showNotification', function(message, kind)
    notify(message, kind)
end)

-- Target system functions
function AddTargetToEntity(entity, benchId)
    local options = {
        {
            name = 'materials_' .. benchId,
            event = 'crafting:openMaterials',
            icon = 'fas fa-box',
            label = 'Open Materials'
        },
        {
            name = 'blueprints_' .. benchId,
            event = 'crafting:openBlueprints',
            icon = 'fas fa-scroll',
            label = 'Open Blueprints'
        },
        {
            name = 'storage_' .. benchId,
            event = 'crafting:openStorage',
            icon = 'fas fa-archive',
            label = 'Open Storage'
        },
        {
            name = 'crafting_' .. benchId,
            event = 'crafting:openCrafting',
            icon = 'fas fa-hammer',
            label = 'Open Crafting'
        }
    }

    local target = Systems.target or Systems.detectTarget()
    if target == 'ox_target' then
        exports.ox_target:addLocalEntity(entity, options)
    elseif target == 'qb-target' then
        local success = pcall(function()
            exports['qb-target']:AddTargetEntity(entity, { options = options, distance = 2.0 })
        end)
        if not success and Config.Debug then
            print('[noir_guncraft] qb-target export not found, skipping target setup')
        end
    elseif target == 'interact' then
        exports.interact:AddLocalEntityInteraction({
            entity = entity,
            name = 'crafting_bench_' .. benchId,
            id = 'crafting_bench_' .. benchId,
            distance = 4.0,
            interactDst = 4.0,
            offset = vector3(0.0, 0.0, 0.9),
            options = options
        })
    end
end

function RemoveTargetFromEntity(entity, benchId)
    local target = Systems.target or Systems.detectTarget()
    if target == 'ox_target' then
        exports.ox_target:removeLocalEntity(entity)
    elseif target == 'qb-target' then
        pcall(function()
            exports['qb-target']:RemoveTargetEntity(entity)
        end)
    elseif target == 'interact' then
        exports.interact:RemoveLocalEntityInteraction(entity)
    end
end

-- Helper function to get closest bench ID
function GetClosestBenchId()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestBench, closestDistance = nil, 3.0

    for id, entity in pairs(benchEntities) do
        if DoesEntityExist(entity) then
            local distance = #(playerCoords - GetEntityCoords(entity))
            if distance < closestDistance then
                closestDistance = distance
                closestBench = id
            end
        end
    end

    return closestBench
end

-- Commands
RegisterCommand('pickupbench', function()
    local benchId = GetClosestBenchId()
    if not benchId then
        notify('No bench nearby', 'error')
        return
    end
    TriggerServerEvent('crafting:pickupBench', benchId)
end)

RegisterCommand('refreshcrafting', function()
    if currentBench then
        TriggerServerEvent('crafting:getCraftingData', currentBench)
    end
end)

RegisterCommand('refundbench', function(_, args)
    if not args[1] then
        notify('Usage: /refundbench [serial]', 'error')
        return
    end
    TriggerServerEvent('crafting:refundBench', args[1])
end)

-- Initialize
CreateThread(function()
    while not Systems or not Systems.target do Wait(100) end
    TriggerServerEvent('crafting:requestBenches')
end)

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    HandleCloseUI()

    for id in pairs(benchEntities) do
        despawnBench(id)
    end
    benchData = {}

    selectedWeapon = nil
    attachmentMarkerActive = false
    currentBench, currentBenchEntity = nil, nil
end)
