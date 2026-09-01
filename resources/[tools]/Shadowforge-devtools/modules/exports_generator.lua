-- modules/exports_generator.lua
-- Catalogue of ready-made code snippets for fast script bootstrapping.

SFD = SFD or {}
SFD.Snippets = {}

local function R(n) return SFD.Round(n, 2) end

local function playerHere()
    local p = GetEntityCoords(PlayerPedId())
    local h = GetEntityHeading(PlayerPedId())
    return p, h
end

-- ───────────────────────────────────────────────
-- Templates
-- ───────────────────────────────────────────────
local templates = {}

templates.vector3 = function()
    local p = playerHere()
    return SFD.FormatVec3(p)
end

templates.vector4 = function()
    local p, h = playerHere()
    return SFD.FormatVec4(p, h)
end

templates.create_object = function()
    local p, h = playerHere()
    return ([[
local hash = `prop_chair_01a`
lib.requestModel(hash)
local obj = CreateObject(hash, %s, %s, %s, true, true, false)
SetEntityHeading(obj, %s)
SetEntityCollision(obj, true, true)
FreezeEntityPosition(obj, true)
]]):format(R(p.x), R(p.y), R(p.z), R(h))
end

templates.create_vehicle = function()
    local p, h = playerHere()
    return ([[
local hash = `adder`
lib.requestModel(hash)
local veh = CreateVehicle(hash, %s, %s, %s, %s, true, false)
SetVehicleNumberPlateText(veh, 'DEV')
SetVehicleOnGroundProperly(veh)
]]):format(R(p.x), R(p.y), R(p.z), R(h))
end

templates.create_ped = function()
    local p, h = playerHere()
    return ([[
local hash = `a_m_y_business_01`
lib.requestModel(hash)
local ped = CreatePed(4, hash, %s, %s, %s, %s, true, false)
SetEntityInvincible(ped, true)
SetBlockingOfNonTemporaryEvents(ped, true)
FreezeEntityPosition(ped, true)
]]):format(R(p.x), R(p.y), R(p.z), R(h))
end

templates.target_box_zone = function()
    local p, h = playerHere()
    return ([[
exports.ox_target:addBoxZone({
    coords   = vec3(%s, %s, %s),
    size     = vec3(2.0, 2.0, 2.0),
    rotation = %s,
    debug    = true,
    options  = {
        { label = 'Interact', icon = 'fa-solid fa-hand', onSelect = function(data) print(data.entity) end },
    },
})]]):format(R(p.x), R(p.y), R(p.z), R(h))
end

templates.target_sphere_zone = function()
    local p = playerHere()
    return ([[
exports.ox_target:addSphereZone({
    coords = vec3(%s, %s, %s),
    radius = 1.5,
    debug  = true,
    options = {
        { label = 'Interact', icon = 'fa-solid fa-hand', onSelect = function() end },
    },
})]]):format(R(p.x), R(p.y), R(p.z))
end

templates.target_add_model = [[
exports.ox_target:addModel(`prop_chair_01a`, {
    {
        label = 'Sit',
        icon  = 'fa-solid fa-chair',
        onSelect = function(data)
            -- data.entity is the prop the player targeted
        end,
    },
})]]

templates.target_add_entity = [[
exports.ox_target:addLocalEntity(entity, {
    {
        label = 'Talk',
        icon  = 'fa-solid fa-comment',
        onSelect = function() print('hello') end,
    },
})]]

templates.lib_zone_box = function()
    local p, h = playerHere()
    return ([[
local zone = lib.zones.box({
    coords   = vec3(%s, %s, %s),
    size     = vec3(2.0, 2.0, 2.0),
    rotation = %s,
    debug    = true,
    onEnter = function(self) end,
    onExit  = function(self) end,
    inside  = function(self) end,
})]]):format(R(p.x), R(p.y), R(p.z), R(h))
end

templates.lib_zone_sphere = function()
    local p = playerHere()
    return ([[
local zone = lib.zones.sphere({
    coords = vec3(%s, %s, %s),
    radius = 1.5,
    debug  = true,
    onEnter = function(self) end,
    onExit  = function(self) end,
})]]):format(R(p.x), R(p.y), R(p.z))
end

templates.qb_target_box = function()
    local p, h = playerHere()
    return ([[
exports['qb-target']:AddBoxZone('zoneName', vector3(%s, %s, %s), 2.0, 2.0, {
    name = 'zoneName', heading = %s, debugPoly = true, minZ = %s, maxZ = %s,
}, {
    options = { { label = 'Interact', icon = 'fa-solid fa-hand', action = function() end } },
    distance = 2.5,
})]]):format(R(p.x), R(p.y), R(p.z), R(h), R(p.z - 1.0), R(p.z + 1.0))
end

templates.event_handler_client = [[
RegisterNetEvent('myresource:client:doSomething', function(payload)
    -- runs on client
end)]]

templates.event_handler_server = [[
RegisterNetEvent('myresource:server:doSomething', function(payload)
    local src = source
    -- validate, then act
end)]]

templates.progress_bar = [[
local success = lib.progressBar({
    label    = 'Working…',
    duration = 5000,
    useWhileDead = false,
    canCancel = true,
    disable  = { car = true, move = true, combat = true },
    anim     = { dict = 'mini@repair', clip = 'fixing_a_ped' },
})
if success then
    print('done')
else
    print('canceled')
end]]

templates.context_menu = [[
lib.registerContext({
    id = 'myresource_main',
    title = 'Main menu',
    canClose = true,
    options = {
        { title = 'Action 1', description = 'Description', icon = 'circle', onSelect = function() end },
        { title = 'Action 2', icon = 'star', onSelect = function() end },
    },
})
lib.showContext('myresource_main')]]

templates.input_dialog = [[
local input = lib.inputDialog('Title', {
    { type = 'input',  label = 'Name',  required = true, max = 32 },
    { type = 'number', label = 'Count', default = 1,     min = 1   },
    { type = 'select', label = 'Color', options = {
        { value = 'red',  label = 'Red'  },
        { value = 'blue', label = 'Blue' },
    }},
})
if input then
    -- input[1] name, input[2] count, input[3] color
end]]

templates.notify = [[
lib.notify({
    title       = 'Hello',
    description = 'This is a notification',
    type        = 'success', -- 'error' | 'inform' | 'warning'
})]]

templates.command = [[
RegisterCommand('mycommand', function(source, args, raw)
    -- runs on the side it's registered on
end, false)]]

templates.ace_check_server = [[
local function isAdmin(src)
    return IsPlayerAceAllowed(src, 'group.admin')
end

RegisterNetEvent('myresource:adminAction', function()
    local src = source
    if not isAdmin(src) then return end
    -- safe to act
end)]]

templates.discord_webhook = [[
local function postLog(title, fields)
    PerformHttpRequest('YOUR_WEBHOOK_URL', function() end, 'POST', json.encode({
        username = 'My Resource',
        embeds = {{
            title  = title,
            color  = 12624639,
            fields = fields,
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        }},
    }), { ['Content-Type'] = 'application/json' })
end]]

-- ───────────────────────────────────────────────
-- Catalogue (UI)
-- ───────────────────────────────────────────────
local CATALOGUE = {
    { group = 'Coordinates', items = {
        { id = 'vector3', label = 'vector3 (player)' },
        { id = 'vector4', label = 'vector4 (player)' },
    }},
    { group = 'Spawn', items = {
        { id = 'create_object',  label = 'CreateObject template' },
        { id = 'create_vehicle', label = 'CreateVehicle template' },
        { id = 'create_ped',     label = 'CreatePed template' },
    }},
    { group = 'ox_target', items = {
        { id = 'target_box_zone',    label = 'addBoxZone (here)' },
        { id = 'target_sphere_zone', label = 'addSphereZone (here)' },
        { id = 'target_add_model',   label = 'addModel' },
        { id = 'target_add_entity',  label = 'addLocalEntity' },
    }},
    { group = 'ox_lib zones', items = {
        { id = 'lib_zone_box',    label = 'lib.zones.box (here)' },
        { id = 'lib_zone_sphere', label = 'lib.zones.sphere (here)' },
    }},
    { group = 'qb-target', items = {
        { id = 'qb_target_box', label = 'AddBoxZone (here)' },
    }},
    { group = 'Events & commands', items = {
        { id = 'event_handler_client', label = 'Client event handler' },
        { id = 'event_handler_server', label = 'Server event handler' },
        { id = 'command',              label = 'RegisterCommand' },
    }},
    { group = 'ox_lib UI', items = {
        { id = 'progress_bar',  label = 'lib.progressBar' },
        { id = 'context_menu',  label = 'lib.registerContext + show' },
        { id = 'input_dialog',  label = 'lib.inputDialog' },
        { id = 'notify',        label = 'lib.notify' },
    }},
    { group = 'Server', items = {
        { id = 'ace_check_server', label = 'ACE permission check' },
        { id = 'discord_webhook',  label = 'Discord webhook helper' },
    }},
}

local function resolveSnippet(id)
    local t = templates[id]
    if type(t) == 'function' then return t() end
    if type(t) == 'string' then return t end
    return nil
end

local function copySnippet(id, label)
    local snippet = resolveSnippet(id)
    if not snippet then SFD.Notify.error('Template missing.') return end
    SFD.SetClipboard(snippet)
    SFD.Notify.success(('Copied: %s'):format(label))
    if Config.Discord.log.snippet then SFD.LogServer('snippet', { id = id }) end
end

local function groupMenu(group, items)
    local options = {}
    for _, it in ipairs(items) do
        options[#options + 1] = {
            title = it.label, icon = 'code',
            onSelect = function() copySnippet(it.id, it.label) end,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.Snippets.openMenu() end }
    local id = 'sfd_snip_grp_' .. group
    lib.registerContext({ id = id, title = group, menu = 'sfd_snip_main', canClose = true, options = options })
    lib.showContext(id)
end

function SFD.Snippets.openMenu()
    local options = {}
    for _, g in ipairs(CATALOGUE) do
        options[#options + 1] = {
            title = g.group,
            description = ('%d snippets'):format(#g.items),
            icon = 'folder', arrow = true,
            onSelect = function() groupMenu(g.group, g.items) end,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'arrow-left', onSelect = function() SFD.OpenMain() end }
    lib.registerContext({ id = 'sfd_snip_main', title = 'Snippet Generator', menu = 'sfd_main_menu', canClose = true, options = options })
    lib.showContext('sfd_snip_main')
end

SFD.RegisterModule({
    id = 'snippets', label = 'Snippet Generator',
    description = 'Ready-made code: events · zones · UI · webhook · permissions',
    icon = 'code',
    open = function() SFD.Snippets.openMenu() end,
})
