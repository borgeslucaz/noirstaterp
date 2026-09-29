---Registro das rotas em memória, persistência pelo storage e publicação da visão
---pública no GlobalState.

local SharedConfig = require 'config.shared'
local Rules = require 'shared.rules'
local Storage = require 'server.storage'
local Integrations = require 'server.integrations'

local STATE_KEY = 'noir_gathering:routes'

local Routes = {}

---@type table<integer, table>
local routes = {}

---@type fun(routeId: integer)[]
local changeListeners = {}

---No boot o item não é conferido contra o inventário: um item removido depois não
---pode apagar a rota inteira. Ele só falha na hora de entregar, com log.
local function acceptAnyItem() return true end

function Routes.load()
    routes = {}
    for _, row in ipairs(Storage.loadAll()) do
        local ok, decoded = pcall(json.decode, row.data)
        local route, err = nil, 'invalid_json'
        if ok then route, err = Rules.normalizeRoute(decoded, SharedConfig.limits, acceptAnyItem) end
        if route then
            route.name = row.name
            routes[row.id] = route
        else
            lib.print.warn(('rota %s (%s) ignorada: %s'):format(row.id, row.name, err))
        end
    end
    Routes.publish()
end

function Routes.publish()
    local list = {}
    for id, route in pairs(routes) do
        if Rules.isPlayable(route) then
            local view = Rules.publicView(id, route)
            -- O client não fala com o inventário: o rótulo já vai resolvido.
            for itemName, item in pairs(view.items) do
                item.label = item.label or Integrations.itemLabel(itemName)
            end
            list[#list + 1] = view
        end
    end
    GlobalState:set(STATE_KEY, list, true)
end

---@param id any
---@return table?
function Routes.get(id)
    if not Rules.isInteger(id) then return nil end
    return routes[id]
end

---Lista completa para o menu de admin, ordenada por nome.
---@return { id: integer, route: table }[]
function Routes.list()
    local list = {}
    for id, route in pairs(routes) do list[#list + 1] = { id = id, route = route } end
    table.sort(list, function(a, b) return a.route.name < b.route.name end)
    return list
end

---@param listener fun(routeId: integer)
function Routes.onChange(listener)
    changeListeners[#changeListeners + 1] = listener
end

local function changed(id)
    Routes.publish()
    for index = 1, #changeListeners do changeListeners[index](id) end
end

---O que uma rota pode citar ao ser salva: itens do inventário, props da lista, e as
---categorias e desbloqueios do noir_illegal_core. Com o core fora do ar, rota que cita
---categoria ou desbloqueio não salva — não dá para conferir.
---@param knownItems table<string, boolean>
---@return table
function Routes.catalog(knownItems)
    local progression = Integrations.progressionCatalog()
    local categories, unlocks, props = {}, {}, {}
    for _, category in ipairs(progression and progression.categories or {}) do categories[category.id] = true end
    for _, unlock in ipairs(progression and progression.unlocks or {}) do unlocks[unlock] = true end
    for _, prop in ipairs(SharedConfig.haul.stackProps) do props[prop.model] = true end
    return {
        item = function(name) return knownItems[name] == true end,
        category = function(id) return categories[id] == true end,
        unlock = function(key) return unlocks[key] == true end,
        prop = function(model) return props[model] == true end,
        reputationCap = progression and progression.gatheringRewardCap or 0,
    }
end

---Cria (`id` nil) ou substitui uma rota. O que o admin mandou é revalidado inteiro,
---inclusive se cada item existe no inventário.
---@param id integer?
---@param input table
---@return integer? id
---@return string? errorCode
function Routes.save(id, input)
    if id ~= nil and not routes[id] then return nil, 'not_found' end

    local known = {}
    for _, item in ipairs(Integrations.itemList()) do known[item.name] = true end
    if next(known) == nil then return nil, 'provider_unavailable' end

    local route, err = Rules.normalizeRoute(input, SharedConfig.limits, Routes.catalog(known))
    if not route then return nil, err end

    local data = json.encode(route)
    if id then
        local ok, updateErr = Storage.update(id, route.name, data)
        if not ok then return nil, updateErr end
    else
        local newId, insertErr = Storage.insert(route.name, data)
        if not newId then return nil, insertErr end
        id = newId
    end

    routes[id] = route
    changed(id)
    return id
end

---@param id integer
---@return boolean ok
---@return string? errorCode
function Routes.delete(id)
    if not routes[id] then return false, 'not_found' end
    if not Storage.delete(id) then return false, 'storage_failed' end
    routes[id] = nil
    changed(id)
    return true
end

return Routes
