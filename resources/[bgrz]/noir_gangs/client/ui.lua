-- Ponte da tela de gestão.
--
-- A página só apresenta: recebe o snapshot inteiro do servidor, devolve intenção, e nunca
-- decide o que alguém pode fazer — o que ela esconde, o servidor recusa de novo.
--
-- Este arquivo guarda o último snapshot porque o CEF pode recarregar sozinho: quando isso
-- acontece a página avisa `uiReady` e é redesenhada do zero, sem passar pelo servidor.

Menu = { state = 'CLOSED' }

local CLOSE_TIMEOUT_MS = 1200 -- segurança: libera o foco mesmo se a página não responder
local snapshot = nil ---@type table|nil último estado enviado, reenviado no uiReady
local closeToken = nil

local core = exports.bgrz_core

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

function Menu.isOpen()
    return Menu.state ~= 'CLOSED'
end

---O mapa de territórios vem do `noir_territories`, que é dono dos bairros, das cores e da
---projeção dos tiles. Sem ele a aba existe e explica a ausência — território é informação
---de apoio aqui, não a razão da tela.
---@return table|nil { zones, map }
local function territoryMap()
    if GetResourceState('noir_territories') ~= 'started' then return end
    local ok, data = pcall(function() return exports.noir_territories:GetTerritoryMap() end)
    if not ok or type(data) ~= 'table' then return end
    return data
end

---Snapshot completo: gestão do servidor mais o mapa, que é do cliente. É tudo que a página
---precisa para se redesenhar inteira.
---@return table|nil
---@return table|nil snapshot
---@return boolean notReady o resource subiu sem registro; não é falta de permissão
local function fetch()
    local data = lib.callback.await('noir_gangs:server:getSnapshot', false)
    if type(data) ~= 'table' then return end
    -- Bootstrap falhado tem sintoma igual ao de não ter gang, e as duas causas pedem
    -- reações opostas: uma é da pessoa, a outra é da administração.
    if data.notReady then return nil, true end
    -- Sem `view_members` a tela abriria vazia, e vazia por falta de permissão parece vazia
    -- por falta de gente. Melhor não abrir e dizer o motivo.
    if not data.inGang or not data.permissions.view_members then return end
    data.territory = territoryMap()
    return data
end

local function finalizeClose()
    if Menu.state == 'CLOSED' then return end
    Menu.state = 'CLOSED'
    snapshot = nil
    closeToken = nil
    SetNuiFocus(false, false)
end

---Inicia a saída animada; o foco é liberado no `closeComplete` ou pelo timeout. Depender só
---do aviso da página deixaria o jogador sem teclado se ela travasse no meio.
local function beginClose()
    Menu.state = 'CLOSING'
    local token = {}
    closeToken = token
    SetTimeout(CLOSE_TIMEOUT_MS, function()
        if closeToken == token then finalizeClose() end
    end)
end

---Fechamento imediato: morte, logout, restart do resource.
function Menu.forceClose()
    if Menu.state == 'CLOSED' then return end
    send('gang:close', { immediate = true })
    finalizeClose()
end

function Menu.open()
    if Menu.state ~= 'CLOSED' then return end
    if not core:IsLoggedIn() then return end

    Menu.state = 'OPENING'
    local data, notReady = fetch()
    if Menu.state ~= 'OPENING' then return end
    if not data then
        Menu.state = 'CLOSED'
        if notReady then
            return core:Notify('O sistema de gangs não subiu neste servidor. Avise a administração.', 'error')
        end
        return core:Notify('Sem acesso à gestão da gang.', 'error')
    end

    snapshot = data
    Menu.state = 'READY'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    send('gang:open', data)

    -- Morrer com a tela aberta deixaria o jogador olhando a gestão enquanto sangra no chão,
    -- com o teclado preso na página. A vigia nasce com a tela e morre com ela.
    CreateThread(function()
        while Menu.state ~= 'CLOSED' do
            Wait(500)
            if Menu.state == 'READY' and IsEntityDead(cache.ped) then Menu.forceClose() end
        end
    end)
end

-- ───────────────────────── callbacks da página (sempre respondem) ─────────────────────────

RegisterNUICallback('uiReady', function(_, cb)
    cb({})
    if Menu.state == 'READY' and snapshot then send('gang:open', snapshot) end
end)

RegisterNUICallback('closeMenu', function(_, cb)
    if Menu.state ~= 'READY' then return cb({ ok = false }) end
    beginClose()
    cb({ ok = true })
end)

RegisterNUICallback('closeComplete', function(_, cb)
    cb({})
    finalizeClose()
end)

RegisterNUICallback('refresh', function(_, cb)
    if Menu.state ~= 'READY' then return cb({ ok = false, code = 'not_open' }) end
    local data = fetch()
    if Menu.state ~= 'READY' then return cb({ ok = false, code = 'not_open' }) end
    if not data then
        -- Perdeu a gang com o menu aberto (desligado por outra pessoa, por exemplo). A tela
        -- não tem mais o que mostrar.
        Menu.forceClose()
        return cb({ ok = false, code = 'no_gang' })
    end
    snapshot = data
    cb({ ok = true, data = data })
end)

---Uma ação por vez: `BUSY` fecha a porta para o clique repetido enquanto o servidor
---responde, e o retorno já traz o snapshot novo para a lista não ficar mentindo.
RegisterNUICallback('memberAction', function(data, cb)
    if Menu.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end
    local citizenid = type(data) == 'table' and data.citizenid or nil
    local action = type(data) == 'table' and data.action or nil
    if type(citizenid) ~= 'string' or #citizenid == 0 or #citizenid > 64 then
        return cb({ ok = false, code = 'invalid_member' })
    end

    -- `level` só existe em `setGrade`: a tela manda o cargo escolhido em vez de uma
    -- direção. Normalizado aqui porque o `<select>` entrega texto, e o servidor recusa
    -- payload que não seja número.
    local level = type(data) == 'table' and tonumber(data.level) or nil
    if action == 'setGrade' and (not level or level < 0 or level % 1 ~= 0) then
        return cb({ ok = false, code = 'invalid_action' })
    end

    Menu.state = 'BUSY'
    local ok, code, rankLabel = lib.callback.await('noir_gangs:server:memberAction', false, citizenid, action, level)
    if Menu.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Menu.state = 'READY'

    local fresh = ok and fetch() or nil
    if fresh then snapshot = fresh end
    cb({ ok = ok == true, code = code, rankLabel = rankLabel, data = fresh })
end)

---As três do editor de cargos seguem o mesmo desenho da ação sobre membro: uma por vez, e
---o retorno já traz o snapshot novo — mudar o que um cargo pode muda a lista de membros na
---aba ao lado, e as duas não podem discordar na mesma tela.
local function rankAction(callback, cb, ...)
    if Menu.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end

    Menu.state = 'BUSY'
    local ok, code, extra = lib.callback.await(callback, false, ...)
    if Menu.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Menu.state = 'READY'

    local fresh = ok and fetch() or nil
    if fresh then snapshot = fresh end
    cb({ ok = ok == true, code = code, extra = extra, data = fresh })
end

RegisterNUICallback('createRank', function(data, cb)
    local label = type(data) == 'table' and data.label or nil
    if type(label) ~= 'string' then return cb({ ok = false, code = 'invalid_label' }) end
    rankAction('noir_gangs:server:createRank', cb, label)
end)

RegisterNUICallback('updateRank', function(data, cb)
    if type(data) ~= 'table' or type(data.level) ~= 'number' then
        return cb({ ok = false, code = 'rank_not_found' })
    end
    rankAction('noir_gangs:server:updateRank', cb, data.level,
        { label = data.label, permissions = data.permissions, bankAuth = data.bankAuth == true })
end)

RegisterNUICallback('deleteRank', function(data, cb)
    if type(data) ~= 'table' or type(data.level) ~= 'number' then
        return cb({ ok = false, code = 'rank_not_found' })
    end
    rankAction('noir_gangs:server:deleteRank', cb, data.level)
end)

---Convite dado, a tela sai de cena: quem convida quer ver a pessoa do lado, não uma janela.
---Por isso o aviso de sucesso sai pelo jogo, como no radial — uma mensagem dentro da tela
---que fecha em seguida ninguém leria.
---
---A recusa é o contrário: ela fica na tela, com o motivo, porque "já tem convite pendente"
---é coisa que se lê e se resolve ali mesmo.
RegisterNUICallback('invite', function(_, cb)
    if Menu.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end

    local closest = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.Invitation.maxDistance, false)
    if not closest then return cb({ ok = false, code = 'no_one_near' }) end

    Menu.state = 'BUSY'
    local ok, code, name = lib.callback.await('noir_gangs:server:invite', false, GetPlayerServerId(closest))
    if Menu.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Menu.state = 'READY'

    if ok then
        core:Notify(('Convite enviado para %s.'):format(name or 'a pessoa ao lado'), 'success')
        cb({ ok = true, name = name })
        return beginClose()
    end
    cb({ ok = false, code = code })
end)

RegisterNUICallback('leaveGang', function(_, cb)
    if Menu.state ~= 'READY' then return cb({ ok = false, code = 'busy' }) end

    Menu.state = 'BUSY'
    local ok, code, label = lib.callback.await('noir_gangs:server:leaveGang', false)
    if Menu.state ~= 'BUSY' then return cb({ ok = false, code = 'busy' }) end
    Menu.state = 'READY'

    if ok then
        core:Notify(('Você saiu de %s.'):format(label or 'sua gang'), 'inform')
        cb({ ok = true })
        return beginClose()
    end
    cb({ ok = false, code = code })
end)
