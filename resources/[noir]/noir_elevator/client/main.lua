local config = require 'config.client'
local Integrations = require 'client.integrations'
local Travel = require 'client.travel'

---@type integer[]
local zones = {}

---@param elevatorId string
---@param elevator NoirElevator
---@param here integer índice do stop onde o jogador chamou
local function openPanel(elevatorId, elevator, here)
    local options = {}
    for i, stop in ipairs(elevator.stops) do
        local isHere = i == here
        options[#options + 1] = {
            title = stop.label,
            description = isHere and locale('here') or locale('go_to', stop.label),
            disabled = isHere,
            onSelect = function()
                Travel.run(elevator, elevator.stops[here], stop)
            end,
        }
    end

    local menuId = ('noir_elevator:%s'):format(elevatorId)
    lib.registerContext({
        id = menuId,
        title = locale('panel_title', elevator.label),
        options = options,
    })
    lib.showContext(menuId)
end

---Botão da parada: o medido, ou o do elevador girado com o w da cabine.
---@param elevator NoirElevator
---@param stop NoirElevatorStop
---@return vector3
local function buttonOf(elevator, stop)
    if stop.target then return stop.target end
    local button, c = elevator.button, stop.coords
    local h = math.rad(c.w)
    local forward = vec3(-math.sin(h), math.cos(h), 0.0)
    local right = vec3(math.cos(h), math.sin(h), 0.0)
    return c.xyz + forward * button.forward + right * button.right + vec3(0.0, 0.0, button.up)
end

local function canCall()
    return not Travel.isActive() and not cache.vehicle
end

for elevatorId, elevator in pairs(config.elevators) do
    for i, stop in ipairs(elevator.stops) do
        zones[#zones + 1] = Integrations.addZone({
            name = ('noir_elevator:%s:%d'):format(elevatorId, i),
            coords = buttonOf(elevator, stop),
            size = vec3(elevator.button.size, elevator.button.size, elevator.button.size),
            rotation = stop.coords.w,
            debug = config.debugTargets,
            options = {
                {
                    name = 'noir_elevator:call',
                    label = locale('call'),
                    icon = 'fa-solid fa-elevator',
                    distance = 2.0,
                    canInteract = canCall,
                    onSelect = function()
                        openPanel(elevatorId, elevator, i)
                    end,
                },
            },
        })
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(zones) do Integrations.removeZone(id) end
    if Travel.isActive() then Travel.cleanup() end
end)
