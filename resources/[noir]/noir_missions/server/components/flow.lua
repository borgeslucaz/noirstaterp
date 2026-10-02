---Fluxo e comunicação: variáveis, timers, ramificação (se/chance/ir para passo), fim de
---missão, SMS, aviso, informação, blips, som, dispatch e itens.
---Passos: esperar, esperar condição, só ações.
local Utils = require 'shared.utils.core'
local MissionComponents = require 'server.components.registry'
local Runtime = require 'server.instances.runtime'
local World = require 'server.instances.world'
local Integrations = require 'server.integrations'

local function actorList(inst, ctx, who)
    if who == 'actor' and ctx and ctx.actor and inst.participants[ctx.actor] then return { ctx.actor } end
    return Runtime.participantList(inst)
end

local function renderLines(inst, lines)
    local out = {}
    for index = 1, #(lines or {}) do
        out[#out + 1] = {
            label = Runtime.render(inst, lines[index].label),
            value = Runtime.render(inst, lines[index].value),
        }
    end
    return out
end

---@param inst table
---@param action table
---@return table? coords
local function actionCoords(inst, action)
    if action.source == 'var' then
        local place = inst.places and inst.places[action.var]
        return place and place.coords or nil
    end
    return action.coords
end

local Flow = {}

---Roda agora, ou depois de `delaySeconds` sem segurar a lista de ações. Missão que acabou na
---espera não manda nada (Runtime.schedule confere).
---@param inst table
---@param action table
---@param fn function
local function later(inst, action, fn)
    local delay = tonumber(action.delaySeconds) or 0
    if delay <= 0 then return fn() end
    Runtime.schedule(inst, delay * 1000, fn)
end

---Informação revelada (manifesto) para todos os participantes.
---@param inst table
---@param title string
---@param lines table[]
function Flow.showInfo(inst, title, lines)
    local info = { title = Runtime.render(inst, title), lines = renderLines(inst, lines) }
    -- Fica fixa no checklist da HUD até o fim da missão; o aviso avulso é para quem está com
    -- o checklist recolhido.
    inst.infos[#inst.infos + 1] = info
    Runtime.broadcast(inst, 'noir_missions:client:info', info)
    Runtime.markDirty(inst)
end

MissionComponents.register('flow', {
    actions = {
        set_var = function(inst, action, ctx)
            Runtime.setVar(inst, action.var, action.value, ctx)
        end,
        add_var = function(inst, action, ctx)
            local current = tonumber(Runtime.resolve(inst, action.var)) or 0
            Runtime.setVar(inst, action.var, current + (tonumber(action.amount) or 1), ctx)
        end,
        random_var = function(inst, action, ctx)
            local value = Utils.pick(action.values, Runtime.io.random)
            if value ~= nil then Runtime.setVar(inst, action.var, value, ctx) end
        end,
        ['if'] = function(inst, action, ctx)
            if Runtime.check(inst, action.condition) then
                Runtime.runActions(inst, action['then'], ctx)
            else
                Runtime.runActions(inst, action['else'], ctx)
            end
        end,
        chance = function(inst, action, ctx)
            local percent = action.percent or 50
            if percent >= 100 or (percent > 0 and Runtime.io.random(1, 100) <= percent) then
                Runtime.trace(inst, ('chance de %d%%: saiu'):format(percent))
                Runtime.runActions(inst, action['then'], ctx)
            else
                Runtime.trace(inst, ('chance de %d%%: não saiu'):format(percent))
                Runtime.runActions(inst, action['else'], ctx)
            end
        end,
        goto_step = function(inst, action)
            Runtime.gotoStep(inst, action.step)
        end,
        complete_mission = function(inst)
            Runtime.finish(inst, 'COMPLETED', 'action')
        end,
        fail_mission = function(inst, action)
            Runtime.finish(inst, 'FAILED', Runtime.render(inst, action.reason or 'action'))
        end,
        start_timer = function(inst, action)
            local timer = { token = {}, endsAt = Runtime.io.now() + (action.seconds or 30) * 1000, show = action.show }
            inst.timers[action.timer] = timer
            Runtime.markDirty(inst)
            Runtime.schedule(inst, (action.seconds or 30) * 1000, function()
                if inst.timers[action.timer] ~= timer then return end
                inst.timers[action.timer] = nil
                Runtime.markDirty(inst)
                Runtime.emit(inst, 'timer', { timer = action.timer })
            end)
        end,
        cancel_timer = function(inst, action)
            if inst.timers[action.timer] then
                inst.timers[action.timer] = nil
                Runtime.markDirty(inst)
            end
        end,

        send_sms = function(inst, action, ctx)
            if ctx.silent then return end
            later(inst, action, function()
                -- Texto montado na hora do envio: variável que mudou na espera já sai certa.
                local text = Runtime.render(inst, action.text)
                for _, source in ipairs(Runtime.participantList(inst)) do
                    Integrations.sendSms(source, text)
                end
            end)
        end,
        notify = function(inst, action, ctx)
            if ctx.silent then return end
            later(inst, action, function()
                local text = Runtime.render(inst, action.text)
                for _, source in ipairs(Runtime.participantList(inst)) do
                    Integrations.notify(source, text, action.kind)
                end
            end)
        end,
        show_info = function(inst, action, ctx)
            if ctx.silent then return end
            Flow.showInfo(inst, action.title, action.lines)
        end,
        play_sound = function(inst, action, ctx)
            if ctx.silent then return end
            Runtime.broadcast(inst, 'noir_missions:client:sound', action.name, action.set)
        end,
        create_blip = function(inst, action)
            local coords = actionCoords(inst, action)
            if not coords then return end
            inst.blips[action.blip] = {
                coords = coords, sprite = action.sprite or 1, color = action.color or 5,
                label = Runtime.render(inst, action.label or 'Local'), route = action.route == true,
            }
            Runtime.markDirty(inst)
        end,
        remove_blip = function(inst, action)
            if inst.blips[action.blip] then
                inst.blips[action.blip] = nil
                Runtime.markDirty(inst)
            end
        end,
        dispatch = function(inst, action, ctx)
            if ctx.silent or not action.coords then return end
            Integrations.dispatch({
                code = action.code or '10-90',
                title = Runtime.render(inst, action.title or 'Atividade suspeita'),
                message = Runtime.render(inst, action.message or ''),
                coords = { x = action.coords.x, y = action.coords.y, z = action.coords.z },
                jobs = { 'police' },
            })
        end,

        give_item = function(inst, action, ctx)
            for _, source in ipairs(actorList(inst, ctx, action.to)) do
                local ok, code = Integrations.addItem(source, action.item, action.amount or 1)
                if not ok then
                    Runtime.io.log('warn', ('give_item %s para %s falhou: %s'):format(action.item, source, code))
                end
            end
        end,
        take_item = function(inst, action, ctx)
            for _, source in ipairs(actorList(inst, ctx, action.from)) do
                Integrations.removeItem(source, action.item, action.amount or 1)
            end
        end,
    },

    steps = {
        wait = {
            start = function(inst, step, state)
                local min = step.seconds or 0
                local seconds = Utils.randomBetween(min, math.max(min, step.secondsMax or 0), Runtime.io.random)
                state.endsAt = Runtime.io.now() + seconds * 1000
                Runtime.schedule(inst, seconds * 1000, function()
                    Runtime.completeStep(inst, step)
                end)
            end,
            objective = function(inst, _, state)
                local seconds = math.max(0, math.ceil((state.endsAt - Runtime.io.now()) / 1000))
                return { timer = { label = 'wait', seconds = seconds } }
            end,
        },
        condition = {
            start = function(inst, step)
                if Runtime.check(inst, step['until']) then Runtime.completeStep(inst, step) end
            end,
            tick = function(inst, step)
                if Runtime.check(inst, step['until']) then Runtime.completeStep(inst, step) end
            end,
            event = function(inst, step, _, name)
                if name ~= 'step_started' and Runtime.check(inst, step['until']) then
                    Runtime.completeStep(inst, step)
                end
            end,
        },
        actions = {
            start = function(inst, step)
                Runtime.completeStep(inst, step)
            end,
        },
    },

    cleanup = function(inst)
        World.cleanupInstance(inst)
    end,
})

return Flow
