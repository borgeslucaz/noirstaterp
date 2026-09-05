local taxiZones  = {}
local inTaxiZone = false
local currentZone = nil

function CreateTaxiZones()
    local hasPolyZone = GetResourceState('PolyZone') == 'started'

    if not hasPolyZone then
        
        Citizen.CreateThread(function()
            while true do
                Citizen.Wait(500)

                local playerPed    = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                local wasInZone    = inTaxiZone
                local oldZone      = currentZone
                inTaxiZone  = false
                currentZone = nil

                for _, stop in pairs(Config.TaxiStops) do
                    local distance = #(playerCoords - stop.coords)
                    if distance < 5.0 then
                        inTaxiZone  = true
                        currentZone = stop.name

                        if oldZone ~= stop.name then
                            TriggerEvent('rd-taxi:client:enterZone', stop)
                        end
                        break
                    end
                end

                if wasInZone and not inTaxiZone then
                    TriggerEvent('rd-taxi:client:exitZone')
                end
            end
        end)
    else
        
        for _, stop in pairs(Config.TaxiStops) do
            local zone = BoxZone:Create(
                stop.coords,
                stop.size.x,
                stop.size.y,
                {
                    name     = stop.name,
                    heading  = stop.heading,
                    debugPoly = false,
                    minZ     = stop.coords.z - 2.0,
                    maxZ     = stop.coords.z + 2.0
                }
            )

            zone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    inTaxiZone  = true
                    currentZone = stop.name
                    TriggerEvent('rd-taxi:client:enterZone', stop)
                else
                    if currentZone == stop.name then
                        inTaxiZone  = false
                        currentZone = nil
                        TriggerEvent('rd-taxi:client:exitZone')
                    end
                end
            end)

            taxiZones[stop.name] = zone
        end
    end

    
    for _, stop in pairs(Config.TaxiStops) do
        local blip = AddBlipForCoord(stop.coords.x, stop.coords.y, stop.coords.z)
        SetBlipSprite(blip, Config.TaxiBlipSprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.TaxiBlipScale)
        SetBlipColour(blip, Config.TaxiBlipColor)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(stop.label)
        EndTextCommandSetBlipName(blip)
    end
end

function IsInTaxiZone()    return inTaxiZone  end
function GetCurrentZone()  return currentZone  end

function GetCurrentZoneData()
    if not currentZone then return nil end
    for _, stop in pairs(Config.TaxiStops) do
        if stop.name == currentZone then return stop end
    end
    return nil
end