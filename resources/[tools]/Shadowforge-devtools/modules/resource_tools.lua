-- modules/resource_tools.lua
-- Dependency state, framework detection, controlled resource restart (Config.SafeResources only).

SFD = SFD or {}
SFD.ResourceTools = {}

local function dot(state)
    if state == 'started' then return '✓ started' end
    if state == 'starting' then return '… starting' end
    if state == 'stopped' then return '✗ stopped' end
    if state == 'missing' then return '✗ missing' end
    return state or 'unknown'
end

local function dependenciesMenu()
    local deps = {
        { name = 'ox_lib',       state = GetResourceState('ox_lib') },
        { name = 'ox_target',    state = GetResourceState('ox_target') },
        { name = 'ox_inventory', state = GetResourceState('ox_inventory') },
        { name = 'qbx_core',     state = GetResourceState('qbx_core') },
        { name = 'qb-core',      state = GetResourceState('qb-core') },
        { name = 'es_extended',  state = GetResourceState('es_extended') },
    }
    local options = {}
    for _, d in ipairs(deps) do
        options[#options + 1] = {
            title = d.name,
            description = dot(d.state),
            icon = d.state == 'started' and 'circle-check' or 'circle-xmark',
            iconColor = d.state == 'started' and '#4ade80' or '#ff6b35',
            readOnly = true,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.ResourceTools.openMenu() end }
    lib.registerContext({ id = 'sfd_res_deps', title = 'Dependencies', menu = 'sfd_res_main', canClose = true, options = options })
    lib.showContext('sfd_res_deps')
end

local function safeResourcesMenu()
    local list = lib.callback.await('sfd:listSafeResources', false) or {}
    local options = {}
    if #list == 0 then
        options[#options + 1] = { title = 'No resources whitelisted', description = 'Edit Config.SafeResources', icon = 'circle-info', readOnly = true }
    end
    for _, r in ipairs(list) do
        options[#options + 1] = {
            title = r.name, description = dot(r.state), icon = 'box',
            arrow = true,
            onSelect = function()
                lib.registerContext({
                    id = 'sfd_res_one_' .. r.name,
                    title = r.name, menu = 'sfd_res_safe', canClose = true,
                    options = {
                        { title = 'Restart (ensure)', icon = 'rotate',
                          onSelect = function() TriggerServerEvent('sfd:resource', 'restart', r.name); SFD.Notify.success(('ensure %s'):format(r.name)) end },
                        { title = 'Start', icon = 'play',
                          onSelect = function() TriggerServerEvent('sfd:resource', 'start', r.name); SFD.Notify.success(('start %s'):format(r.name)) end },
                        { title = 'Stop',  icon = 'stop',  iconColor = '#ff6b35',
                          onSelect = function() TriggerServerEvent('sfd:resource', 'stop', r.name); SFD.Notify.warning(('stop %s'):format(r.name)) end },
                        { title = 'Back', icon = 'arrow-left', onSelect = function() safeResourcesMenu() end },
                    },
                })
                lib.showContext('sfd_res_one_' .. r.name)
            end,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.ResourceTools.openMenu() end }
    lib.registerContext({ id = 'sfd_res_safe', title = 'Safe resources', menu = 'sfd_res_main', canClose = true, options = options })
    lib.showContext('sfd_res_safe')
end

function SFD.ResourceTools.openMenu()
    local fwLabel = ({
        qbox = 'Qbox', qbcore = 'QBCore', esx = 'ESX', standalone = 'Standalone',
    })[SFD.Framework] or SFD.Framework or 'Standalone'

    lib.registerContext({
        id = 'sfd_res_main', title = 'Resource Tools', menu = 'sfd_main_menu', canClose = true,
        options = {
            { title = 'Resource',  description = SFD.ResourceName, icon = 'box',     readOnly = true },
            { title = 'Framework', description = fwLabel,          icon = 'sitemap', readOnly = true },
            { title = 'Game build', description = tostring(GetGameBuildNumber and GetGameBuildNumber() or 'n/a'), icon = 'gamepad', readOnly = true },
            { title = 'Dependency status', icon = 'puzzle-piece', arrow = true, onSelect = function() dependenciesMenu() end },
            { title = 'Safe resource control', description = ('%d whitelisted'):format(#(Config.SafeResources or {})), icon = 'shield-halved', arrow = true,
              onSelect = function() safeResourcesMenu() end },
            { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end },
        },
    })
    lib.showContext('sfd_res_main')
end

SFD.RegisterModule({
    id = 'resource_tools', label = 'Resource Tools',
    description = 'Dependency status · controlled restart of whitelisted resources',
    icon = 'box',
    open = function() SFD.ResourceTools.openMenu() end,
})
