---Carga nas mãos.
---
---O servidor marca quem carrega no state bag do jogador (`noir_missions:carry`, texto
---`modelo;osso;ox,oy,oz;rx,ry,rz;dict;anim;corre`). Cada cliente cria, LOCALMENTE, o objeto
---preso na mão daquele jogador. Não há objeto de rede carregado: troca de dono não tem o que
---quebrar, e quem desconecta não deixa nada pendurado.
---
---As três regras de objeto local preso, que já derrubaram cliente aqui (prettycrimes):
---  1. `DeleteObject`, não `DeleteEntity`;
---  2. `DetachEntity` antes de apagar;
---  3. nada de criar/apagar dentro do handler de state bag — ele só anota, o laço faz.
local ClientConfig = require 'config.client'
local State = require 'client.runtime.state'
local Integrations = require 'client.integrations'
local Targets = require 'client.interactions.targets'

local Carry = {}

local STATE_KEY = 'noir_missions:carry'

---@type table<integer, string> serverId -> texto do state bag
local carriers = {}
---@type table<integer, { object: integer, ped: integer, value: string }>
local props = {}
local loopRunning = false
local ownLoopRunning = false

---@param value string
---@return table? parsed
local function parse(value)
    if type(value) ~= 'string' then return nil end
    local parts = {}
    for part in (value .. ';'):gmatch('([^;]*);') do parts[#parts + 1] = part end
    if #parts < 7 then return nil end
    local function vec(text)
        local x, y, z = text:match('^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$')
        return tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0
    end
    local ox, oy, oz = vec(parts[3])
    local rx, ry, rz = vec(parts[4])
    return {
        model = parts[1], bone = tonumber(parts[2]) or 28422,
        offset = { ox, oy, oz }, rotation = { rx, ry, rz },
        dict = parts[5], anim = parts[6], canSprint = parts[7] == '1',
    }
end

---@param entry table
local function deleteProp(entry)
    if entry.object and DoesEntityExist(entry.object) then
        DetachEntity(entry.object, true, false)
        DeleteObject(entry.object)
    end
end

---@param ped integer
---@param data table
---@return integer? object
local function createProp(ped, data)
    local model = joaat(data.model)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        lib.print.warn(('[noir_missions] modelo de carga inexistente neste build: %s'):format(data.model))
        return nil
    end
    if not lib.requestModel(model, 5000) then return nil end
    local coords = GetEntityCoords(ped)
    local object = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not object or object == 0 then return nil end
    SetEntityCollision(object, false, false)
    SetEntityCompletelyDisableCollision(object, false, false)
    AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, data.bone),
        data.offset[1], data.offset[2], data.offset[3],
        data.rotation[1], data.rotation[2], data.rotation[3],
        true, true, false, true, 1, true)
    return object
end

---Mantém um objeto na mão de cada jogador que carrega e está no escopo.
local function refresh()
    for serverId, value in pairs(carriers) do
        local player = GetPlayerFromServerId(serverId)
        local ped = player ~= -1 and GetPlayerPed(player) or 0
        local entry = props[serverId]
        if ped == 0 or not DoesEntityExist(ped) then
            if entry then
                deleteProp(entry)
                props[serverId] = nil
            end
        elseif not entry or entry.ped ~= ped or entry.value ~= value or not DoesEntityExist(entry.object) then
            if entry then deleteProp(entry) end
            local data = parse(value)
            local object = data and createProp(ped, data)
            props[serverId] = object and { object = object, ped = ped, value = value } or nil
        end
    end
    for serverId, entry in pairs(props) do
        if not carriers[serverId] then
            deleteProp(entry)
            props[serverId] = nil
        end
    end
end

local function ensureLoop()
    if loopRunning then return end
    loopRunning = true
    CreateThread(function()
        while next(carriers) or next(props) do
            refresh()
            Wait(300)
        end
        loopRunning = false
    end)
end

-- O próprio jogador carregando: animação, sem correr/atirar/entrar em veículo, tecla de largar.

local function dropKeyLabel()
    return ClientConfig.keys.drop
end

local function ownLoop()
    if ownLoopRunning then return end
    ownLoopRunning = true
    CreateThread(function()
        local data = parse(LocalPlayer.state[STATE_KEY])
        local dictOk = data and DoesAnimDictExist(data.dict) and lib.requestAnimDict(data.dict, 5000)
        Integrations.showKeys({ { key = dropKeyLabel(), label = 'Largar' } }, 'baixo')
        local nextAnim = 0
        while LocalPlayer.state[STATE_KEY] do
            local ped = cache.ped
            if dictOk and GetGameTimer() >= nextAnim then
                if not IsEntityPlayingAnim(ped, data.dict, data.anim, 3) then
                    TaskPlayAnim(ped, data.dict, data.anim, 8.0, 8.0, -1, 49, 0.0, false, false, false)
                end
                nextAnim = GetGameTimer() + 500
            end
            if data and not data.canSprint then DisableControlAction(0, 21, true) end -- correr
            DisableControlAction(0, 22, true)  -- pular
            DisableControlAction(0, 23, true)  -- entrar em veículo
            DisableControlAction(0, 24, true)  -- atacar
            DisableControlAction(0, 25, true)  -- mirar
            DisableControlAction(0, 37, true)  -- roda de armas
            DisableControlAction(0, 44, true)  -- cobertura
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            Wait(0)
        end
        Integrations.hideKeys()
        if data and dictOk then
            StopAnimTask(cache.ped, data.dict, data.anim, 2.0)
            RemoveAnimDict(data.dict)
        end
        ownLoopRunning = false
    end)
end

AddStateBagChangeHandler(STATE_KEY, nil, function(bagName, _, value)
    local player = GetPlayerFromStateBagName(bagName)
    if not player or player == 0 then return end
    local serverId = GetPlayerServerId(player)
    carriers[serverId] = type(value) == 'string' and value or nil
    -- Só anota. Criar e apagar objeto fica para o laço, fora do processamento do state bag.
    SetTimeout(0, function()
        ensureLoop()
        if serverId == cache.serverId and carriers[serverId] then ownLoop() end
    end)
end)

RegisterCommand('+noirMissionsDrop', function()
    local instanceId = State.instanceId()
    if not instanceId or not State.isCarrying() then return end
    Targets.report(lib.callback.await('noir_missions:server:cargoDrop', false, instanceId))
end, false)
RegisterCommand('-noirMissionsDrop', function() end, false)
RegisterKeyMapping('+noirMissionsDrop', 'Noir: largar carga de missão', 'keyboard', ClientConfig.keys.drop)

---Quem já carregava antes deste cliente ligar (restart, entrada no servidor) não gera
---mudança de state bag; lê uma vez de todos os jogadores ativos.
function Carry.scan()
    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        local value = Player(serverId).state[STATE_KEY]
        if type(value) == 'string' and carriers[serverId] ~= value then
            carriers[serverId] = value
            ensureLoop()
            if serverId == cache.serverId then ownLoop() end
        end
    end
end

function Carry.cleanup()
    for serverId, entry in pairs(props) do
        deleteProp(entry)
        props[serverId] = nil
    end
    carriers = {}
end

return Carry
