---Boot e infraestrutura comum do servidor.
---
---Mesma regra do client: nada específico de crime aqui. Este arquivo carrega os
---módulos ligados, limpa o estado de quem desconecta e expõe a API pública.

local Config = require 'config.shared'
local Constants = require 'shared.constants'
local Utils = require 'shared.utils'
local Security = require 'server.security'
local Integrations = require 'server.integrations'

local DebugPrint = Utils.debugPrint('boot')

---@type table<string, table> id do crime -> módulo carregado
local loaded = {}

---@param id string
local function startCrime(id)
    local ok, module = pcall(require, 'server.crimes.' .. id)
    if not ok then
        lib.print.error(('falha ao carregar server/crimes/%s: %s'):format(id, module))
        return
    end
    if type(module) ~= 'table' or type(module.start) ~= 'function' then
        lib.print.error(('server/crimes/%s não devolveu um módulo com start()'):format(id))
        return
    end

    local started, err = pcall(module.start)
    if not started then
        lib.print.error(('erro no start de %s: %s'):format(id, err))
        return
    end

    loaded[id] = module
    DebugPrint('crime iniciado:', id)
end

local function boot()
    local ids = Utils.sortedKeys(Config.crimes)
    for index = 1, #ids do
        local id = ids[index]
        if Config.crimes[id] == true then
            if Constants.crimes[id] then
                startCrime(id)
            elseif Constants.plannedCrimes[id] then
                lib.print.warn(('"%s" ainda não tem módulo; mantenha desligado.'):format(id))
            else
                lib.print.error(('crime desconhecido em Config.crimes: "%s"'):format(id))
            end
        end
    end

    -- Aviso único no boot em vez de uma linha por ação recusada mais tarde.
    if next(loaded) ~= nil and not Integrations.coreReady() then
        lib.print.warn('bgrz_core não está started: nenhuma recompensa será concedida.')
    end
end

boot()

AddEventHandler('playerDropped', function()
    local dropped = source
    if type(dropped) ~= 'number' then return end

    Security.forget(dropped)
    for _, module in pairs(loaded) do
        if type(module.onPlayerDropped) == 'function' then
            pcall(module.onPlayerDropped, dropped)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- API pública
-- ---------------------------------------------------------------------------

---@param id string
---@return boolean
exports('IsCrimeEnabled', function(id)
    return loaded[id] ~= nil
end)

---@return string[] ids dos crimes carregados, em ordem
exports('GetLoadedCrimes', function()
    return Utils.sortedKeys(loaded)
end)
