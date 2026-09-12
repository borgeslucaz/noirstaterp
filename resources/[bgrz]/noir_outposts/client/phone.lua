-- App "The Exchange" no telefone, registrado pelo contrato do bgrz_core.
-- O gate do ícone é apenas visual: todo dado vem de callback revalidado no servidor.
NoirOutposts = NoirOutposts or {}

local Phone = {}
NoirOutposts.Phone = Phone

local shared = require 'config.shared'
local clientConfig = require 'config.client'
local C = NoirOutposts.Constants

local registered = false
local lastPush = 0

local function definition()
    local resource = GetCurrentResourceName()
    local app = {
        identifier = shared.phone.identifier,
        name = shared.phone.name,
        description = shared.phone.description,
        developer = 'Noir State',
        ui = ('https://cfx-nui-%s/html/phone/index.html'):format(resource),
        icon = ('https://cfx-nui-%s/html/phone/icon.svg'):format(resource),
        -- Sem isto o app fica apenas listado na App Store, esperando instalação.
        defaultApp = shared.phone.defaultApp == true,
    }
    if shared.phone.requiresItem then
        app.requires = { item = shared.phone.requiresItem }
    end
    return app
end

local function register()
    if registered then return end
    if GetResourceState('bgrz_core') ~= 'started' then return end
    local ok, err = exports.bgrz_core:RegisterPhoneApp(definition())
    if not ok then
        if clientConfig.debug then
            lib.print.debug(('[noir_outposts] app do telefone indisponível: %s'):format(tostring(err)))
        end
        return
    end
    registered = true
end

---Busca o snapshot no servidor e envia ao app. Nada é calculado aqui.
---@return boolean sent
function Phone.pushState()
    if not registered then return false end
    if not NoirOutposts.Client.loggedIn then return false end

    local now = GetGameTimer()
    if now - lastPush < 1000 then return false end
    lastPush = now

    local response = lib.callback.await(C.Callbacks.PHONE_STATE, false)
    if not response or not response.ok then return false end

    exports.bgrz_core:SendPhoneAppMessage(shared.phone.identifier, {
        action = 'exchange:state',
        data = response.data,
    })
    return true
end

-- O app pede o estado ao abrir; o phone repassa a mensagem para a NUI do resource.
RegisterNUICallback('phone:requestState', function(_, cb)
    cb({ ok = true })
    Phone.pushState()
end)

---Uma página do feed. Responde direto ao fetch do app, sem passar pelo provider.
RegisterNUICallback('phone:feed', function(data, cb)
    if not NoirOutposts.Client.loggedIn then
        cb({ ok = false, code = 'invalid_player' })
        return
    end
    local cursor = type(data) == 'table' and data.cursor or nil
    if cursor ~= nil and type(cursor) ~= 'table' then
        cb({ ok = false, code = 'invalid_payload' })
        return
    end
    local response = lib.callback.await(C.Callbacks.PHONE_FEED, false, { cursor = cursor })
    cb(response or { ok = false, code = 'internal_error' })
end)

---Limpa o feed do jogador. O ledger não é tocado.
RegisterNUICallback('phone:clearFeed', function(_, cb)
    cb(lib.callback.await(C.Callbacks.PHONE_FEED_CLEAR, false) or { ok = false, code = 'internal_error' })
end)

---Preferências de alerta.
RegisterNUICallback('phone:settings', function(_, cb)
    cb(lib.callback.await(C.Callbacks.PHONE_SETTINGS, false) or { ok = false, code = 'internal_error' })
end)

RegisterNUICallback('phone:setAlerts', function(data, cb)
    if type(data) ~= 'table' or type(data.alerts) ~= 'table' then
        cb({ ok = false, code = 'invalid_payload' })
        return
    end
    local response = lib.callback.await(C.Callbacks.PHONE_SETTINGS_SET, false, { alerts = data.alerts })
    cb(response or { ok = false, code = 'internal_error' })
end)

---Define rota até um outpost a partir do app.
RegisterNUICallback('phone:setWaypoint', function(data, cb)
    if type(data) ~= 'table' or type(data.x) ~= 'number' or type(data.y) ~= 'number' then
        cb({ ok = false, code = 'invalid_payload' })
        return
    end
    SetNewWaypoint(data.x + 0.0, data.y + 0.0)
    cb({ ok = true })
end)

CreateThread(function()
    local attempts = 0
    while not registered and attempts < 100 do
        attempts = attempts + 1
        register()
        if registered then break end
        Wait(1000)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'sd-phone' then return end
    registered = false
    CreateThread(function()
        Wait(2000)
        register()
    end)
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    registered = false
end)
