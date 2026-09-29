---Minigame da mesa de embalar (NUI). A tela escolhe variedade e quantidade, o jogador
---arrasta cada bud até um saquinho, e o resultado vai para o servidor pelo mesmo
---begin/finish das outras ações. A tela só apresenta: quem entrega é o servidor, que
---confere ingredientes e distância (velocidade só vira registro).

local Shared = require 'config.shared'
local Actions = require 'client.actions'

local Packing = {}

local IMAGE = 'nui://ox_inventory/web/images/%s.png'

---{ tableId, def } enquanto a tela está aberta
local current
---{ qty } entre o start e o finish
local round

local function image(item)
    return IMAGE:format(item)
end

local function playAnimation()
    local anim = Shared.animations.pack
    if not anim or not pcall(lib.requestAnimDict, anim.dict, 5000) then return end
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, anim.flag, 0, false, false, false)
    RemoveAnimDict(anim.dict)
end

local function stopAnimation()
    ClearPedTasks(cache.ped)
end

---Receitas que o jogador pode fazer agora, já com as imagens. Vazio = nada no bolso.
---@param tableId integer
---@param def table
---@return table[]? recipes
---@return string? code
local function fetchRecipes(tableId, def)
    local response = lib.callback.await('noir_weed:server:tableRecipes', false, tableId)
    if not response or not response.ok then return nil, response and response.code end
    local list = {}
    for _, entry in ipairs(response.recipes) do
        local recipe = def.recipes[entry.key]
        local game = recipe and recipe.minigame
        if game then
            list[#list + 1] = {
                key = entry.key,
                label = recipe.label,
                max = entry.max,
                have = entry.have,
                images = { drag = image(game.drag), target = image(game.target), result = image(game.result) },
            }
        end
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function close()
    if not current then return end
    if round then
        Actions.cancel()
        round = nil
        stopAnimation()
    end
    current = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@param tableId integer
---@param def table entrada de `Shared.tables`
function Packing.open(tableId, def)
    if current or Actions.isBusy() then return end
    local recipes, code = fetchRecipes(tableId, def)
    if not recipes then return Actions.fail(code) end
    if #recipes == 0 then return Actions.fail('missing_ingredients') end

    current = { tableId = tableId, def = def }
    SendNUIMessage({
        action = 'open',
        data = {
            title = def.label,
            recipes = recipes,
            game = {
                seal = Shared.packGame.seal,
                radius = Shared.packGame.radius,
                slots = Shared.packGame.slots,
                volume = Shared.packGame.volume,
                wasteOnMiss = Shared.packGame.wasteOnMiss,
            },
            locale = {
                pick = locale('pack_pick'),
                recipe = locale('pack_recipe'),
                start = locale('pack_start'),
                playing = locale('pack_playing', '%s'),
                drag = locale('pack_drag'),
                buds = locale('pack_buds'),
                bags = locale('pack_bags'),
                done = locale('pack_done'),
                stop = locale('pack_stop'),
                result = locale('pack_result'),
                resultNone = locale('pack_result_none'),
                closeTable = locale('pack_close'),
                again = locale('pack_again'),
                max = locale('pack_max', '%s'),
                have = locale('pack_have', '%s'),
                wasted = locale('pack_wasted', '%s'),
                volume = locale('pack_volume'),
            },
        },
    })
    SetNuiFocus(true, true)
end

RegisterNUICallback('start', function(data, cb)
    if not current or round then return cb({ ok = false }) end
    local qty = tonumber(data and data.qty)
    local key = data and data.recipe
    local recipe = type(key) == 'string' and current.def.recipes[key]
    if not recipe or not qty or qty < 1 or qty > Shared.packGame.maxBatch or qty % 1 ~= 0 then
        return cb({ ok = false })
    end

    local began = Actions.begin('pack', { id = current.tableId, recipe = key, qty = qty })
    if not began then return cb({ ok = false }) end
    round = { qty = qty }
    playAnimation()
    cb({ ok = true })
end)

RegisterNUICallback('finish', function(data, cb)
    if not current or not round then return cb({ ok = false, done = 0, wasted = 0 }) end
    local done = math.max(0, math.floor(tonumber(data and data.done) or 0))
    local wasted = math.max(0, math.floor(tonumber(data and data.wasted) or 0))
    done = math.min(done, round.qty)
    wasted = math.min(wasted, round.qty - done)
    round = nil
    local response = Actions.finish('pack', { done = done, wasted = wasted })
    stopAnimation()
    local result = response and response.result or {}
    cb({ ok = response ~= nil, done = result.done or 0, wasted = result.wasted or 0 })
end)

RegisterNUICallback('again', function(_, cb)
    if not current then return cb({ ok = false }) end
    local recipes, code = fetchRecipes(current.tableId, current.def)
    if not recipes or #recipes == 0 then
        Actions.fail(recipes and 'missing_ingredients' or code)
        close()
        return cb({ ok = false })
    end
    cb({ ok = true, recipes = recipes })
end)

RegisterNUICallback('close', function(_, cb)
    close()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not current then return end
    SetNuiFocus(false, false)
    if round then stopAnimation() end
end)

return Packing
