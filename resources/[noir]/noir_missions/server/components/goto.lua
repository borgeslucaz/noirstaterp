---Passos de deslocamento: ir até um local e sair de uma área.
---As posições dos participantes vêm do monitor (coordenadas do ped no servidor, §7.3).
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local Cargo = require 'server.components.cargo'

local Goto = {}

---Quantos participantes estão dentro do raio (cilindro: só o plano conta).
---@param inst table
---@param center table
---@param radius number
---@return integer inside
---@return integer total
function Goto.countInside(inst, center, radius)
    local inside, total = 0, 0
    for _, position in pairs(inst.positions) do
        total = total + 1
        if Utils.distance2d(position, center) <= radius then inside = inside + 1 end
    end
    return inside, total
end

---@param inside integer
---@param total integer
---@param who string
---@return boolean
local function satisfied(inside, total, who)
    if total == 0 then return false end
    if who == 'all' then return inside == total end
    return inside > 0
end

---Veículos que levam pelo menos `required` peças da carga.
---@param inst table
---@param cargoId string?
---@param required integer
---@return table[] records
local function vehiclesWithCargo(inst, cargoId, required)
    local list = {}
    if cargoId then
        for _, entry in ipairs(Cargo.loadedByVehicle(inst, cargoId)) do
            if entry.count >= required then list[#list + 1] = entry.record end
        end
        return list
    end
    for _, vehicle in pairs(inst.vehicles or {}) do
        if vehicle.record then list[#list + 1] = vehicle.record end
    end
    return list
end

MissionComponents.register('goto', {
    steps = {
        ['goto'] = {
            tick = function(inst, step)
                local inside, total = Goto.countInside(inst, step.coords, step.radius or 100)
                if satisfied(inside, total, step.who) then Runtime.completeStep(inst, step) end
            end,
            view = function(inst, step, _, view)
                if step.showBlip ~= false or step.showGps then
                    view.blips[#view.blips + 1] = {
                        id = 'step:' .. step.id, coords = step.coords, sprite = step.blipSprite or 1,
                        color = step.blipColor or 5, label = Runtime.render(inst, step.blipLabel or step.label),
                        route = step.showGps ~= false, radius = step.blipArea and step.radius or nil,
                    }
                end
            end,
        },
        leave_area = {
            tick = function(inst, step)
                            local required = step.cargoCount or 0
                if step.cargo and required <= 0 then required = Cargo.total(inst, step.cargo) end

                if step.who == 'vehicle' then
                    local candidates = vehiclesWithCargo(inst, step.cargo, required)
                    for index = 1, #candidates do
                        local coords = GetEntityCoords(candidates[index].entity)
                        if Utils.distance2d(coords, step.coords) > step.radius then
                            Runtime.completeStep(inst, step)
                            return
                        end
                    end
                    return
                end

                if step.cargo and Cargo.count(inst, step.cargo, 'loaded') < required then return end
                local inside, total = Goto.countInside(inst, step.coords, step.radius)
                local outside = total - inside
                if total > 0 and ((step.who == 'all' and inside == 0) or (step.who ~= 'all' and outside > 0)) then
                    Runtime.completeStep(inst, step)
                end
            end,
            objective = function(inst, step)
                            if not step.cargo then return nil end
                local required = (step.cargoCount or 0) > 0 and step.cargoCount or Cargo.total(inst, step.cargo)
                local loaded = Cargo.count(inst, step.cargo, 'loaded')
                if loaded >= required then return nil end
                return { progress = { current = loaded, max = required } }
            end,
            view = function(_, step, _, view)
                if step.showArea ~= false then
                    view.blips[#view.blips + 1] = {
                        id = 'step:' .. step.id, coords = step.coords, sprite = 0, color = 1,
                        label = 'Área', radius = step.radius, areaOnly = true,
                    }
                end
            end,
        },
    },
})

return Goto
