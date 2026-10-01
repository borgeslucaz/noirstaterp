---Modo de posicionamento: a NUI some, o admin mira onde quer (raycast da câmera), gira com a
---roda do mouse e confirma. Para ped, veículo e objeto aparece uma prévia do modelo no lugar.
---
---O gizmo (object_gizmo) não funciona no Enhanced — cursor sem seta e alças que não pegam
---clique —, então é mira, como no noir_garage.
---
---A coordenada gravada é a ORIGEM da entidade como a prévia está: o servidor cria exatamente
---ali, então o que o admin vê é o que nasce.
local ClientConfig = require 'config.client'
local Integrations = require 'client.integrations'

local Placement = {}

local active = false

local CONTROLS_DISABLED = { 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 177, 194, 199, 200, 202, 241, 242, 257, 261, 262 }

---@param kind string
---@param modelName string?
---@return integer? model
local function validModel(kind, modelName)
    if type(modelName) ~= 'string' or modelName == '' then return nil end
    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return nil end
    if kind == 'ped' and not IsModelAPed(model) then return nil end
    if kind == 'vehicle' and not IsModelAVehicle(model) then return nil end
    return model
end
Placement.validModel = validModel

---Entidade local de prévia (não vai para a rede), meio transparente e sem colisão.
---@param kind string
---@param model integer
---@param coords vector3
---@return integer? entity
function Placement.createGhost(kind, model, coords)
    if not lib.requestModel(model, 5000) then return nil end
    local entity
    if kind == 'ped' then
        entity = CreatePed(4, model, coords.x, coords.y, coords.z, 0.0, false, false)
        SetEntityInvincible(entity, true)
        SetBlockingOfNonTemporaryEvents(entity, true)
    elseif kind == 'vehicle' then
        entity = CreateVehicle(model, coords.x, coords.y, coords.z, 0.0, false, false)
        SetVehicleDoorsLocked(entity, 2)
    else
        entity = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    end
    SetModelAsNoLongerNeeded(model)
    if not entity or entity == 0 then return nil end
    FreezeEntityPosition(entity, true)
    SetEntityCollision(entity, false, false)
    SetEntityAlpha(entity, 170, false)
    return entity
end

---@param entity integer?
function Placement.deleteGhost(entity)
    if not entity or not DoesEntityExist(entity) then return end
    local kind = GetEntityType(entity)
    SetEntityAsMissionEntity(entity, true, true)
    if kind == 1 then DeletePed(entity)
    elseif kind == 2 then DeleteVehicle(entity)
    else DeleteObject(entity) end
end

---Distância da origem até a base do modelo: é o que se soma ao chão para a entidade ficar
---apoiada nele.
---@param kind string
---@param model integer?
---@return number
local function groundOffset(kind, model)
    if not model then return 0.0 end
    if kind == 'ped' then return 1.0 end
    local minimum = GetModelDimensions(model)
    return -minimum.z
end

---@param request table { requestId, kind, model?, heading, current? }
---@param done fun(result: table)
function Placement.start(request, done)
    if active then return done({ requestId = request.requestId, ok = false }) end
    active = true

    local kind = request.kind or 'position'
    local model = kind ~= 'position' and validModel(kind, request.model) or nil
    local offset = groundOffset(kind, model)
    local heading = (type(request.current) == 'table' and tonumber(request.current.w)) or GetEntityHeading(cache.ped)
    local lift = 0.0
    local ghost = model and Placement.createGhost(kind, model, GetEntityCoords(cache.ped)) or nil

    local keys = {
        { key = 'E', label = 'Confirmar' },
        { key = 'G', label = 'Minha posição' },
    }
    if request.heading then keys[#keys + 1] = { key = 'Roda', label = 'Girar' } end
    keys[#keys + 1] = { key = 'Shift + Roda', label = 'Altura' }
    keys[#keys + 1] = { key = 'Backspace', label = 'Cancelar' }
    Integrations.showKeys(keys, 'baixo')

    CreateThread(function()
        local result = { requestId = request.requestId, ok = false }
        local point
        while true do
            for index = 1, #CONTROLS_DISABLED do DisableControlAction(0, CONTROLS_DISABLED[index], true) end

            local hit, _, endCoords = lib.raycast.cam(1 | 16, 4, ClientConfig.placement.maxDistance)
            if hit and endCoords then point = endCoords end

            local shift = IsControlPressed(0, 21)
            if IsDisabledControlJustPressed(0, 241) then
                if shift then lift = lift + ClientConfig.placement.heightStep * 4
                elseif request.heading then heading = (heading + ClientConfig.placement.rotateStep) % 360 end
            elseif IsDisabledControlJustPressed(0, 242) then
                if shift then lift = lift - ClientConfig.placement.heightStep * 4
                elseif request.heading then heading = (heading - ClientConfig.placement.rotateStep) % 360 end
            end

            local position = point and vector3(point.x, point.y, point.z + offset + lift) or nil
            if position then
                if ghost then
                    SetEntityCoordsNoOffset(ghost, position.x, position.y, position.z, false, false, false)
                    SetEntityHeading(ghost, heading)
                end
                DrawMarker(28, point.x, point.y, point.z + lift + 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.12, 0.12, 0.12, 242, 242, 242, 200, false, false, 2, false, nil, nil, false)
                if request.heading then
                    local radians = math.rad(heading)
                    local tip = vector3(position.x - math.sin(radians) * 1.2, position.y + math.cos(radians) * 1.2, point.z + lift + 0.05)
                    DrawLine(point.x, point.y, point.z + lift + 0.05, tip.x, tip.y, tip.z, 57, 223, 69, 255)
                end
            end

            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 194) then
                break
            end
            if IsControlJustPressed(0, 47) then -- G: onde o admin está (ou o veículo em que está)
                local entity = (kind == 'vehicle' and cache.vehicle) or cache.ped
                local coords = GetEntityCoords(entity)
                local z = coords.z
                if kind == 'position' or kind == 'object' then z = z - 0.98 end
                result = {
                    requestId = request.requestId, ok = true,
                    position = { x = coords.x, y = coords.y, z = z, w = GetEntityHeading(entity) },
                }
                break
            end
            if (IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 201)) and position then
                result = {
                    requestId = request.requestId, ok = true,
                    position = { x = position.x, y = position.y, z = position.z, w = heading },
                }
                break
            end
            Wait(0)
        end
        Placement.deleteGhost(ghost)
        Integrations.hideKeys()
        active = false
        done(result)
    end)
end

---@return boolean
function Placement.isActive() return active end

return Placement
