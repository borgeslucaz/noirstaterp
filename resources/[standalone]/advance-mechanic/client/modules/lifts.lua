local Lifts = {}
local Framework = require 'shared.framework'
local activeLift = nil
local liftZones = {}
local lockedVehicles = {}

local function isMechanic()
    local playerData = Framework.GetPlayerData()
    return playerData and playerData.job and playerData.job.name == Config.JobName
end

function Lifts.CreateZones(shops)
    -- Clear existing zones
    for _, zone in pairs(liftZones) do
        zone:remove()
    end
    liftZones = {}
    
    for _, shop in ipairs(shops) do
        if shop.lifts then
            for liftId, lift in ipairs(shop.lifts) do
                if type(lift) == 'table' and lift.control and lift.entry and lift.pos then
                -- Create lift control point
                local controlZone = lib.points.new({
                    coords = lift.control,
                    distance = 5,
                    lift = lift,
                    liftId = liftId,
                    shopId = shop.id
                })
                
                function controlZone:nearby()
                    if self.currentDistance < 2.0 and isMechanic() then
                        lib.showTextUI(locale('press_to_control_lift'))
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            activeLift = {
                                data = self.lift,
                                id = self.liftId,
                                shopId = self.shopId
                            }
                            Lifts.OpenControlMenu()
                        end
                    end
                end
                
                function controlZone:onExit()
                    lib.hideTextUI()
                end
                
                -- Create entry point
                local entryZone = lib.points.new({
                    coords = lift.entry,
                    distance = 10,
                    lift = lift,
                    liftId = liftId,
                    shopId = shop.id
                })
                
                function entryZone:onEnter()
                    if isMechanic() and cache.vehicle and GetPedInVehicleSeat(cache.vehicle, -1) == cache.ped then
                        local vehicleState = Entity(cache.vehicle).state
                        if not vehicleState.onLift then
                            lib.showTextUI(locale('position_vehicle_on_lift'))
                            self.positionCheckTicker = lib.timer(500, function()
                                if not self.isInside or not cache.vehicle then
                                    self.positionCheckTicker:forceEnd()
                                    return
                                end
                                
                                local vehiclePos = GetEntityCoords(cache.vehicle)
                                local distance = #(vehiclePos - self.lift.pos)
                                
                                if distance < 1.5 then
                                    self.vehicleOnLift = cache.vehicle
                                    vehicleState:set('onLift', true, true)
                                    vehicleState:set('liftId', self.liftId, true)
                                    vehicleState:set('shopId', self.shopId, true)
                                    vehicleState:set('liftOccupiedBy', VehToNet(cache.vehicle), true)
                                    
                                    lib.notify({
                                        title = locale('vehicle_positioned'),
                                        description = locale('use_lift_controls'),
                                        type = 'success'
                                    })
                                    self.positionCheckTicker:forceEnd()
                                end
                            end)
                        end
                    end
                end
                
                function entryZone:onExit()
                    lib.hideTextUI()
                    
                    if self.positionCheckTicker then
                        self.positionCheckTicker:forceEnd()
                        self.positionCheckTicker = nil
                    end
                    
                    local vehicle = self.vehicleOnLift or cache.vehicle
                    if vehicle and DoesEntityExist(vehicle) then
                        local vehicleState = Entity(vehicle).state
                        if vehicleState.onLift and (not vehicleState.liftHeight or vehicleState.liftHeight == 0) then
                            vehicleState:set('onLift', false, true)
                            vehicleState:set('liftId', nil, true)
                            vehicleState:set('shopId', nil, true)
                            vehicleState:set('liftOccupiedBy', nil, true)
                        end
                    end
                    self.vehicleOnLift = nil
                end
                
                table.insert(liftZones, controlZone)
                table.insert(liftZones, entryZone)
                end
            end
        end
    end
end

function Lifts.OpenControlMenu()
    if not activeLift then return end
    
    local vehicle = lib.getClosestVehicle(activeLift.data.pos, 3.0, false)
    local vehicleState = vehicle and Entity(vehicle).state
    if not vehicle or not vehicleState or not vehicleState.onLift
        or vehicleState.shopId ~= activeLift.shopId or vehicleState.liftId ~= activeLift.id then
        lib.notify({
            title = locale('no_vehicle_on_lift'),
            type = 'error'
        })
        return
    end
    
    lib.registerContext({
        id = 'lift_control',
        title = locale('lift_control'),
        options = {
            {
                title = locale('raise_lift'),
                icon = 'fas fa-arrow-up',
                onSelect = function()
                    Lifts.Move(vehicle, 'up')
                end
            },
            {
                title = locale('lower_lift'),
                icon = 'fas fa-arrow-down',
                onSelect = function()
                    Lifts.Move(vehicle, 'down')
                end
            },
            {
                title = locale('lock_vehicle'),
                icon = 'fas fa-lock',
                onSelect = function()
                    Lifts.LockVehicle(vehicle, true)
                end
            },
            {
                title = locale('unlock_vehicle'),
                icon = 'fas fa-unlock',
                onSelect = function()
                    Lifts.LockVehicle(vehicle, false)
                end
            },
            {
                title = locale('inspect_vehicle'),
                icon = 'fas fa-search',
                description = locale('inspect_vehicle_desc'),
                onSelect = function()
                    local Inspection = require 'client.modules.inspection'
                    Inspection.InspectOnLift(vehicle)
                end
            }
        }
    })
    
    lib.showContext('lift_control')
end

function Lifts.Move(vehicle, direction)
    if not vehicle or not DoesEntityExist(vehicle) or not activeLift then return end
    if direction ~= 'up' and direction ~= 'down' then return end
    
    local vehicleState = Entity(vehicle).state
    if vehicleState.liftMoving then
        lib.notify({ title = locale('lift_in_use'), type = 'warning' })
        return
    end

    local lift = activeLift
    if vehicleState.shopId ~= lift.shopId or vehicleState.liftId ~= lift.id then return end

    local currentHeight = tonumber(vehicleState.liftHeight) or 0.0
    currentHeight = math.max(Config.Lifts.minHeight, math.min(Config.Lifts.maxHeight, currentHeight))
    local targetHeight = currentHeight
    
    if direction == 'up' then
        targetHeight = math.min(currentHeight + 0.5, Config.Lifts.maxHeight)
    else
        targetHeight = math.max(currentHeight - 0.5, Config.Lifts.minHeight)
    end
    
    if targetHeight == currentHeight then
        lib.notify({
            title = locale('lift_at_limit'),
            type = 'warning'
        })
        return
    end
    
    -- Set statebag for synchronization
    vehicleState:set('liftMoving', true, true)
    vehicleState:set('liftTarget', targetHeight, true)
    vehicleState:set('onLift', true, true)
    vehicleState:set('liftId', lift.id, true)
    vehicleState:set('shopId', lift.shopId, true)
    
    -- Animate lift movement
    local startHeight = currentHeight
    local startTime = GetGameTimer()
    local duration = math.abs(targetHeight - startHeight) / Config.Lifts.moveSpeed * 1000
    
    CreateThread(function()
        while DoesEntityExist(vehicle) and GetGameTimer() - startTime < duration do
            local progress = (GetGameTimer() - startTime) / duration
            local newHeight = startHeight + (targetHeight - startHeight) * progress
            
            local pos = GetEntityCoords(vehicle)
            SetEntityCoords(vehicle, pos.x, pos.y, lift.data.pos.z + newHeight, false, false, false, true)
            
            Wait(0)
        end
        
        -- Final position
        if not DoesEntityExist(vehicle) then return end
        local finalPos = GetEntityCoords(vehicle)
        SetEntityCoords(vehicle, finalPos.x, finalPos.y, lift.data.pos.z + targetHeight, false, false, false, true)
        
        -- Update statebag
        vehicleState:set('liftMoving', false, true)
        vehicleState:set('liftHeight', targetHeight, true)
        
        lib.notify({
            title = locale('lift_moved'),
            type = 'success'
        })
    end)
end

function Lifts.LockVehicle(vehicle, locked)
    if not vehicle then return end
    
    FreezeEntityPosition(vehicle, locked)
    lockedVehicles[vehicle] = locked or nil
    local vehicleState = Entity(vehicle).state
    vehicleState:set('liftLocked', locked, true)
    
    lib.notify({
        title = locked and locale('vehicle_locked') or locale('vehicle_unlocked'),
        type = 'success'
    })
end

-- Watch for other players moving vehicles on lifts
AddStateBagChangeHandler('liftMoving', nil, function(bagName, key, value, _reserved, replicated)
    if not value or not replicated then return end
    
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 then return end
    
    local vehicleState = Entity(entity).state
    if activeLift and vehicleState.shopId == activeLift.shopId and vehicleState.liftId == activeLift.id then
        -- Another player is controlling this lift
        lib.notify({
            title = locale('lift_in_use'),
            type = 'warning'
        })
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for vehicle in pairs(lockedVehicles) do
        if DoesEntityExist(vehicle) then
            FreezeEntityPosition(vehicle, false)
        end
    end
end)

return Lifts
