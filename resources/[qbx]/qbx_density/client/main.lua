SetRelationshipBetweenGroups(1, `AMBIENT_GANG_HILLBILLY`, `PLAYER`)
SetRelationshipBetweenGroups(1, `AMBIENT_GANG_BALLAS`, `PLAYER`)
SetRelationshipBetweenGroups(1, `AMBIENT_GANG_MEXICAN`, `PLAYER`)
SetRelationshipBetweenGroups(1, `AMBIENT_GANG_FAMILY`, `PLAYER`)
SetRelationshipBetweenGroups(1, `AMBIENT_GANG_MARABUNTE`, `PLAYER`)
SetRelationshipBetweenGroups(1, `AMBIENT_GANG_SALVA`, `PLAYER`)
SetRelationshipBetweenGroups(1, `AMBIENT_GANG_LOST`, `PLAYER`)
SetRelationshipBetweenGroups(1, `GANG_1`, `PLAYER`)
SetRelationshipBetweenGroups(1, `GANG_2`, `PLAYER`)
SetRelationshipBetweenGroups(1, `GANG_9`, `PLAYER`)
SetRelationshipBetweenGroups(1, `GANG_10`, `PLAYER`)
SetRelationshipBetweenGroups(1, `FIREMAN`, `PLAYER`)
SetRelationshipBetweenGroups(1, `MEDIC`, `PLAYER`)
SetRelationshipBetweenGroups(1, `COP`, `PLAYER`)
SetRelationshipBetweenGroups(1, `PRISONER`, `PLAYER`)

local density = lib.load('config.client')
local activeDensity = {
    parked = density.parked,
    vehicle = density.vehicle,
    randomvehicles = density.randomvehicles,
    peds = density.peds,
    scenario = density.scenario,
}

local blockedPedModels = {}
for i = 1, #(density.blockedPedModels or {}) do
    blockedPedModels[joaat(density.blockedPedModels[i])] = true
end

AddEventHandler('populationPedCreating', function(_, _, _, model)
    if blockedPedModels[model] then
        CancelEvent()
    end
end)

local function applyDensityProfile(profile)
    activeDensity.parked = profile.parked or density.parked
    activeDensity.vehicle = profile.vehicle or density.vehicle
    activeDensity.randomvehicles = profile.randomvehicles or density.randomvehicles
    activeDensity.peds = profile.peds or density.peds
    activeDensity.scenario = profile.scenario or density.scenario
end

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local profile = density

        for i = 1, #(density.zones or {}) do
            local zone = density.zones[i]
            local delta = coords - zone.coords
            if delta.x * delta.x + delta.y * delta.y + delta.z * delta.z <= zone.radius * zone.radius then
                profile = zone.density or density
                break
            end
        end

        applyDensityProfile(profile)
        Wait(500)
    end
end)

local function setDensity(type, value)
    if type == 'parked' then
        density.parked = value
    elseif type == 'vehicle' then
        density.vehicle = value
    elseif type == 'randomvehicles' then
        density.randomvehicles = value
    elseif type == 'peds' then
        density.peds = value
    elseif type == 'scenario' then
        density.scenario = value
    end

    applyDensityProfile(density)
end

exports('SetDensity', setDensity)

CreateThread(function()
    while true do
        SetParkedVehicleDensityMultiplierThisFrame(activeDensity.parked)
        SetVehicleDensityMultiplierThisFrame(activeDensity.vehicle)
        SetRandomVehicleDensityMultiplierThisFrame(activeDensity.randomvehicles)
        SetPedDensityMultiplierThisFrame(activeDensity.peds)
        SetScenarioPedDensityMultiplierThisFrame(activeDensity.scenario, activeDensity.scenario) -- Walking NPC Density
        Wait(0)
    end
end)
