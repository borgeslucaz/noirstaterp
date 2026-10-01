---Alvos (ox_target) da missão, refeitos a partir do retrato do servidor.
---
---O ox_target só registra alvo de rede quando o netId já existe neste cliente. Tambor e
---computador nascem longe, então o alvo desejado fica numa fila e um laço curto registra
---quando a entidade entra no escopo. Depois de registrado, o ox_target guarda pelo netId e
---sobrevive à entidade sair e voltar do escopo.
---
---Target é convite: toda ação pergunta ao servidor, que confere distância, estado e posse.
local State = require 'client.runtime.state'
local Integrations = require 'client.integrations'
local Interact = require 'client.interactions.interact'

local Targets = {}

---@type table<integer, { signature: string, names: string[], options: table[], registered: boolean }>
local entityTargets = {}
---@type table<string, { zone: integer?, signature: string }>
local zoneTargets = {}
local vehicleOptionsOn = false
local retryLoop = false

local NAME_PREFIX = 'noir_missions:'

local CARGO_MESSAGES = {
    too_far = 'Chegue mais perto.',
    already_carrying = 'Você já está carregando algo.',
    inspect_first = 'Confira a etiqueta antes.',
    wrong_cargo = 'Esse não é o lote certo.',
    not_found = 'Isso já foi levado.',
    wrong_vehicle = 'Isso não vai nesse veículo.',
    vehicle_full = 'O veículo está cheio.',
    vehicle_empty = 'Não tem carga aqui.',
    cannot_carry = 'Sem espaço no inventário.',
    not_carrying = 'Você não está carregando nada.',
}

---@param result table?
---@return boolean ok
local function report(result)
    if result and result.ok then return true end
    local code = result and result.code
    if code ~= 'rate_limited' then
        Integrations.notify(CARGO_MESSAGES[code] or 'Não deu.', 'error')
    end
    return false
end

-- Entidades de rede (computador, tambores) -------------------------------------------------

local function tryRegister(netId, entry)
    if entry.registered or not NetworkDoesNetworkIdExist(netId) then return entry.registered end
    Integrations.addEntityTarget(netId, entry.options)
    entry.registered = true
    return true
end

local function ensureRetryLoop()
    if retryLoop then return end
    retryLoop = true
    CreateThread(function()
        while true do
            local waiting = false
            for netId, entry in pairs(entityTargets) do
                if not tryRegister(netId, entry) then waiting = true end
            end
            if not waiting then break end
            Wait(1000)
        end
        retryLoop = false
    end)
end

local function setEntityTarget(desired, netId, signature, options)
    local names = {}
    for index = 1, #options do names[index] = options[index].name end
    desired[netId] = true
    local current = entityTargets[netId]
    if current and current.signature == signature then return end
    if current and current.registered then Integrations.removeEntityTarget(netId, current.names) end
    local entry = { signature = signature, names = names, options = options, registered = false }
    entityTargets[netId] = entry
    if not tryRegister(netId, entry) then ensureRetryLoop() end
end

---@param view table
---@param desired table<integer, boolean>
local function syncInteractions(view, desired)
    local zonesSeen = {}
    for index = 1, #view.interactions do
        local interaction = view.interactions[index]
        local options = { {
            name = NAME_PREFIX .. 'interaction:' .. interaction.id,
            label = interaction.label,
            icon = interaction.kind == 'hack' and 'fa-solid fa-laptop-code'
                or interaction.kind == 'search' and 'fa-solid fa-magnifying-glass' or 'fa-solid fa-hand',
            distance = interaction.distance,
            onSelect = function() Interact.run(view.instanceId, interaction.id) end,
        } }
        if interaction.netId then
            setEntityTarget(desired, interaction.netId, 'i:' .. interaction.id, options)
        else
            -- Sem objeto próprio: zona na coordenada (computador que já existe no mapa).
            zonesSeen[interaction.id] = true
            local signature = ('%.2f|%.2f|%.2f'):format(interaction.coords.x, interaction.coords.y, interaction.coords.z)
            local current = zoneTargets[interaction.id]
            if not current or current.signature ~= signature then
                if current then Integrations.removeZone(current.zone) end
                zoneTargets[interaction.id] = {
                    signature = signature,
                    zone = Integrations.addSphereZone({
                        coords = vec3(interaction.coords.x, interaction.coords.y, interaction.coords.z),
                        radius = 0.9,
                        options = options,
                    }),
                }
            end
        end
    end
    for id, entry in pairs(zoneTargets) do
        if not zonesSeen[id] then
            Integrations.removeZone(entry.zone)
            zoneTargets[id] = nil
        end
    end
end

---@param view table
---@param desired table<integer, boolean>
local function syncCargo(view, desired)
    for index = 1, #view.cargo do
        local piece = view.cargo[index]
        local options = {}
        if piece.needsInspect then
            options[#options + 1] = {
                name = NAME_PREFIX .. 'cargo:inspect',
                label = 'Ver etiqueta',
                icon = 'fa-solid fa-tag',
                distance = 2.0,
                onSelect = function()
                    local result = lib.callback.await('noir_missions:server:cargoInspect', false, view.instanceId, piece.cargo, piece.index)
                    if report(result) then Integrations.notify(result.label, 'inform') end
                end,
            }
        end
        options[#options + 1] = {
            name = NAME_PREFIX .. 'cargo:pickup',
            label = piece.label and ('Pegar (%s)'):format(piece.label) or ('Pegar %s'):format(piece.name or 'carga'),
            icon = 'fa-solid fa-box',
            distance = 2.0,
            canInteract = function() return not State.isCarrying() end,
            onSelect = function()
                report(lib.callback.await('noir_missions:server:cargoPickup', false, view.instanceId, piece.cargo, piece.index))
            end,
        }
        setEntityTarget(desired, piece.netId, ('c:%s:%d:%s:%s'):format(piece.cargo, piece.index,
            tostring(piece.needsInspect), piece.label or ''), options)
    end
end

-- Veículos: opção global, válida enquanto há missão --------------------------------------

local VEHICLE_OPTIONS = { NAME_PREFIX .. 'vehicle:load', NAME_PREFIX .. 'vehicle:unload' }

---@param entity integer
---@return boolean
local function vehicleHasCargo(entity)
    local view = State.view
    if not view or not view.vehicleCargo then return false end
    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity) or nil
    for index = 1, #view.vehicleCargo do
        if view.vehicleCargo[index].netId == netId then return true end
    end
    return false
end

local function enableVehicleOptions()
    if vehicleOptionsOn then return end
    vehicleOptionsOn = true
    Integrations.addGlobalVehicle({
        {
            name = VEHICLE_OPTIONS[1],
            label = 'Colocar carga',
            icon = 'fa-solid fa-truck-ramp-box',
            distance = 3.5,
            canInteract = function(entity)
                return State.view ~= nil and State.isCarrying() and NetworkGetEntityIsNetworked(entity)
            end,
            onSelect = function(data)
                local view = State.view
                if not view then return end
                report(lib.callback.await('noir_missions:server:cargoLoad', false, view.instanceId,
                    NetworkGetNetworkIdFromEntity(data.entity)))
            end,
        },
        {
            name = VEHICLE_OPTIONS[2],
            label = 'Tirar carga',
            icon = 'fa-solid fa-dolly',
            distance = 3.5,
            canInteract = function(entity)
                return State.view ~= nil and not State.isCarrying() and vehicleHasCargo(entity)
            end,
            onSelect = function(data)
                local view = State.view
                if not view then return end
                report(lib.callback.await('noir_missions:server:cargoUnload', false, view.instanceId,
                    NetworkGetNetworkIdFromEntity(data.entity)))
            end,
        },
    })
end

local function disableVehicleOptions()
    if not vehicleOptionsOn then return end
    vehicleOptionsOn = false
    Integrations.removeGlobalVehicle(VEHICLE_OPTIONS)
end

-- Sincronização ---------------------------------------------------------------------------

---@param view table?
function Targets.sync(view)
    if not view then return Targets.clear() end
    local desired = {}
    syncInteractions(view, desired)
    syncCargo(view, desired)
    for netId, entry in pairs(entityTargets) do
        if not desired[netId] then
            if entry.registered then Integrations.removeEntityTarget(netId, entry.names) end
            entityTargets[netId] = nil
        end
    end
    enableVehicleOptions()
end

function Targets.clear()
    for netId, entry in pairs(entityTargets) do
        if entry.registered then Integrations.removeEntityTarget(netId, entry.names) end
    end
    entityTargets = {}
    for _, entry in pairs(zoneTargets) do Integrations.removeZone(entry.zone) end
    zoneTargets = {}
    disableVehicleOptions()
end

Targets.report = report
return Targets
