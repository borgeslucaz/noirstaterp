-- modules/player_tools.lua
-- Self-targeted dev/test helpers: heal, armor, godmode, noclip, invisible, dev blips.
-- All actions respect Config.PlayerTools toggles and the dangerous permission.

SFD = SFD or {}
SFD.PlayerTools = {}

local function dangerous() return SFD.HasPermission('dangerous') end

-- ───────────────────────────────────────────────
-- Toggles state
-- ───────────────────────────────────────────────
local godmode = false
local invisible = false
local devBlips = false
local devBlipHandles = {}

-- ───────────────────────────────────────────────
-- NOCLIP
-- ───────────────────────────────────────────────
local noclip = false

local function startNoclip()
    if noclip then return end
    if not Config.PlayerTools.allowNoclip then SFD.Notify.error('Noclip is disabled in config.') return end
    if not dangerous() then return end
    noclip = true
    SFD.State.noclipActive = true
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SFD.Notify.success('Noclip enabled.')
    SFD.LogServer('noclip', { state = 'on' })

    CreateThread(function()
        local pos = GetEntityCoords(ped)
        while noclip do
            local mul = 1.0
            if IsControlPressed(0, 21) then mul = Config.PlayerTools.noclipFastMul or 4.0
            elseif IsControlPressed(0, 19) then mul = Config.PlayerTools.noclipSlowMul or 0.25 end

            local camRot = GetGameplayCamRot(2)
            local rZ, rX = math.rad(camRot.z), math.rad(camRot.x)
            local cosX = math.cos(rX)
            local fwd   = vec3(-math.sin(rZ) * cosX, math.cos(rZ) * cosX, math.sin(rX))
            local right = vec3( math.cos(rZ),        math.sin(rZ),       0.0)

            local d = vec3(0, 0, 0)
            if IsControlPressed(0, 32) then d = d + fwd   end -- W
            if IsControlPressed(0, 33) then d = d - fwd   end -- S
            if IsControlPressed(0, 34) then d = d - right end -- A
            if IsControlPressed(0, 35) then d = d + right end -- D
            if IsControlPressed(0, 22) then d = d + vec3(0,0,1) end -- Space (up)
            if IsControlPressed(0, 36) then d = d - vec3(0,0,1) end -- Ctrl (down)

            if d.x ~= 0 or d.y ~= 0 or d.z ~= 0 then
                pos = GetEntityCoords(ped) + d * (Config.PlayerTools.noclipSpeed or 1.0) * mul
                SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
            end
            Wait(0)
        end
    end)
end

local function stopNoclip()
    if not noclip then return end
    noclip = false
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SFD.State.noclipActive = false
    SFD.Notify.info('Noclip disabled.')
    SFD.LogServer('noclip', { state = 'off' })
end

function SFD.PlayerTools.disableNoclip() stopNoclip() end

-- ───────────────────────────────────────────────
-- DEV BLIPS
-- ───────────────────────────────────────────────
local function refreshDevBlips()
    for _, b in ipairs(devBlipHandles) do RemoveBlip(b) end
    devBlipHandles = {}
    if not devBlips then return end
    -- Mark active players
    for _, p in ipairs(GetActivePlayers()) do
        if p ~= PlayerId() then
            local ped = GetPlayerPed(p)
            if DoesEntityExist(ped) then
                local b = AddBlipForEntity(ped)
                SetBlipSprite(b, 1)
                SetBlipColour(b, 1)
                ShowHeadingIndicatorOnBlip(b, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(GetPlayerName(p))
                EndTextCommandSetBlipName(b)
                devBlipHandles[#devBlipHandles + 1] = b
            end
        end
    end
end

CreateThread(function()
    while true do
        if devBlips then refreshDevBlips() end
        Wait(5000)
    end
end)

-- ───────────────────────────────────────────────
-- Stats display
-- ───────────────────────────────────────────────
local function statsMenu()
    local data = lib.callback.await('sfd:getFrameworkData', false) or {}
    local id = lib.callback.await('sfd:getIdentifiers', false) or {}
    local options = {
        { title = 'Server ID', description = tostring(GetPlayerServerId(PlayerId())), icon = 'hashtag', readOnly = true },
        { title = 'Framework', description = data.framework or 'standalone', icon = 'sitemap', readOnly = true },
    }
    if data.job then
        options[#options + 1] = { title = 'Job', description = json.encode(data.job), icon = 'briefcase',
            onSelect = function() SFD.Copied('job table', json.encode(data.job)) end }
    end
    if data.money then
        options[#options + 1] = { title = 'Money', description = json.encode(data.money), icon = 'sack-dollar',
            onSelect = function() SFD.Copied('money table', json.encode(data.money)) end }
    end
    if data.citizenid then
        options[#options + 1] = { title = 'Citizen ID', description = data.citizenid, icon = 'id-card',
            onSelect = function() SFD.Copied('citizenid', data.citizenid) end }
    end
    if id.identifiers then
        options[#options + 1] = { title = 'Identifiers', description = ('%d total'):format(#id.identifiers), icon = 'fingerprint',
            onSelect = function() SFD.Copied('identifiers', json.encode(id.identifiers)) end }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.PlayerTools.openMenu() end }

    lib.registerContext({ id = 'sfd_player_stats', title = 'Player stats', menu = 'sfd_player_main', canClose = true, options = options })
    lib.showContext('sfd_player_stats')
end

-- ───────────────────────────────────────────────
-- Main menu
-- ───────────────────────────────────────────────
function SFD.PlayerTools.openMenu()
    local ped = PlayerPedId()
    lib.registerContext({
        id = 'sfd_player_main', title = 'Player / Dev Tools', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = 'My stats', description = 'Server ID, framework, job, money, identifiers', icon = 'circle-info', arrow = true,
              onSelect = function() statsMenu() end },
            { title = 'Copy own coords', icon = 'location-dot',
              onSelect = function()
                  local p = GetEntityCoords(ped)
                  SFD.Copied('vector4', SFD.FormatVec4(p, GetEntityHeading(ped)))
              end },
            { title = 'Copy current model hash', icon = 'fingerprint',
              onSelect = function() SFD.Copied('model hash', tostring(GetEntityModel(ped))) end },
            { title = 'Teleport to waypoint', icon = 'map-pin',
              onSelect = function()
                  if not dangerous() then return end
                  local wp = GetFirstBlipInfoId(8)
                  if not DoesBlipExist(wp) then SFD.Notify.warning('No waypoint set.') return end
                  local c = GetBlipInfoIdCoord(wp)
                  local _, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 100.0, false)
                  SetPedCoordsKeepVehicle(ped, c.x, c.y, gz ~= 0.0 and gz or c.z)
                  SFD.Notify.success('Teleported to waypoint.')
                  SFD.LogServer('teleport', { dest = 'waypoint' })
              end },
            { title = 'Heal', description = 'Restore HP to max', icon = 'heart',
              onSelect = function()
                  if not Config.PlayerTools.allowSelfHeal then SFD.Notify.error('Disabled in config.') return end
                  if not dangerous() then return end
                  SetEntityHealth(ped, GetEntityMaxHealth(ped))
                  SFD.Notify.success('Healed.')
              end },
            { title = 'Armor 100', icon = 'shield',
              onSelect = function()
                  if not Config.PlayerTools.allowSelfArmor then SFD.Notify.error('Disabled in config.') return end
                  if not dangerous() then return end
                  SetPedArmour(ped, 100); SFD.Notify.success('Armor restored.')
              end },
            { title = godmode and 'Godmode: ON (toggle off)' or 'Godmode: OFF (toggle on)', icon = 'shield-halved',
              onSelect = function()
                  if not Config.PlayerTools.allowGodmode then SFD.Notify.error('Disabled in config.') return end
                  if not dangerous() then return end
                  godmode = not godmode
                  SetEntityInvincible(ped, godmode)
                  SetPlayerInvincible(PlayerId(), godmode)
                  SFD.Notify.success(godmode and 'Godmode enabled.' or 'Godmode disabled.')
                  SFD.LogServer('godmode', { state = godmode })
                  SFD.PlayerTools.openMenu()
              end },
            { title = invisible and 'Invisible: ON (toggle off)' or 'Invisible: OFF (toggle on)', icon = 'ghost',
              onSelect = function()
                  if not Config.PlayerTools.allowInvisible then SFD.Notify.error('Disabled in config.') return end
                  if not dangerous() then return end
                  invisible = not invisible
                  SetEntityVisible(ped, not invisible, false)
                  SFD.PlayerTools.openMenu()
              end },
            { title = noclip and 'Noclip: ON (toggle off)' or 'Noclip: OFF (toggle on)', icon = 'person-walking',
              description = 'WASD · Space/Ctrl · Shift fast · Alt slow',
              onSelect = function()
                  if noclip then stopNoclip() else startNoclip() end
                  SFD.PlayerTools.openMenu()
              end },
            { title = devBlips and 'Dev blips: ON (toggle off)' or 'Dev blips: OFF (toggle on)', icon = 'map',
              onSelect = function()
                  if not Config.PlayerTools.allowDevBlips then SFD.Notify.error('Disabled in config.') return end
                  devBlips = not devBlips
                  if not devBlips then for _, b in ipairs(devBlipHandles) do RemoveBlip(b) end; devBlipHandles = {} end
                  refreshDevBlips()
                  SFD.PlayerTools.openMenu()
              end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_player_main')
end

SFD.RegisterModule({
    id = 'player_tools', label = 'Player / Dev Tools',
    description = 'Self heal · noclip · godmode · waypoint TP · stats',
    icon = 'user',
    open = function() SFD.PlayerTools.openMenu() end,
})
