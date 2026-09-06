-- ============================================================
-- CLIENT MAIN — Estado, ponte NUI, sessão confirmada pelo servidor
-- e fluxo físico canônico (spawns, carreta, destino, devolução).
-- ============================================================

-- State Variables
local npcPed = false
local illegalNpcPed = false
nuiReady = false
local blipsList = {}
local returnBlip = nil
cam = false
local routeBlip = false
local truckBlip = false
local trailerBlip = false
local carryBoxProp = false
local isProcessingJob = false
local isJobActive = false
local isPauseMenuOpen = false
local truckVehicle = false
local trailerVehicle = false
local attachedObject = false
local isIllegalMissionActive = false
illegal = false
local selectedRoute = nil
local selectedMission = nil
local currentPhase = 0
local trailerAttached = false
local isAcceptedIllegal = false
local isPendingCall = false
local activeJobToken = 0
local activeSession = nil      -- { sessionId, missionId, routeIndex, tier, truckModel, trailerSpawnIndex }
local isMenuOpen = false
local isEditingHud = false

-- ============================================================
-- CORE INIT
-- ============================================================

CreateThread(function()
  while Core == nil do
    Wait(0)
  end

  Core = GetCore()
  Config.Framework = select(2, GetCore())

  InitNPCInteraction()
  SetPlayerJob()
end)

-- ============================================================
-- RPC (request/response por eventos)
-- ============================================================

local rpcPending = {}
local rpcNextId = 0

--- Envia um pedido ao servidor e aguarda a resposta (ou timeout).
--- @param name string
--- @param data any
--- @param timeoutMs number|nil
--- @return table
function Rpc(name, data, timeoutMs)
  rpcNextId = rpcNextId + 1
  local id = rpcNextId
  local p = promise.new()
  rpcPending[id] = p

  TriggerServerEvent('peak-trucking:rpc', id, name, data or {})

  SetTimeout(timeoutMs or 8000, function()
    if rpcPending[id] then
      rpcPending[id] = nil
      p:resolve({ ok = false, error = 'timeout', message = Config.Language.err_timeout })
    end
  end)

  return Citizen.Await(p)
end

RegisterNetEvent('peak-trucking:rpcResult')
AddEventHandler('peak-trucking:rpcResult', function(id, result)
  local p = rpcPending[id]
  if p then
    rpcPending[id] = nil
    p:resolve(result or { ok = false, error = 'empty' })
  end
end)

-- ============================================================
-- NUI BRIDGE
-- ============================================================

function NuiMessage(action, payload)
  WaitNui()
  SendNUIMessage({
    action = action,
    payload = payload
  })
end

local function GetFuel(vehicle)
  if not DoesEntityExist(vehicle) then return 0 end

  if GetResourceState('ox_fuel') == 'started' then
    return Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)
  end

  local system = Config.Fuel
  if system == 'ox_fuel' then
    return Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)
  elseif system == 'lc_fuel' then
    local ok, fuel = pcall(function() return exports['lc_fuel']:GetFuel(vehicle) end)
    return ok and fuel or GetVehicleFuelLevel(vehicle)
  elseif system == 'legacyfuel' or system == 'LegacyFuel' then
    return exports.LegacyFuel:GetFuel(vehicle)
  elseif system == 'ps-fuel' then
    return exports['ps-fuel']:GetFuel(vehicle)
  elseif system == 'ti_fuel' then
    return exports['ti_fuel']:getFuel(vehicle)
  elseif system == 'okokGasStation' then
    return exports['okokGasStation']:GetFuel(vehicle)
  else
    return GetVehicleFuelLevel(vehicle)
  end
end

function WaitNui()
  while not nuiReady do
    Wait(0)
  end
end

local function ResolveNuiCallback(cb, payload)
  if cb then
    cb(payload or { ok = true })
  end
end

local function ReleaseMenuCameraAndFocus()
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)

  if DoesCamExist(cam) then
    SetCamActive(cam, false)
  end

  RenderScriptCams(false, true, 500, true, true)

  if DoesCamExist(cam) then
    DestroyCam(cam, true)
  end

  cam = false
end

local function ContractConfigPayload()
  return {
    companies = Config.Companies,
    reputationTiers = Config.Reputation.tiers,
    levelBands = Config.ContractBoard.global.levelBands,
    starterMissions = Config.ContractBoard.starterMissions,
    routeMeta = Config.RouteMeta,
    rotationMinutes = Config.ContractBoard.rotationMinutes,
  }
end

--- Re-pushes all one-shot NUI state whenever the NUI announces readiness.
local function ResyncNuiState()
  CreateThread(function()
    WaitCore()
    NuiMessage("setXP", Config.XP)
    NuiMessage("setLanguage", Config.Language)
    NuiMessage("setTrucks", Config.Trucks)
    NuiMessage("setTrucksCopy", Config.Trucks)
    NuiMessage("setKeyBinds", Config.KeyPressed)
    NuiMessage("set_missions", Config.Missions)
    NuiMessage("setContractConfig", ContractConfigPayload())
    TriggerServerEvent("peak-trucking:LoadPlayerData")
  end)
end

RegisterNUICallback("ready", function(data, cb)
  local wasReady = nuiReady
  nuiReady = true
  ResolveNuiCallback(cb)
  if not wasReady then
    ResyncNuiState()
  end
end)

-- ============================================================
-- NPC SPAWNING
-- ============================================================

local function LoadPedModel(model, label)
  local modelHash = type(model) == 'string' and GetHashKey(model) or model

  if not modelHash or not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
    Peak.Utils.Warn(("Invalid %s model:"):format(label), model, "hash:", modelHash)
    return nil
  end

  RequestModel(modelHash)
  local timeout = 0
  while not HasModelLoaded(modelHash) and timeout < 500 do
    Wait(10)
    timeout = timeout + 1
  end

  if not HasModelLoaded(modelHash) then
    Peak.Utils.Warn(("Failed to load %s model:"):format(label), model, "hash:", modelHash)
    return nil
  end

  return modelHash
end

function SpawnPed()
  if DoesEntityExist(npcPed) then
    DeleteEntity(npcPed)
  end

  local model = LoadPedModel(Config.NpcLocation.model, "NPC")
  if not model then return end

  local coords = Config.NpcLocation.coords
  npcPed = CreatePed(0, model, coords.x, coords.y, coords.z, coords.w, false, false)
  SetModelAsNoLongerNeeded(model)
  FreezeEntityPosition(npcPed, true)
  SetEntityInvincible(npcPed, true)
  SetBlockingOfNonTemporaryEvents(npcPed, true)
end

function SpawnIllegalPed()
  if DoesEntityExist(illegalNpcPed) then
    DeleteEntity(illegalNpcPed)
  end

  local model = LoadPedModel(Config.IllegalNPC.model, "Illegal NPC")
  if not model then return end

  local coords = Config.IllegalNPC.coords
  illegalNpcPed = CreatePed(0, model, coords.x, coords.y, coords.z, coords.w, false, false)
  SetModelAsNoLongerNeeded(model)
  FreezeEntityPosition(illegalNpcPed, true)
  SetEntityInvincible(illegalNpcPed, true)
  SetBlockingOfNonTemporaryEvents(illegalNpcPed, true)
end

AddEventHandler("onResourceStop", function(resourceName)
  if GetCurrentResourceName() ~= resourceName then
    return
  end

  if DoesEntityExist(npcPed) then DeleteEntity(npcPed) end
  if DoesEntityExist(illegalNpcPed) then DeleteEntity(illegalNpcPed) end
end)

CreateThread(function()
  while not Peak.Client.Ready do
    Wait(100)
  end

  SpawnPed()
  SpawnIllegalPed()
end)

CreateThread(function()
  while not nuiReady do
    Wait(2000)
    if NetworkIsSessionStarted() then
      SendNUIMessage({ action = "checknui" })
    end
  end
end)

-- ============================================================
-- MENU / MERCADO GLOBAL
-- ============================================================

local function PushSnapshot()
  local res = Rpc('getDispatchBoard', {})
  if res and res.ok and res.snapshot then
    NuiMessage("dispatchSnapshot", res.snapshot)
    return true
  end
  NuiMessage("dispatchSnapshot", nil)
  if res and res.message then createNotification(res.message) end
  return false
end

RegisterNUICallback("close", function(data, cb)
  isEditingHud = false
  isMenuOpen = false
  NuiMessage("toggle_hud_edit", { editing = false })
  ReleaseMenuCameraAndFocus()
  ResolveNuiCallback(cb)
end)

RegisterNetEvent("peak-trucking:OpenMenu")
AddEventHandler("peak-trucking:OpenMenu", function()
  if canOpenMenu() then
    TriggerServerEvent("peak-trucking:CheckDailyMission")
    isMenuOpen = true
    NuiMessage("open")
    SetNuiFocus(true, true)
    CreateCamera()
    CreateThread(function() PushSnapshot() end)
  else
    createNotification(Config.Language.notaccessjob)
  end
end)

RegisterNUICallback("getDispatchBoard", function(data, cb)
  local res = Rpc('getDispatchBoard', {})
  cb(res or { ok = false })
end)

RegisterNUICallback("refreshDispatchBoard", function(data, cb)
  local res = Rpc('getDispatchBoard', {})
  cb(res or { ok = false })
end)

RegisterNUICallback("getLeaderboard", function(data, cb)
  local res = Rpc('getLeaderboard', { metric = data and data.metric or 'level' })
  cb(res or { ok = false, data = {} })
end)

RegisterNUICallback("reportClosed", function(data, cb)
  ResolveNuiCallback(cb)
end)

-- Eventos do servidor → NUI
RegisterNetEvent("peak-trucking:rotationChanged")
AddEventHandler("peak-trucking:rotationChanged", function(payload)
  NuiMessage("rotationChanged", payload)
  if isMenuOpen then
    CreateThread(function() PushSnapshot() end)
  end
end)

RegisterNetEvent("peak-trucking:globalOfferClaimed")
AddEventHandler("peak-trucking:globalOfferClaimed", function(payload)
  NuiMessage("globalOfferClaimed", payload)
end)

RegisterNetEvent("peak-trucking:jobResult")
AddEventHandler("peak-trucking:jobResult", function(result)
  NuiMessage("jobResult", result)
end)

RegisterNetEvent("peak-trucking:jobFailed")
AddEventHandler("peak-trucking:jobFailed", function(payload)
  NuiMessage("jobFailed", payload)
  -- Falha decidida pelo servidor (ex.: técnica) enquanto o job local ainda roda
  if activeSession and payload and payload.sessionId == activeSession.sessionId and isJobActive then
    CancelActiveJob("server_" .. tostring(payload.reason or "failed"), false, true)
    if payload.status == 'failed_system' then
      createNotification(Config.Language.job_failed_system)
    end
  end
end)

-- ============================================================
-- BLIPS & CAMERA
-- ============================================================

function CreateBlip(coords, sprite, color, scale, name, show, isEntity, entity)
  if show then
    local blip = nil
    if isEntity then
      blip = AddBlipForEntity(entity)
    else
      blip = AddBlipForCoord(coords)
    end

    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name)
    EndTextCommandSetBlipName(blip)

    return blip
  end
end

local function SetRouteBlip(x, y, z)
  if DoesBlipExist(routeBlip) then
    RemoveBlip(routeBlip)
  end
  routeBlip = AddBlipForCoord(x, y, z)
  SetBlipColour(routeBlip, 5)
  SetBlipRoute(routeBlip, true)
  SetBlipRouteColour(routeBlip, 5)
end

function Close()
  isMenuOpen = false
  NuiMessage("close")
  ReleaseMenuCameraAndFocus()
end

CreateThread(function()
  Wait(2000)

  local npcCoords = Config.NpcLocation.coords
  local npcBlip = CreateBlip(
    vector3(npcCoords.x, npcCoords.y, npcCoords.z),
    Config.NpcLocation.blip.sprite,
    Config.NpcLocation.blip.color,
    Config.NpcLocation.blip.scale,
    Config.NpcLocation.blip.name,
    Config.NpcLocation.blip.show
  )
  table.insert(blipsList, npcBlip)
end)

-- ============================================================
-- VEHICLE & OBJECT SPAWNING
-- ============================================================

function SpawnVehicle(modelName, coords, teleportInto, heading, giveKey)
  local modelHash = GetHashKey(modelName)
  RequestModel(modelHash)

  local timeout = 0
  while not HasModelLoaded(modelHash) and timeout < 1000 do
    Wait(10)
    timeout = timeout + 1
  end
  if not HasModelLoaded(modelHash) then
    return 0
  end

  local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, true, true)

  if giveKey then
    Config.GiveVehicleKey(GetVehicleNumberPlateText(vehicle), GetHashKey(vehicle), vehicle)
  end

  Config.SetVehicleFuel(vehicle, 100.0)

  if heading then
    SetEntityHeading(vehicle, heading)
  end

  if teleportInto then
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
  end

  return vehicle
end

function SpawnObject(modelName, coords)
  local modelHash = GetHashKey(modelName)
  RequestModel(modelHash)

  while not HasModelLoaded(modelHash) do
    Wait(0)
  end

  local object = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, true)
  return object
end

-- ============================================================
-- JOB INFO & PROP HELPERS
-- ============================================================

function IsVehicleUnusable(veh)
  if not veh or not DoesEntityExist(veh) then return true end
  if IsEntityDead(veh) then return true end
  if IsEntityInWater(veh) then return true end
  if IsEntityOnFire(veh) then return true end
  if GetVehicleEngineHealth(veh) <= 0.0 then return true end
  if GetVehicleBodyHealth(veh) <= 0.0 then return true end
  if GetEntityHealth(veh) <= 0 then return true end
  if not IsVehicleDriveable(veh, false) then return true end
  return false
end

function IsEntityUnusable(entity)
  if not entity or not DoesEntityExist(entity) then return true end
  if IsEntityAVehicle(entity) then
    return IsVehicleUnusable(entity)
  end
  if IsEntityDead(entity) then return true end
  if IsEntityInWater(entity) then return true end
  if IsEntityOnFire(entity) then return true end
  if GetEntityHealth(entity) <= 0 then return true end
  return false
end

function setJobInfo(key, value)
  NuiMessage("setJobInfo", {
    key = key,
    value = value
  })
end

local function RemoveTrackedBlip(blip)
  if blip and DoesBlipExist(blip) then
    RemoveBlip(blip)
  end
end

local function DeleteTrackedEntity(entity)
  if entity and DoesEntityExist(entity) then
    if IsEntityAVehicle(entity) then
      DeleteVehicle(entity)
    else
      DeleteEntity(entity)
    end
  end
end

local function CleanupCarryBox()
  if DoesEntityExist(carryBoxProp) then
    DeleteEntity(carryBoxProp)
  end
  carryBoxProp = false
  ClearPedTasks(PlayerPedId())
end

--- Encerra o job local. `serverDecided` evita reenviar cancelamento ao servidor.
function CancelActiveJob(reason, notifyPlayer, serverDecided)
  local hadJob = isJobActive or DoesEntityExist(truckVehicle) or DoesEntityExist(trailerVehicle) or DoesEntityExist(attachedObject)

  if not hadJob then
    if notifyPlayer then
      createNotification(Config.Language.no_active_job)
    end
    return false
  end

  activeJobToken = activeJobToken + 1
  setJobInfo("started", false)
  setJobInfo("attachedTrailer", false)
  setJobInfo("boxProgress", nil)
  setJobInfo("tier", nil)

  isJobActive = false
  isProcessingJob = false
  isIllegalMissionActive = false
  isAcceptedIllegal = false
  isPendingCall = false
  illegal = false
  trailerAttached = false
  currentPhase = 0

  CleanupCarryBox()

  if DoesEntityExist(truckVehicle) then
    Config.RemoveVehiclekey(GetVehicleNumberPlateText(truckVehicle), GetHashKey(truckVehicle), truckVehicle)
  end

  DeleteTrackedEntity(attachedObject)
  DeleteTrackedEntity(trailerVehicle)
  DeleteTrackedEntity(truckVehicle)

  attachedObject = false
  trailerVehicle = false
  truckVehicle = false

  DeleteWaypoint()
  RemoveTrackedBlip(routeBlip)
  RemoveTrackedBlip(returnBlip)
  RemoveTrackedBlip(truckBlip)
  RemoveTrackedBlip(trailerBlip)
  routeBlip = false
  returnBlip = false
  truckBlip = false
  trailerBlip = false

  local session = activeSession
  activeSession = nil

  if not serverDecided and session then
    TriggerServerEvent("peak-trucking:session:cancel", session.sessionId, reason or "cancelled")
  end

  if notifyPlayer then
    createNotification(Config.Language.job_cancelled)
  end

  return true
end

function LoadPropDict(propName)
  while not HasModelLoaded(GetHashKey(propName)) do
    RequestModel(GetHashKey(propName))
    Wait(10)
  end
end

function AttachBoxToPed()
  local propName = "hei_prop_heist_box"
  local boneId = 60309
  local offset = { 0.025, 0.08, 0.255, -145.0, 290.0, 0.0 }

  local playerPed = PlayerPedId()
  local playerCoords = GetEntityCoords(playerPed)

  if not HasModelLoaded(propName) then
    LoadPropDict(propName)
  end

  carryBoxProp = CreateObject(GetHashKey(propName), playerCoords.x, playerCoords.y, playerCoords.z + 0.2, true, true, true)

  AttachEntityToEntity(
    carryBoxProp,
    playerPed,
    GetPedBoneIndex(playerPed, boneId),
    offset[1], offset[2], offset[3],
    offset[4], offset[5], offset[6],
    true, true, false, true, 1, true
  )

  SetModelAsNoLongerNeeded(propName)

  while not HasAnimDictLoaded("anim@heists@box_carry@") do
    RequestAnimDict("anim@heists@box_carry@")
    Citizen.Wait(100)
  end

  TaskPlayAnim(playerPed, "anim@heists@box_carry@", "idle", 4.0, 4.0, -1, 51, 0, false, false, false)
end

-- Pause Menu Handler
CreateThread(function()
  while true do
    if IsPauseMenuActive() then
      if not isPauseMenuOpen and isJobActive then
        isPauseMenuOpen = true
        setJobInfo("started", false)
      end
    end

    if not IsPauseMenuActive() then
      if isPauseMenuOpen and isJobActive then
        isPauseMenuOpen = false
        setJobInfo("started", true)
      end
    end

    Wait(1500)
  end
end)

RegisterNUICallback("stopJob", function(data, cb)
  CancelActiveJob("player_cancelled", true)
  ResolveNuiCallback(cb)
end)

RegisterCommand(Config.CancelJobCommand or "canceltrucking", function()
  CancelActiveJob("player_command", true)
end, false)

CreateThread(function()
  TriggerEvent("chat:addSuggestion", "/" .. (Config.CancelJobCommand or "canceltrucking"), "Cancel active delivery")
end)

-- ============================================================
-- INÍCIO DO CONTRATO (NUI envia apenas identificadores)
-- ============================================================

RegisterNUICallback("startContract", function(data, cb)
  if isProcessingJob then
    ResolveNuiCallback(cb, { ok = false, error = "processing" })
    return
  end

  if isJobActive then
    createNotification(Config.Language.already_active_job)
    ResolveNuiCallback(cb, { ok = false, error = "active_job", message = Config.Language.already_active_job })
    return
  end

  if type(data) ~= 'table' or not data.rotationId or not data.offerId or not data.truckModel then
    ResolveNuiCallback(cb, { ok = false, error = "invalid", message = Config.Language.err_invalid })
    return
  end

  isProcessingJob = true

  local res = Rpc('startContract', {
    rotationId = tostring(data.rotationId),
    offerId = tostring(data.offerId),
    truckModel = tostring(data.truckModel),
  }, 10000)

  if not res or not res.ok then
    isProcessingJob = false
    local message = res and res.message or Config.Language.err_timeout
    createNotification(message)
    ResolveNuiCallback(cb, { ok = false, error = res and res.error or "timeout", message = message })
    return
  end

  -- Sessão confirmada pelo servidor: resolve o catálogo canônico localmente.
  local mission, route = ResolveCatalogRoute(res.missionId, res.routeIndex)
  if not mission or not route then
    isProcessingJob = false
    TriggerServerEvent("peak-trucking:session:cancel", res.sessionId, "spawn_catalog_missing")
    ResolveNuiCallback(cb, { ok = false, error = "catalog" })
    return
  end

  activeSession = {
    sessionId = res.sessionId,
    missionId = res.missionId,
    routeIndex = res.routeIndex,
    tier = res.tier,
    truckModel = res.truckModel,
    trailerSpawnIndex = res.trailerSpawnIndex,
  }

  ResolveNuiCallback(cb, { ok = true, sessionId = res.sessionId })
  NuiMessage("jobSessionStarted", { sessionId = res.sessionId, offerId = data.offerId, tier = res.tier })

  RunContract(mission, route, activeSession)

  Wait(3000)
  isProcessingJob = false
end)

--- Fluxo físico canônico. Recebe missão/rota do catálogo e a sessão confirmada.
function RunContract(mission, route, session)
  selectedRoute = route
  selectedMission = mission
  activeJobToken = activeJobToken + 1
  local jobToken = activeJobToken
  local sessionId = session.sessionId

  isAcceptedIllegal = false
  trailerAttached = false

  -- Spawn da carreta escolhido pelo servidor (índice), coordenadas do catálogo.
  local trailerSpawnLocation = nil
  if route.trailerSpawnAvaliableCoords then
    local spot = route.trailerSpawnAvaliableCoords[session.trailerSpawnIndex or 1] or route.trailerSpawnAvaliableCoords[1]
    trailerSpawnLocation = vector4(spot.x, spot.y, spot.z, spot.w)
  end

  -- Caminhão fornecido pela empresa
  truckVehicle = SpawnVehicle(session.truckModel, Config.VehSpawn, true, Config.VehSpawn.w, true)
  if not truckVehicle or truckVehicle == 0 or not DoesEntityExist(truckVehicle) then
    truckVehicle = false
    createNotification(Config.Language.job_failed_system)
    TriggerServerEvent("peak-trucking:session:cancel", sessionId, "spawn_vehicle_failed")
    activeSession = nil
    Close()
    return
  end

  isJobActive = true
  truckBlip = CreateBlip(false, 477, 3, 0.8, "Truck", true, true, truckVehicle)

  -- Registra o veículo na sessão autoritativa
  local netId = NetworkGetNetworkIdFromEntity(truckVehicle)
  SetNetworkIdCanMigrate(netId, true)
  TriggerServerEvent("peak-trucking:session:vehicle", sessionId, netId)

  -- Carreta da rota
  if route.trailerModel and trailerSpawnLocation then
    CreateThread(function()
      local trailerSpawned = false
      while not trailerSpawned and isJobActive and activeJobToken == jobToken do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local spawnLocation = vector3(trailerSpawnLocation.x, trailerSpawnLocation.y, trailerSpawnLocation.z)
        local distance = #(playerCoords - spawnLocation)

        if distance < 70.0 then
          trailerVehicle = SpawnVehicle(
            route.trailerModel,
            vector3(trailerSpawnLocation.x, trailerSpawnLocation.y, trailerSpawnLocation.z + 1.0),
            false,
            trailerSpawnLocation.w
          )
          trailerBlip = CreateBlip(false, 479, 3, 0.8, "Trailer", true, true, trailerVehicle)
          trailerSpawned = true
        end
        Wait(1000)
      end
    end)
  end

  -- Carga acoplada da rota
  if route.attachModel and trailerSpawnLocation then
    CreateThread(function()
      local objectSpawned = false
      while not objectSpawned and isJobActive and activeJobToken == jobToken do
        if DoesEntityExist(trailerVehicle) then
          if route.attachModel == "apc" or route.attachModel == "rhino" or route.attachModel == "scarab" then
            attachedObject = SpawnVehicle(
              route.attachModel,
              vector3(trailerSpawnLocation.x, trailerSpawnLocation.y, trailerSpawnLocation.z + 1.0),
              false
            )
          else
            attachedObject = SpawnObject(route.attachModel, trailerSpawnLocation)
          end

          local attachHeight = route.attachModelHeight or 0.0
          AttachEntityToEntity(
            attachedObject,
            trailerVehicle,
            GetEntityBoneIndexByName(trailerVehicle, GetHashKey("boot")),
            0.0, 0.0, attachHeight,
            0.0, 0.0, 0.0,
            false, false, false, false, 0.0, true
          )
          objectSpawned = true
        end
        Wait(1000)
      end
    end)
  end

  -- Blip inicial
  if trailerSpawnLocation then
    SetRouteBlip(trailerSpawnLocation.x, trailerSpawnLocation.y, trailerSpawnLocation.z)
  else
    SetRouteBlip(route.destination.x, route.destination.y, route.destination.z)
  end

  createNotification(Config.Language.get_trailer)
  Close()

  setJobInfo("started", true)
  setJobInfo("attachedTrailer", false)
  setJobInfo("routeHeader", route.label)
  setJobInfo("tier", session.tier)

  currentPhase = 1
  if not trailerSpawnLocation then
    currentPhase = 2
  end

  if OnMissionStarted then
    pcall(OnMissionStarted, mission.id, session.routeIndex)
  end

  -- Monitor de destruição
  CreateThread(function()
    local trailerWasSpawned = false
    local attachedObjectWasSpawned = false

    while isJobActive and activeJobToken == jobToken do
      if IsVehicleUnusable(truckVehicle) then
        CancelActiveJob("truck_destroyed", false)
        createNotification(Config.Language.job_cancelled_vehicle_destroyed)
        return
      end

      if DoesEntityExist(trailerVehicle) then trailerWasSpawned = true end
      if DoesEntityExist(attachedObject) then attachedObjectWasSpawned = true end

      if route.trailerModel and trailerWasSpawned and currentPhase < 3 then
        if IsVehicleUnusable(trailerVehicle) then
          CancelActiveJob("cargo_destroyed", false)
          createNotification(Config.Language.job_cancelled_cargo_destroyed)
          return
        end
      end

      if route.attachModel and attachedObjectWasSpawned and currentPhase < 3 then
        if IsEntityUnusable(attachedObject) then
          CancelActiveJob("cargo_destroyed", false)
          createNotification(Config.Language.job_cancelled_cargo_destroyed)
          return
        end
      end

      Wait(500)
    end
  end)

  -- Ghost mode na área de spawn
  if Config.EnableGhostMode then
    CreateThread(function()
      local isGhostActive = false
      while DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local spawnCoords = vector3(Config.VehSpawn.x, Config.VehSpawn.y, Config.VehSpawn.z)
        local distance = #(playerCoords - spawnCoords)

        if distance < 15.0 then
          if not isGhostActive then
            SetLocalPlayerAsGhost(true)
            isGhostActive = true
          end
        elseif isGhostActive then
          SetLocalPlayerAsGhost(false)
          isGhostActive = false
        end

        Wait(1000)
      end
      SetLocalPlayerAsGhost(false)
    end)
  end

  -- Tecla de marcar local
  CreateThread(function()
    while DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
      if IsControlJustPressed(0, Config.KeyPressed.mark_location.key) then
        if not isIllegalMissionActive then
          if currentPhase == 1 then
            if mission.id == 16 then
              SetRouteBlip(route.board.x, route.board.y, route.board.z)
            elseif trailerSpawnLocation then
              SetRouteBlip(trailerSpawnLocation.x, trailerSpawnLocation.y, trailerSpawnLocation.z)
            end
          elseif currentPhase == 2 then
            SetRouteBlip(route.destination.x, route.destination.y, route.destination.z)
          elseif currentPhase == 3 then
            SetRouteBlip(Config.VehSpawn.x, Config.VehSpawn.y, Config.VehSpawn.z)
          end
        end
      end

      Wait(0)
    end
  end)

  -- Saúde e combustível → HUD
  CreateThread(function()
    while DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
      setJobInfo("bodyHealth", GetVehicleBodyHealth(truckVehicle) / 10)
      setJobInfo("fuel", GetFuel(truckVehicle))
      Wait(2000)
    end
  end)

  -- Lógica principal
  CreateThread(function()
    if mission.id == 16 then
      -- Missão 16: carregamento manual de 10 caixas (fluxo preservado)
      local boxCount = 0
      local hasBox = false

      SetRouteBlip(route.board.x, route.board.y, route.board.z)

      while DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
        local checkInterval = 1000

        local truckBackCoords = GetWorldPositionOfEntityBone(truckVehicle, GetEntityBoneIndexByName(truckVehicle, "platelight"))
        local playerCoords = GetEntityCoords(PlayerPedId())
        local distToTruck = #(playerCoords - truckBackCoords)

        local boardCoords = vector3(route.board.x, route.board.y, route.board.z)
        local distToBoard = #(playerCoords - boardCoords)

        local loadDistance = 2.5

        if distToTruck < loadDistance and hasBox then
          checkInterval = 0
          DrawMarker(2, vector3(truckBackCoords.x, truckBackCoords.y, truckBackCoords.z + 1.0), 0.0, 0.0, 0.0, 0.0, 0.0,
            0.0, 0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)
          DrawText3D(truckBackCoords.x, truckBackCoords.y, truckBackCoords.z, Config.Language.load_box)
          DrawMarker(2, truckBackCoords.x, truckBackCoords.y, truckBackCoords.z + 4.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)

          if IsControlJustPressed(0, 38) then
            if not IsPedInAnyVehicle(PlayerPedId()) then
              boxCount = boxCount + 1
              hasBox = false
              DeleteEntity(carryBoxProp)
              ClearPedTasks(PlayerPedId())
              setJobInfo("boxProgress", boxCount .. "/10")

              if boxCount == 10 then
                ClearPedTasks(PlayerPedId())
                setJobInfo("boxProgress", nil)
                break
              end
              Wait(1000)
            else
              createNotification(Config.Language.in_vehicle)
            end
          end
        end

        if distToBoard < 5.0 and not hasBox then
          checkInterval = 0
          DrawMarker(2, vector3(route.board.x, route.board.y, route.board.z), 0.0, 0.0, 0.0,
            0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)
          DrawText3D(route.board.x, route.board.y, route.board.z, Config.Language.take_box)

          if IsControlJustPressed(0, 38) then
            if not IsPedInAnyVehicle(PlayerPedId()) then
              AttachBoxToPed()
              hasBox = true
            else
              createNotification(Config.Language.in_vehicle)
            end
          end
        end

        Wait(checkInterval)
      end
    else
      -- Missões com carreta: aguarda o engate
      while trailerSpawnLocation and DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
        local checkInterval = 1000

        local isTrailerAttached = GetVehicleTrailerVehicle(truckVehicle)
        if isTrailerAttached then
          break
        end

        if DoesEntityExist(trailerVehicle) then
          local trailerCoords = GetEntityCoords(trailerVehicle)
          local truckCoords = GetEntityCoords(truckVehicle)
          local distance = #(truckCoords - trailerCoords)

          if distance < 100.0 then
            if distance < 50.0 then
              checkInterval = 0
              DrawMarker(2, trailerCoords.x, trailerCoords.y, trailerCoords.z + 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)
            else
              checkInterval = 500
            end
          end
        end

        Wait(checkInterval)
      end
    end

    if not isJobActive or activeJobToken ~= jobToken then
      return
    end

    -- Coleta confirmada (para missões sem carreta o servidor já avançou)
    if trailerSpawnLocation or mission.id == 16 then
      TriggerServerEvent("peak-trucking:session:pickup", sessionId)
    end

    SetRouteBlip(route.destination.x, route.destination.y, route.destination.z)
    createNotification(Config.Language.deliver_trailer)
    setJobInfo("attachedTrailer", true)
    currentPhase = 2

    -- Viagem ao destino
    while DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
      local checkInterval = 1000
      local playerCoords = GetEntityCoords(PlayerPedId())
      local destination = vector3(route.destination.x, route.destination.y, route.destination.z)
      local distanceToDest = #(playerCoords - destination)

      if distanceToDest < 10.0 then
        checkInterval = 0
        DrawMarker(23,
          vector3(route.destination.x, route.destination.y, route.destination.z - 0.9), 0.0,
          0.0, 0.0, 0.0, 0.0, 0.0, 3.8, 3.8, 3.8, 255, 255, 255, 255, false, false, false, true, false, false, false)
        DrawText3D(route.destination.x, route.destination.y, route.destination.z, Config.Language.deliver)

        if IsControlJustPressed(0, 38) then
          local vehicleSpeed = GetEntitySpeed(truckVehicle)

          if vehicleSpeed <= 0 then
            local hasTrailerNow, currentTrailer = GetVehicleTrailerVehicle(truckVehicle)

            local trailerMatches = true
            if route.trailerModel then
              trailerMatches = hasTrailerNow and currentTrailer == trailerVehicle
            end

            if trailerMatches then
              TriggerServerEvent("peak-trucking:session:destination", sessionId)

              if DoesBlipExist(routeBlip) then
                RemoveBlip(routeBlip)
              end

              Wait(500)

              returnBlip = AddBlipForCoord(Config.VehSpawn.x, Config.VehSpawn.y, Config.VehSpawn.z)
              SetBlipColour(returnBlip, 5)
              SetBlipRoute(returnBlip, true)
              SetBlipRouteColour(returnBlip, 5)
              SetNewWaypoint(Config.VehSpawn.x, Config.VehSpawn.y)

              createNotification(Config.Language.return_veh)
              setJobInfo("started", false)
              currentPhase = 3

              if DoesEntityExist(trailerVehicle) then
                DetachVehicleFromTrailer(truckVehicle)
                local deliveredTrailer = trailerVehicle
                local deliveredAttachedObject = attachedObject
                local deliveredTrailerBlip = trailerBlip
                trailerVehicle = false
                attachedObject = false
                trailerBlip = false
                CreateThread(function()
                  Wait(Config.VehicleDeleteTimeout)
                  RemoveTrackedBlip(deliveredTrailerBlip)
                  DeleteTrackedEntity(deliveredTrailer)
                  if DoesEntityExist(deliveredAttachedObject) then
                    if IsEntityAVehicle(deliveredAttachedObject) then
                      DeleteVehicle(deliveredAttachedObject)
                    else
                      DeleteEntity(deliveredAttachedObject)
                    end
                  end
                end)
              end

              break
            else
              createNotification(Config.Language.trailer_doesnt_match)
            end
          else
            createNotification(Config.Language.stop_vehicle)
          end
        end
      end

      Wait(checkInterval)
    end

    if not isJobActive or activeJobToken ~= jobToken then
      return
    end

    -- Devolução do caminhão
    currentPhase = 3

    while DoesEntityExist(truckVehicle) and isJobActive and activeJobToken == jobToken do
      local checkInterval = 1000
      local playerCoords = GetEntityCoords(PlayerPedId())
      local spawnCoords = vector3(Config.VehSpawn.x, Config.VehSpawn.y, Config.VehSpawn.z)
      local distanceToSpawn = #(playerCoords - spawnCoords)

      if distanceToSpawn < 10.0 then
        checkInterval = 0
        DrawMarker(2, vector3(Config.VehSpawn.x, Config.VehSpawn.y, Config.VehSpawn.z), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
          0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)
        DrawText3D(Config.VehSpawn.x, Config.VehSpawn.y, Config.VehSpawn.z, Config.Language.finish_job)

        if IsControlJustPressed(0, 38) then
          -- Conclusão autoritativa: o servidor valida e paga antes do cleanup
          local res = Rpc('finishContract', {
            sessionId = sessionId,
            vehicleHealth = GetVehicleBodyHealth(truckVehicle) / 10,
          }, 10000)

          if not res or not res.ok then
            createNotification(res and res.message or Config.Language.err_timeout)
            Wait(1500)
          else
            setJobInfo("started", false)

            if DoesBlipExist(returnBlip) then RemoveBlip(returnBlip) end
            if DoesBlipExist(routeBlip) then RemoveBlip(routeBlip) end
            RemoveTrackedBlip(truckBlip)
            RemoveTrackedBlip(trailerBlip)

            isJobActive = false
            isIllegalMissionActive = false
            isAcceptedIllegal = false
            activeSession = nil
            setJobInfo("tier", nil)

            createNotification(Config.Language.leave_vehicle)
            Config.RemoveVehiclekey(GetVehicleNumberPlateText(truckVehicle), GetHashKey(truckVehicle), truckVehicle)
            TaskLeaveAnyVehicle(PlayerPedId(), 0, 0)

            local completedTruck = truckVehicle
            truckVehicle = false
            truckBlip = false
            CreateThread(function()
              Wait(Config.VehicleDeleteTimeout)
              DeleteTrackedEntity(completedTruck)
            end)

            if OnMissionCompleted and res.result then
              pcall(OnMissionCompleted, mission.id, res.result.total)
            end

            break
          end
        end
      end

      Wait(checkInterval)
    end
  end)
end

-- ============================================================
-- CARGA ILEGAL (ramo opcional dentro da sessão)
-- ============================================================

CreateThread(function()
  while true do
    local checkInterval = 1500
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local illegalNpcCoords = vector3(
      Config.IllegalNPC.coords.x,
      Config.IllegalNPC.coords.y,
      Config.IllegalNPC.coords.z
    )
    local distanceToIllegalNpc = #(playerCoords - illegalNpcCoords)

    if distanceToIllegalNpc < 4.0 then
      checkInterval = 0
      DrawText3D(
        Config.IllegalNPC.coords.x,
        Config.IllegalNPC.coords.y,
        Config.IllegalNPC.coords.z + 1.1,
        Config.Language.take_illegal
      )

      if IsControlJustPressed(0, 38) then
        if not DoesEntityExist(truckVehicle) or not isJobActive then
          createNotification(Config.Language.must_have_job)
        else
          if isIllegalMissionActive or isPendingCall then
            createNotification(Config.Language.already_illegal)
          else
            isPendingCall = true
            createNotification(Config.Language.wait_call)
            SetTimeout(math.random(15000, 25000), function()
              isPendingCall = false
              if #(GetEntityCoords(PlayerPedId()) - illegalNpcCoords) < 50.0 then
                isAcceptedIllegal = true
                NuiMessage("callillegal")
                SetTimeout(15000, function()
                  if isAcceptedIllegal then
                    isAcceptedIllegal = false
                    NuiMessage("declineillegal")
                  end
                end)
              else
                createNotification(Config.Language.too_far)
              end
            end)
          end
        end
      end
    end
    Wait(checkInterval)
  end
end)

CreateThread(function()
  while true do
    local wait = 1000
    if isAcceptedIllegal then
      wait = 0
      if IsControlJustPressed(0, 246) then -- [Y] Accept
        NuiMessage("acceptillegal")
        isAcceptedIllegal = false
        isIllegalMissionActive = true
        TriggerServerEvent("peak-trucking:AcceptIllegalDeal")
        createNotification(Config.Language.go_to_pickup)

        SetTimeout(10000, function()
          NuiMessage("declineillegal")
        end)

        SetRouteBlip(Config.IllegalNPC.boardLocation.x, Config.IllegalNPC.boardLocation.y, Config.IllegalNPC.boardLocation.z)

        CreateThread(function()
          local boxCount = 0
          local hasBox = false

          while isIllegalMissionActive and DoesEntityExist(truckVehicle) do
            local pedCoords = GetEntityCoords(PlayerPedId())
            local truckBackCoords = GetWorldPositionOfEntityBone(truckVehicle, GetEntityBoneIndexByName(truckVehicle, "platelight"))
            if truckBackCoords == vector3(0, 0, 0) then
              truckBackCoords = GetEntityCoords(truckVehicle)
            end
            local distToTruck = #(pedCoords - truckBackCoords)

            local boardLocation = vector3(
              Config.IllegalNPC.boardLocation.x,
              Config.IllegalNPC.boardLocation.y,
              Config.IllegalNPC.boardLocation.z
            )
            local distToBoard = #(pedCoords - boardLocation)

            if distToTruck < 2.5 and hasBox then
              DrawMarker(2, vector3(truckBackCoords.x, truckBackCoords.y, truckBackCoords.z + 1.0), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)
              DrawText3D(truckBackCoords.x, truckBackCoords.y, truckBackCoords.z, Config.Language.load_box)

              if IsControlJustPressed(0, 38) then
                if not IsPedInAnyVehicle(PlayerPedId()) then
                  boxCount = boxCount + 1
                  hasBox = false
                  DeleteEntity(carryBoxProp)
                  ClearPedTasks(PlayerPedId())
                  TriggerServerEvent("peak-trucking:GiveIllegalItem")
                  setJobInfo("boxProgress", boxCount .. "/10")
                else
                  createNotification(Config.Language.in_vehicle)
                end

                if boxCount == 10 then
                  ClearPedTasks(PlayerPedId())
                  trailerAttached = true
                  setJobInfo("boxProgress", nil)

                  if currentPhase == 1 and selectedRoute then
                    SetRouteBlip(selectedRoute.destination.x, selectedRoute.destination.y, selectedRoute.destination.z)
                  end

                  isIllegalMissionActive = false
                  break
                end
                Wait(1000)
              end
            end

            if distToBoard < 5.0 and not hasBox then
              DrawMarker(2, vector3(boardLocation.x, boardLocation.y, boardLocation.z), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 255, 255, 255, true, false, false, true, false, false, false)
              DrawText3D(Config.IllegalNPC.boardLocation.x, Config.IllegalNPC.boardLocation.y, Config.IllegalNPC.boardLocation.z, Config.Language.take_box)

              if IsControlJustPressed(0, 38) then
                if not IsPedInAnyVehicle(PlayerPedId()) then
                  AttachBoxToPed()
                  hasBox = true
                else
                  createNotification(Config.Language.in_vehicle)
                end
              end
            end
            Wait(0)
          end
        end)
      elseif IsControlJustPressed(0, 249) then -- [N] Decline
        NuiMessage("declineillegal")
        isIllegalMissionActive = false
        isAcceptedIllegal = false
      end
    end
    Wait(wait)
  end
end)

-- ============================================================
-- SINCRONIZAÇÃO DE DADOS / NOTIFICAÇÕES
-- ============================================================

RegisterNetEvent("peak-trucking:SyncPlayerDataByKey")
AddEventHandler("peak-trucking:SyncPlayerDataByKey", function(key, value)
  NuiMessage("SyncPlayerDataByKey", {
    key = key,
    value = value
  })
end)

RegisterNetEvent("peak-trucking:SyncAllPlayerData")
AddEventHandler("peak-trucking:SyncAllPlayerData", function(data)
  NuiMessage("SyncAllPlayerData", data)
end)

function createNotification(message)
  if not message then return end
  NuiMessage("createNotification", message)
end

RegisterNetEvent("peak-trucking:createNotification")
AddEventHandler("peak-trucking:createNotification", function(message)
  createNotification(message)
end)

RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function()
  TriggerServerEvent("peak-trucking:LoadPlayerData")
end)

RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
  TriggerServerEvent("peak-trucking:LoadPlayerData")
end)

AddEventHandler("onResourceStart", function(resourceName)
  if GetCurrentResourceName() ~= resourceName then
    return
  end

  TriggerEvent("chat:addSuggestion", "/" .. (Config.CancelJobCommand or "canceltrucking"), "Cancel active delivery")

  WaitNui()
  WaitCore()
  if not WaitPlayer() then return end

  while Core == nil do
    Wait(0)
  end

  TriggerServerEvent("peak-trucking:LoadPlayerData")
end)

-- Send config data to NUI
CreateThread(function()
  Wait(2000)

  while Core == nil do
    Wait(0)
  end

  WaitNui()

  NuiMessage("setXP", Config.XP)
  NuiMessage("setLanguage", Config.Language)
  NuiMessage("setTrucks", Config.Trucks)
  NuiMessage("setTrucksCopy", Config.Trucks)
  NuiMessage("setKeyBinds", Config.KeyPressed)
  NuiMessage("set_missions", Config.Missions)
  NuiMessage("setContractConfig", ContractConfigPayload())
end)

function CreateCamera()
  if IsPedInAnyVehicle(PlayerPedId(), false) then
    return
  end

  local camOffset = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 1.38, -1.7, 0)

  RenderScriptCams(true, true, 500, true, true)
  DestroyCam(cam, false)

  if not DoesCamExist(cam) then
    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
    SetCamCoord(cam, camOffset.x, camOffset.y, camOffset.z + 0.2)
    SetCamRot(cam, 5.0, 0.0, GetEntityHeading(PlayerPedId()))
    SetCamNearClip(cam, 0.1)
    SetCamFarClip(cam, 1000.0)
    SetCamFov(cam, 68.0)
    SetCamDofFnumberOfLens(cam, 24.0)
    SetCamDofFocalLengthMultiplier(cam, 50.0)
  end
end

function WaitPlayer()
  local timeout = 0

  while timeout < 500 do
    local data = Peak.Client.GetPlayerData()
    if data and data.job then
      return true
    end

    Wait(100)
    timeout = timeout + 1
  end

  Peak.Utils.Warn("Failed to load PlayerData.job")
  return false
end

-- ============================================================
-- HUD REPOSITIONING
-- ============================================================

RegisterCommand("truckhud", function()
  isEditingHud = not isEditingHud
  if isEditingHud then
    NuiMessage("toggle_hud_edit", { editing = true })
    SetNuiFocus(true, true)
    createNotification(Config.Language.edit_hud_hint)
  else
    NuiMessage("toggle_hud_edit", { editing = false })
    SetNuiFocus(false, false)
  end
end)

RegisterNUICallback("save_hud_pos", function(data, cb)
  isEditingHud = false
  NuiMessage("toggle_hud_edit", { editing = false })
  SetNuiFocus(false, false)
  ResolveNuiCallback(cb)
end)

AddEventHandler("onResourceStop", function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end
  ReleaseMenuCameraAndFocus()
end)

-- Export usado por client/custom.lua
function GetActiveSessionInfo()
  return activeSession
end
