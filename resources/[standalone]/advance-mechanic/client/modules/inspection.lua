local Inspection = {}
local VisualEffects = require 'client.modules.visual_effects'
local checkpoints = Config.Inspection.checkPoints
local activeShops = {}

function Inspection.SetActiveShops(shops)
    activeShops = shops
end

function Inspection.IsInMechanicShop(coords)
    coords = coords or GetEntityCoords(cache.ped)
    
    for _, shop in ipairs(activeShops) do
        if shop.zones and shop.zones.inspection then
            local distance = #(coords - shop.zones.inspection)
            if distance < 50.0 then
                return true, shop.id
            end
        end
    end
    
    return false, nil
end

function Inspection.InspectOnLift(vehicle)
if not DoesEntityExist(vehicle) then return end
    
    -- Ensure the hood is open for engine inspection
    if not IsVehicleDoorFullyOpen(vehicle, 4) then -- 4 is the hood
        lib.notify({
            title = locale('open_hood_first'),
            type = 'error'
        })
        return
    end
    
    local vehicleState = Entity(vehicle).state
    if not vehicleState.onLift then
        lib.notify({
            title = locale('vehicle_not_on_lift'),
            type = 'error'
        })
        return
    end
    
    Inspection.PerformInspection(vehicle, true)
end

function Inspection.Inspect(vehicle)
    if not DoesEntityExist(vehicle) then return end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local isOwned = lib.callback.await('mechanic:server:isVehicleOwned', false, plate)
    
    if not isOwned then
        lib.notify({
            title = locale('vehicle_not_owned'),
            type = 'error'
        })
        return
    end
    
    local isInShop = Inspection.IsInMechanicShop()
    
    if not isInShop then
        local toolboxCount = tonumber(exports.ox_inventory:Search('count', 'toolbox')) or 0
        if toolboxCount < 1 then
            lib.notify({
                title = locale('toolbox_required_outside'),
                description = locale('need_toolbox_outside_shop'),
                type = 'error'
            })
            return
        end
    end
    
    Inspection.PerformInspection(vehicle, false)
end

function Inspection.PerformInspection(vehicle, isOnLift)
    if not DoesEntityExist(vehicle) then return end
    
    -- Check if hood is open for better inspection
    if not VisualEffects.CheckHoodOpen(vehicle) then
        lib.notify({
            title = locale('open_hood_recommended'),
            description = locale('better_inspection_with_hood_open'),
            type = 'info'
        })
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    local inspectionResults = {}
    local totalIssues = 0
    local storedInspection = lib.callback.await('mechanic:server:getVehicleInspection', false, plate) or {}
    local fluidData = lib.callback.await('mechanic:server:getVehicleFluidData', false, plate) or {}
    
    for name, checkpoint in pairs(checkpoints) do
        -- Add visual effects for engine inspection
        local effects = nil
        if name == 'engine' and VisualEffects.CheckHoodOpen(vehicle) then
            local enginePos = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, "engine"))
            effects = VisualEffects.CreateParticleAtCoords('smoke', enginePos, 2000)
        end
        
        local progress = lib.progressBar({
            duration = isOnLift and Config.Animations.inspect.duration / 2 or Config.Animations.inspect.duration,
            label = locale('checking_part', checkpoint.label),
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true
            },
            anim = {
                dict = Config.Animations.inspect.dict,
                clip = Config.Animations.inspect.anim
            }
        })
        
        if progress then
            local engineHealth = math.max(0, math.min(100, GetVehicleEngineHealth(vehicle) / 10))
            local bodyHealth = math.max(0, math.min(100, GetVehicleBodyHealth(vehicle) / 10))
            local stored = type(storedInspection[name]) == 'table' and tonumber(storedInspection[name].health) or 100
            local measured = {
                engine = engineHealth,
                oil = tonumber(fluidData.oilLevel),
                battery = tonumber(fluidData.batteryLevel),
                transmission = tonumber(fluidData.gearBoxHealth),
                coolant = tonumber(fluidData.coolantLevel),
                suspension = bodyHealth,
                tires = 100 - (tonumber(fluidData.tireWear) or 0)
            }
            local health = math.max(0, math.min(100, measured[name] or stored))

            if name == 'tires' then
                local tiresPopped = 0
                for i = 0, 5 do
                    if IsVehicleTyreBurst(vehicle, i, false) then
                        tiresPopped = tiresPopped + 1
                    end
                end
                if tiresPopped > 0 then health = 0 end
            end

            local degradation = 1 - (health / 100)
            
            inspectionResults[name] = {
                label = checkpoint.label,
                health = math.floor((1 - degradation) * 100),
                needsRepair = degradation > 0.3
            }
            
            if degradation > 0.3 then
                totalIssues = totalIssues + 1
            end
            
        else
            lib.notify({
                title = locale('inspection_cancelled'),
                type = 'error'
            })
            return
        end
    end
    
    local saved, verifiedResults = lib.callback.await(
        'mechanic:server:saveInspection', false, VehToNet(vehicle), inspectionResults
    )
    if not saved or type(verifiedResults) ~= 'table' then
        lib.notify({ title = locale('inspection_cancelled'), type = 'error' })
        return
    end

    totalIssues = 0
    for name, data in pairs(verifiedResults) do
        data.label = checkpoints[name] and checkpoints[name].label or name
        data.needsRepair = (tonumber(data.health) or 0) < 70
        if data.needsRepair then totalIssues = totalIssues + 1 end
    end
    Inspection.ShowResults(vehicle, verifiedResults, totalIssues)
end

function Inspection.ShowResults(vehicle, results, totalIssues)
    local options = {}
    
    for name, data in pairs(results) do
        local statusIcon = data.needsRepair and 'fas fa-exclamation-triangle' or 'fas fa-check-circle'
        local statusColor = data.needsRepair and '#ff6b6b' or '#51cf66'
        
        table.insert(options, {
            title = data.label,
            description = locale('health_status', data.health),
            icon = statusIcon,
            iconColor = statusColor,
            progress = data.health,
            colorScheme = data.needsRepair and 'red' or 'green',
            disabled = true
        })
    end
    
    table.insert(options, {
        title = locale('repair_all'),
        description = locale('repair_all_issues', totalIssues),
        icon = 'fas fa-wrench',
        disabled = totalIssues == 0,
        onSelect = function()
            local Maintenance = require 'client.modules.maintenance'
            Maintenance.RepairAll(vehicle)
        end
    })
    
    table.insert(options, {
        title = locale('paint_vehicle'),
        description = locale('customize_vehicle_colors'),
        icon = 'fas fa-paint-brush',
        onSelect = function()
            Inspection.OpenPaintMenu(vehicle)
        end
    })
    
    lib.registerContext({
        id = 'inspection_results',
        title = locale('inspection_results'),
        options = options
    })
    
    lib.showContext('inspection_results')
end

function Inspection.OpenPaintMenu(vehicle)
    require('client.modules.paint_booth').Open(vehicle)
end

return Inspection
