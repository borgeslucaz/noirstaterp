---Registro de componentes de missão.
---
---    MissionComponents.register('cargo', {
---        steps = { cargo = { start = fn, tick = fn, event = fn, objective = fn, view = fn } },
---        actions = { reveal_cargo = fn(inst, action, ctx) },
---        init = fn(inst),            -- estado inicial na instância
---        start = fn(inst),           -- missão começou (spawn do que nasce no início)
---        tick = fn(inst),            -- uma vez por volta do monitor
---        event = fn(inst, name, payload),
---        view = fn(inst, view),      -- contribui com o snapshot enviado aos participantes
---        resolve = fn(inst, parts) -> found, value   -- valores calculados (cargo.x.loaded)
---        participantLeft = fn(inst, source, lastCoords),
---        cleanup = fn(inst),
---        debug = fn(inst, out),
---    })
---
---O runtime não conhece nenhum componente pelo nome: ele chama os ganchos registrados. É o
---que deixa adicionar um tipo de passo ou ação sem mexer no núcleo.
local MissionComponents = {
    steps = {},
    actions = {},
    names = {},
}

local HOOKS = { 'init', 'start', 'tick', 'event', 'view', 'resolve', 'participantLeft', 'cleanup', 'debug' }
local hooks = {}
for index = 1, #HOOKS do hooks[HOOKS[index]] = {} end

---@param name string
---@param component table
function MissionComponents.register(name, component)
    MissionComponents.names[#MissionComponents.names + 1] = name
    for stepType, handler in pairs(component.steps or {}) do
        if MissionComponents.steps[stepType] then
            error(('[noir_missions] passo %s registrado duas vezes'):format(stepType))
        end
        handler.component = name
        MissionComponents.steps[stepType] = handler
    end
    for actionType, fn in pairs(component.actions or {}) do
        if MissionComponents.actions[actionType] then
            error(('[noir_missions] ação %s registrada duas vezes'):format(actionType))
        end
        MissionComponents.actions[actionType] = fn
    end
    for index = 1, #HOOKS do
        local hook = HOOKS[index]
        if component[hook] then
            hooks[hook][#hooks[hook] + 1] = { name = name, fn = component[hook] }
        end
    end
end

---Chama o gancho em todo componente que o registrou. Erro de um não impede os outros.
---@param hook string
function MissionComponents.each(hook, ...)
    local list = hooks[hook]
    for index = 1, #list do
        local ok, err = pcall(list[index].fn, ...)
        if not ok then
            lib.print.error(('[noir_missions] %s.%s: %s'):format(list[index].name, hook, err))
        end
    end
end

---@param inst table
---@param parts string[]
---@return boolean found
---@return any value
function MissionComponents.resolve(inst, parts)
    local list = hooks.resolve
    for index = 1, #list do
        local ok, found, value = pcall(list[index].fn, inst, parts)
        if ok and found then return true, value end
    end
    return false, nil
end

---@param stepType string
---@return table?
function MissionComponents.step(stepType)
    return MissionComponents.steps[stepType]
end

---@param actionType string
---@return function?
function MissionComponents.action(actionType)
    return MissionComponents.actions[actionType]
end

return MissionComponents
