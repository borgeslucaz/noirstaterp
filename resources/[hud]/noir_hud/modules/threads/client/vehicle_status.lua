local interface = lib.require("modules.interface.client")
local utility = lib.require("modules.utility.shared.main")
local functions = lib.require("config.functions")
local config = lib.require("config.shared")

local VehicleStatusThread = {}
VehicleStatusThread.__index = VehicleStatusThread

local function shallowEqual(previous, current)
    if not previous then return false end

    for key, value in pairs(current) do
        if previous[key] ~= value then return false end
    end

    for key in pairs(previous) do
        if current[key] == nil then return false end
    end

    return true
end

function VehicleStatusThread.new(playerStatus, seatbeltLogic)
    local self = setmetatable({}, VehicleStatusThread)
    self.playerStatus = playerStatus
    self.seatbelt = seatbeltLogic

    SetHudComponentPosition(6, 999999.0, 999999.0) -- VEHICLE NAME
    SetHudComponentPosition(7, 999999.0, 999999.0) -- AREA NAME
    SetHudComponentPosition(8, 999999.0, 999999.0) -- VEHICLE CLASS
    SetHudComponentPosition(9, 999999.0, 999999.0) -- STREET NAME

    return self
end

function GetNosLevel(veh)
    local noslevelraw = functions.getNosLevel(veh)
    local noslevel

    if noslevelraw == nil then
        noslevel = 0
    else
        noslevel = math.floor(noslevelraw)
    end

    return noslevel
end

function VehicleStatusThread:start()
    CreateThread(function()
        local playerStatusThread = self.playerStatus
        local convertRpmToPercentage = utility.convertRpmToPercentage
        local convertEngineHealthToPercentage = utility.convertEngineHealthToPercentage
        local fastInterval = config.vehicleUpdateInterval or 125
        local slowInterval = config.vehicleSlowUpdateInterval or 500
        local normalizedSpeedUnit = string.lower(config.speedUnit or "kph")
        local lastVehicle
        local lastVehicleData
        local nextSlowUpdate = 0
        local slowData = {}
        local uiWasVisible = false

        if normalizedSpeedUnit ~= "kph" and normalizedSpeedUnit ~= "mph" then
            lib.print.error("Invalid speed unit; falling back to kph:", config.speedUnit)
            normalizedSpeedUnit = "kph"
        end

        playerStatusThread:setIsVehicleThreadRunning(true)

        while true do
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then break end

            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= lastVehicle then
                lastVehicle = vehicle
                nextSlowUpdate = 0
                lastVehicleData = nil
            end

            local vehicleType = GetVehicleTypeRaw(vehicle)
            local speedMetersPerSecond = GetEntitySpeed(vehicle)
            local currentGear = GetVehicleDashboardCurrentGear()
            local now = GetGameTimer()

            if now >= nextSlowUpdate then
                local rawFuelValue = functions.getVehicleFuel(vehicle)
                local fuelValue = math.max(0, math.min(rawFuelValue or 0, 100))
                local highGear = GetVehicleHighGear(vehicle)
                local _, lightsOn, highbeamsOn = GetVehicleLightsState(vehicle)

                slowData.engineHealth = convertEngineHealthToPercentage(GetVehicleEngineHealth(vehicle))
                slowData.nos = GetNosLevel(vehicle)
                slowData.fuel = math.floor(fuelValue)
                slowData.engineState = GetIsVehicleEngineRunning(vehicle)
                slowData.gears = highGear == 1 and 0 or highGear
                slowData.highGear = highGear
                slowData.headlights = (highbeamsOn == true or highbeamsOn == 1) and 100
                    or (lightsOn == true or lightsOn == 1) and 50
                    or 0
                nextSlowUpdate = now + slowInterval
            end

            local gearString = "N"
            if not slowData.engineState then
                gearString = ""
            elseif currentGear == 0 and speedMetersPerSecond > 0 then
                gearString = "R"
            elseif currentGear == 1 and speedMetersPerSecond < 0.1 then
                gearString = "N"
            elseif currentGear == 1 then
                gearString = "1"
            elseif currentGear > 1 then
                gearString = tostring(math.floor(currentGear))
            end
            if slowData.highGear == 1 then
                gearString = ""
            end

            local speed = math.floor(speedMetersPerSecond * (normalizedSpeedUnit == "mph" and 2.236936 or 3.6))

            local rpm
            if vehicleType == 8 then -- Helicopters: Simulate RPM based on speed
                -- Keep the helicopter estimate independent of the display unit (150 MPH reference).
                rpm = math.floor(math.min(speedMetersPerSecond * 2.236936 / 150, 1) * 100 + 0.5)
            else -- All other vehicles: Use actual RPM
                rpm = convertRpmToPercentage(GetVehicleCurrentRpm(vehicle))
            end

            local vehicleData = {
                speedUnit = normalizedSpeedUnit,
                speed = speed,
                rpm = rpm,
                engineHealth = slowData.engineHealth,
                engineState = slowData.engineState,
                gears = slowData.gears,
                currentGear = gearString,
                fuel = slowData.fuel,
                nos = slowData.nos,
                headlights = slowData.headlights,
            }

            local uiVisible = interface.store.visibility.app
            if uiVisible and not uiWasVisible then
                lastVehicleData = nil
            end
            uiWasVisible = uiVisible

            if uiVisible and not shallowEqual(lastVehicleData, vehicleData) then
                interface:message("state::vehicle::set", vehicleData)
                lastVehicleData = vehicleData
            end

            Wait(fastInterval)
        end

        if self.seatbelt then
            lib.print.verbose("(vehicleStatusThread) seatbelt found, toggling to false")
            self.seatbelt:toggle(false)
        end

        playerStatusThread:setIsVehicleThreadRunning(false)
        lib.print.verbose("(vehicleStatusThread) Vehicle status thread ended.")
    end)
end

return VehicleStatusThread
