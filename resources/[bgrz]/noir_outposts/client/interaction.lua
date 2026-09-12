-- Zonas do computador, progress bars e envio de intenção. Nenhum resultado nasce aqui.
NoirOutposts = NoirOutposts or {}

local Interaction = {}
NoirOutposts.Interaction = Interaction

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

local zones = {}
local busy = false

local function requestId()
    return ('%s%x%x'):format('r', GetGameTimer(), math.random(0, 0xFFFFFF))
end

Interaction.requestId = requestId

---@param animation table?
local function playAnimation(animation)
    if not animation then return end
    if not lib.requestAnimDict(animation.dict, 3000) then return end
    TaskPlayAnim(cache.ped, animation.dict, animation.clip, 3.0, -3.0, -1, animation.flag or 1, 0, false, false, false)
    RemoveAnimDict(animation.dict)
end

local function stopAnimation()
    ClearPedTasks(cache.ped)
end

---Progress bar com cancelamento; a duração real é validada no servidor.
---@param label string
---@param durationMs integer
---@param animation table?
---@return boolean completed
local function runProgress(label, durationMs, animation)
    playAnimation(animation)
    local completed = lib.progressCircle({
        label = label,
        duration = durationMs,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    stopAnimation()
    return completed == true
end

Interaction.runProgress = runProgress

local function clearZones()
    for name in pairs(zones) do
        exports.bgrz_core:RemoveZoneTarget(name)
        zones[name] = nil
    end
end

function Interaction.clear()
    clearZones()
    NoirOutposts.Entities.clear()
end

---Cria/remove o acesso ao computador conforme o outpost está ativo.
---Onde existe atendente, ele é o alvo; a zona invisível cobre o resto.
function Interaction.refresh()
    local Client = NoirOutposts.Client
    local wanted = {}

    for index = 1, #Client.outposts do
        local outpost = Client.outposts[index]
        if outpost.status ~= C.OutpostStatus.INACTIVE then wanted[outpost.id] = true end
    end

    local withNpc = NoirOutposts.Entities.syncTerminals(wanted)

    for name in pairs(zones) do
        local outpostId = name:match('^computer:(.+)$')
        if outpostId and (not wanted[outpostId] or withNpc[outpostId]) then
            exports.bgrz_core:RemoveZoneTarget(name)
            zones[name] = nil
        end
    end

    for outpostId in pairs(wanted) do
        local name = 'computer:' .. outpostId
        if not zones[name] and not withNpc[outpostId] then
            local definition = shared.outposts[outpostId]
            local ok = exports.bgrz_core:AddSphereZoneTarget({
                name = name,
                coords = vector3(definition.computer.x, definition.computer.y, definition.computer.z),
                radius = shared.interaction.computerDistance,
                debug = clientConfig.debug,
                options = {
                    {
                        name = 'computer:open',
                        icon = clientConfig.target.icons.computer,
                        label = locale('target.open_computer'),
                        distance = shared.interaction.computerDistance,
                        onSelect = function() Interaction.openComputer(outpostId) end,
                    },
                },
            })
            if ok then zones[name] = true end
        end
    end
end

---@param outpostId string
function Interaction.openComputer(outpostId)
    if busy then return end
    busy = true
    local response = lib.callback.await(C.Callbacks.OPEN_PANEL, false, { outpostId = outpostId })
    busy = false
    if not NoirOutposts.Client.handleFailure(response) then return end
    NoirOutposts.Ui.open(outpostId, response.data)
end

---Organização do jogador, lida do bridge. Um bridge antigo ou parado não pode apagar a
---opção do target, então nesse caso caímos para o último snapshot conhecido.
---@return string? organizationId
function Interaction.organizationId()
    local ok, gang = pcall(function() return exports.bgrz_core:GetGang() end)
    if not ok then
        return NoirOutposts.Client.context.organizationId
    end
    if type(gang) ~= 'table' or type(gang.name) ~= 'string' then return nil end
    if gang.name == '' or gang.name == 'none' then return nil end
    return gang.name
end

---Só esconde a opção de quem é do dono. Lê a gang viva do bridge em vez do snapshot
---guardado: um evento de grupo perdido deixaria o cache preso na gang antiga e
---o jogador sem conseguir roubar.
---@param netId integer
---@return boolean
function Interaction.canRobDealer(netId)
    local dealerId = NoirOutposts.Entities.dealerOf(netId)
    if not dealerId then return false end
    local entity = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or nil
    if not entity or entity == 0 then return false end

    local outpostId, _, status = NoirOutposts.Entities.readState(entity)
    if status ~= C.DealerStatus.DEPLOYED then return false end

    local outpost = outpostId and NoirOutposts.Client.outpost(outpostId) or nil
    if not outpost or not outpost.ownerOrganizationId then return false end

    return outpost.ownerOrganizationId ~= Interaction.organizationId()
end

---@param dealerId integer
---@param netId integer
function Interaction.inspectDealer(dealerId, netId)
    if busy then return end
    busy = true
    local response = lib.callback.await(C.Callbacks.INSPECT, false, { dealerId = dealerId, netId = netId })
    busy = false
    if not NoirOutposts.Client.handleFailure(response) then return end

    local data = response.data
    local lines = { ('%s · %s'):format(data.name, locale('dealer.status_' .. data.status)) }
    if data.isOwner then
        lines[#lines + 1] = locale('dealer.stock_line', data.stockTotal or 0)
        lines[#lines + 1] = locale('dealer.sales_line', data.lifetimeSales or 0)
    end
    lib.notify({
        title = data.outpostLabel,
        description = table.concat(lines, '  \n'),
        type = 'inform',
        duration = 6000,
    })
end

---@param dealerId integer
---@param netId integer
function Interaction.robDealer(dealerId, netId)
    if busy then return end
    busy = true

    local started = lib.callback.await(C.Callbacks.ROBBERY_START, false, { dealerId = dealerId, netId = netId })
    if not NoirOutposts.Client.handleFailure(started) then
        busy = false
        return
    end

    local sessionId = started.data.sessionId
    local completed = runProgress(
        locale('progress.robbery'), started.data.durationMs, clientConfig.animations.robbery)

    if not completed then
        lib.callback.await(C.Callbacks.ROBBERY_CANCEL, false, { sessionId = sessionId })
        busy = false
        return
    end

    local result = lib.callback.await(C.Callbacks.ROBBERY_COMPLETE, false, { sessionId = sessionId })
    busy = false
    if not NoirOutposts.Client.handleFailure(result) then return end

    local data = result.data
    if (data.purse or 0) > 0 then
        NoirOutposts.Client.notify(locale('robbery.purse_taken', data.purse), 'success')
    end
    if (data.quantity or 0) > 0 then
        NoirOutposts.Client.notify(locale('robbery.stock_taken', data.quantity), 'success')
    end
end

RegisterNetEvent(C.Events.SESSION_ABORTED, function(payload)
    if source ~= 65535 then return end
    busy = false
    if type(payload) ~= 'table' then return end
    NoirOutposts.Client.notify(NoirOutposts.Client.message(payload.reason or 'internal_error'), 'error')
end)

-- Diagnóstico local: diz por que a opção de roubar aparece ou não no corredor mais próximo.
RegisterCommand('outpostsdebug', function()
    local Client = NoirOutposts.Client
    local ok, gang = pcall(function() return exports.bgrz_core:GetGang() end)
    local lines = {
        ('bridge GetGang: %s'):format(ok and 'ok' or 'indisponível (reinicie o bgrz_core)'),
        ('sua organização: %s'):format(Interaction.organizationId() or 'nenhuma'),
        ('gang bruta: %s'):format(ok and type(gang) == 'table' and tostring(gang.name) or '-'),
    }

    local coords = GetEntityCoords(cache.ped)
    local nearest, nearestDistance
    for index = 1, #Client.outposts do
        local outpost = Client.outposts[index]
        local definition = shared.outposts[outpost.id]
        local distance = #(coords - vector3(definition.entrance.x, definition.entrance.y, definition.entrance.z))
        if not nearestDistance or distance < nearestDistance then
            nearest, nearestDistance = outpost, distance
        end
    end
    if nearest then
        lines[#lines + 1] = ('outpost mais próximo: %s (%s), dono %s'):format(
            nearest.id, nearest.status, nearest.ownerOrganizationId or 'nenhum')
        lines[#lines + 1] = ('corredores no snapshot: %d'):format(#(nearest.dealers or {}))
    end

    local targets = 0
    for netId, dealerId in pairs(NoirOutposts.Entities.tracked()) do
        targets = targets + 1
        local entity = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0
        local _, _, status = NoirOutposts.Entities.readState(entity)
        lines[#lines + 1] = ('corredor %s: netId %s, estado %s, pode roubar %s'):format(
            dealerId, netId, tostring(status), tostring(Interaction.canRobDealer(netId)))
    end
    if targets == 0 then lines[#lines + 1] = 'nenhum ped de corredor registrado neste client' end

    for index = 1, #lines do print(('[noir_outposts] %s'):format(lines[index])) end
    lib.notify({ description = table.concat(lines, '  \n'), type = 'inform', duration = 15000 })
end, false)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearZones()
    stopAnimation()
end)
