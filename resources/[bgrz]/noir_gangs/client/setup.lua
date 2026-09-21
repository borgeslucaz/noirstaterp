-- Tela de administração das gangs (`/gangsetup`).
--
-- É a mesma página da gestão — um resource tem um `ui_page` só — em outro modo. As duas
-- nunca abrem juntas, e é este arquivo que garante isso: quem abre uma com a outra no ar
-- simplesmente não abre.
--
-- Tudo aqui é de admin. A tela esconder um botão não protege nada: cada ação atravessa o
-- mesmo portão de ace no servidor, que é onde a decisão acontece de verdade.

Setup = { state = 'CLOSED' }

local CLOSE_TIMEOUT_MS = 1200
local snapshot = nil ---@type table|nil último estado enviado, reenviado no uiReady
local closeToken = nil

local core = exports.bgrz_core

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

function Setup.isOpen()
    return Setup.state ~= 'CLOSED'
end

local function fetch()
    local data = lib.callback.await('noir_gangs:server:getSetup', false)
    return type(data) == 'table' and data or nil
end

local function finalizeClose()
    if Setup.state == 'CLOSED' then return end
    Setup.state = 'CLOSED'
    snapshot = nil
    closeToken = nil
    SetNuiFocus(false, false)
end

local function beginClose()
    Setup.state = 'CLOSING'
    local token = {}
    closeToken = token
    SetTimeout(CLOSE_TIMEOUT_MS, function()
        if closeToken == token then finalizeClose() end
    end)
end

function Setup.forceClose()
    if Setup.state == 'CLOSED' then return end
    send('gangSetup:close', { immediate = true })
    finalizeClose()
end

---Solta o foco sem fechar a tela: é o que o posicionamento no mundo precisa. A página
---continua montada, escondida, e volta com `resume`.
local function suspend()
    Setup.state = 'PLACING'
    SetNuiFocus(false, false)
    send('gangSetup:suspend', {})
end

local function resume(data)
    if Setup.state ~= 'PLACING' then return end
    snapshot = data or snapshot
    Setup.state = 'READY'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    send('gangSetup:open', snapshot)
end

function Setup.open()
    if Setup.state ~= 'CLOSED' then return end
    -- A gestão e o setup dividem a mesma página. Abrir por cima trocaria o conteúdo com o
    -- foco de outra tela ainda ativo.
    if Menu and Menu.isOpen() then return core:Notify('Feche a gestão da gang antes.', 'error') end

    Setup.state = 'OPENING'
    local data = fetch()
    if Setup.state ~= 'OPENING' then return end
    if not data then
        Setup.state = 'CLOSED'
        return core:Notify('Acesso negado.', 'error')
    end

    snapshot = data
    Setup.state = 'READY'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    send('gangSetup:open', data)
end

-- ───────────────────────── posicionamento no mundo ─────────────────────────

---Marca um ponto no chão. A tela sai de cena enquanto isso — não dá para escolher um lugar
---no mundo olhando para uma janela — e volta com o resultado.
---@param gangName string
---@param locationId integer|nil quando existe, o ponto é movido em vez de criado
local function place(gangName, locationId)
    suspend()
    core:Notify('Posicione-se no local. E confirma; BACKSPACE cancela.')

    CreateThread(function()
        while Setup.state == 'PLACING' do
            Wait(0)
            local coords = GetEntityCoords(cache.ped)
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                1.5, 1.5, 0.5, 210, 11, 11, 100, false, false, 2, false)

            if IsControlJustReleased(0, 38) then
                local data = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(cache.ped) }
                local ok = locationId
                    and lib.callback.await('noir_gangs:server:updateLocation', false, locationId, data)
                    or lib.callback.await('noir_gangs:server:createLocation', false, gangName, data)
                core:Notify(ok and 'Ponto de gestão salvo.' or 'Não foi possível salvar.', ok and 'success' or 'error')
                return resume(fetch())
            elseif IsControlJustReleased(0, 177) then
                core:Notify('Posicionamento cancelado.')
                return resume(nil)
            end
        end
    end)
end

-- ───────────────────────── callbacks da página ─────────────────────────

RegisterNUICallback('setupReady', function(_, cb)
    cb({})
    if Setup.state == 'READY' and snapshot then send('gangSetup:open', snapshot) end
end)

RegisterNUICallback('closeSetup', function(_, cb)
    if Setup.state ~= 'READY' then return cb({ ok = false }) end
    beginClose()
    cb({ ok = true })
end)

RegisterNUICallback('setupCloseComplete', function(_, cb)
    cb({})
    finalizeClose()
end)

RegisterNUICallback('refreshSetup', function(_, cb)
    if Setup.state ~= 'READY' then return cb({ ok = false, code = 'not_open' }) end
    local data = fetch()
    if not data then
        Setup.forceClose()
        return cb({ ok = false, code = 'no_permission' })
    end
    snapshot = data
    cb({ ok = true, data = data })
end)

---Uma ação por vez, e o retorno já traz o snapshot novo: criar uma gang muda a lista, a
---contagem de cargos e o que o seletor de arquétipo pode oferecer em seguida.
local function action(callback, cb, payload)
    if Setup.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end

    Setup.state = 'BUSY'
    local ok, code, extra = lib.callback.await(callback, false, payload)
    if Setup.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Setup.state = 'READY'

    local fresh = ok and fetch() or nil
    if fresh then snapshot = fresh end
    cb({ ok = ok == true, code = code, extra = extra, data = fresh })
end

RegisterNUICallback('createGang', function(data, cb)
    if type(data) ~= 'table' then return cb({ ok = false, code = 'invalid_name' }) end
    action('noir_gangs:server:createGang', cb, data)
end)

RegisterNUICallback('updateGang', function(data, cb)
    if type(data) ~= 'table' then return cb({ ok = false, code = 'gang_not_found' }) end
    action('noir_gangs:server:updateGang', cb, data)
end)

---O primeiro chefe. Duas informações em vez de uma tabela só porque é assim que o
---callback do servidor é: gang e quem assume.
RegisterNUICallback('assignBoss', function(data, cb)
    if Setup.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end
    local gangName = type(data) == 'table' and data.gang or nil
    local target = type(data) == 'table' and tonumber(data.target) or nil
    if type(gangName) ~= 'string' or not target then return cb({ ok = false, code = 'invalid_member' }) end

    Setup.state = 'BUSY'
    local ok, code, name = lib.callback.await('noir_gangs:server:assignBoss', false, gangName, target)
    if Setup.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Setup.state = 'READY'

    local fresh = ok and fetch() or nil
    if fresh then snapshot = fresh end
    cb({ ok = ok == true, code = code, extra = name, data = fresh })
end)

RegisterNUICallback('placeLocation', function(data, cb)
    if Setup.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end
    local gangName = type(data) == 'table' and data.gang or nil
    if type(gangName) ~= 'string' then return cb({ ok = false, code = 'gang_not_found' }) end

    local locationId = type(data.id) == 'number' and data.id or nil
    cb({ ok = true })
    place(gangName, locationId)
end)

RegisterNUICallback('deleteLocation', function(data, cb)
    if Setup.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end
    local id = type(data) == 'table' and data.id or nil
    if type(id) ~= 'number' then return cb({ ok = false, code = 'location_not_found' }) end

    Setup.state = 'BUSY'
    local ok = lib.callback.await('noir_gangs:server:deleteLocation', false, id)
    if Setup.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Setup.state = 'READY'

    local fresh = ok and fetch() or nil
    if fresh then snapshot = fresh end
    cb({ ok = ok == true, code = not ok and 'failed' or nil, data = fresh })
end)

---Teleportar fecha a tela: o admin quer ir até lá, não olhar o ponto de dentro da janela.
RegisterNUICallback('teleportToLocation', function(data, cb)
    if Setup.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end
    local coords = type(data) == 'table' and data.coords or nil
    if type(coords) ~= 'table' or not tonumber(coords.x) then
        return cb({ ok = false, code = 'location_not_found' })
    end

    cb({ ok = true })
    SetEntityCoords(cache.ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
    beginClose()
    send('gangSetup:close', {})
end)

RegisterNetEvent('noir_gangs:client:openSetup', function()
    Setup.open()
end)
