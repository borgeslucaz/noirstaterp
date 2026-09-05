local Garage = {}
local Framework = require 'shared.framework'
local garageBlip = nil
local garageZones = {}

function Garage.ResetZones()
    for _, zone in ipairs(garageZones) do
        zone:remove()
    end
    garageZones = {}
end

function Garage.CreateZone(shop)
    if shop.zones.garage then
        local zone = lib.points.new({
            coords = shop.zones.garage,
            distance = 5,
            shop = shop
        })
        
        function zone:nearby()
            local playerData = Framework.GetPlayerData()
            if self.currentDistance < 2.0 and playerData and playerData.job and playerData.job.name == Config.JobName then
                lib.showTextUI(locale('press_to_manage_garage'))
                
                if IsControlJustPressed(0, 38) then -- E key
                    Garage.OpenMenu(self.shop)
                end
            end
        end
        
        function zone:onExit()
            lib.hideTextUI()
        end

        garageZones[#garageZones + 1] = zone
    end
end

function Garage.OpenMenu(shop)
    local options = {
        {
            title = locale('spawn_vehicle'),
            icon = 'fas fa-car',
            onSelect = function()
                Garage.SpawnVehicle(shop)
            end
        },
        {
            title = locale('store_vehicle'),
            icon = 'fas fa-parking',
            onSelect = function()
                Garage.StoreVehicle(shop)
            end
        }
    }
    
    lib.registerContext({
        id = 'garage_menu',
        title = locale('garage'),
        options = options
    })
    
    lib.showContext('garage_menu')
end

function Garage.SpawnVehicle(shop)
    local vehicles = {}
    
    for vehicleType, data in pairs(Config.Towing.vehicles) do
        table.insert(vehicles, {
            title = data.model,
            icon = 'fas fa-truck',
            onSelect = function()
                local spawnPoint = shop.vehicleSpawns.service[1]
                if spawnPoint then
                    lib.callback('mechanic:server:spawnGarageVehicle', false, function(success)
                        if success then
                            lib.notify({
                                title = locale('vehicle_spawned'),
                                type = 'success'
                            })
                        end
                    end, data.model, spawnPoint)
                end
            end
        })
    end
    
    lib.registerContext({
        id = 'garage_vehicles',
        title = locale('select_vehicle'),
        menu = 'garage_menu',
        options = vehicles
    })
    
    lib.showContext('garage_vehicles')
end

function Garage.StoreVehicle(shop)
    local vehicle = cache.vehicle
    if not vehicle or not DoesEntityExist(vehicle) then
        lib.notify({
            title = locale('no_vehicle_detected'),
            type = 'error'
        })
        return
    end
    if not Entity(vehicle).state.mechanicServiceVehicle then
        lib.notify({ title = locale('vehicle_cannot_be_stored'), type = 'error' })
        return
    end
    
    TriggerServerEvent('mechanic:server:deleteVehicle', VehToNet(vehicle))
    lib.notify({
        title = locale('vehicle_stored'),
        type = 'success'
    })
end

return Garage
