---Único ponto do servidor que conhece outro resource pelo nome (§2.1, §24).
---
---Tudo passa pelo `bgrz_core`: personagem, gang, itens, dinheiro, chaves, SMS, dispatch.
---Provider fora do ar não derruba a missão: cada função devolve falha com código e quem
---chama decide o que fazer (em geral, cair para uma notificação).
local Integrations = {}

local CORE = 'bgrz_core'

---@return boolean
local function coreReady()
    return GetResourceState(CORE) == 'started'
end

---@param fn fun(): ...
---@return boolean ok
---@return any ...
local function call(fn)
    if not coreReady() then return false, 'provider_unavailable' end
    return pcall(fn)
end

---No build Enhanced o retorno vem 1/0, não booleano (memória do servidor).
---@param source integer
---@param ace string
---@return boolean
function Integrations.isAceAllowed(source, ace)
    if type(source) ~= 'number' or source <= 0 then return false end
    local allowed = IsPlayerAceAllowed(source, ace)
    return allowed == true or allowed == 1
end

---@param source integer
---@param message string
---@param kind? 'inform'|'success'|'warning'|'error'
function Integrations.notify(source, message, kind)
    local ok = call(function() exports[CORE]:Notify(source, message, kind or 'inform') end)
    if not ok then
        lib.print.warn(('[noir_missions] notificação perdida para %s: %s'):format(source, message))
    end
end

---@param source integer
---@return { citizenId: string, name: string }?
function Integrations.getCharacter(source)
    local ok, character = call(function() return exports[CORE]:GetCharacter(source) end)
    if not ok or type(character) ~= 'table' then return nil end
    local citizenId = character.citizenId
    if type(citizenId) ~= 'string' then return nil end
    local full = type(character.name) == 'table' and character.name.full or ''
    full = full:gsub('^%s+', ''):gsub('%s+$', '')
    return { citizenId = citizenId, name = full ~= '' and full or GetPlayerName(source) or '?' }
end

---@param source integer
---@return { name: string, label: string?, grade: integer }?
function Integrations.getGang(source)
    local ok, gang = call(function() return exports[CORE]:GetGang(source) end)
    if not ok or type(gang) ~= 'table' or type(gang.name) ~= 'string' or gang.name == 'none' then return nil end
    return { name = gang.name, label = gang.label, grade = tonumber(gang.grade) or 0 }
end

---SMS anônimo pelo telefone; sem telefone ou sem chip, vira notificação.
---@param source integer
---@param text string
function Integrations.sendSms(source, text)
    local character = Integrations.getCharacter(source)
    if character then
        local ok, sent = call(function()
            return exports[CORE]:SendPhoneAnonymousMessage(character.citizenId, text)
        end)
        if ok and sent then return true end
    end
    Integrations.notify(source, text, 'inform')
    return false
end

---@param source integer
---@param item string
---@param amount integer
---@return boolean ok
---@return string? code
function Integrations.addItem(source, item, amount)
    local ok, canCarry = call(function() return exports[CORE]:CanCarryItem(source, item, amount) end)
    if not ok then return false, 'provider_unavailable' end
    if not canCarry then return false, 'cannot_carry' end
    local called, added, err = call(function() return exports[CORE]:AddItem(source, item, amount) end)
    if not called then return false, 'provider_unavailable' end
    if not added then return false, err or 'add_failed' end
    return true
end

---@param source integer
---@param item string
---@param amount integer
---@return boolean ok
---@return string? code
function Integrations.removeItem(source, item, amount)
    local called, removed, err = call(function() return exports[CORE]:RemoveItem(source, item, amount) end)
    if not called then return false, 'provider_unavailable' end
    if not removed then return false, err or 'remove_failed' end
    return true
end

---@param source integer
---@param item string
---@return integer
function Integrations.itemCount(source, item)
    local ok, count = call(function() return exports[CORE]:GetItemCount(source, item) end)
    if not ok then return 0 end
    return tonumber(count) or 0
end

---@return { name: string, label: string }[]
function Integrations.itemList()
    local ok, list = call(function() return exports[CORE]:GetItemList() end)
    if not ok or type(list) ~= 'table' then return {} end
    return list
end

---@param source integer
---@param account string
---@param amount integer
---@param reason string
---@return boolean
function Integrations.addMoney(source, account, amount, reason)
    local ok, added = call(function() return exports[CORE]:AddMoney(source, account, amount, reason) end)
    return ok and added ~= false
end

---Chave temporária do veículo de missão. A placa vai junto porque, logo depois de trocar a
---placa no servidor, a leitura ainda pode devolver a antiga (README do bgrz_core).
---@param source integer
---@param vehicle integer
---@param plate string
---@return boolean
function Integrations.giveKeys(source, vehicle, plate)
    local ok, given = call(function() return exports[CORE]:GiveVehicleKeys(source, vehicle, plate) end)
    return ok and given == true
end

---Caído (last stand) ou morto.
---@param source integer
---@return boolean
function Integrations.isDowned(source)
    local ok, downed = call(function() return exports[CORE]:IsPlayerDowned(source) end)
    return ok and downed == true
end

---Classe do veículo (numeração do GTA) pelo modelo. Pode ceder a thread na primeira vez.
---@param model integer hash
---@return integer?
function Integrations.vehicleClass(model)
    local ok, class = call(function() return exports[CORE]:GetVehicleClass(model) end)
    if not ok then return nil end
    return tonumber(class)
end

---@param payload table
---@return boolean
function Integrations.dispatch(payload)
    local ok, sent = call(function() return exports[CORE]:SendDispatch(payload) end)
    return ok and sent == true
end

return Integrations
