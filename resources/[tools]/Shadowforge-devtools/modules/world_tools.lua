-- modules/world_tools.lua
-- Time, weather (local or sync'd), street/zone/interior info.

SFD = SFD or {}
SFD.WorldTools = {}

local function dangerous() return SFD.HasPermission('dangerous') end

-- Local override flags
local timeFrozen, frozenH, frozenM = false, 12, 0
local weatherOverride = nil
local blackout = false

CreateThread(function()
    while true do
        if timeFrozen then
            NetworkOverrideClockTime(frozenH, frozenM, 0)
        end
        if weatherOverride then
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypeNowPersist(weatherOverride)
            SetWeatherTypeNow(weatherOverride)
            SetWeatherTypePersist(weatherOverride)
        end
        SetArtificialLightsState(blackout)
        Wait(2000)
    end
end)

-- Apply server-broadcast world sync
RegisterNetEvent('sfd:applyWorldSync', function(payload)
    if not payload then return end
    if payload.weather then SetWeatherTypeNowPersist(payload.weather) end
    if payload.hour then NetworkOverrideClockTime(payload.hour, payload.minute or 0, 0) end
    if payload.blackout ~= nil then SetArtificialLightsState(payload.blackout) end
end)

local function infoMenu()
    local p = GetEntityCoords(PlayerPedId())
    local s1, s2 = GetStreetNameAtCoord(p.x, p.y, p.z)
    local street = s1 ~= 0 and GetStreetNameFromHashKey(s1) or 'Unknown'
    local crossing = s2 ~= 0 and GetStreetNameFromHashKey(s2) or '—'
    local zoneHash = GetNameOfZone(p.x, p.y, p.z)
    local zoneLabel = GetLabelText(zoneHash)
    local interior = GetInteriorAtCoords(p.x, p.y, p.z)
    local roomKey = interior ~= 0 and GetKeyForEntityInRoom and GetKeyForEntityInRoom(PlayerPedId()) or 0

    lib.registerContext({
        id = 'sfd_world_info', title = 'World — Info', menu = 'sfd_world_main', canClose = true,
        options = {
            { title = 'Street',    description = street,                    icon = 'road',     onSelect = function() SFD.Copied('street', street) end },
            { title = 'Crossing',  description = crossing,                  icon = 'road-circle-check', readOnly = true },
            { title = 'Zone',      description = ('%s (%s)'):format(zoneLabel, zoneHash), icon = 'map',
              onSelect = function() SFD.Copied('zone', zoneLabel) end },
            { title = 'Interior',  description = ('id %d · room %d'):format(interior, roomKey or 0), icon = 'door-open', readOnly = true },
            { title = 'Coords + street',
              description = ('%s @ %s'):format(SFD.FormatVec3(p), street),
              icon = 'location-dot',
              onSelect = function() SFD.Copied('coords + street', ('%s -- %s, %s'):format(SFD.FormatVec3(p), street, zoneLabel)) end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.WorldTools.openMenu() end },
        },
    })
    lib.showContext('sfd_world_info')
end

local function timeMenu()
    lib.registerContext({
        id = 'sfd_world_time', title = 'World — Time', menu = 'sfd_world_main', canClose = true,
        options = {
            { title = ('Frozen: %s'):format(timeFrozen and 'YES' or 'NO'), icon = 'snowflake',
              onSelect = function() timeFrozen = not timeFrozen; if not timeFrozen then NetworkClearClockTimeOverride() end; timeMenu() end },
            { title = 'Set frozen time', description = ('current: %02d:%02d'):format(frozenH, frozenM), icon = 'clock',
              onSelect = function()
                  local input = lib.inputDialog('Set time', {
                      { type = 'slider', label = 'Hour',   min = 0, max = 23, default = frozenH },
                      { type = 'slider', label = 'Minute', min = 0, max = 59, default = frozenM },
                  })
                  if input then frozenH, frozenM = input[1], input[2]; timeFrozen = true end
                  timeMenu()
              end },
            { title = 'Sync to all (server)', icon = 'tower-broadcast',
              description = Config.World.syncToServer and 'Broadcasts to every player' or 'Disabled in config',
              onSelect = function()
                  if not Config.World.syncToServer then SFD.Notify.error('Disabled in config.') return end
                  if not dangerous() then return end
                  TriggerServerEvent('sfd:worldSync', { hour = frozenH, minute = frozenM })
                  SFD.Notify.success('Time broadcast sent.')
              end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.WorldTools.openMenu() end },
        },
    })
    lib.showContext('sfd_world_time')
end

local function weatherMenu()
    local options = {
        { title = ('Override: %s'):format(weatherOverride or 'OFF'), icon = 'cloud-sun', readOnly = true },
        { title = 'Clear override', icon = 'eye-slash',
          onSelect = function() weatherOverride = nil; ClearOverrideWeather(); ClearWeatherTypePersist(); weatherMenu() end },
    }
    for _, w in ipairs(Config.World.weatherTypes) do
        options[#options + 1] = {
            title = w, icon = 'cloud',
            onSelect = function() weatherOverride = w; SFD.Notify.success(('Weather: %s'):format(w)); weatherMenu() end,
        }
    end
    options[#options + 1] = { title = 'Sync to all (server)', icon = 'tower-broadcast',
        description = Config.World.syncToServer and 'Broadcasts to every player' or 'Disabled in config',
        onSelect = function()
            if not Config.World.syncToServer then SFD.Notify.error('Disabled in config.') return end
            if not dangerous() then return end
            TriggerServerEvent('sfd:worldSync', { weather = weatherOverride })
            SFD.Notify.success('Weather broadcast sent.')
        end }
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.WorldTools.openMenu() end }

    lib.registerContext({ id = 'sfd_world_weather', title = 'World — Weather', menu = 'sfd_world_main', canClose = true, options = options })
    lib.showContext('sfd_world_weather')
end

function SFD.WorldTools.openMenu()
    lib.registerContext({
        id = 'sfd_world_main', title = 'World / Environment', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = 'Info (street · zone · interior)', icon = 'circle-info', arrow = true, onSelect = function() infoMenu() end },
            { title = 'Time',    icon = 'clock',    arrow = true, onSelect = function() timeMenu() end },
            { title = 'Weather', icon = 'cloud-sun', arrow = true, onSelect = function() weatherMenu() end },
            { title = blackout and 'Blackout: ON (toggle off)' or 'Blackout: OFF (toggle on)', icon = 'lightbulb',
              onSelect = function() blackout = not blackout; SetArtificialLightsState(blackout); SFD.WorldTools.openMenu() end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_world_main')
end

SFD.RegisterModule({
    id = 'world_tools', label = 'World Tools',
    description = 'Time · weather · blackout · street/zone/interior info',
    icon = 'cloud-sun',
    open = function() SFD.WorldTools.openMenu() end,
})
