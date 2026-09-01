-- modules/ped_tools.lua
-- Inspect/spawn peds, set scenarios, copy snippets.

SFD = SFD or {}
SFD.PedTools = {}

local function dangerous() return SFD.HasPermission('dangerous') end

local function aimedPed()
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rZ, rX = math.rad(rot.z), math.rad(rot.x)
    local cosX = math.cos(rX)
    local d = 25.0
    local dest = vec3(cam.x + (-math.sin(rZ) * cosX) * d, cam.y + (math.cos(rZ) * cosX) * d, cam.z + (math.sin(rX)) * d)
    local h = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 12, PlayerPedId(), 0)
    local r, hit, _, _, ent = 0
    repeat r, hit, _, _, ent = GetShapeTestResult(h); if r == 0 then Wait(0) end until r ~= 0
    if hit == 1 and ent and ent ~= 0 and GetEntityType(ent) == 1 then return ent end
end

local function buildInfo(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local p = GetEntityCoords(ped)
    local _, weapon = GetCurrentPedWeapon(ped, true)
    return {
        entity = ped,
        model  = GetEntityModel(ped),
        coords = p,
        heading = GetEntityHeading(ped),
        health = GetEntityHealth(ped),
        armor  = GetPedArmour(ped),
        weapon = weapon,
        netId  = NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or nil,
        isPlayer = IsPedAPlayer(ped),
    }
end

local function snippetSpawn(info, scenario)
    return ([[
local hash = `%s`
lib.requestModel(hash)
local ped = CreatePed(4, hash, %s, %s, %s, %s, true, false)
SetEntityInvincible(ped, true)
SetBlockingOfNonTemporaryEvents(ped, true)
FreezeEntityPosition(ped, true)%s
]]):format(
        info.model,
        SFD.Round(info.coords.x), SFD.Round(info.coords.y), SFD.Round(info.coords.z), SFD.Round(info.heading),
        scenario and ('\nTaskStartScenarioInPlace(ped, "%s", 0, true)'):format(scenario) or '')
end

local function snippetTarget(info)
    return ([[
exports.ox_target:addLocalEntity(ped, {
    {
        label = 'Talk',
        icon = 'fa-solid fa-comment',
        onSelect = function() print('hi') end,
    },
})
]])
end

local function pickScenarioMenu(callback)
    local options = {}
    for _, name in ipairs(Config.Scenarios or {}) do
        options[#options + 1] = {
            title = name, icon = 'person',
            onSelect = function() callback(name) end,
        }
    end
    options[#options + 1] = { title = 'Custom…', icon = 'pen',
        onSelect = function()
            local input = lib.inputDialog('Custom scenario', { { type = 'input', label = 'Scenario name', required = true } })
            if input and input[1] then callback(input[1]) end
        end }
    lib.registerContext({
        id = 'sfd_ped_scenarios', title = 'Pick a scenario', menu = 'sfd_ped_main',
        canClose = true, options = options,
    })
    lib.showContext('sfd_ped_scenarios')
end

local function buildMenu(info)
    local options = {
        { title = 'Identity', description = ('handle %d · model %s'):format(info.entity, info.model), icon = 'id-card', readOnly = true },
        { title = 'Coords',   description = SFD.FormatVec4(info.coords, info.heading), icon = 'location-dot',
          onSelect = function() SFD.Copied('vector4', SFD.FormatVec4(info.coords, info.heading)) end },
        { title = 'Stats',    description = ('hp %d · armor %d · weapon %s'):format(info.health, info.armor, tostring(info.weapon)), icon = 'heart-pulse', readOnly = true },
        { title = 'Network',  description = info.netId and ('netId %d'):format(info.netId) or 'not networked', icon = 'network-wired', readOnly = true },
        { title = 'Copy CreatePed snippet', icon = 'code',
          onSelect = function() SFD.Copied('CreatePed', snippetSpawn(info)) end },
        { title = 'Copy ox_target template', icon = 'crosshairs',
          onSelect = function() SFD.Copied('target template', snippetTarget(info)) end },
        { title = 'Set scenario', icon = 'person-walking',
          onSelect = function()
              if not dangerous() then return end
              pickScenarioMenu(function(name)
                  ClearPedTasksImmediately(info.entity)
                  TaskStartScenarioInPlace(info.entity, name, 0, true)
                  SFD.Notify.success(('Scenario set: %s'):format(name))
              end)
          end },
        { title = 'Clear tasks', icon = 'broom',
          onSelect = function()
              if not dangerous() then return end
              ClearPedTasksImmediately(info.entity); SFD.Notify.success('Tasks cleared.')
          end },
        { title = 'Toggle invincible', icon = 'shield',
          onSelect = function()
              if not dangerous() then return end
              local now = not GetPlayerInvincible(NetworkGetEntityOwner(info.entity) or -1)
              SetEntityInvincible(info.entity, true); SFD.Notify.success('Invincible enabled.')
          end },
        { title = 'Toggle freeze', icon = 'snowflake',
          onSelect = function()
              if not dangerous() then return end
              local frozen = IsEntityPositionFrozen(info.entity)
              FreezeEntityPosition(info.entity, not frozen)
              SFD.Notify.success(frozen and 'Unfrozen.' or 'Frozen.')
          end },
        { title = 'Delete ped', icon = 'trash', iconColor = '#ff6b35',
          onSelect = function()
              if not dangerous() then return end
              if info.isPlayer then SFD.Notify.error('Refusing to delete a player ped.') return end
              SetEntityAsMissionEntity(info.entity, true, true)
              DeleteEntity(info.entity)
              SFD.Notify.success('Ped deleted.')
              SFD.LogServer('delete', { type = 'Ped', model = info.model })
          end },
        { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.PedTools.openMenu() end },
    }
    lib.registerContext({ id = 'sfd_ped_actions', title = 'Ped — actions', menu = 'sfd_ped_main', canClose = true, options = options })
    lib.showContext('sfd_ped_actions')
end

local function spawnFlow()
    local input = lib.inputDialog('Spawn ped', {
        { type = 'input', label = 'Model name (e.g. a_m_y_business_01)', required = true },
        { type = 'select', label = 'Scenario',
          options = (function()
              local opts = { { value = '', label = 'None' } }
              for _, s in ipairs(Config.Scenarios or {}) do opts[#opts+1] = { value = s, label = s } end
              return opts
          end)() },
    })
    if not input then return end
    if not dangerous() then return end
    local hash = joaat(input[1])
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then SFD.Notify.error('Invalid model.') return end
    local ok = lib.requestModel(hash, 5000)
    if not ok then SFD.Notify.error('Model failed to load.') return end
    local p = GetEntityCoords(PlayerPedId())
    local fwd = GetEntityForwardVector(PlayerPedId())
    local sp = p + fwd * 1.5
    local ped = CreatePed(4, hash, sp.x, sp.y, sp.z, GetEntityHeading(PlayerPedId()), true, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if input[2] and input[2] ~= '' then TaskStartScenarioInPlace(ped, input[2], 0, true) end
    SetModelAsNoLongerNeeded(hash)
    SFD.State.spawnedPeds[#SFD.State.spawnedPeds + 1] = ped
    SFD.LogServer('spawn', { type = 'Ped', model = input[1] })
    SFD.Notify.success(('Spawned ped (handle %d).'):format(ped))
end

function SFD.PedTools.openMenu()
    lib.registerContext({
        id = 'sfd_ped_main', title = 'Ped Tools', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = 'Inspect aimed ped', icon = 'crosshairs',
              onSelect = function()
                  local p = aimedPed()
                  if not p then SFD.Notify.warning('No ped in sight.') return end
                  buildMenu(buildInfo(p))
              end },
            { title = 'Inspect own ped', icon = 'user',
              onSelect = function() buildMenu(buildInfo(PlayerPedId())) end },
            { title = 'Spawn dev ped', description = 'Spawned peds are tracked & cleaned on resource stop', icon = 'plus',
              onSelect = function() spawnFlow() end },
            { title = 'Cleanup spawned peds', description = ('%d tracked'):format(#(SFD.State.spawnedPeds or {})), icon = 'broom',
              onSelect = function()
                  for _, e in ipairs(SFD.State.spawnedPeds or {}) do
                      if DoesEntityExist(e) then SetEntityAsMissionEntity(e, true, true); DeleteEntity(e) end
                  end
                  SFD.State.spawnedPeds = {}
                  SFD.Notify.success('Spawned peds removed.')
              end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_ped_main')
end

SFD.RegisterModule({
    id = 'ped_tools', label = 'Ped Tools',
    description = 'Inspect & spawn peds · scenarios · target snippets',
    icon = 'person',
    open = function() SFD.PedTools.openMenu() end,
})
