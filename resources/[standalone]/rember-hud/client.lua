-- Rember HUD — client (FiveM), standalone.
-- Reads native player stats every tick, merges any custom values pushed in by
-- other resources, and streams them to the component-based NUI. No framework
-- dependency: hunger/thirst/etc. are just values any script can set.
--
--   -- from a framework or your own status script:
--   exports['rember-hud']:SetValue('hunger', 82.5)
--   exports['rember-hud']:SetValues({ hunger = 82.5, thirst = 60, stress = 15 })

local custom = { hunger = 100.0, thirst = 100.0, stress = 0.0 } -- defaults until something feeds them
local visible = true
local LAYOUT_KEY = 'rember-hud:layout'
local LAYOUT_VERSION_KEY = 'rember-hud:layout-version'

-- Public API for other resources -------------------------------------------
function SetValue(key, value)
  custom[key] = value + 0.0
end
function SetValues(tbl)
  for k, v in pairs(tbl or {}) do custom[k] = v + 0.0 end
end
function SetHudVisible(state)
  visible = state and true or false
  SendNUIMessage({ action = 'visible', visible = visible })
end
exports('SetValue', SetValue)
exports('SetValues', SetValues)
exports('SetHudVisible', SetHudVisible)

-- Push the component config to the UI (build step). --------------------------
local function sendConfig()
  -- Apply a new shipped default layout once when its version changes. This keeps
  -- old drag positions from scattering the HUD after an administrator redesign.
  if GetResourceKvpInt(LAYOUT_VERSION_KEY) ~= Config.LayoutVersion then
    DeleteResourceKvp(LAYOUT_KEY)
    SetResourceKvpInt(LAYOUT_VERSION_KEY, Config.LayoutVersion)
  end

  -- Load this player's saved gauge layout, if any (set via /hudedit).
  local layout = {}
  local raw = GetResourceKvpString(LAYOUT_KEY)
  if raw then
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then layout = decoded end
  end
  SendNUIMessage({
    action = 'config',
    components = Config.Components,
    position = Config.Position,
    speedUnit = Config.SpeedUnit,
    theme = Config.Theme,
    scale = Config.Scale,
    layout = layout,
  })
end

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi else return v end
end

local function mpsToUnit(mps)
  return Config.SpeedUnit == 'kmh' and (mps * 3.6) or (mps * 2.236936)
end

-- QBX syncs these status values to the player's state bag. Read them here so
-- the bundled hunger/thirst gauges work out of the box on this Qbox server,
-- while retaining the public exports above for other frameworks/custom stats.
local function qboxValues()
  if GetResourceState('qbx_core') ~= 'started' then return {} end

  local state = LocalPlayer.state
  local values = {
    hunger = state.hunger,
    thirst = state.thirst,
    stress = state.stress,
  }

  -- During character loading the state bag may not have arrived yet. QBX's
  -- cached player data is a safe fallback for hunger and thirst in that window.
  if values.hunger == nil or values.thirst == nil or values.stress == nil then
    local playerData = exports.qbx_core:GetPlayerData()
    local metadata = playerData and playerData.metadata or {}
    values.hunger = values.hunger or metadata.hunger
    values.thirst = values.thirst or metadata.thirst
    values.stress = values.stress or metadata.stress
  end

  for key, value in pairs(values) do
    if type(value) == 'number' then custom[key] = clamp(value + 0.0, 0, 100) end
  end

  return custom
end

-- Native reads — FiveM (GTA V) ----------------------------------------------
local function nativeValuesGta()
  local ped = PlayerPedId()
  local player = PlayerId()

  local hp = GetEntityHealth(ped)
  local health = hp <= 100 and 0.0 or clamp((hp - 100) / 100 * 100, 0, 100)

  local inVehicle = IsPedInAnyVehicle(ped, false)
  local speed = 0.0
  if inVehicle then speed = GetEntitySpeed(GetVehiclePedIsIn(ped, false)) end

  local oxygen = 100.0
  if IsPedSwimmingUnderWater(ped) then
    oxygen = clamp(GetPlayerUnderwaterTimeRemaining(player) * 10.0, 0, 100)
  end

  return {
    health  = health,
    armor   = clamp(GetPedArmour(ped) + 0.0, 0, 100),
    stamina = clamp(GetPlayerSprintStaminaRemaining(player) + 0.0, 0, 100),
    voice   = NetworkIsPlayerTalking(player) and 100.0 or 0.0,
    oxygen  = oxygen,
    speed   = math.floor(mpsToUnit(speed) + 0.5),
    inVehicle = inVehicle,
  }
end

-- Native reads — RedM (RDR3) ------------------------------------------------
-- RDR2 has no armor; health and stamina are "attribute cores" (0-100); you ride
-- a mount rather than sit in a car. These use the documented core native and are
-- fully guarded with pcall so a native mismatch degrades to 0 instead of erroring.
-- ⚠️ VERIFY ON A LIVE REDM SERVER — core native ranges/hashes can vary by build.
local function coreValue(ped, idx)
  local ok, v = pcall(GetAttributeCoreValue, ped, idx)             -- named native, if present
  if ok and type(v) == 'number' then return clamp(v + 0.0, 0, 100) end
  ok, v = pcall(function() return Citizen.InvokeNative(0x36731AC041289BB1, ped, idx) end)
  return (ok and type(v) == 'number') and clamp(v + 0.0, 0, 100) or 0.0
end

local function nativeValuesRdr3()
  local ped = PlayerPedId()
  local player = PlayerId()

  local speed, inVehicle = 0.0, false
  if IsPedInAnyVehicle(ped, false) then                           -- wagons / boats / trains
    inVehicle = true
    speed = GetEntitySpeed(GetVehiclePedIsIn(ped, false))
  else
    local ok, mount = pcall(function()
      if Citizen.InvokeNative(0x460BC76A0E10A110, ped) then       -- IS_PED_ON_MOUNT
        return Citizen.InvokeNative(0xE7B6E5B7, ped)              -- GET_MOUNT
      end
    end)
    if ok and mount and mount ~= 0 then inVehicle = true; speed = GetEntitySpeed(mount) end
  end

  return {
    health  = coreValue(ped, 0),   -- health core
    stamina = coreValue(ped, 1),   -- stamina core
    voice   = NetworkIsPlayerTalking(player) and 100.0 or 0.0,
    speed   = math.floor(mpsToUnit(speed) + 0.5),
    inVehicle = inVehicle,
    -- no armor / oxygen in RDR2 (their gauges simply have no data → hidden)
  }
end

local nativeValues = (Config.Game == 'rdr3') and nativeValuesRdr3 or nativeValuesGta

CreateThread(function()
  Wait(250)          -- let the UI load before first config
  sendConfig()
  while true do
    if visible then
      local values = nativeValues()
      qboxValues()
      for k, v in pairs(custom) do values[k] = v end
      SendNUIMessage({ action = 'update', values = values })
    end
    Wait(Config.UpdateMs)
  end
end)

AddEventHandler('onClientResourceStart', function(name)
  if name == GetCurrentResourceName() then sendConfig() end
end)

RegisterCommand('hud', function()
  SetHudVisible(not visible)
end, false)

-- Layout editor: drag gauges anywhere, saved per-player. ---------------------
local editing = false

RegisterCommand('hudedit', function()
  editing = not editing
  SetNuiFocus(editing, editing)   -- give the cursor so gauges can be dragged
  SendNUIMessage({ action = 'edit', on = editing })
end, false)

RegisterCommand('hudreset', function()
  SendNUIMessage({ action = 'resetLayout' })
end, false)

-- NUI closed edit mode itself (Esc) — release focus.
RegisterNUICallback('editClosed', function(_, cb)
  editing = false
  SetNuiFocus(false, false)
  cb('ok')
end)

-- Persist the dragged layout to per-client storage.
RegisterNUICallback('saveLayout', function(data, cb)
  if data and data.layout then
    SetResourceKvp(LAYOUT_KEY, json.encode(data.layout))
  end
  cb('ok')
end)

RegisterNUICallback('resetLayout', function(_, cb)
  DeleteResourceKvp(LAYOUT_KEY)
  cb('ok')
end)
