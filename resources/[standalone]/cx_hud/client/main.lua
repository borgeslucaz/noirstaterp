-- ─────────────────────────────────────────────────────────────────
-- Tiny inline replacements for the two ox_lib globals cx-hud touches:
-- `cache` (player ped / vehicle / seat / id helpers) and `lib.notify`
-- (toast). Atlas already has all the underlying functionality through
-- atlas_core; these wrappers just translate the call shapes so cx-hud
-- code stays verbatim.
-- ─────────────────────────────────────────────────────────────────

---@diagnostic disable-next-line: lowercase-global
cache = setmetatable({}, {
    __index = function(_, key)
        local ped = PlayerPedId()
        if key == 'ped'      then return ped end
        if key == 'playerId' then return PlayerId() end
        if key == 'serverId' then return GetPlayerServerId(PlayerId()) end
        if key == 'vehicle'  then
            local v = GetVehiclePedIsIn(ped, false)
            return (v ~= 0 and v) or false
        end
        if key == 'seat' then
            local v = GetVehiclePedIsIn(ped, false)
            if v == 0 then return false end
            for i = -1, 16 do
                if GetPedInVehicleSeat(v, i) == ped then return i end
            end
            return false
        end
        if key == 'weapon' then
            local has, w = GetCurrentPedWeapon(ped, true)
            return (has and w ~= 0 and w) or false
        end
        return nil
    end,
})

---@diagnostic disable-next-line: lowercase-global
lib = lib or {}
function lib.notify(opts)
    if type(opts) ~= 'table' then opts = { description = tostring(opts) } end
    local Atlas = exports['atlas_core']:GetCoreObject()
    if not Atlas or not Atlas.Functions or not Atlas.Functions.Notify then return end
    Atlas.Functions.Notify({
        text  = opts.description or opts.title or '',
        title = opts.title,
    }, opts.type or 'primary', opts.duration or 5000)
end

local hudHidden = false
local hudUserHidden = false
local State = {
    playerData      = {},
    hudShowing      = false,
    coreLoaded      = false,
    playerSpawned   = false,
    isTalking       = false,
    voiceLabel      = Config.DefaultVoice,
    seatbeltOn      = false,
    ejected         = false,
    menuIsOpen      = false,
    gameIsPaused    = false,
    lastLights      = {
        headlights = false, highbeam = false,
        indicatorLeft = false, indicatorRight = false, hazard = false,
    },
}

local function isReady()
    return State.coreLoaded and State.playerSpawned and LocalPlayer.state.isLoggedIn
end

-- Inline replacement for ox_lib's `lib.load(path)` module loader.
-- Each cx-hud module file ends with `return function(deps) … end`; we
-- pull the file off disk, compile it, and call the returned function
-- with the supplied deps. Equivalent to `lib.load(path)(deps)`.
local function loadModule(path)
    local resource = GetCurrentResourceName()
    local content  = LoadResourceFile(resource, path .. '.lua')
    if not content then error(('cx_hud: failed to load %s.lua'):format(path)) end
    local fn, err = load(content, ('@@%s/%s.lua'):format(resource, path))
    if not fn then error(err) end
    return fn()
end

local Utils   = loadModule('client/utils')(Config)
local Minimap = loadModule('client/minimap')(State, Utils, isReady, Config)
local Vehicle = loadModule('client/vehicle')(State, Utils, Config)
local Weapon  = loadModule('client/weapon')(State, Utils, isReady, Config)
local Status  = loadModule('client/status')(State, Utils, Vehicle, Minimap, isReady, Config)
loadModule('client/seatbelt')(State, Utils, Config)
loadModule('client/lights')(State, Utils, isReady)
loadModule('client/nui')(State, Utils, Minimap, Status, Vehicle, Config)
loadModule('client/events')(State, Utils, Minimap, Status, Vehicle, isReady, Config)

AddStateBagChangeHandler('invOpen', nil, function(bagName, key, value)
    if not bagName:find('player:') then return end
    if value then
        if not hudHidden and not State.hudShowing then return end
        if not hudHidden then SendNUIMessage({ action = 'hideHud' }); hudHidden = true end
    else
        if hudHidden and State.hudShowing then SendNUIMessage({ action = 'showHud' }); hudHidden = false end
    end
end)

exports('showHud', function()
    if not State.hudShowing then
        Minimap.setHudVisible(true)
        Status.pushConfig()
        Status.showHud(true)
        Status.pushStatus(true)
        Vehicle.pushVehicle(true)
    end
end)

exports('hideHud', function()
    if State.hudShowing and not hudHidden then
        Minimap.setHudVisible(false)
        Status.showHud(false)
    end
end)

exports('toggleHud', function()
    hudUserHidden = not hudUserHidden
    if hudUserHidden then
        Minimap.setHudVisible(false)
        Status.showHud(false)
    else
        Minimap.setHudVisible(true)
        Status.showHud(true)
        Status.pushStatus(true)
        Vehicle.pushVehicle(true)
    end
end)