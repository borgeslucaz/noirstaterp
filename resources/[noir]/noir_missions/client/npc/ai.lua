---Comportamento de ped de missão, aplicado pelo dono de rede a partir da descrição do
---registro (server/instances/world.lua). Cada tarefa é uma função; tarefa nova = função nova.
local Vehicles = require 'client.vehicles.ai'

local Ai = {}

local HOSTILE, GUARD

-- Tarefas de script, para saber se a mira do aviso ainda está de pé (7 = não está rodando).
local AIM_TASK = joaat('SCRIPT_TASK_AIM_GUN_AT_ENTITY')
local TURN_TASK = joaat('SCRIPT_TASK_TURN_PED_TO_FACE_ENTITY')

---Grupos de relação são locais de cada cliente; criados uma vez na entrada.
function Ai.setupRelationships()
    local _, hostile = AddRelationshipGroup('NOIR_MISSION_HOSTILE')
    local _, guard = AddRelationshipGroup('NOIR_MISSION_GUARD')
    HOSTILE, GUARD = hostile, guard
    local player = joaat('PLAYER')
    SetRelationshipBetweenGroups(5, HOSTILE, player)
    SetRelationshipBetweenGroups(5, player, HOSTILE)
    SetRelationshipBetweenGroups(1, GUARD, player)
    SetRelationshipBetweenGroups(0, HOSTILE, HOSTILE)
    SetRelationshipBetweenGroups(0, HOSTILE, GUARD)
    SetRelationshipBetweenGroups(0, GUARD, HOSTILE)
    SetRelationshipBetweenGroups(0, GUARD, GUARD)
end

---@param serverId integer?
---@return integer ped (0 se fora do escopo)
function Ai.playerPed(serverId)
    if not serverId then return 0 end
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return 0 end
    return GetPlayerPed(player)
end

---Configuração de combate. Reaplicada a cada troca de dono: atributos não acompanham a
---entidade na migração.
---@param ped integer
---@param cfg table
---@param hostile boolean
function Ai.configure(ped, cfg, hostile)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, hostile and HOSTILE or GUARD)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 5, true)   -- sempre luta
    SetPedCombatAttributes(ped, 46, true)  -- encara mesmo em desvantagem
    SetPedCombatAttributes(ped, 17, false) -- nunca foge
    SetPedAccuracy(ped, math.floor(cfg.accuracy or 35))
    SetPedCombatAbility(ped, math.floor(cfg.combatAbility or 1))
    SetPedCombatRange(ped, math.floor(cfg.combatRange or 1))
    SetPedCombatMovement(ped, hostile and 2 or 1)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedCanSwitchWeapon(ped, true)
    if cfg.weapon then
        local weapon = joaat(cfg.weapon)
        if not HasPedGotWeapon(ped, weapon, false) then GiveWeaponToPed(ped, weapon, 250, false, true) end
    end
end

---Vida e colete só uma vez por entidade (o servidor marca depois que o primeiro dono avisa).
---@param ped integer
---@param cfg table
function Ai.firstSetup(ped, cfg)
    local health = math.floor(cfg.health or 200)
    SetEntityMaxHealth(ped, health)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, math.floor(cfg.armor or 0))
end

local tasks = {}

tasks.idle = function(ped, desc)
    local cfg = desc.cfg
    ClearPedTasks(ped)
    -- Bloqueado também na patrulha: sem isso, mirar no guarda dispara a reação de combate do
    -- jogo e ele atira antes de o servidor decidir hostilidade (teste 4.6).
    SetBlockingOfNonTemporaryEvents(ped, true)
    local anchor = cfg.anchor
    if cfg.movement == 'patrol' and anchor then
        TaskWanderInArea(ped, anchor.x, anchor.y, anchor.z, (cfg.patrolRadius or 10) + 0.0, 2.0, 6.0)
    elseif cfg.movement == 'scenario' and cfg.scenario and cfg.scenario ~= '' then
        TaskStartScenarioInPlace(ped, cfg.scenario, 0, true)
    else
        if anchor then SetEntityHeading(ped, anchor.w or 0.0) end
        TaskStandStill(ped, -1)
    end
end

tasks.warn = function(ped, desc)
    local target = Ai.playerPed(desc.t.target)
    if target == 0 then return tasks.idle(ped, desc) end
    -- Sai do cenário na hora (ClearPedTasks espera a animação de saída) e põe a arma na mão:
    -- no cenário ela fica guardada, e `IsPedArmed` dava falso — o guarda só virava (teste 4.5).
    ClearPedTasksImmediately(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    local weapon = desc.cfg and desc.cfg.weapon and joaat(desc.cfg.weapon)
    if weapon and HasPedGotWeapon(ped, weapon, false) then
        SetCurrentPedWeapon(ped, weapon, true)
        -- -1 = até nova ordem: quem manda abaixar é o servidor, quando todos saem do raio.
        TaskAimGunAtEntity(ped, target, -1, false)
    else
        TaskTurnPedToFaceEntity(ped, target, -1)
    end
end

tasks.combat = function(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedRelationshipGroupHash(ped, HOSTILE)
    SetPedCombatAttributes(ped, 3, true) -- pode sair do veículo
    TaskCombatHatedTargetsAroundPed(ped, 150.0, 0)
end

tasks.exit = function(ped, desc)
    local vehicle = NetworkDoesNetworkIdExist(desc.t.veh) and NetToVeh(desc.t.veh) or 0
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCombatAttributes(ped, 3, true)
    if desc.t.engage then
        SetPedRelationshipGroupHash(ped, HOSTILE)
        local sequence = OpenSequenceTask()
        if vehicle ~= 0 and IsPedInVehicle(ped, vehicle, false) then TaskLeaveVehicle(0, vehicle, 256) end
        TaskCombatHatedTargetsAroundPed(0, 150.0, 0)
        CloseSequenceTask(sequence)
        TaskPerformSequence(ped, sequence)
        ClearSequenceTask(sequence)
    elseif vehicle ~= 0 then
        TaskLeaveVehicle(ped, vehicle, 256)
    end
end

tasks.ride = function(ped)
    SetPedCombatAttributes(ped, 3, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
end

tasks.driveby = function(ped, desc)
    local target = Ai.playerPed(desc.t.target)
    SetPedRelationshipGroupHash(ped, HOSTILE)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCombatAttributes(ped, 1, true)  -- usa veículo
    SetPedCombatAttributes(ped, 2, true)  -- atira de dentro
    SetPedCombatAttributes(ped, 3, false) -- não desce
    if target ~= 0 then TaskCombatPed(ped, target, 0, 16) end
end

tasks.drive_to = function(ped, desc)
    Vehicles.driveTo(ped, desc.t)
end

tasks.chase = function(ped, desc)
    SetPedRelationshipGroupHash(ped, HOSTILE)
    SetPedCombatAttributes(ped, 2, desc.t.shoot == true)
    SetPedCombatAttributes(ped, 3, false)
    Vehicles.chase(ped, desc.t, Ai.playerPed(desc.t.target))
end

tasks.wander = function(ped, desc)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedRelationshipGroupHash(ped, GUARD)
    Vehicles.wander(ped, desc.t)
end

---Entrega: o NPC entra no veículo, passa para o volante se entrou pelo lado errado e sai
---dirigindo pela cidade. Quem apaga os dois depois é o servidor (World.release).
tasks.drive_off = function(ped, desc)
    local vehicle = NetworkDoesNetworkIdExist(desc.t.veh) and NetToVeh(desc.t.veh) or 0
    if vehicle == 0 then return end
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedRelationshipGroupHash(ped, GUARD)
    if GetPedInVehicleSeat(vehicle, -1) == ped then
        Vehicles.wander(ped, { veh = desc.t.veh })
    elseif GetVehiclePedIsIn(ped, false) == vehicle then
        TaskShuffleToNextVehicleSeat(ped, vehicle)
    else
        ClearPedTasks(ped)
        TaskEnterVehicle(ped, vehicle, 20000, -1, 1.0, 1, 0)
    end
end

tasks.none = function() end

---Tarefa hostil? Decide o grupo de relação antes de aplicar.
local HOSTILE_TASKS = { combat = true, chase = true, driveby = true }

---Tarefas de quem está dentro do veículo. O ped nasce ao lado (world.lua) e quem é dono dele
---o põe no banco.
local SEATED_TASKS = { ride = true, drive_to = true, chase = true, driveby = true }

---@param ped integer
---@param desc table
---@return boolean seated
local function ensureSeat(ped, desc)
    if not desc.seat or not desc.t or not SEATED_TASKS[desc.t.n] or not desc.t.veh then return true end
    if not NetworkDoesNetworkIdExist(desc.t.veh) then return false end
    local vehicle = NetToVeh(desc.t.veh)
    if vehicle == 0 then return false end
    if IsPedInVehicle(ped, vehicle, false) then return true end
    -- Só banco que existe e está livre. Banco inexistente (terceiro NPC numa moto) derrubava
    -- o jogo: ponteiro vazio dentro do GTA, crash de 2026-10-02.
    local passengers = GetVehicleMaxNumberOfPassengers(vehicle)
    if desc.seat < -1 or desc.seat >= passengers or not IsVehicleSeatFree(vehicle, desc.seat) then
        return false
    end
    SetPedIntoVehicle(ped, vehicle, desc.seat)
    return IsPedInVehicle(ped, vehicle, false)
end

---@param ped integer
---@param desc table
function Ai.apply(ped, desc)
    local name = desc.t and desc.t.n or 'idle'
    local crew = type(desc.g) == 'string' and (desc.g:sub(1, 6) == 'reinf:' or desc.g:sub(1, 6) == 'chase:')
    local hostile = HOSTILE_TASKS[name] or (name == 'exit' and desc.t.engage) or (crew and name ~= 'wander')
    Ai.configure(ped, desc.cfg or {}, hostile == true)
    ensureSeat(ped, desc)
    local fn = tasks[name]
    if fn then fn(ped, desc) end
end

---Manutenção barata de quem já está com a tarefa: combate que acabou por falta de alvo à
---vista volta a procurar; motorista parado longe do destino retoma.
---@param ped integer
---@param desc table
---@param state table
function Ai.maintain(ped, desc, state)
    if IsPedDeadOrDying(ped, true) then return end
    local name = desc.t and desc.t.n
    local now = GetGameTimer()
    if (state.nextCheck or 0) > now then return end
    state.nextCheck = now + (name == 'warn' and 1000 or 5000)
    if name == 'warn' then
        -- A mira pode cair (empurrão, troca de dono, evento): volta a apontar.
        if GetScriptTaskStatus(ped, AIM_TASK) == 7 and GetScriptTaskStatus(ped, TURN_TASK) == 7 then
            tasks.warn(ped, desc)
        end
        return
    end
    -- Veículo ainda fora do escopo quando a tarefa chegou: senta e reaplica quando aparecer.
    if SEATED_TASKS[name] and desc.seat and not IsPedInAnyVehicle(ped, false) then
        if ensureSeat(ped, desc) then Ai.apply(ped, desc) end
        return
    end
    if name == 'drive_off' then
        -- Entrou, trocou de banco ou ficou parado: reavalia. Motor ligado por quem controla a
        -- van; sem isso o NPC fica sentado nela.
        local vehicle = NetworkDoesNetworkIdExist(desc.t.veh) and NetToVeh(desc.t.veh) or 0
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and GetEntitySpeed(vehicle) < 1.0 then
            NetworkRequestControlOfEntity(vehicle)
            SetVehicleUndriveable(vehicle, false)
            SetVehicleEngineOn(vehicle, true, true, false)
        end
        -- 160 = entrando no veículo: não interrompe quem ainda está abrindo a porta.
        if vehicle ~= 0 and not GetIsTaskActive(ped, 160)
            and (GetPedInVehicleSeat(vehicle, -1) ~= ped or GetEntitySpeed(vehicle) < 1.0) then
            tasks.drive_off(ped, desc)
        end
        return
    end
    if name == 'combat' and not IsPedInCombat(ped, 0) then
        tasks.combat(ped, desc)
    elseif name == 'drive_to' or name == 'chase' then
        if Vehicles.isStuck(ped, desc.t, state) then Ai.apply(ped, desc) end
    end
end

return Ai
