---Fluxo das ações do lado do client: begin -> (escolha do lugar) -> animação -> finish.
---Qualquer desistência no meio avisa o servidor para soltar a ação. A duração da barra
---vem do servidor, que é quem vai conferir o tempo.

local Shared = require 'config.shared'
local Integrations = require 'client.integrations'

local Actions = {}

local busy = false

---@return boolean
function Actions.isBusy()
    return busy
end

---@param code? string
function Actions.fail(code)
    Integrations.notify(locale('error_' .. tostring(code or 'operation_failed')), 'error')
end

---@param action string
---@param duration integer
---@param animation? string chave em `Shared.animations`, quando não é o nome da ação
---@return boolean
local function playProgress(action, duration, animation)
    if duration <= 0 then return true end
    local anim = Shared.animations[animation or action]
    return lib.progressBar({
        duration = duration,
        label = locale('progress_' .. action),
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = anim and { dict = anim.dict, clip = anim.clip, flag = anim.flag } or nil,
        prop = Shared.props[action],
    })
end

---Primeira metade, para quem controla o meio (o minigame da mesa). Liga `busy`; o
---chamador termina com `finish` ou `cancel`.
---@param action string
---@param payload table
---@return table? began `{ ok, duration }`
function Actions.begin(action, payload)
    if busy then return nil end
    busy = true
    local began = lib.callback.await('noir_weed:server:begin', false, action, payload)
    if not began or not began.ok then
        busy = false
        Actions.fail(began and began.code)
        return nil
    end
    return began
end

---@param action string
---@param extra? table
---@return table? response
function Actions.finish(action, extra)
    local response = lib.callback.await('noir_weed:server:finish', false, action, extra)
    busy = false
    if not response or not response.ok then
        Actions.fail(response and response.code)
        return nil
    end
    return response
end

function Actions.cancel()
    if not busy then return end
    TriggerServerEvent('noir_weed:server:cancel')
    busy = false
end

---Fluxo inteiro com barra de progresso.
---@param action string
---@param payload table
---@param options? { choose?: fun(): table?, animation?: string }
---@return table? response
function Actions.perform(action, payload, options)
    options = options or {}
    local began = Actions.begin(action, payload)
    if not began then return nil end

    local extra
    if options.choose then
        extra = options.choose()
        if not extra then
            Actions.cancel()
            return nil
        end
    end

    if not playProgress(action, began.duration or 0, options.animation) then
        Actions.cancel()
        return nil
    end

    return Actions.finish(action, extra)
end

return Actions
