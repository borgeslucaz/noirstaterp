-- Entidades do client: alvos dos dealers (peds criados pelo servidor) e o atendente
-- local do terminal, que existe apenas para dar um alvo visível enquanto não há MLO.
NoirOutposts = NoirOutposts or {}

local Entities = {}
NoirOutposts.Entities = Entities

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

local tracked = {}
local terminals = {}

local function optionNames()
    return { 'dealer:inspect', 'dealer:rob' }
end

---O ped é criado pelo servidor, que não consegue configurar comportamento de IA.
---Cada client ajusta o seu: o corredor aguenta o posto em vez de fugir, mas morre normalmente.
---@param entity integer
local function settleDealer(entity)
    SetBlockingOfNonTemporaryEvents(entity, true)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCanRagdollFromPlayerImpact(entity, false)
    SetPedDropsWeaponsWhenDead(entity, false)
end

---@param netId integer
---@param dealerId integer
---@param entity integer
local function attach(netId, dealerId, entity)
    if tracked[netId] then return end
    settleDealer(entity)

    local options = {
        {
            name = 'dealer:inspect',
            icon = clientConfig.target.icons.inspect,
            label = locale('target.inspect_dealer'),
            distance = shared.interaction.dealerDistance,
            onSelect = function()
                NoirOutposts.Interaction.inspectDealer(dealerId, netId)
            end,
        },
        {
            name = 'dealer:rob',
            icon = clientConfig.target.icons.robbery,
            label = locale('target.rob_dealer'),
            distance = shared.interaction.dealerDistance,
            canInteract = function()
                return NoirOutposts.Interaction.canRobDealer(netId)
            end,
            onSelect = function()
                NoirOutposts.Interaction.robDealer(dealerId, netId)
            end,
        },
    }

    local ok, err = exports.bgrz_core:AddEntityTarget(netId, options)
    if not ok then
        if clientConfig.debug then
            lib.print.debug(('[noir_outposts] target do dealer %s falhou: %s'):format(dealerId, tostring(err)))
        end
        return
    end
    tracked[netId] = dealerId
end

---@param netId integer
local function detach(netId)
    if not tracked[netId] then return end
    exports.bgrz_core:RemoveEntityTarget(netId, optionNames())
    tracked[netId] = nil
end

---Peds de corredor com target registrado neste client, para diagnóstico.
---@return table<integer, integer> netId -> dealerId
function Entities.tracked()
    local copy = {}
    for netId, dealerId in pairs(tracked) do copy[netId] = dealerId end
    return copy
end

---@param netId integer
---@return integer? dealerId
function Entities.dealerOf(netId)
    return tracked[netId]
end

---@param entity number
---@return string? outpostId, integer? dealerId, string? status
function Entities.readState(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local state = Entity(entity).state
    return state[C.StateBag.OUTPOST], state[C.StateBag.DEALER], state[C.StateBag.DEALER_STATE]
end

-- Atendente do terminal -----------------------------------------------------------------

---@param outpostId string
---@return boolean enabled
local function terminalEnabled(outpostId)
    local npc = shared.terminalNpc
    if type(npc) ~= 'table' or npc.enabled ~= true then return false end
    return shared.outposts[outpostId].terminalNpc ~= false
end

---@param outpostId string
local function removeTerminal(outpostId)
    local terminal = terminals[outpostId]
    if not terminal then return end
    terminals[outpostId] = nil
    if DoesEntityExist(terminal.ped) then
        exports.bgrz_core:RemoveEntityTarget(terminal.ped, { 'terminal:open' })
        SetEntityAsMissionEntity(terminal.ped, true, true)
        DeleteEntity(terminal.ped)
    end
end

---Cria o atendente local do terminal. Ped não networked: é só âncora de interação,
---nenhuma autoridade passa por ele.
---@param outpostId string
---@return boolean created
local function createTerminal(outpostId)
    if terminals[outpostId] then return true end

    local definition = shared.outposts[outpostId]
    local coords = definition.computer
    local model = joaat(shared.terminalNpc.model)
    if not IsModelInCdimage(model) or not IsModelAPed(model) then
        lib.print.warn(('[noir_outposts] modelo de atendente inválido: %s'):format(shared.terminalNpc.model))
        return false
    end
    if not lib.requestModel(model, 5000) then
        lib.print.warn(('[noir_outposts] timeout carregando o atendente de %s'):format(outpostId))
        return false
    end

    -- `computer` é a posição absoluta do ped. Uma coordenada copiada da posição do jogador
    -- fica cerca de 1m acima do chão, então desconte isso ao cadastrar um local novo.
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    FreezeEntityPosition(ped, true)
    if shared.terminalNpc.scenario then
        TaskStartScenarioInPlace(ped, shared.terminalNpc.scenario, 0, true)
    end

    local ok, err = exports.bgrz_core:AddEntityTarget(ped, {
        {
            name = 'terminal:open',
            icon = clientConfig.target.icons.computer,
            label = locale('target.open_computer'),
            distance = shared.interaction.computerDistance,
            onSelect = function() NoirOutposts.Interaction.openComputer(outpostId) end,
        },
    })
    if not ok then
        lib.print.warn(('[noir_outposts] target do atendente de %s falhou: %s'):format(outpostId, tostring(err)))
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
        return false
    end

    terminals[outpostId] = { ped = ped }
    return true
end

---Sincroniza os atendentes com os outposts ativos.
---@param activeIds table<string, boolean>
---@return table<string, boolean> withNpc locais que ficaram com atendente
function Entities.syncTerminals(activeIds)
    local withNpc = {}

    for outpostId in pairs(terminals) do
        if not activeIds[outpostId] or not terminalEnabled(outpostId) then
            removeTerminal(outpostId)
        end
    end

    for outpostId in pairs(activeIds) do
        if terminalEnabled(outpostId) then
            local terminal = terminals[outpostId]
            -- O ped pode ter sido removido pelo engine ao sair do stream.
            if terminal and not DoesEntityExist(terminal.ped) then
                terminals[outpostId] = nil
            end
            if createTerminal(outpostId) then withNpc[outpostId] = true end
        end
    end

    return withNpc
end

function Entities.clearTerminals()
    local ids = {}
    for outpostId in pairs(terminals) do ids[#ids + 1] = outpostId end
    for index = 1, #ids do removeTerminal(ids[index]) end
end

function Entities.clear()
    local netIds = {}
    for netId in pairs(tracked) do netIds[#netIds + 1] = netId end
    for index = 1, #netIds do detach(netIds[index]) end
    Entities.clearTerminals()
end

-- State bags são apenas identificação: nunca autorizam a ação.
AddStateBagChangeHandler(C.StateBag.DEALER, nil, function(bagName, _, value)
    CreateThread(function()
        -- O bag pode chegar antes da entidade existir localmente: tentar por até 2s e desistir.
        local entity, attempts = 0, 0
        repeat
            entity = GetEntityFromStateBagName(bagName)
            if entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityIsNetworked(entity) then break end
            attempts = attempts + 1
            Wait(100)
        until attempts >= 20
        if entity == 0 or not DoesEntityExist(entity) or not NetworkGetEntityIsNetworked(entity) then return end

        local netId = NetworkGetNetworkIdFromEntity(entity)
        if type(value) == 'number' then
            attach(netId, value, entity)
        else
            detach(netId)
        end
    end)
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Entities.clear()
end)
