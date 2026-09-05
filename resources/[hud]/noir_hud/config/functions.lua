local fuelGetter
local seatbeltGetter

local fuelResources = {
	['ps-fuel'] = function(vehicle)
		return exports['ps-fuel']:GetFuel(vehicle)
	end,
	['cdn-fuel'] = function(vehicle)
		return exports['cdn-fuel']:GetFuel(vehicle)
	end,
	LegacyFuel = function(vehicle)
		return exports['LegacyFuel']:GetFuel(vehicle)
	end,
	['ox_fuel'] = function(vehicle)
		return Entity(vehicle).state.fuel
	end,
}

local fuelResourceOrder = { 'ps-fuel', 'cdn-fuel', 'LegacyFuel', 'ox_fuel' }

local function resolveFuelGetter()
	for i = 1, #fuelResourceOrder do
		local resourceName = fuelResourceOrder[i]
		if GetResourceState(resourceName) == 'started' then
			fuelGetter = fuelResources[resourceName]
			return fuelGetter
		end
	end

	fuelGetter = GetVehicleFuelLevel
	return fuelGetter
end

local function invalidateFuelGetter(resourceName)
	if fuelResources[resourceName] then
		fuelGetter = nil
	end

	if resourceName == 'jim-mechanic' then
		seatbeltGetter = nil
	end
end

AddEventHandler('onClientResourceStart', invalidateFuelGetter)
AddEventHandler('onClientResourceStop', invalidateFuelGetter)

return {
	isSeatbeltOn = function()
		if not seatbeltGetter then
			if GetResourceState('jim-mechanic') == 'started' then
				seatbeltGetter = function()
					return exports['jim-mechanic']:seatBeltOn()
				end
			else
				-- qbx_seatbelt stores both states directly on LocalPlayer.
				seatbeltGetter = function()
					return LocalPlayer.state.seatbelt or LocalPlayer.state.harness or false
				end
			end
		end

		return seatbeltGetter()
	end,
	getVehicleFuel = function(currentVehicle)
		return (fuelGetter or resolveFuelGetter())(currentVehicle)
	end,
	getNosLevel = function(currentVehicle) -- Replace this with your own logic to grab the nos level of the vehicle.
		return 0
	end,
}
