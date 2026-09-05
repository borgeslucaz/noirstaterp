-- Apresentação e IA do passageiro NPC (a entidade é criada pelo servidor).
NPC = {}

local P = Config.Passenger

---@param entity number
---@return boolean
function NPC.requestControl(entity)
    if not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local ok = pcall(lib.waitFor, function()
        if NetworkHasControlOfEntity(entity) then return true end
    end, 'no control of passenger entity', 1500)
    return ok
end

---Aguarda a entidade do servidor existir localmente e aplica atributos de missão.
---@param netId number
---@return number ped (0 se falhou)
function NPC.attach(netId)
    local ok = pcall(lib.waitFor, function()
        if NetworkDoesEntityExistWithNetworkId(netId) then return true end
    end, 'passenger did not stream in', 6000)
    if not ok then return 0 end

    local ped = NetToPed(netId)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return 0 end

    NPC.requestControl(ped)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanBeTargetted(ped, false)
    SetPedCanRagdoll(ped, false)
    SetPedCanBeDraggedOut(ped, false)
    SetPedKeepTask(ped, true)
    SetEntityInvincible(ped, true)
    TaskStartScenarioInPlace(ped, P.Scenario, 0, true)
    return ped
end

---Assento preferencial: traseiro direito, traseiro esquerdo, passageiro dianteiro.
---@param vehicle number
---@return number|nil seat
function NPC.findSeat(vehicle)
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 1
    for _, seat in ipairs(P.SeatOrder) do
        if seat <= seats - 1 and IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end
    return nil
end

local function waitInVehicle(ped, vehicle, timeoutMs, abortFn)
    local deadline = GetGameTimer() + timeoutMs
    while GetGameTimer() < deadline do
        if IsPedInVehicle(ped, vehicle, false) then return true end
        if abortFn and abortFn() then return false end
        Wait(100)
    end
    return IsPedInVehicle(ped, vehicle, false)
end

---Embarque com tentativas, warp local e warp pelo servidor como último recurso.
---@param ped number
---@param vehicle number
---@param seat number
---@param abortFn? fun(): boolean
---@param serverWarp? fun(): boolean pede ao servidor para colocar o ped no veículo
---@return boolean
function NPC.board(ped, vehicle, seat, abortFn, serverWarp)
    for _ = 1, P.BoardingAttempts do
        if not DoesEntityExist(ped) then return false end
        if IsPedInVehicle(ped, vehicle, false) then return true end

        if NPC.requestControl(ped) then
            SetPedKeepTask(ped, false)
            ClearPedTasksImmediately(ped)
            TaskEnterVehicle(ped, vehicle, P.BoardingTimeout, seat, 1.0, 1, 0)
            if waitInVehicle(ped, vehicle, P.BoardingTimeout, abortFn) then return true end
        else
            -- Sem controle da entidade a tarefa não teria efeito; tenta de novo em seguida.
            Wait(500)
        end
        if abortFn and abortFn() then return false end
    end

    if not DoesEntityExist(ped) then return false end
    if NPC.requestControl(ped) then
        ClearPedTasksImmediately(ped)
        TaskWarpPedIntoVehicle(ped, vehicle, seat)
        if waitInVehicle(ped, vehicle, 1500, abortFn) then return true end
    end

    if serverWarp and serverWarp() then
        return waitInVehicle(ped, vehicle, 2000, abortFn)
    end
    return IsPedInVehicle(ped, vehicle, false)
end

---Desembarque: sai do veículo e caminha para longe. A remoção da entidade é do servidor.
---@param ped number
---@param vehicle number
function NPC.exit(ped, vehicle)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    NPC.requestControl(ped)
    SetPedKeepTask(ped, false)
    TaskLeaveVehicle(ped, vehicle, 0)
    CreateThread(function()
        local deadline = GetGameTimer() + 6000
        while GetGameTimer() < deadline and DoesEntityExist(ped) and IsPedInVehicle(ped, vehicle, false) do
            Wait(200)
        end
        if DoesEntityExist(ped) then
            SetBlockingOfNonTemporaryEvents(ped, false)
            TaskWanderStandard(ped, 10.0, 10)
        end
    end)
end

---Limpa referências locais ao passageiro atual.
function NPC.release()
    if Taxi.fare and Taxi.fare.npc and Taxi.fare.npc ~= 0 then
        local ped = Taxi.fare.npc
        if DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, false) then
            SetPedKeepTask(ped, false)
            ClearPedTasks(ped)
        end
        Taxi.fare.npc = 0
        Taxi.fare.npcNetId = nil
    end
end
