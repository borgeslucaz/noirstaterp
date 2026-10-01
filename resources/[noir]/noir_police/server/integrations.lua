---Único arquivo do servidor que conhece outro resource pelo nome.
---
---Framework, dinheiro, metadata, itens, dispatch, veículos e banco passam pelo
---`bgrz_core`. Duas famílias de chamada vão direto ao `ox_inventory`, pelo mesmo
---motivo do §2.5 (ox_target):
---
---  * `registerHook`: o ox_inventory guarda o hook com `GetInvokingResource()` e o
---    remove no stop desse resource. Registrado pelo bridge, o hook ficaria atribuído
---    ao bgrz_core: um restart do noir_police empilharia hooks duplicados.
---  * stash, container e inventário aberto à força (`RegisterStash`,
---    `setContainerProperties`, `forceOpenInventory`, `GetContainerFromSlot`,
---    `GetInventoryItems`, `ClearInventory`, `GetCurrentWeapon`): superfície de
---    inventário que o bridge ainda não tem e que só este resource usa.
---
---Tudo o que é ox_inventory fica neste arquivo, para uma troca de provider ser mexer
---num lugar só.

local CORE = 'bgrz_core'
local INVENTORY = 'ox_inventory'

local Integrations = {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

local function call(resource, method, ...)
    if GetResourceState(resource) ~= 'started' then return false, 'provider_unavailable' end
    local results = table.pack(pcall(exports[resource][method], exports[resource], ...))
    if not results[1] then
        lib.print.error(('[noir_police] %s:%s falhou: %s'):format(resource, method, tostring(results[2])))
        return false, 'provider_unavailable'
    end
    return true, table.unpack(results, 2, results.n)
end

Integrations.coreReady = coreReady

-- Jogador --------------------------------------------------------------------------

---@param source number
---@return table? job { name, label, type, grade, onDuty }
function Integrations.getJob(source)
    local ok, job = call(CORE, 'GetJob', source)
    return ok and job or nil
end

---@param source number
---@return string?
function Integrations.getCitizenId(source)
    local ok, cid = call(CORE, 'GetCitizenId', source)
    return ok and cid or nil
end

---@param citizenId string
---@return number?
function Integrations.getSourceByCitizenId(citizenId)
    local ok, src = call(CORE, 'GetCharacterSource', citizenId)
    return ok and src or nil
end

---@param citizenIds string[]
---@return table<string, string>
function Integrations.getNames(citizenIds)
    local ok, names = call(CORE, 'GetCharacterNames', citizenIds)
    return ok and type(names) == 'table' and names or {}
end

---@param source number
---@return string
function Integrations.getName(source)
    local cid = Integrations.getCitizenId(source)
    if not cid then return ('#%s'):format(source) end
    return Integrations.getNames({ cid })[cid] or cid
end

---@param source number
---@param key string
function Integrations.getMetadata(source, key)
    local ok, value = call(CORE, 'GetMetadata', source, key)
    if ok then return value end
end

---@param source number
---@param key string
---@param value any
---@return boolean
function Integrations.setMetadata(source, key, value)
    return (call(CORE, 'SetMetadata', source, key, value))
end

---@param source number
---@param onDuty boolean
---@return boolean ok, string? err
function Integrations.setDuty(source, onDuty)
    local ok, result, err = call(CORE, 'SetJobDuty', source, onDuty)
    if not ok then return false, result end
    return result == true, err
end

---@param jobType string
---@return integer[]
function Integrations.onDutyByType(jobType)
    local ok, list = call(CORE, 'GetOnDutyPlayersByType', jobType)
    return ok and type(list) == 'table' and list or {}
end

---@param source number
---@return boolean
function Integrations.isDowned(source)
    local ok, downed = call(CORE, 'IsPlayerDowned', source)
    return ok and downed == true
end

---@param source number
---@param message string
---@param kind? 'inform'|'success'|'warning'|'error'
function Integrations.notify(source, message, kind)
    call(CORE, 'Notify', source, message, kind or 'inform')
end

---Notificação no celular (sky_phone, pelo bridge). Sem telefone equipado, não chega.
---@param source number
---@param title string
---@param body string
function Integrations.phoneNotify(source, title, body)
    call(CORE, 'SendPhoneNotification', source, { appId = 'noir_police', title = title, body = body })
end

---SMS pela linha de serviço da empresa no telefone (fica na conversa; chega offline).
---@return boolean ok
function Integrations.phoneMessage(companyId, citizenId, body)
    local ok, result = call(CORE, 'SendPhoneServiceMessage', companyId, citizenId, body)
    return ok and result == true
end

-- Dinheiro -------------------------------------------------------------------------

---@return boolean
function Integrations.removeMoney(source, account, amount, reason)
    local ok, result = call(CORE, 'RemoveMoney', source, account, amount, reason)
    return ok and result == true
end

---@return boolean
function Integrations.addMoney(source, account, amount, reason)
    local ok, result = call(CORE, 'AddMoney', source, account, amount, reason)
    return ok and result == true
end

---O banco está com o cache de contas carregado?
---@return boolean
function Integrations.bankingReady()
    local ok, ready = call(CORE, 'IsBankingReady')
    return ok and ready == true
end

---@param accountId string
---@param label string
---@return boolean ok, string? err
function Integrations.ensureOrgAccount(accountId, label)
    local ok, result, err = call(CORE, 'EnsureOrgAccount', accountId, label, 0)
    if not ok then return false, result end
    return result == true, err
end

---Cobrança pendente no banco (fatura/multa). O dinheiro só sai quando a pessoa paga.
---@param data table ver bgrz_core CreateInvoice
---@return string? id, string? err
function Integrations.createInvoice(data)
    local ok, id, err = call(CORE, 'CreateInvoice', data)
    if not ok then return nil, id end
    return id, err
end

---@return boolean
function Integrations.addOrgMoney(accountId, amount)
    local ok, result = call(CORE, 'AddOrgMoney', accountId, amount)
    return ok and result ~= false
end

-- Itens (bridge) -------------------------------------------------------------------

---@return integer
function Integrations.itemCount(holder, item, metadata)
    local ok, count = call(CORE, 'GetItemCount', holder, item, metadata)
    return ok and tonumber(count) or 0
end

---@return boolean ok, string? err
function Integrations.addItem(holder, item, amount, metadata)
    local ok, result, err = call(CORE, 'AddItem', holder, item, amount, metadata)
    if not ok then return false, result end
    return result == true, err
end

---@return boolean ok, string? err
function Integrations.removeItem(holder, item, amount, metadata)
    local ok, result, err = call(CORE, 'RemoveItem', holder, item, amount, metadata)
    if not ok then return false, result end
    return result == true, err
end

---@return boolean
function Integrations.canCarry(holder, item, amount, metadata)
    local ok, result = call(CORE, 'CanCarryItem', holder, item, amount, metadata)
    return ok and result == true
end

---@return table[] slots
function Integrations.itemSlots(holder, item)
    local ok, slots = call(CORE, 'GetItemSlots', holder, item)
    return ok and type(slots) == 'table' and slots or {}
end

---@return boolean ok, string? err
function Integrations.removeItemFromSlot(holder, item, amount, slot)
    local ok, result, err = call(CORE, 'RemoveItemFromSlot', holder, item, amount, slot)
    if not ok then return false, result end
    return result == true, err
end

---Remove os slots cujo metadata tem todos os campos de `match` (comparação campo a
---campo; o RemoveItem do ox exige metadata idêntico).
---@return integer removed
function Integrations.removeItemsWithMetadata(holder, item, match)
    local ok, result, removed = call(CORE, 'RemoveItemsWithMetadata', holder, item, match)
    return ok and result == true and tonumber(removed) or 0
end

---@return string
function Integrations.itemLabel(item)
    local ok, label = call(CORE, 'GetItemLabel', item)
    return ok and type(label) == 'string' and label or item
end

-- Dispatch e veículos --------------------------------------------------------------

---@param request table ver bgrz_core:SendDispatch
function Integrations.dispatch(request)
    local ok, sent, result = call(CORE, 'SendDispatch', request)
    if not ok or not sent then
        lib.print.warn(('[noir_police] dispatch recusado: %s'):format(tostring(result)))
    end
end

---@return number? netId, number? vehicle
function Integrations.spawnVehicle(source, model, coords, warp, plate)
    local ok, netId, vehicle = call(CORE, 'SpawnVehicle', source, model, coords, warp, plate)
    if not ok then return nil end
    return netId, vehicle
end

-- ox_inventory (ver cabeçalho) ------------------------------------------------------

---@param event string
---@param fn function
---@param options? table
---@return integer? hookId
function Integrations.registerInventoryHook(event, fn, options)
    local ok, id = call(INVENTORY, 'registerHook', event, fn, options)
    return ok and id or nil
end

function Integrations.registerStash(id, label, slots, maxWeight, groups, coords)
    call(INVENTORY, 'RegisterStash', id, label, slots, maxWeight, nil, groups, coords)
end

function Integrations.setContainerProperties(item, properties)
    call(INVENTORY, 'setContainerProperties', item, properties)
end

---@param source number
---@param invType string
---@param data any
function Integrations.forceOpenInventory(source, invType, data)
    call(INVENTORY, 'forceOpenInventory', source, invType, data)
end

---Troca o metadata de um slot (etiqueta da caixa).
function Integrations.setSlotMetadata(source, slot, metadata)
    call(INVENTORY, 'SetMetadata', source, slot, metadata)
end

---@return table? container
function Integrations.containerFromSlot(source, slot)
    local ok, container = call(INVENTORY, 'GetContainerFromSlot', source, slot)
    return ok and container or nil
end

---@return table[] items
function Integrations.inventoryItems(inventory)
    local ok, items = call(INVENTORY, 'GetInventoryItems', inventory)
    return ok and type(items) == 'table' and items or {}
end

function Integrations.clearInventory(inventory)
    call(INVENTORY, 'ClearInventory', inventory)
end

---@return table? weapon slot { name, metadata }
function Integrations.currentWeapon(source)
    local ok, weapon = call(INVENTORY, 'GetCurrentWeapon', source)
    return ok and type(weapon) == 'table' and weapon or nil
end

---Munição que a arma usa, pelo cadastro do inventário.
---@param weaponItem string
---@return string?
function Integrations.weaponAmmo(weaponItem)
    local ok, data = call(INVENTORY, 'Items', weaponItem)
    return ok and type(data) == 'table' and data.ammoname or nil
end

-- Log ------------------------------------------------------------------------------

---Auditoria pelo logger do ox_lib (ox:logger, hoje fivemanage).
---@param source number|false
---@param event string
---@param message string
function Integrations.log(source, event, message)
    lib.logger(source or 0, ('noir_police:%s'):format(event), message)
end

return Integrations
