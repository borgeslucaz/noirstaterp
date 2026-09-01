-- modules/vehicle_tools.lua
-- Inspect aimed/own vehicle, modify properties, generate spawn snippets.

SFD = SFD or {}
SFD.VehicleTools = {}

local CLASS_NAMES = {
    [0]='Compacts',[1]='Sedans',[2]='SUVs',[3]='Coupes',[4]='Muscle',[5]='Sports Classics',
    [6]='Sports',[7]='Super',[8]='Motorcycles',[9]='Off-road',[10]='Industrial',
    [11]='Utility',[12]='Vans',[13]='Cycles',[14]='Boats',[15]='Helicopters',
    [16]='Planes',[17]='Service',[18]='Emergency',[19]='Military',[20]='Commercial',
    [21]='Trains',[22]='Open Wheel',
}

local function aimedVehicle()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rZ, rX = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.cos(rX)
    local d = 30.0
    local dest = vec3(cam.x + (-math.sin(rZ) * cosX) * d, cam.y + (math.cos(rZ) * cosX) * d, cam.z + (math.sin(rX)) * d)
    local h = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 10, PlayerPedId(), 0)
    local r, hit, _, _, ent = 0
    repeat r, hit, _, _, ent = GetShapeTestResult(h); if r == 0 then Wait(0) end until r ~= 0
    if hit == 1 and ent and ent ~= 0 and GetEntityType(ent) == 2 then return ent end
end

local function currentVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return GetVehiclePedIsIn(ped, false) end
end

local function buildInfo(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local model = GetEntityModel(veh)
    local pri, sec = GetVehicleColours(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    local p = GetEntityCoords(veh)
    return {
        entity      = veh,
        model       = model,
        displayName = GetDisplayNameFromVehicleModel(model),
        plate       = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+$', ''),
        class       = GetVehicleClass(veh),
        className   = CLASS_NAMES[GetVehicleClass(veh)] or 'Unknown',
        coords      = p,
        heading     = GetEntityHeading(veh),
        engineH     = GetVehicleEngineHealth(veh),
        bodyH       = GetVehicleBodyHealth(veh),
        tankH       = GetVehiclePetrolTankHealth(veh),
        fuel        = GetVehicleFuelLevel and GetVehicleFuelLevel(veh) or nil,
        dirt        = GetVehicleDirtLevel(veh),
        locked      = GetVehicleDoorLockStatus(veh),
        netId       = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) or nil,
        engineOn    = GetIsVehicleEngineRunning(veh),
        livery      = GetVehicleLivery(veh),
        primary     = pri, secondary = sec, pearlescent = pearl, wheel = wheel,
    }
end

local function snippetSpawn(info)
    return ([[
local hash = `%s`
lib.requestModel(hash)
local veh = CreateVehicle(hash, %s, %s, %s, %s, true, false)
SetVehicleNumberPlateText(veh, '%s')
SetVehicleColours(veh, %d, %d)
SetVehicleExtraColours(veh, %d, %d)
SetVehicleOnGroundProperly(veh)
]]):format(
        info.displayName:lower(),
        SFD.Round(info.coords.x), SFD.Round(info.coords.y), SFD.Round(info.coords.z), SFD.Round(info.heading),
        info.plate ~= '' and info.plate or 'DEV',
        info.primary or 0, info.secondary or 0, info.pearlescent or 0, info.wheel or 0)
end

local function snippetQbxShared(info)
    return ([[
['%s'] = {
    name     = '%s',
    brand    = 'Brand',
    model    = '%s',
    price    = 50000,
    category = '%s',
    type     = 'automobile',
    shop     = 'pdm',
},
]]):format(info.displayName:lower(), info.displayName, info.displayName:lower(), info.className:lower())
end

local function snippetTarget(info)
    return ([[
exports.ox_target:addModel(`%s`, {
    {
        label = 'Open trunk',
        icon = 'fa-solid fa-box',
        bones = { 'boot' },
        onSelect = function(data)
            local veh = data.entity
            -- ...
        end,
    },
})
]]):format(info.displayName:lower())
end

local function dangerous() return SFD.HasPermission('dangerous') end

local function buildMenu(info, source)
    local title = ('Vehicle — %s'):format(info.displayName)
    local options = {
        { title = 'Identity', description = ('hash %s · plate "%s"'):format(info.model, info.plate), icon = 'id-card', readOnly = true },
        { title = 'Class',    description = ('%d — %s'):format(info.class, info.className), icon = 'layer-group', readOnly = true },
        { title = 'Coords',   description = SFD.FormatVec4(info.coords, info.heading), icon = 'location-dot',
          onSelect = function() SFD.Copied('vector4', SFD.FormatVec4(info.coords, info.heading)) end },
        { title = 'Health',   description = ('engine %.0f · body %.0f · tank %.0f'):format(info.engineH, info.bodyH, info.tankH), icon = 'heart-pulse', readOnly = true },
        { title = 'Fuel & dirt', description = ('fuel %s · dirt %.1f'):format(info.fuel or 'n/a', info.dirt or 0), icon = 'gas-pump', readOnly = true },
        { title = 'Colors',   description = ('pri %d · sec %d · pearl %d · wheel %d'):format(info.primary or 0, info.secondary or 0, info.pearlescent or 0, info.wheel or 0), icon = 'palette', readOnly = true },
        { title = 'Network',  description = info.netId and ('netId %d'):format(info.netId) or 'not networked', icon = 'network-wired', readOnly = true },
        { title = 'Copy spawn snippet',     icon = 'code',
          onSelect = function() SFD.Copied('spawn snippet', snippetSpawn(info)) end },
        { title = 'Copy Qbox shared entry', icon = 'code-branch',
          onSelect = function() SFD.Copied('qbx vehicles entry', snippetQbxShared(info)) end },
        { title = 'Copy ox_target template',icon = 'crosshairs',
          onSelect = function() SFD.Copied('ox_target template', snippetTarget(info)) end },
        { title = 'Repair',     icon = 'wrench',
          onSelect = function()
              if not dangerous() then return end
              SetVehicleFixed(info.entity); SetVehicleDeformationFixed(info.entity)
              SetVehicleEngineHealth(info.entity, 1000.0); SetVehicleBodyHealth(info.entity, 1000.0)
              SFD.Notify.success('Vehicle repaired.')
          end },
        { title = 'Clean (dirt 0)', icon = 'soap',
          onSelect = function()
              if not dangerous() then return end
              SetVehicleDirtLevel(info.entity, 0.0); SFD.Notify.success('Cleaned.')
          end },
        { title = 'Flip upright',   icon = 'rotate',
          onSelect = function()
              if not dangerous() then return end
              SetVehicleOnGroundProperly(info.entity); SFD.Notify.success('Flipped.')
          end },
        { title = 'Toggle engine',  icon = 'power-off',
          onSelect = function()
              if not dangerous() then return end
              SetVehicleEngineOn(info.entity, not info.engineOn, true, true)
              SFD.Notify.success('Engine toggled.')
          end },
        { title = 'Change plate (testing)', icon = 'pen',
          onSelect = function()
              if not dangerous() then return end
              local input = lib.inputDialog('Change plate', { { type = 'input', label = 'Plate', max = 8, required = true } })
              if input and input[1] then SetVehicleNumberPlateText(info.entity, input[1]); SFD.Notify.success('Plate updated.') end
          end },
        { title = 'Delete vehicle', icon = 'trash', iconColor = '#ff6b35',
          onSelect = function()
              if not dangerous() then return end
              SetEntityAsMissionEntity(info.entity, true, true)
              DeleteEntity(info.entity)
              SFD.Notify.success('Vehicle deleted.')
              SFD.LogServer('delete', { type = 'Vehicle', model = info.model })
          end },
        { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.VehicleTools.openMenu() end },
    }

    lib.registerContext({
        id = 'sfd_veh_actions',
        title = title,
        menu = 'sfd_veh_main',
        canClose = true,
        options = options,
    })
    lib.showContext('sfd_veh_actions')
end

function SFD.VehicleTools.openMenu()
    lib.registerContext({
        id = 'sfd_veh_main',
        title = 'Vehicle Tools',
        menu = 'sfd_main_menu',
        canClose = true,
        options = {
            { title = 'Inspect current vehicle', description = 'Vehicle you are sitting in', icon = 'car',
              onSelect = function()
                  local v = currentVehicle()
                  if not v then SFD.Notify.warning('You are not in a vehicle.') return end
                  buildMenu(buildInfo(v))
              end },
            { title = 'Inspect aimed vehicle', description = 'Look at a vehicle, then pick this', icon = 'crosshairs',
              onSelect = function()
                  local v = aimedVehicle()
                  if not v then SFD.Notify.warning('No vehicle in your sight.') return end
                  buildMenu(buildInfo(v))
              end },
            { title = 'Inspect closest vehicle', description = 'Within 10m', icon = 'location-crosshairs',
              onSelect = function()
                  local p = GetEntityCoords(PlayerPedId())
                  local closest, dist = 0, 999.0
                  for veh in EnumerateVehicles() do
                      local d = #(p - GetEntityCoords(veh))
                      if d < dist then closest, dist = veh, d end
                  end
                  if closest == 0 then SFD.Notify.warning('No nearby vehicle.') return end
                  buildMenu(buildInfo(closest))
              end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_veh_main')
end

function EnumerateVehicles()
    return coroutine.wrap(function()
        local handle, ent = FindFirstVehicle()
        repeat
            coroutine.yield(ent)
            local ok
            ok, ent = FindNextVehicle(handle)
            if not ok then break end
        until not ok
        EndFindVehicle(handle)
    end)
end

SFD.RegisterModule({
    id = 'vehicle_tools',
    label = 'Vehicle Tools',
    description = 'Inspect & modify vehicles · export shared/shop entries',
    icon = 'car',
    open = function() SFD.VehicleTools.openMenu() end,
})
