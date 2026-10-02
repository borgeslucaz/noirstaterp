---Runtime de uma execução de missão (instância). Fonte de verdade de tudo: passo atual,
---variáveis, participantes, carga, entidades. O cliente só recebe o retrato (view) e manda
---intenções, que os componentes validam.
---
---O runtime conhece só conceitos: passo, gatilho, ação, condição, variável. O que cada passo
---ou ação faz mora em server/components/, registrado no MissionComponents.
local Utils = require 'shared.utils.core'
local Conditions = require 'shared.utils.conditions'
local Template = require 'shared.utils.template'
local Definition = require 'shared.types.definition'
local Schema = require 'shared.types.schema'
local MissionComponents = require 'server.components.registry'

local Runtime = {}

---Bordas com o mundo. Os testes trocam estas funções; o resto do runtime não sabe se está
---num servidor de verdade.
Runtime.io = {
    now = function() return GetGameTimer() end,
    seconds = function() return os.time() end,
    setTimeout = function(ms, fn) SetTimeout(ms, fn) end,
    random = function(...) return math.random(...) end,
    send = function(source, event, ...) TriggerClientEvent(event, source, ...) end,
    emitLocal = function(event, ...) TriggerEvent(event, ...) end,
    log = function(level, message) lib.print[level](('[noir_missions] %s'):format(message)) end,
    onFinish = nil, ---@type fun(inst: table)?
}

---@type table<integer, table>
local instances = {}
---@type table<integer, integer> source -> instanceId
local byPlayer = {}
local nextId = 0

local MAX_EMIT_DEPTH = 8
local FINAL = { COMPLETED = true, FAILED = true, CANCELLED = true }

Runtime.instances = instances
Runtime.byPlayer = byPlayer

---@param id integer
---@return table?
function Runtime.get(id) return instances[id] end

---@param source integer
---@return table?
function Runtime.forPlayer(source)
    local id = byPlayer[source]
    return id and instances[id] or nil
end

---@param inst table
---@return boolean
function Runtime.isActive(inst)
    return inst ~= nil and inst.status == 'ACTIVE'
end

---@param inst table
---@param source integer
---@return boolean
function Runtime.isParticipant(inst, source)
    return inst ~= nil and inst.participants[source] ~= nil
end

---@return integer
function Runtime.count()
    return Utils.count(instances)
end

local function log(inst, level, message)
    Runtime.io.log(level, ('#%s %s: %s'):format(inst.id, inst.missionId, message))
end

Runtime.logEvents = false

---Trilha de decisões da execução, para descobrir por que algo não aconteceu.
---@param inst table
---@param message string
function Runtime.trace(inst, message)
    if Runtime.logEvents then log(inst, 'info', message) end
end

local function describe(payload)
    local parts = {}
    for key, value in pairs(payload) do
        if type(value) ~= 'table' then parts[#parts + 1] = ('%s=%s'):format(key, tostring(value)) end
    end
    table.sort(parts)
    return table.concat(parts, ' ')
end

-- Tempo ------------------------------------------------------------------------------------

---Agenda `fn` para daqui a `ms`, só se a instância ainda for a mesma execução ativa. O token
---troca quando a instância termina, então nada agendado roda depois do fim.
---@param inst table
---@param ms number
---@param fn function
function Runtime.schedule(inst, ms, fn)
    local token = inst.token
    Runtime.io.setTimeout(math.max(0, math.floor(ms)), function()
        if inst.token ~= token or inst.status ~= 'ACTIVE' then return end
        local ok, err = pcall(fn)
        if not ok then log(inst, 'error', ('agendado: %s'):format(err)) end
    end)
end

-- Variáveis --------------------------------------------------------------------------------

---@param inst table
---@param name string
---@return any
function Runtime.resolve(inst, name)
    if type(name) ~= 'string' then return nil end
    local value = inst.vars[name]
    if value ~= nil then return value end
    if name == 'participants' then return Utils.count(inst.participants) end
    if name == 'elapsed' then return math.floor((Runtime.io.now() - inst.startedMs) / 1000) end
    if name == 'step' then return inst.step and inst.step.id or nil end
    local parts = {}
    for part in name:gmatch('[^%.]+') do parts[#parts + 1] = part end
    if #parts > 1 then
        local found, computed = MissionComponents.resolve(inst, parts)
        if found then return computed end
    end
    return nil
end

---@param inst table
---@return fun(name: string): any
function Runtime.resolver(inst)
    return function(name) return Runtime.resolve(inst, name) end
end

---@param inst table
---@param text any
---@return string
function Runtime.render(inst, text)
    return Template.render(text, Runtime.resolver(inst))
end

---@param inst table
---@param condition table?
---@return boolean
function Runtime.check(inst, condition)
    return Conditions.evaluate(condition, Runtime.resolver(inst))
end

---@param inst table
---@param name string
---@param value any
---@param ctx? table
function Runtime.setVar(inst, name, value, ctx)
    if type(name) ~= 'string' or name == '' then return end
    local varDef = Utils.findById(inst.def.variables, name)
    value = Definition.castValue(value, varDef and varDef.type or nil)
    local old = inst.vars[name]
    inst.vars[name] = value
    if old ~= value then
        Runtime.markDirty(inst)
        Runtime.emit(inst, 'var_changed', { var = name, actor = ctx and ctx.actor })
    end
end

-- Participantes ----------------------------------------------------------------------------

---@param inst table
---@param source integer
---@param character { citizenId: string, name: string }
function Runtime.addParticipant(inst, source, character)
    if inst.participants[source] then return end
    inst.participants[source] = {
        citizenId = character.citizenId, name = character.name, joinedAt = Runtime.io.seconds(),
    }
    inst.order[#inst.order + 1] = source
    byPlayer[source] = inst.id
    if not inst.leader then inst.leader = source end
end

---@param inst table
---@return integer[]
function Runtime.participantList(inst)
    local list = {}
    for index = 1, #inst.order do
        if inst.participants[inst.order[index]] then list[#list + 1] = inst.order[index] end
    end
    return list
end

---@param inst table
---@param source integer
---@param reason string
function Runtime.removeParticipant(inst, source, reason)
    if not inst.participants[source] then return end
    local lastCoords = inst.positions[source]
    MissionComponents.each('participantLeft', inst, source, lastCoords)
    inst.participants[source] = nil
    inst.positions[source] = nil
    byPlayer[source] = nil
    if inst.leader == source then
        inst.leader = Runtime.participantList(inst)[1]
    end
    Runtime.io.send(source, 'noir_missions:client:ended', {
        instanceId = inst.id, status = 'LEFT', reason = reason, title = inst.def.name,
    })
    if not FINAL[inst.status] then
        if Utils.count(inst.participants) == 0 then
            Runtime.finish(inst, 'FAILED', 'abandoned')
            return
        end
        Runtime.emit(inst, 'participant_left', {})
        Runtime.markDirty(inst)
    end
end

-- Eventos e gatilhos -----------------------------------------------------------------------

---@param trigger table
---@param name string
---@param payload table
---@return boolean
local function triggerMatches(trigger, name, payload)
    if trigger.on ~= name then return false end
    if trigger.match == nil or trigger.match == '' then return true end
    local event = Schema.eventByValue[name]
    local key = event and event.match and event.match.key
    return key ~= nil and payload[key] == trigger.match
end

---Dispara um evento da missão: gatilhos da definição, o passo atual e os componentes.
---@param inst table
---@param name string
---@param payload? table
function Runtime.emit(inst, name, payload)
    if inst.status ~= 'ACTIVE' then return end
    payload = payload or {}
    inst.emitDepth = (inst.emitDepth or 0) + 1
    if inst.emitDepth > MAX_EMIT_DEPTH then
        inst.emitDepth = inst.emitDepth - 1
        log(inst, 'warn', ('evento %s descartado: gatilhos em cadeia demais'):format(name))
        return
    end

    Runtime.trace(inst, ('evento %s %s'):format(name, describe(payload)))
    local ctx = { actor = payload.actor, event = name }
    local triggers = inst.def.triggers
    for index = 1, #triggers do
        local trigger = triggers[index]
        if not (trigger.once and inst.fired[trigger.id]) and triggerMatches(trigger, name, payload)
            and Runtime.check(inst, trigger.condition) then
            local roll = trigger.chance or 100
            if roll >= 100 or Runtime.io.random(1, 100) <= roll then
                inst.fired[trigger.id] = (inst.fired[trigger.id] or 0) + 1
                local delay = Utils.randomBetween(trigger.delay or 0,
                    math.max(trigger.delay or 0, trigger.delayMax or 0), Runtime.io.random)
                Runtime.trace(inst, ('gatilho %s disparou (espera %ds)'):format(trigger.id, delay))
                if delay > 0 then
                    Runtime.schedule(inst, delay * 1000, function()
                        Runtime.runActions(inst, trigger.actions, ctx)
                    end)
                else
                    Runtime.runActions(inst, trigger.actions, ctx)
                end
            else
                Runtime.trace(inst, ('gatilho %s: chance de %d%% não saiu'):format(trigger.id, roll))
                -- Chance que não saiu conta como disparo: "60% de perseguição" é decidido uma vez.
                if trigger.once then inst.fired[trigger.id] = 0 end
            end
        end
        if inst.status ~= 'ACTIVE' then break end
    end

    if inst.status == 'ACTIVE' then
        MissionComponents.each('event', inst, name, payload)
        local step = inst.step
        local handler = step and MissionComponents.step(step.type)
        if handler and handler.event then
            local ok, err = pcall(handler.event, inst, step, inst.stepState, name, payload)
            if not ok then log(inst, 'error', ('passo %s evento %s: %s'):format(step.id, name, err)) end
        end
    end

    inst.emitDepth = inst.emitDepth - 1
    Runtime.io.emitLocal('noir_missions:event', inst.id, inst.missionId, name, payload)
end

-- Ações ------------------------------------------------------------------------------------

---Executa uma lista de ações em ordem. `wait` corta a lista ali e agenda o resto, então tudo
---antes do primeiro `wait` roda na hora — é isso que garante que "sortear entrega" no fim de
---um passo já valeu quando o passo seguinte começa.
---@param inst table
---@param list table[]?
---@param ctx? table
---@param from? integer
function Runtime.runActions(inst, list, ctx, from)
    if type(list) ~= 'table' or #list == 0 then return end
    ctx = ctx or {}
    local token = inst.token
    for index = from or 1, #list do
        if inst.status ~= 'ACTIVE' or inst.token ~= token then return end
        local action = list[index]
        if action.type == 'wait' then
            local min = action.seconds or 0
            local seconds = Utils.randomBetween(min, math.max(min, action.secondsMax or 0), Runtime.io.random)
            Runtime.schedule(inst, seconds * 1000, function()
                Runtime.runActions(inst, list, ctx, index + 1)
            end)
            return
        end
        local fn = MissionComponents.action(action.type)
        if fn then
            local ok, err = pcall(fn, inst, action, ctx)
            if not ok then log(inst, 'error', ('ação %s: %s'):format(action.type, err)) end
        else
            log(inst, 'warn', ('ação sem handler: %s'):format(tostring(action.type)))
        end
    end
end

-- Passos -----------------------------------------------------------------------------------

local activateFrom

---@param inst table
---@param step table
local function stopStep(inst, step)
    local handler = MissionComponents.step(step.type)
    if handler and handler.stop then
        local ok, err = pcall(handler.stop, inst, step, inst.stepState)
        if not ok then log(inst, 'error', ('passo %s stop: %s'):format(step.id, err)) end
    end
end

---@param inst table
---@param index integer
activateFrom = function(inst, index)
    local steps = inst.def.steps
    while index <= #steps do
        if inst.status ~= 'ACTIVE' then return end
        local step = steps[index]
        if step.enabled ~= false and Runtime.check(inst, step.condition) then
            local handler = MissionComponents.step(step.type)
            if not handler then
                log(inst, 'error', ('passo %s sem handler (%s), pulado'):format(step.id, step.type))
            else
                inst.stepIndex = index
                inst.step = step
                inst.stepState = {}
                inst.stepStartedMs = Runtime.io.now()
                Runtime.runActions(inst, step.onStart, { step = step.id })
                -- Uma ação de "Ao começar" pode ter terminado a missão ou pulado de passo.
                if inst.status ~= 'ACTIVE' or inst.step ~= step then return end
                Runtime.trace(inst, ('passo %s (%s) começou'):format(step.id, step.type))
                Runtime.emit(inst, 'step_started', { step = step.id })
                if inst.status ~= 'ACTIVE' or inst.step ~= step then return end
                if handler.start then
                    local ok, err = pcall(handler.start, inst, step, inst.stepState)
                    if not ok then log(inst, 'error', ('passo %s start: %s'):format(step.id, err)) end
                end
                Runtime.markDirty(inst)
                return
            end
        end
        index = index + 1
    end
    inst.step = nil
    Runtime.finish(inst, 'COMPLETED', 'all_steps')
end

---Conclui o passo, se ainda for o atual. Chamado pelo handler do passo.
---@param inst table
---@param step table
---@param ctx? table
function Runtime.completeStep(inst, step, ctx)
    if inst.status ~= 'ACTIVE' or inst.step ~= step then return end
    -- Checklist da HUD: o texto do objetivo como estava ao cumprir (com a contagem final).
    -- Passo só de ações não tem objetivo para o jogador e não entra.
    if step.type ~= 'actions' then
        local objective = Runtime.objective(inst)
        local text = objective.text or step.label
        if objective.progress and objective.progress.max then
            text = ('%s (%d/%d)'):format(text, objective.progress.max, objective.progress.max)
        end
        inst.completed[#inst.completed + 1] = { id = step.id, text = text }
    end
    stopStep(inst, step)
    inst.step = nil
    inst.completing = true
    Runtime.emit(inst, 'step_completed', { step = step.id, actor = ctx and ctx.actor })
    Runtime.runActions(inst, step.onComplete, { step = step.id, actor = ctx and ctx.actor })
    inst.completing = false
    if inst.status ~= 'ACTIVE' then return end
    local jump = inst.jumpTo
    inst.jumpTo = nil
    if inst.step then return end -- uma ação já ativou outro passo
    activateFrom(inst, jump or (inst.stepIndex + 1))
end

---Salta para um passo. Dentro de "Ao concluir", só registra o salto: quem ativa o próximo é
---o `completeStep`, depois de terminar as ações.
---@param inst table
---@param stepId string
function Runtime.gotoStep(inst, stepId)
    local _, index = Utils.findById(inst.def.steps, stepId)
    if not index then return end
    if inst.completing then
        inst.jumpTo = index
        return
    end
    if inst.step then
        stopStep(inst, inst.step)
        inst.step = nil
    end
    activateFrom(inst, index)
end

-- Ciclo de vida ----------------------------------------------------------------------------

---@param def table definição já normalizada (cópia própria desta execução)
---@param opts { test?: boolean, sandbox?: boolean, origin?: string }
---@return table inst
function Runtime.create(def, opts)
    nextId = nextId + 1
    local inst = {
        id = nextId + 10000,
        missionId = def.id,
        def = def,
        test = opts.test == true,
        sandbox = opts.sandbox == true,
        origin = opts.origin or 'export',
        status = 'STARTING',
        participants = {},
        order = {},
        positions = {},
        vars = {},
        fired = {},
        timers = {},
        blips = {},
        completed = {},
        infos = {},
        stepIndex = 0,
        step = nil,
        stepState = {},
        startedAt = Runtime.io.seconds(),
        startedMs = Runtime.io.now(),
        token = {},
    }

    for index = 1, #def.variables do
        local variable = def.variables[index]
        local value
        if type(variable.random) == 'table' and #variable.random > 0 then
            value = Utils.pick(variable.random, Runtime.io.random)
        else
            value = variable.default
        end
        inst.vars[variable.id] = Definition.castValue(value, variable.type)
    end

    MissionComponents.each('init', inst)
    instances[inst.id] = inst
    return inst
end

---Começa a execução. `fromStep` (teste) pula para um passo, rodando antes as ações dos
---anteriores sem mensagens, para o mundo chegar no estado em que o passo espera.
---@param inst table
---@param fromStep? string
function Runtime.start(inst, fromStep)
    inst.status = 'ACTIVE'
    MissionComponents.each('start', inst)
    Runtime.emit(inst, 'mission_started', {})
    if inst.status ~= 'ACTIVE' then return end
    if inst.sandbox then
        Runtime.markDirty(inst)
        return
    end

    local startIndex = 1
    if fromStep then
        local _, index = Utils.findById(inst.def.steps, fromStep)
        if index then
            for skipped = 1, index - 1 do
                local step = inst.def.steps[skipped]
                if step.enabled ~= false then
                    Runtime.runActions(inst, step.onStart, { step = step.id, silent = true })
                    Runtime.runActions(inst, step.onComplete, { step = step.id, silent = true })
                end
            end
            startIndex = index
        end
    end
    activateFrom(inst, startIndex)
end

---@param inst table
---@param status 'COMPLETED'|'FAILED'|'CANCELLED'
---@param reason? string
function Runtime.finish(inst, status, reason)
    if FINAL[inst.status] then return end
    local wasActive = inst.status == 'ACTIVE'
    inst.status = status
    inst.reason = reason
    inst.token = {}
    if inst.step then
        stopStep(inst, inst.step)
        inst.step = nil
    end

    if Runtime.io.onFinish then
        local ok, err = pcall(Runtime.io.onFinish, inst)
        if not ok then log(inst, 'error', ('onFinish: %s'):format(err)) end
    end

    MissionComponents.each('cleanup', inst)

    local payload = { instanceId = inst.id, status = status, reason = reason, title = inst.def.name }
    for source in pairs(inst.participants) do
        Runtime.io.send(source, 'noir_missions:client:ended', payload)
        byPlayer[source] = nil
    end
    instances[inst.id] = nil

    if wasActive then
        local event = status == 'COMPLETED' and 'noir_missions:missionCompleted' or 'noir_missions:missionFailed'
        Runtime.io.emitLocal(event, inst.id, inst.missionId, Runtime.participantList(inst), reason)
    end
    log(inst, 'info', ('terminou: %s (%s)'):format(status, tostring(reason)))
end

-- Retrato para os clientes -----------------------------------------------------------------

---@param inst table
---@return table
function Runtime.objective(inst)
    local step = inst.step
    if not step then return { visible = false } end
    local handler = MissionComponents.step(step.type)
    local text = Runtime.render(inst, (step.objective and step.objective ~= '') and step.objective or step.label)
    local objective = {
        visible = true, title = inst.def.name, text = text,
        completed = inst.completed, infos = inst.infos,
    }
    if handler and handler.objective then
        local ok, extra = pcall(handler.objective, inst, step, inst.stepState)
        if ok and type(extra) == 'table' then
            for key, value in pairs(extra) do objective[key] = value end
        end
    end
    for id, timer in pairs(inst.timers) do
        if timer.show then
            local seconds = math.max(0, math.ceil((timer.endsAt - Runtime.io.now()) / 1000))
            objective.timer = { label = id, seconds = seconds }
        end
    end
    return objective
end

---@param inst table
---@return table
function Runtime.view(inst)
    local view = {
        instanceId = inst.id,
        missionId = inst.missionId,
        title = inst.def.name,
        test = inst.test,
        objective = Runtime.objective(inst),
        blips = {},
        interactions = {},
        cargo = {},
        vehicles = {},
        areas = {},
        deliveries = {},
    }
    for id, blip in pairs(inst.blips) do
        view.blips[#view.blips + 1] = {
            id = id, coords = blip.coords, sprite = blip.sprite, color = blip.color,
            label = blip.label, route = blip.route, radius = blip.radius,
        }
    end
    MissionComponents.each('view', inst, view)
    local step = inst.step
    local handler = step and MissionComponents.step(step.type)
    if handler and handler.view then
        local ok, err = pcall(handler.view, inst, step, inst.stepState, view)
        if not ok then log(inst, 'error', ('passo %s view: %s'):format(step.id, err)) end
    end
    return view
end

---Junta mudanças e manda um retrato só, em vez de um por alteração.
---@param inst table
function Runtime.markDirty(inst)
    if inst.flushPending then return end
    inst.flushPending = true
    Runtime.io.setTimeout(150, function()
        inst.flushPending = false
        if inst.status ~= 'ACTIVE' then return end
        Runtime.flush(inst)
    end)
end

---@param inst table
function Runtime.flush(inst)
    local view = Runtime.view(inst)
    for source in pairs(inst.participants) do
        Runtime.io.send(source, 'noir_missions:client:sync', view)
    end
end

---Mensagem para todos os participantes.
---@param inst table
---@param event string
function Runtime.broadcast(inst, event, ...)
    for source in pairs(inst.participants) do
        Runtime.io.send(source, event, ...)
    end
end

---@param inst table
---@return table
function Runtime.debug(inst)
    local out = {
        instanceId = inst.id, missionId = inst.missionId, status = inst.status, test = inst.test,
        step = inst.step and inst.step.id or nil, stepIndex = inst.stepIndex,
        vars = inst.vars, fired = inst.fired, participants = {},
        elapsed = math.floor((Runtime.io.now() - inst.startedMs) / 1000),
    }
    for source, info in pairs(inst.participants) do
        out.participants[#out.participants + 1] = ('%s (%d)'):format(info.name, source)
    end
    MissionComponents.each('debug', inst, out)
    return out
end

---@return table[]
function Runtime.summaries()
    local list = {}
    for _, inst in pairs(instances) do
        list[#list + 1] = {
            instanceId = inst.id, missionId = inst.missionId, name = inst.def.name,
            step = inst.step and inst.step.label or (inst.sandbox and 'sandbox' or '-'),
            participants = Utils.count(inst.participants), test = inst.test, startedAt = inst.startedAt,
        }
    end
    table.sort(list, function(a, b) return a.instanceId < b.instanceId end)
    return list
end

return Runtime
