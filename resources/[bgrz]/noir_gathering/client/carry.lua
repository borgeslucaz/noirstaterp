---Caixa na mão, vista por todo mundo por perto.
---
---Quem diz que um jogador está carregando é o SERVIDOR, pelo state bag replicado
---`noirGatheringCarry` do jogador. Cada client olha os jogadores próximos e põe uma caixa
---local na mão de quem está com o state ligado; a animação de quem carrega já é
---sincronizada pelo jogo. Assim não existe prop de rede para ficar órfão quando alguém cai,
---e a caixa some sozinha com o ped.
---
---A leitura é por varredura, não dentro do handler do state bag: criar e apagar prop
---dentro do handler já derrubou cliente aqui.
---
---Para o próprio jogador, `start`/`stop` cuidam só do que é dele: animação e controles
---travados (não corre, não pula, não entra em veículo, não saca arma).

local Config = require 'config.shared'

local Carry = {}

local STATE_KEY = 'noirGatheringCarry'
local SCAN_MS = 250
local SCAN_DISTANCE = 60.0

local settings = Config.haul.carry
local carrying = false

---@type table<integer, { entity: integer, ped: integer }> serverId -> caixa na mão
local boxes = {}

local function removeBox(serverId)
    local box = boxes[serverId]
    if not box then return end
    boxes[serverId] = nil
    if DoesEntityExist(box.entity) then
        DetachEntity(box.entity, true, false)
        SetEntityAsMissionEntity(box.entity, true, true)
        DeleteObject(box.entity)
    end
end

---@param ped integer
---@return integer?
local function createBox(ped)
    local model = joaat(settings.prop)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 5000) then return nil end
    local coords = GetEntityCoords(ped)
    local entity = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if entity == 0 then return nil end
    SetEntityCollision(entity, false, false)
    local offset, rotation = settings.offset, settings.rotation
    AttachEntityToEntity(entity, ped, GetPedBoneIndex(ped, settings.bone),
        offset[1], offset[2], offset[3], rotation[1], rotation[2], rotation[3],
        true, true, false, true, 1, true)
    return entity
end

---Uma volta: caixa em quem está carregando e perto; nenhuma em mais ninguém.
local function scan()
    local origin = GetEntityCoords(cache.ped)
    local wanted = {}
    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)
        local ped = GetPlayerPed(player)
        if Player(serverId).state[STATE_KEY] == true and DoesEntityExist(ped)
            and #(GetEntityCoords(ped) - origin) <= SCAN_DISTANCE then
            wanted[serverId] = ped
        end
    end

    for serverId, box in pairs(boxes) do
        -- Ped trocado (respawn, troca de modelo) leva a caixa junto com o antigo.
        if wanted[serverId] ~= box.ped or not DoesEntityExist(box.entity) then removeBox(serverId) end
    end
    for serverId, ped in pairs(wanted) do
        if not boxes[serverId] then
            local entity = createBox(ped)
            if entity then boxes[serverId] = { entity = entity, ped = ped } end
        end
    end
end

CreateThread(function()
    while true do
        scan()
        -- Sem ninguém carregando por perto, a varredura fica mais espaçada.
        Wait(next(boxes) and SCAN_MS or SCAN_MS * 4)
    end
end)

---@return boolean
function Carry.isCarrying()
    return carrying
end

local function hasAnim()
    return DoesAnimDictExist(settings.dict) and pcall(lib.requestAnimDict, settings.dict, 5000)
end

function Carry.start()
    if carrying then return end
    carrying = true
    local animated = hasAnim()

    CreateThread(function()
        while carrying do
            DisableControlAction(0, 21, true) -- correr
            DisableControlAction(0, 22, true) -- pular
            DisableControlAction(0, 23, true) -- entrar em veículo
            DisableControlAction(0, 24, true) -- atacar
            DisableControlAction(0, 25, true) -- mirar
            DisableControlAction(0, 37, true) -- roda de armas
            if animated and not IsEntityPlayingAnim(cache.ped, settings.dict, settings.clip, 3) then
                TaskPlayAnim(cache.ped, settings.dict, settings.clip, 8.0, 8.0, -1, 49, 0, false, false, false)
            end
            Wait(0)
        end
    end)
end

function Carry.stop()
    if not carrying then return end
    carrying = false
    StopAnimTask(cache.ped, settings.dict, settings.clip, 1.0)
    RemoveAnimDict(settings.dict)
end

---Resource parando: nenhuma caixa local fica para trás.
function Carry.clearAll()
    for serverId in pairs(boxes) do removeBox(serverId) end
end

return Carry
