-- ShadowForge DevTools — Client orchestrator
-- Detects framework, registers commands & keybind, opens the main panel.

SFD = SFD or {}
SFD.State = SFD.State or {}
SFD.State.spawnedProps  = SFD.State.spawnedProps  or {}
SFD.State.spawnedPeds   = SFD.State.spawnedPeds   or {}
SFD.State.savedLocations = SFD.State.savedLocations or {}

-- ───────────────────────────────────────────────
-- Framework & dependency detection
-- ───────────────────────────────────────────────
local function detect()
    SFD.Detected = {
        ox_lib       = GetResourceState('ox_lib')       == 'started',
        ox_target    = GetResourceState('ox_target')    == 'started',
        ox_inventory = GetResourceState('ox_inventory') == 'started',
        qbx_core     = GetResourceState('qbx_core')     == 'started',
        qb_core      = GetResourceState('qb-core')      == 'started',
        es_extended  = GetResourceState('es_extended')  == 'started',
    }
    if SFD.Detected.qbx_core then
        SFD.Framework = 'qbox'
    elseif SFD.Detected.qb_core then
        SFD.Framework = 'qbcore'
    elseif SFD.Detected.es_extended then
        SFD.Framework = 'esx'
    else
        SFD.Framework = 'standalone'
    end
end

CreateThread(function()
    Wait(500)
    detect()
end)

-- ───────────────────────────────────────────────
-- Main panel
-- ───────────────────────────────────────────────
local MAIN = 'sfd_main_menu'
local ABOUT = 'sfd_about'

local function buildMainMenu()
    local options = {}
    for _, mod in ipairs(SFD.Modules) do
        if Config.Modules[mod.id] ~= false then
            options[#options + 1] = {
                title       = mod.label,
                description = mod.description or '',
                icon        = mod.icon or 'wrench',
                iconColor   = mod.iconColor,
                arrow       = true,
                onSelect    = function() mod.open() end,
            }
        end
    end
    if Config.Modules.settings ~= false then
        options[#options + 1] = {
            title       = 'About & Status',
            description = 'Framework, dependencies, version',
            icon        = 'circle-info',
            arrow       = true,
            onSelect    = function() SFD.OpenAbout() end,
        }
    end
    lib.registerContext({
        id        = MAIN,
        title     = Config.UI.panelTitle,
        menu      = nil,
        canClose  = true,
        options   = options,
    })
end

function SFD.OpenPanel()
    if Config.Permissions.require and not SFD.HasPermission('base') then
        SFD.Notify.error('You do not have permission to use ShadowForge DevTools.')
        return
    end
    buildMainMenu()
    lib.showContext(MAIN)
    SFD.LogServer('open', {})
end

function SFD.OpenMain()
    SFD.OpenPanel()
end

function SFD.OpenAbout()
    detect()
    local fwLabel = ({
        qbox      = 'Qbox (qbx_core)',
        qbcore    = 'QBCore (qb-core)',
        esx       = 'ESX (es_extended)',
        standalone = 'Standalone',
    })[SFD.Framework] or SFD.Framework

    local function dep(name, ok)
        return ('%s — %s'):format(name, ok and '✓ started' or '✗ not started')
    end

    lib.registerContext({
        id       = ABOUT,
        title    = 'About & Status',
        menu     = MAIN,
        canClose = true,
        options  = {
            { title = 'Version',      description = '1.0.0',          icon = 'tag' },
            { title = 'Resource',     description = SFD.ResourceName, icon = 'box' },
            { title = 'Framework',    description = fwLabel,          icon = 'sitemap' },
            { title = 'Game build',   description = tostring(GetGameBuildNumber and GetGameBuildNumber() or 'n/a'), icon = 'gamepad' },
            { title = dep('ox_lib',       SFD.Detected.ox_lib),       icon = 'puzzle-piece' },
            { title = dep('ox_target',    SFD.Detected.ox_target),    icon = 'crosshairs' },
            { title = dep('ox_inventory', SFD.Detected.ox_inventory), icon = 'boxes-stacked' },
            { title = dep('qbx_core',     SFD.Detected.qbx_core),     icon = 'cube' },
            { title = dep('qb-core',      SFD.Detected.qb_core),      icon = 'cube' },
            { title = dep('es_extended',  SFD.Detected.es_extended),  icon = 'cube' },
            {
                title = 'GitHub & Issues',
                description = 'Open the project repository',
                icon = 'fab fa-github',
                onSelect = function()
                    SFD.SetClipboard('https://github.com/shadowforge/shadowforge-devtools')
                    SFD.Notify.info('Repository URL copied to clipboard.')
                end,
            },
            {
                title = 'Back',
                icon = 'arrow-left',
                onSelect = function() SFD.OpenPanel() end,
            },
        },
    })
    lib.showContext(ABOUT)
end

-- ───────────────────────────────────────────────
-- Commands & keybind
-- ───────────────────────────────────────────────
for _, cmd in ipairs(Config.Commands) do
    RegisterCommand(cmd, function() SFD.OpenPanel() end, false)
    TriggerEvent('chat:addSuggestion', '/' .. cmd, 'Open ShadowForge DevTools')
end

if Config.Keybind.enabled and lib and lib.addKeybind then
    lib.addKeybind({
        name        = Config.Keybind.name,
        description = Config.Keybind.description,
        defaultKey  = Config.Keybind.defaultKey,
        onPressed   = function() SFD.OpenPanel() end,
    })
end

-- ───────────────────────────────────────────────
-- Cleanup on resource stop
-- ───────────────────────────────────────────────
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, ent in pairs(SFD.State.spawnedProps or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    for _, ent in pairs(SFD.State.spawnedPeds or {}) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    if lib and lib.hideTextUI then lib.hideTextUI() end
    if SFD.State.noclipActive and SFD.PlayerTools and SFD.PlayerTools.disableNoclip then
        SFD.PlayerTools.disableNoclip()
    end
end)
