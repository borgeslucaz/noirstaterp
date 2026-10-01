---Normalização e validação da definição de missão, guiadas pelo esquema.
---
---Uma passada só faz as duas coisas: aplica default em campo ausente, converte o tipo do que
---veio do JSON (número digitado como texto, booleano como "true") e junta os erros com o
---caminho de cada um (`steps[3].interaction`). Rascunho com erro pode ser salvo; publicar e
---testar exigem lista de erros vazia.
---
---O caminhamento é genérico: componente novo no esquema já sai validado aqui.
local Utils = require 'shared.utils.core'
local Schema = require 'shared.types.schema'
local Conditions = require 'shared.utils.conditions'

local Definition = {}

Definition.SCHEMA_VERSION = 1
Definition.LIMITS = {
    collectionItems = 64,
    steps = 64,
    triggers = 64,
    actionsPerList = 32,
    actionDepth = 4,
    conditionRules = 12,
    strings = 32,
    stringLength = 300,
    textLength = 120,
    textareaLength = 600,
}

local validOps = {}
for index = 1, #Conditions.ops do validOps[Conditions.ops[index].value] = true end

---@class DefinitionContext
---@field errors { path: string, message: string }[]
---@field ids table<string, table<string, boolean>>
---@field refs { path: string, collection: string, id: string }[]

local normalizeFields, normalizeActions

local function addError(ctx, path, message)
    if #ctx.errors < 200 then ctx.errors[#ctx.errors + 1] = { path = path, message = message } end
end

local function joinPath(base, key)
    if base == '' then return tostring(key) end
    if type(key) == 'number' then return ('%s[%d]'):format(base, key) end
    return base .. '.' .. key
end

---@param spec table campo do esquema
---@param object table objeto que contém o campo
---@param hidden? table<string, boolean> campos já escondidos
---@return boolean
local function isVisible(spec, object, hidden)
    local rule = spec.showIf
    if not rule then return true end
    -- Controle escondido esconde os dependentes dele também.
    if hidden and hidden[rule.key] then return false end
    local value = object[rule.key]
    for index = 1, #rule.is do
        if value == rule.is[index] then return true end
    end
    return false
end

local function cleanPosition(value)
    if not Utils.isPosition(value) then return nil end
    local function round(number) return math.floor(number * 1000 + 0.5) / 1000 end
    return {
        x = round(value.x), y = round(value.y), z = round(value.z),
        w = value.w and round(value.w % 360) or nil,
    }
end

local function cleanModel(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('%s', '')
    if value == '' or #value > 64 or not value:match('^[%w_]+$') then return nil end
    return value:lower()
end

local function toBoolean(value)
    if value == true or value == 1 or value == 'true' or value == '1' then return true end
    return false
end

---Valor de variável vindo de texto: "true" vira booleano, "12" vira número.
---@param value any
---@param varType string?
---@return any
function Definition.castValue(value, varType)
    if varType == 'boolean' then return toBoolean(value) end
    if varType == 'number' then return tonumber(value) or 0 end
    if varType == 'string' then
        if value == nil then return '' end
        return Utils.cleanString(value, Definition.LIMITS.stringLength)
    end
    if type(value) == 'string' then
        if value == 'true' then return true end
        if value == 'false' then return false end
        local number = tonumber(value)
        if number then return number end
    end
    return value
end

local function normalizeCondition(value, path, ctx)
    if type(value) ~= 'table' or type(value.rules) ~= 'table' then return nil end
    local rules = {}
    for index = 1, math.min(#value.rules, Definition.LIMITS.conditionRules) do
        local rule = value.rules[index]
        local rulePath = joinPath(joinPath(path, 'rules'), index)
        if type(rule) == 'table' then
            local var = Utils.cleanString(rule.var, 64)
            local op = validOps[rule.op] and rule.op or 'eq'
            if var == '' then
                addError(ctx, rulePath, 'regra sem variável')
            end
            local cleanValue = rule.value
            if type(cleanValue) == 'string' then cleanValue = Utils.cleanString(cleanValue, 120) end
            if type(cleanValue) == 'table' then cleanValue = nil end
            rules[#rules + 1] = { var = var, op = op, value = cleanValue }
        end
    end
    if #rules == 0 then return nil end
    return { mode = value.mode == 'any' and 'any' or 'all', rules = rules }
end

---@param spec table
---@param value any
---@param path string
---@param ctx DefinitionContext
---@param depth integer
---@return any
local function normalizeValue(spec, value, path, ctx, depth)
    local kind = spec.type

    if kind == 'text' or kind == 'textarea' or kind == 'var' or kind == 'eventMatch' then
        local limit = spec.maxLength or (kind == 'textarea' and Definition.LIMITS.textareaLength or Definition.LIMITS.textLength)
        if value == nil then value = spec.default end
        if value == nil then return nil end
        local text = Utils.cleanString(value, limit)
        if text == '' then return nil end
        return text
    end

    if kind == 'number' then
        if value == nil or value == '' then value = spec.default end
        if value == nil then return nil end
        local number = tonumber(value)
        if not Utils.isFiniteNumber(number) then
            addError(ctx, path, 'número inválido')
            return spec.default
        end
        if spec.min and number < spec.min then number = spec.min end
        if spec.max and number > spec.max then number = spec.max end
        return number
    end

    if kind == 'bool' then
        if value == nil then return spec.default == true end
        return toBoolean(value)
    end

    if kind == 'select' then
        if value == nil then value = spec.default end
        for index = 1, #spec.options do
            local option = spec.options[index].value
            if option == value or tostring(option) == tostring(value) then return option end
        end
        if value ~= nil then addError(ctx, path, ('opção inválida: %s'):format(tostring(value))) end
        return spec.default
    end

    if kind == 'position' then
        if value == nil then return nil end
        local position = cleanPosition(value)
        if not position then addError(ctx, path, 'posição inválida') end
        return position
    end

    if kind == 'positions' then
        if type(value) ~= 'table' then return {} end
        local list = {}
        for index = 1, math.min(#value, spec.max or 50) do
            local position = cleanPosition(value[index])
            if position then
                list[#list + 1] = position
            else
                addError(ctx, joinPath(path, index), 'posição inválida')
            end
        end
        return list
    end

    if kind == 'model' then
        if value == nil or value == '' then value = spec.default end
        if value == nil or value == '' then return nil end
        local model = cleanModel(value)
        if not model then addError(ctx, path, 'modelo inválido') end
        return model
    end

    if kind == 'weapon' then
        if value == nil then value = spec.default end
        if value == nil or value == '' then return nil end
        if type(value) ~= 'string' or not value:upper():match('^WEAPON_[%w_]+$') then
            addError(ctx, path, 'arma inválida (use WEAPON_*)')
            return nil
        end
        return value:upper()
    end

    if kind == 'item' then
        if value == nil or value == '' then return nil end
        if type(value) ~= 'string' or not value:match('^[%w_]+$') or #value > 64 then
            addError(ctx, path, 'item inválido')
            return nil
        end
        return value
    end

    if kind == 'minigame' then
        if value == nil or value == '' or value == 'none' then return nil end
        if type(value) ~= 'string' or #value > 64 or not value:match('^[%w_:%-%.]+$') then
            addError(ctx, path, 'minigame inválido')
            return nil
        end
        return value
    end

    if kind == 'ref' then
        if value == nil or value == '' then return nil end
        if type(value) ~= 'string' then
            addError(ctx, path, 'referência inválida')
            return nil
        end
        ctx.refs[#ctx.refs + 1] = { path = path, collection = spec.ref, id = value }
        return value
    end

    if kind == 'refs' then
        if type(value) ~= 'table' then return {} end
        local list = {}
        for index = 1, math.min(#value, 32) do
            if type(value[index]) == 'string' and value[index] ~= '' then
                list[#list + 1] = value[index]
                ctx.refs[#ctx.refs + 1] = { path = joinPath(path, index), collection = spec.ref, id = value[index] }
            end
        end
        return list
    end

    if kind == 'strings' then
        if type(value) ~= 'table' then return {} end
        local list = {}
        for index = 1, math.min(#value, Definition.LIMITS.strings) do
            local text = Utils.cleanString(value[index], Definition.LIMITS.stringLength)
            if text ~= '' then list[#list + 1] = text end
        end
        return list
    end

    if kind == 'condition' then
        return normalizeCondition(value, path, ctx)
    end

    if kind == 'actions' then
        return normalizeActions(value, path, ctx, depth + 1)
    end

    if kind == 'list' then
        if type(value) ~= 'table' then value = {} end
        local list = {}
        local max = spec.max or Definition.LIMITS.collectionItems
        for index = 1, math.min(#value, max) do
            if type(value[index]) == 'table' then
                list[#list + 1] = normalizeFields(spec.fields, value[index], joinPath(path, index), ctx, depth)
            end
        end
        if spec.min and #list < spec.min then
            addError(ctx, path, ('precisa de pelo menos %d'):format(spec.min))
        end
        return list
    end

    return nil
end

---@param fields table[]
---@param object table
---@param path string
---@param ctx DefinitionContext
---@param depth integer
---@return table
normalizeFields = function(fields, object, path, ctx, depth)
    local out = {}
    -- Visibilidade depende de irmãos já normalizados (um select com default), então os
    -- campos de controle saem primeiro e os dependentes depois.
    for index = 1, #fields do
        local spec = fields[index]
        if not spec.showIf then
            out[spec.key] = normalizeValue(spec, object[spec.key], joinPath(path, spec.key), ctx, depth)
        end
    end
    -- Campos dependentes vêm declarados depois do campo de que dependem, então uma passada
    -- em ordem já enxerga o valor final do controle.
    local hidden = {}
    for index = 1, #fields do
        local spec = fields[index]
        if spec.showIf then
            if isVisible(spec, out, hidden) then
                local fieldPath = joinPath(path, spec.key)
                out[spec.key] = normalizeValue(spec, object[spec.key], fieldPath, ctx, depth)
                if spec.required and (out[spec.key] == nil or out[spec.key] == '') then
                    addError(ctx, fieldPath, 'obrigatório')
                end
            else
                hidden[spec.key] = true
            end
            if hidden[spec.key] and object[spec.key] ~= nil then
                -- Escondido: guarda o que tinha, limpo mas sem acusar erro, para não perder
                -- o que o admin digitou antes de trocar o modo.
                local quiet = { errors = {}, ids = ctx.ids, refs = {} }
                out[spec.key] = normalizeValue(spec, object[spec.key], '', quiet, depth)
            end
        end
    end
    for index = 1, #fields do
        local spec = fields[index]
        if spec.required and not spec.showIf and (out[spec.key] == nil or out[spec.key] == '') then
            addError(ctx, joinPath(path, spec.key), 'obrigatório')
        end
    end
    return out
end

---@param value any
---@param path string
---@param ctx DefinitionContext
---@param depth integer
---@return table[]
normalizeActions = function(value, path, ctx, depth)
    if type(value) ~= 'table' then return {} end
    if depth > Definition.LIMITS.actionDepth then
        addError(ctx, path, 'ações aninhadas demais')
        return {}
    end
    local list = {}
    for index = 1, math.min(#value, Definition.LIMITS.actionsPerList) do
        local action = value[index]
        local actionPath = joinPath(path, index)
        local spec = type(action) == 'table' and Schema.actionByType[action.type] or nil
        if not spec then
            addError(ctx, actionPath, 'ação desconhecida')
        else
            local normalized = normalizeFields(spec.fields, action, actionPath, ctx, depth)
            normalized.type = action.type
            list[#list + 1] = normalized
        end
    end
    return list
end

local function registerIds(collection, list, path, ctx)
    local ids = {}
    ctx.ids[collection] = ids
    for index = 1, #list do
        local id = list[index].id
        local itemPath = joinPath(joinPath(path, collection), index)
        if not Utils.isId(id, 48) then
            addError(ctx, itemPath .. '.id', 'id inválido (minúsculas, números, _ e -)')
        elseif ids[id] then
            addError(ctx, itemPath .. '.id', ('id repetido: %s'):format(id))
        else
            ids[id] = true
        end
    end
end

---@param raw table definição como veio do editor ou do arquivo
---@return table definition
---@return { path: string, message: string }[] errors
function Definition.normalize(raw)
    ---@type DefinitionContext
    local ctx = { errors = {}, ids = {}, refs = {} }
    raw = type(raw) == 'table' and raw or {}

    local def = normalizeFields(Schema.general, raw, '', ctx, 0)
    def.schema = Definition.SCHEMA_VERSION
    def.id = raw.id
    if not Utils.isId(def.id, 48) then addError(ctx, 'id', 'id inválido (minúsculas, números, _ e -)') end
    if (def.minPlayers or 1) > (def.maxPlayers or 1) then
        addError(ctx, 'maxPlayers', 'máximo menor que o mínimo')
    end

    def.start = normalizeFields(Schema.start, type(raw.start) == 'table' and raw.start or {}, 'start', ctx, 0)
    if def.start.type == 'npc' and not def.start.npcCoords then addError(ctx, 'start.npcCoords', 'obrigatório para início por NPC') end
    if def.start.type == 'zone' and not def.start.zoneCoords then addError(ctx, 'start.zoneCoords', 'obrigatório para início por zona') end

    for index = 1, #Schema.collections do
        local collection = Schema.collections[index]
        local source = type(raw[collection.key]) == 'table' and raw[collection.key] or {}
        local list = {}
        for itemIndex = 1, math.min(#source, Definition.LIMITS.collectionItems) do
            local item = source[itemIndex]
            if type(item) == 'table' then
                local itemPath = joinPath(collection.key, itemIndex)
                local normalized = normalizeFields(collection.fields, item, itemPath, ctx, 0)
                normalized.id = item.id
                list[#list + 1] = normalized
            end
        end
        def[collection.key] = list
        registerIds(collection.key, list, '', ctx)
    end

    -- Passos.
    local steps = {}
    local rawSteps = type(raw.steps) == 'table' and raw.steps or {}
    for index = 1, math.min(#rawSteps, Definition.LIMITS.steps) do
        local step = rawSteps[index]
        local stepPath = joinPath('steps', index)
        local spec = type(step) == 'table' and Schema.stepByType[step.type] or nil
        if not spec then
            addError(ctx, stepPath, 'tipo de passo desconhecido')
        else
            local normalized = normalizeFields(Schema.stepCommon, step, stepPath, ctx, 0)
            local specific = normalizeFields(spec.fields, step, stepPath, ctx, 0)
            for key, value in pairs(specific) do normalized[key] = value end
            normalized.id = step.id
            normalized.type = step.type
            steps[#steps + 1] = normalized
        end
    end
    def.steps = steps
    registerIds('steps', steps, '', ctx)

    -- Gatilhos.
    local triggers = {}
    local rawTriggers = type(raw.triggers) == 'table' and raw.triggers or {}
    for index = 1, math.min(#rawTriggers, Definition.LIMITS.triggers) do
        local trigger = rawTriggers[index]
        if type(trigger) == 'table' then
            local triggerPath = joinPath('triggers', index)
            local normalized = normalizeFields(Schema.trigger, trigger, triggerPath, ctx, 0)
            normalized.id = trigger.id
            local event = Schema.eventByValue[normalized.on]
            if event and event.match and event.match.ref and normalized.match then
                ctx.refs[#ctx.refs + 1] = { path = triggerPath .. '.match', collection = event.match.ref, id = normalized.match }
            end
            triggers[#triggers + 1] = normalized
        end
    end
    def.triggers = triggers
    registerIds('triggers', triggers, '', ctx)

    -- Recompensas.
    local rewards = {}
    local rawRewards = type(raw.rewards) == 'table' and raw.rewards or {}
    for index = 1, math.min(#rawRewards, 16) do
        if type(rawRewards[index]) == 'table' then
            local rewardPath = joinPath('rewards', index)
            local reward = normalizeFields(Schema.reward, rawRewards[index], rewardPath, ctx, 0)
            if reward.type == 'item' and not reward.item then addError(ctx, rewardPath .. '.item', 'obrigatório') end
            rewards[#rewards + 1] = reward
        end
    end
    def.rewards = rewards

    -- Referências só no fim, quando todas as coleções já têm os ids.
    for index = 1, #ctx.refs do
        local ref = ctx.refs[index]
        local ids = ctx.ids[ref.collection]
        if not ids or not ids[ref.id] then
            addError(ctx, ref.path, ('não existe: %s'):format(ref.id))
        end
    end

    -- Regras que o esquema sozinho não expressa.
    for index = 1, #def.cargo do
        local cargo = def.cargo[index]
        local path = joinPath('cargo', index)
        if #(cargo.pieces or {}) < (cargo.quantity or 1) then
            addError(ctx, path .. '.pieces', 'menos posições que a quantidade certa')
        end
        if cargo.mode == 'inventory' and not cargo.item then
            addError(ctx, path .. '.item', 'modo inventário precisa de item')
        end
        if cargo.requireVehicle and cargo.vehicleMode == 'mission' and not cargo.vehicleId then
            addError(ctx, path .. '.vehicleId', 'escolha o veículo da missão')
        end
    end
    for index = 1, #def.chases do
        local chase = def.chases[index]
        if (chase.countMin or 1) > (chase.countMax or 1) then chase.countMax = chase.countMin end
    end

    return def, ctx.errors
end

---Definição vazia, já válida a não ser pelo nome.
---@param id string
---@param name string
---@return table
function Definition.blank(id, name)
    local def = Definition.normalize({ id = id, name = name })
    def.variables = {
        { id = 'alarm_active', type = 'boolean', default = 'false', random = {} },
    }
    return def
end

---Lista de nomes que condições podem ler: variáveis + valores calculados.
---@param def table
---@return string[]
function Definition.readableNames(def)
    local names = {}
    for index = 1, #(def.variables or {}) do names[#names + 1] = def.variables[index].id end
    for index = 1, #Schema.computed do
        local computed = Schema.computed[index]
        if computed.collection then
            local list = def[computed.collection] or {}
            for itemIndex = 1, #list do
                names[#names + 1] = (computed.name:gsub('{id}', list[itemIndex].id))
            end
        else
            names[#names + 1] = computed.name
        end
    end
    return names
end

return Definition
