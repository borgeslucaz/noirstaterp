---Único ponto do servidor que conhece outro resource pelo nome.
---
---Trocar notificação, inventário, dispatch ou framework é mexer só aqui. Se você
---estiver escrevendo `exports.<qualquer coisa>` dentro de `server/crimes/`, o
---wrapper está faltando neste arquivo.
---
---Toda integração passa pelo `bgrz_core` — framework, inventário e dispatch. Não
---há chamada direta a `qbx_core` nem a `ox_inventory` em lugar nenhum do resource,
---como manda o §2.1 do SCRIPT_GOOD_PRACTICES. Quando o bridge não está de pé, a
---ação é recusada em vez de seguir por um segundo caminho meio testado.

local Config = require 'config.server'
local Utils = require 'shared.utils'

local DebugPrint = Utils.debugPrint('integrations')

local CORE = 'bgrz_core'

local Integrations = {}

---@return boolean
local function coreReady()
    if GetResourceState(CORE) == 'started' then return true end
    DebugPrint('bgrz_core não está started; ação recusada')
    return false
end

Integrations.coreReady = coreReady

---@param source number
---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end

---@param source number
---@return string? citizenId
function Integrations.getCitizenId(source)
    if not coreReady() then return nil end
    return exports[CORE]:GetCitizenId(source)
end

---@param source number
---@param item string
---@param amount integer
---@return boolean ok
---@return string? errorCode
function Integrations.addItem(source, item, amount)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:AddItem(source, item, amount)
end

---@param source number
---@param item string
---@param amount integer
---@return boolean
function Integrations.canCarry(source, item, amount)
    if not coreReady() then return false end
    return exports[CORE]:CanCarryItem(source, item, amount) == true
end

---@param source number
---@param item string
---@param amount integer
---@return boolean ok
function Integrations.removeItem(source, item, amount)
    if not coreReady() then return false end
    return exports[CORE]:RemoveItem(source, item, amount) == true
end

---Qual destas ferramentas o jogador tem, se tiver alguma.
---
---Devolve o NOME e não um booleano porque quem chama precisa saber qual consumir
---depois — perguntar de novo na hora de quebrar a ferramenta abriria uma janela
---entre a checagem e o consumo.
---
---É a conferência que vale: o `items` de uma opção do ox_target esconde o alvo da
---tela de quem não tem a ferramenta, e esconder não é impedir (§7.1).
---@param source number
---@param items string[]
---@return string? item
function Integrations.firstItemOwned(source, items)
    if not coreReady() then return nil end
    if type(items) ~= 'table' then return nil end

    for index = 1, #items do
        local item = items[index]
        if type(item) == 'string' then
            local count = exports[CORE]:GetItemCount(source, item)
            if type(count) == 'number' and count > 0 then return item end
        end
    end

    return nil
end

---@param source number
---@param account 'cash'|'bank'
---@param amount integer
---@param reason string
---@return boolean
function Integrations.addMoney(source, account, amount, reason)
    if not coreReady() then return false end
    return exports[CORE]:AddMoney(source, account or 'cash', amount, reason) == true
end

---Alerta policial. `coords` sai do servidor, nunca do client.
---@param payload { title: string, message?: string, coords: vector3|table, code?: string }
---@return boolean
function Integrations.dispatch(payload)
    if not Config.dispatch.enabled then return false end
    if not coreReady() then return false end

    local ok, result = exports[CORE]:SendDispatch({
        title = payload.title,
        message = payload.message or payload.title,
        coords = payload.coords,
        code = payload.code,
        jobs = Config.dispatch.jobs,
        duration = Config.dispatch.duration,
        priority = Config.dispatch.priority,
    })
    if not ok then DebugPrint('dispatch recusado:', result) end
    return ok == true
end

---Rótulo de exibição de um item, pelo bridge.
---@param item string
---@return string
function Integrations.itemLabel(item)
    if not coreReady() then return item end
    local label = exports[CORE]:GetItemLabel(item)
    return type(label) == 'string' and label or item
end

---Classe do veículo (numeração do GTA), pelo bridge.
---@param model number hash do modelo
---@return integer? class
function Integrations.vehicleClass(model)
    if not coreReady() then return nil end
    local class = exports[CORE]:GetVehicleClass(model)
    if type(class) ~= 'number' then
        DebugPrint('classe de veículo indisponível para', model)
        return nil
    end
    return class
end

---Progressão criminal opcional. Desligada, é um no-op — e é assim que ela vem.
---@param source number
---@param activityKey string
---@param transactionId string
---@param metadata? table
---@return boolean
function Integrations.recordActivity(source, activityKey, transactionId, metadata)
    local progression = Config.progression
    if not progression.enabled then return false end
    if GetResourceState(progression.resource) ~= 'started' then
        DebugPrint('progressão ligada mas', progression.resource, 'não está started')
        return false
    end

    local ok, result = exports[progression.resource]:RecordActivity(
        source, activityKey, transactionId, { metadata = metadata })
    if not ok then DebugPrint('RecordActivity recusado:', json.encode(result or {})) end
    return ok == true
end

---Id estável para uma tentativa, usado como chave de transação da progressão.
---@return string
function Integrations.transactionId()
    -- O ox_lib não expõe uuid; este formato basta para desduplicar retry.
    return ('%s-%s-%s'):format(os.time(), math.random(0, 0xFFFFFF), math.random(0, 0xFFFFFF))
end

return Integrations
