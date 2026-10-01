---Roda um minigame do catálogo e devolve se passou. Um executor por fornecedor: a NUI
---própria para os portados do XS, e os exports/eventos de cada resource para os outros.
---Nenhum outro resource é alterado; os de fora só são chamados quando estão ligados.

local Catalogue = require 'shared.catalogue'
local Config = require 'config.client'

Play = { busy = false }

local nuiPending = nil
local safePending = nil

---@param provider string
---@return boolean
function Play.available(provider)
    local def = Catalogue.providers[provider]
    if not def then return false end
    if not def.resource then return true end
    return GetResourceState(def.resource) == 'started'
end

-- Espera com limite: o que não responder em `timeoutSeconds` conta como falha.
local function await(p, onTimeout)
    local settled = false
    SetTimeout(Config.timeoutSeconds * 1000, function()
        if settled then return end
        if onTimeout then onTimeout() end
        p:resolve(false)
    end)
    local result = Citizen.Await(p)
    settled = true
    return result
end

local function api(resource)
    return exports[resource]
end

local Runners = {}

function Runners.noir(def, difficulty)
    nuiPending = promise.new()
    local p = nuiPending
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'noir_minigames:play', kind = def.kind, difficulty = difficulty })
    local passed = await(p, function() SendNUIMessage({ action = 'noir_minigames:abort' }) end)
    nuiPending = nil
    SetNuiFocus(false, false)
    return passed == true
end

RegisterNUICallback('result', function(data, cb)
    cb('ok')
    local p = nuiPending
    nuiPending = nil
    if p then p:resolve(type(data) == 'table' and data.passed == true) end
end)

-- Recarga do CEF no meio de uma partida: a partida pendente cai como falha.
RegisterNUICallback('uiReady', function(_, cb)
    cb('ok')
    local p = nuiPending
    nuiPending = nil
    if p then
        SetNuiFocus(false, false)
        p:resolve(false)
    end
end)

function Runners.ox_lib(def, difficulty)
    local params = Catalogue.params(def.id, difficulty)
    return lib.skillCheck(params[1], Config.skillCheckKeys) == true
end

function Runners.ps_lib(def, difficulty)
    local params = Catalogue.params(def.id, difficulty)
    local ps = api('ps_lib')
    return ps[def.export](ps, false, table.unpack(params)) == true
end

function Runners.peuren(def, difficulty)
    local params = Catalogue.params(def.id, difficulty)
    local peuren = api('peuren_minigames')

    if def.export == 'StartLooting' then
        -- Saque não tem passou/falhou: termina quando o jogador fecha. Conta o que pegou
        -- só para mostrar no aviso.
        local taken = 0
        local size = params[2]
        peuren.StartLooting(peuren, Config.lootingSample, params[1], { x = size, y = size }, function()
            taken = taken + 1
            return true
        end)
        return true, { looted = taken }
    end

    return peuren[def.export](peuren, table.unpack(params)) == true
end

function Runners.enginewire()
    local wires = api('rep-enginewire')
    return wires.MiniGame(wires) == true
end

function Runners.mhacking(def, difficulty)
    local params = Catalogue.params(def.id, difficulty)
    local p = promise.new()
    TriggerEvent('mhacking:show')
    TriggerEvent('mhacking:start', params[1], params[2], function(success)
        p:resolve(success == true)
    end)
    local passed = await(p)
    TriggerEvent('mhacking:hide')
    return passed == true
end

-- O safecracker avisa o fim por evento local, não por retorno.
AddEventHandler('SafeCracker:EndMinigame', function(won)
    local p = safePending
    safePending = nil
    if p then p:resolve(won == true) end
end)

function Runners.safecracker(def, difficulty)
    local count = Catalogue.params(def.id, difficulty)[1]
    local combo = {}
    for i = 1, count do combo[i] = math.random(10, 350) end
    safePending = promise.new()
    local p = safePending
    TriggerEvent('SafeCracker:StartMinigame', combo)
    local passed = await(p, function() TriggerEvent('SafeCracker:EndGame') end)
    safePending = nil
    return passed == true
end

function Runners.voltlab(def, difficulty)
    local seconds = Catalogue.params(def.id, difficulty)[1]
    local p = promise.new()
    -- 1 = passou; 0 falhou/cancelou; 2 tempo; -1 configuração inválida.
    TriggerEvent('ultra-voltlab', seconds, function(result)
        p:resolve(result == 1)
    end)
    return await(p) == true
end

---Roda um minigame do catálogo.
---@param id string id do catálogo (ex.: 'noir:drill', 'ps_lib:circle')
---@param difficulty? integer 1 fácil, 2 normal, 3 difícil
---@return boolean passed
---@return string|table? detail código de erro, ou dados extras do jogo
function Play.run(id, difficulty)
    local def = Catalogue.byId[id]
    if not def then return false, 'unknown' end
    if not Play.available(def.provider) then return false, 'unavailable' end
    if Play.busy then return false, 'busy' end

    difficulty = math.floor(tonumber(difficulty) or 2)
    if difficulty < 1 or difficulty > 3 then difficulty = 2 end

    Play.busy = true
    local ok, passed, detail = pcall(Runners[def.provider], def, difficulty)
    Play.busy = false

    if not ok then
        lib.print.error(('[noir_minigames] %s quebrou: %s'):format(id, tostring(passed)))
        SetNuiFocus(false, false)
        return false, 'error'
    end
    return passed == true, detail
end

exports('Play', Play.run)

exports('List', function()
    local out = {}
    for _, id in ipairs(Catalogue.order) do
        local def = Catalogue.byId[id]
        out[#out + 1] = { id = id, label = def.label, provider = def.provider, available = Play.available(def.provider) }
    end
    return out
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if nuiPending then SetNuiFocus(false, false) end
end)
