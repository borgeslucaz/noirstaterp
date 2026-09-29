---Mesas de processamento: o jogador compra o item, posiciona pela mira e usa as
---receitas da mesa. Qualquer um usa a mesa; só o dono recolhe; polícia em serviço apreende.

local Shared = require 'config.shared'
local Config = require 'config.server'
local Rules = require 'shared.rules'
local Integrations = require 'server.integrations'
local Storage = require 'server.storage'
local World = require 'server.world'
local Actions = require 'server.actions'
local Logs = require 'server.logs'

---@class WeedTable
---@field id integer
---@field owner string
---@field type string item e chave em `Shared.tables`
---@field x number
---@field y number
---@field z number
---@field heading number

local Tables = {}

---@type table<integer, WeedTable>
local benches = {}

---@param bench WeedTable
local function publicView(bench)
    return { id = bench.id, type = bench.type, x = bench.x, y = bench.y, z = bench.z, heading = bench.heading }
end

local function broadcast(bench)
    TriggerClientEvent('noir_weed:client:tableUpsert', -1, publicView(bench))
end

---@param bench WeedTable
local function removeBench(bench)
    benches[bench.id] = nil
    Storage.deleteTable(bench.id)
    TriggerClientEvent('noir_weed:client:tableRemove', -1, bench.id)
end

---@param source number
---@param payload any
---@return WeedTable? bench
---@return string? code
local function reachBench(source, payload)
    local id = type(payload) == 'table' and payload.id or nil
    local bench = type(id) == 'number' and benches[id] or nil
    if not bench then return nil, 'no_table' end
    if World.distanceTo(source, bench) > Config.distance.interact then return nil, 'too_far' end
    return bench
end

---@param bench WeedTable
---@param key any
local function recipeOf(bench, key)
    local def = Shared.tables[bench.type]
    return def and type(key) == 'string' and def.recipes[key] or nil
end

Actions.register('placeTable', {
    check = function(source, citizenId, payload)
        if type(payload) ~= 'table' or type(payload.item) ~= 'string' or not Shared.tables[payload.item] then
            return false, 'invalid_request'
        end
        if World.ownedCount(benches, citizenId) >= Config.maxTables then return false, 'max_tables' end
        if Integrations.count(source, payload.item) < 1 then return false, 'no_table_item' end
        local ok, code = World.checkSpot(source, payload.placement, benches, Config.distance.tableSpacing)
        if not ok then return false, code end
        return true, nil, payload
    end,
    apply = function(source, citizenId, payload)
        if not Integrations.removeItem(source, payload.item, 1) then return false, 'no_table_item' end
        local placement = payload.placement
        local bench = {
            owner = citizenId,
            type = payload.item,
            x = placement.x, y = placement.y, z = placement.z,
            heading = placement.w % 360,
        }
        local id = Storage.insertTable(bench)
        if not id then
            Integrations.addItem(source, payload.item, 1)
            return false, 'operation_failed'
        end
        bench.id = id
        benches[id] = bench
        broadcast(bench)
        TriggerClientEvent('noir_weed:client:tableMine', source, id)
        return true
    end,
})

---Embalar em lote pelo minigame. O begin reserva `qty` unidades; o finish traz quantas
---o jogador embalou (`extra.done`) e quantos buds perdeu errando o saquinho
---(`extra.wasted`, só com `packGame.wasteOnMiss`), somando até `qty`. Os itens só saem
---no finish: a receita vezes `done`, mais o item arrastado vezes `wasted`. A velocidade
---não corta a entrega: abaixo do ritmo esperado (`packSecondsPerUnit`) o servidor só
---registra, para o log olhar depois.
---@param payload any
---@return integer?
local function packQty(payload)
    local qty = payload.qty
    if type(qty) ~= 'number' or qty % 1 ~= 0 or qty < 1 or qty > Shared.packGame.maxBatch then return nil end
    return qty
end

---@param value any
---@return boolean
local function isCount(value)
    return type(value) == 'number' and value % 1 == 0 and value >= 0
end

---@param extra any
---@param qty integer
---@return integer? done
---@return integer? wasted
local function roundOf(extra, qty)
    if type(extra) ~= 'table' then return nil end
    local done, wasted = extra.done, extra.wasted or 0
    if not isCount(done) or not isCount(wasted) or done + wasted > qty then return nil end
    if wasted > 0 and not Shared.packGame.wasteOnMiss then return nil end
    return done, wasted
end

---O que sai do inventário: a receita vezes `done` e o item arrastado vezes `wasted`.
---@param recipe table
---@param done integer
---@param wasted integer
---@return table<string, integer>
local function consumption(recipe, done, wasted)
    local needed = Rules.scale(recipe.ingredients, done)
    if wasted > 0 then
        local drag = recipe.minigame.drag
        needed[drag] = (needed[drag] or 0) + wasted
    end
    return needed
end

Actions.register('pack', {
    check = function(source, _, payload, extra)
        local bench, code = reachBench(source, payload)
        if not bench then return false, code end
        local recipe = recipeOf(bench, payload.recipe)
        local qty = packQty(payload)
        if not recipe or not recipe.minigame or not qty then return false, 'invalid_request' end

        -- No begin confere o lote pedido; no finish, o que foi feito e o que foi perdido.
        local done, wasted = qty, 0
        if extra ~= nil then
            done, wasted = roundOf(extra, qty)
            if not done then return false, 'invalid_request' end
        end
        for item, amount in pairs(consumption(recipe, done, wasted)) do
            if Integrations.count(source, item) < amount then return false, 'missing_ingredients' end
        end
        for item, amount in pairs(Rules.scale(recipe.outputs, done)) do
            if not Integrations.canCarry(source, item, amount) then return false, 'inventory_full' end
        end
        return true, nil, { recipe = recipe, done = done, wasted = wasted }
    end,
    duration = function() return 0 end,
    apply = function(source, _, context, _, elapsed)
        local done, wasted, recipe = context.done, context.wasted, context.recipe
        if done == 0 and wasted == 0 then return true, nil, { done = 0, wasted = 0 } end
        local expected = done * Config.packSecondsPerUnit * 1000
        if done > 0 and elapsed < expected then
            Logs.event(source, 'pack_fast', {
                recipe = recipe.label, units = done,
                elapsed_s = ('%.1f'):format(elapsed / 1000), expected_s = ('%.1f'):format(expected / 1000),
            })
        end
        -- Tira item por item; se um falhar, devolve os que já saíram.
        local taken = {}
        for item, amount in pairs(consumption(recipe, done, wasted)) do
            if amount > 0 then
                if not Integrations.removeItem(source, item, amount) then
                    for index = 1, #taken do Integrations.addItem(source, taken[index][1], taken[index][2]) end
                    return false, 'missing_ingredients'
                end
                taken[#taken + 1] = { item, amount }
            end
        end
        for item, amount in pairs(Rules.scale(recipe.outputs, done)) do
            if amount > 0 then
                local ok, code = Integrations.addItem(source, item, amount)
                if not ok then
                    lib.print.error(('mesa: AddItem %s x%d falhou para %d (%s)'):format(item, amount, source, tostring(code)))
                    return false, 'operation_failed'
                end
            end
        end
        return true, nil, { done = done, wasted = wasted, label = recipe.label }
    end,
})

Actions.register('pickupTable', {
    check = function(source, citizenId, payload)
        local bench, code = reachBench(source, payload)
        if not bench then return false, code end
        if bench.owner ~= citizenId then return false, 'not_owner' end
        if not Integrations.canCarry(source, bench.type, 1) then return false, 'inventory_full' end
        return true, nil, bench
    end,
    apply = function(source, _, bench)
        removeBench(bench)
        local ok, code = Integrations.addItem(source, bench.type, 1)
        if not ok then
            lib.print.error(('mesa %d: devolução falhou para %d (%s)'):format(bench.id, source, tostring(code)))
            return false, 'operation_failed'
        end
        return true
    end,
})

Actions.register('seizeTable', {
    check = function(source, citizenId, payload)
        local bench, code = reachBench(source, payload)
        if not bench then return false, code end
        if bench.owner == citizenId
            or not Integrations.hasAnyJob(source, Shared.destroyJobs, Config.destroyRequiresDuty) then
            return false, 'not_allowed'
        end
        return true, nil, bench
    end,
    apply = function(_, _, bench)
        removeBench(bench)
        return true
    end,
})

---Receitas que o jogador consegue fazer agora, com o máximo de cada uma. O que ele não
---tem no bolso não aparece.
lib.callback.register('noir_weed:server:tableRecipes', function(source, id)
    local bench, code = reachBench(source, { id = id })
    if not bench then return { ok = false, code = code } end
    local count = function(item) return Integrations.count(source, item) end
    local list = {}
    for key, recipe in pairs(Shared.tables[bench.type].recipes) do
        local max = math.min(Rules.maxBatch(recipe.ingredients, count), Shared.packGame.maxBatch)
        if max > 0 then
            list[#list + 1] = { key = key, max = max, have = count(recipe.minigame and recipe.minigame.drag or '') }
        end
    end
    table.sort(list, function(a, b) return a.key < b.key end)
    return { ok = true, recipes = list }
end)

function Tables.load()
    for _, row in ipairs(Storage.loadTables()) do
        if Shared.tables[row.type] then
            benches[row.id] = row
        else
            lib.print.warn(('mesa %d de tipo desconhecido (%s): ignorada'):format(row.id, tostring(row.type)))
        end
    end
end

---@param citizenId? string
---@return table[] views
---@return integer[] mine
function Tables.sync(citizenId)
    local list, mine = {}, {}
    for id, bench in pairs(benches) do
        list[#list + 1] = publicView(bench)
        if citizenId and bench.owner == citizenId then mine[#mine + 1] = id end
    end
    return list, mine
end

return Tables
