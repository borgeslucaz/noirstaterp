---Caixa na mão. Só visual: quem sabe se o jogador está carregando é o servidor.
---
---Prop e animação são conferidas antes de usar (no Enhanced, o que não existe no build
---derruba o cliente); faltando uma delas, o jogador carrega sem a parte que falta. Enquanto
---carrega, não corre, não pula, não entra em veículo e não saca arma.

local Config = require 'config.shared'

local Carry = {}

local carrying = false
local prop = nil

local settings = Config.haul.carry

local function removeProp()
    if not prop then return end
    if DoesEntityExist(prop) then
        DetachEntity(prop, true, false)
        SetEntityAsMissionEntity(prop, true, true)
        DeleteObject(prop)
    end
    prop = nil
end

local function attachProp()
    local model = joaat(settings.prop)
    if not IsModelInCdimage(model) or not pcall(lib.requestModel, model, 5000) then return end
    local coords = GetEntityCoords(cache.ped)
    prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if prop == 0 then prop = nil return end
    SetEntityCollision(prop, false, false)
    local offset, rotation = settings.offset, settings.rotation
    AttachEntityToEntity(prop, cache.ped, GetPedBoneIndex(cache.ped, settings.bone),
        offset[1], offset[2], offset[3], rotation[1], rotation[2], rotation[3],
        true, true, false, true, 1, true)
end

local function hasAnim()
    return DoesAnimDictExist(settings.dict) and pcall(lib.requestAnimDict, settings.dict, 5000)
end

---@return boolean
function Carry.isCarrying()
    return carrying
end

function Carry.start()
    if carrying then return end
    carrying = true
    attachProp()
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
    removeProp()
    StopAnimTask(cache.ped, settings.dict, settings.clip, 1.0)
    RemoveAnimDict(settings.dict)
end

return Carry
