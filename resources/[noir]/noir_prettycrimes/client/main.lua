---Boot e infraestrutura comum do client.
---
---Este arquivo não sabe o que nenhum crime faz. Ele lê a config, carrega os
---módulos ligados e os para no stop do resource. Lógica de crime mora em
---`client/crimes/<id>.lua` e em lugar nenhum além disso.

local Config = require 'config.shared'
local Constants = require 'shared.constants'
local Utils = require 'shared.utils'

local DebugPrint = Utils.debugPrint('boot')

---@type table<string, table> id do crime -> módulo carregado
local loaded = {}

---Carrega e inicia um crime. O `require` só acontece para crime ligado: um crime
---desligado não tem o arquivo lido, então nada dele é registrado no ox_target nem
---escuta evento nenhum.
---@param id string
local function startCrime(id)
    local ok, module = pcall(require, 'client.crimes.' .. id)
    if not ok then
        lib.print.error(('falha ao carregar client/crimes/%s: %s'):format(id, module))
        return
    end
    if type(module) ~= 'table' or type(module.start) ~= 'function' then
        lib.print.error(('client/crimes/%s não devolveu um módulo com start()'):format(id))
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

    if next(loaded) == nil then
        DebugPrint('nenhum crime ligado')
    end
end

boot()

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= Constants.resource then return end
    for id, module in pairs(loaded) do
        if type(module.stop) == 'function' then
            local ok, err = pcall(module.stop)
            if not ok then
                lib.print.error(('erro no stop de %s: %s'):format(id, err))
            end
        end
    end
    loaded = {}
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
