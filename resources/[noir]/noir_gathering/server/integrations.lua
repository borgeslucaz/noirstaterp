---Único ponto do servidor que conhece outro resource pelo nome. O que é do Qbox passa
---pelo `bgrz_core` (§2.1); com a ponte fora do ar, a ação é recusada. Progressão da gang
---é do `noir_illegal_core`, e produto da gang, do `noir_gangs`.

local Config = require 'config.server'

local CORE = 'bgrz_core'
local ILLEGAL = 'noir_illegal_core'
local GANGS = 'noir_gangs'

local Integrations = {}

---@return boolean
function Integrations.coreReady()
    return GetResourceState(CORE) == 'started'
end

local coreReady = Integrations.coreReady

---@param source number
---@param message string
---@param kind? 'inform'|'success'|'error'
function Integrations.notify(source, message, kind)
    if not coreReady() then return end
    exports[CORE]:Notify(source, message, kind or 'inform')
end

---Personagem carregado?
---@param source number
---@return boolean
function Integrations.isLoaded(source)
    if not coreReady() then return false end
    return exports[CORE]:GetCitizenId(source) ~= nil
end

---Job primário ou qualquer gang do personagem com cargo mínimo.
---@param source number
---@param groups table<string, integer>
---@return boolean
function Integrations.hasGroupAccess(source, groups)
    if not coreReady() then return false end
    return exports[CORE]:HasGroupAccess(source, groups) == true
end

---@return { name: string, label: string }[]
function Integrations.itemList()
    if not coreReady() then return {} end
    return exports[CORE]:GetItemList() or {}
end

---@return { name: string, label: string }[]
function Integrations.jobList()
    if not coreReady() then return {} end
    local list = {}
    for _, job in ipairs(exports[CORE]:GetJobList() or {}) do
        list[#list + 1] = { name = job.name, label = job.label }
    end
    return list
end

---@return { name: string, label: string }[]
function Integrations.gangList()
    if not coreReady() then return {} end
    return exports[CORE]:GetGangList() or {}
end

---@param item string
---@return string
function Integrations.itemLabel(item)
    if not coreReady() then return item end
    local label = exports[CORE]:GetItemLabel(item)
    return type(label) == 'string' and label or item
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
---@return string? errorCode
function Integrations.addItem(source, item, amount)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:AddItem(source, item, amount)
end

---@param source number
---@param item string
---@param cost integer
---@return boolean ok
---@return string? errorCode
function Integrations.hasTool(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    return exports[CORE]:HasItemDurability(source, item, cost)
end

---@param source number
---@param item string
---@param cost integer
---@return boolean ok
---@return string? errorCode
function Integrations.useTool(source, item, cost)
    if not coreReady() then return false, 'provider_unavailable' end
    local ok, err = exports[CORE]:ConsumeItemDurability(source, item, cost)
    return ok == true, err
end

---Soma stress, preso entre 0 e o teto. O Qbox replica o valor no state bag do
---jogador, que é de onde a HUD lê.
---@param source number
---@param amount integer
---@param ceiling integer
function Integrations.addStress(source, amount, ceiling)
    if amount <= 0 or not coreReady() then return end
    local current = tonumber(exports[CORE]:GetMetadata(source, 'stress')) or 0
    exports[CORE]:SetMetadata(source, 'stress', math.max(0, math.min(ceiling, current + amount)))
end

---Alerta policial. `coords` sai do servidor, nunca do client.
---@param coords vector3|{ x: number, y: number, z: number }
---@param title string
---@param message string
---@param radius? number área do alerta, em metros
---@return boolean
function Integrations.dispatch(coords, title, message, radius)
    if not coreReady() then return false end
    local ok = exports[CORE]:SendDispatch({
        title = title,
        message = message,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        code = Config.dispatch.code,
        jobs = Config.dispatch.jobs,
        duration = Config.dispatch.duration,
        priority = Config.dispatch.priority,
        radius = radius,
    })
    return ok == true
end

-- Veículo da rota -------------------------------------------------------------------------

---Veículo entregue pela rota, já com a chave de quem vai dirigir.
---@param source number
---@param model string
---@param placement { x: number, y: number, z: number, w: number }
---@return integer? netId
---@return integer? entity
function Integrations.spawnVehicle(source, model, placement)
    if not coreReady() then return nil end
    return exports[CORE]:SpawnVehicle(source, model, vector4(placement.x, placement.y, placement.z, placement.w))
end

-- Progressão da gang (noir_illegal_core) ---------------------------------------------------

local function illegalReady()
    return GetResourceState(ILLEGAL) == 'started'
end

---Desbloqueio e nível são da GANG de quem vai jogar. Sem o core no ar a resposta é não:
---rota com requisito não abre no escuro.
---@param source number
---@param requirement { unlock: string?, category: string?, level: integer? }?
---@return boolean
function Integrations.meetsRequirement(source, requirement)
    if not requirement then return true end
    if not illegalReady() then return false end
    if requirement.unlock then
        local ok, has = exports[ILLEGAL]:HasUnlock(source, requirement.unlock)
        if not ok or has ~= true then return false end
    end
    if requirement.category then
        local ok, level = exports[ILLEGAL]:GetOrganizationLevel(source, requirement.category)
        if not ok or (tonumber(level) or 0) < requirement.level then return false end
    end
    return true
end

---Categorias (com o produto do noir_gangs de cada uma), desbloqueios de gang e o teto da
---reputação por entrega. Vazio com o core fora do ar.
---@return { categories: table[], unlocks: string[], gatheringRewardCap: number }?
function Integrations.progressionCatalog()
    if not illegalReady() then return nil end
    local ok, catalog = exports[ILLEGAL]:GetCatalog()
    if not ok or type(catalog) ~= 'table' then return nil end
    return catalog
end

---Anuncia a entrega; o adaptador do core registra a reputação da gang de quem entregou.
---@param source number
---@param routeId integer
---@param routeName string
---@param category string
---@param amount number
function Integrations.reportDelivery(source, routeId, routeName, category, amount)
    TriggerEvent('noir_gathering:server:routeCompleted', {
        source = source,
        routeId = routeId,
        route = routeName,
        reward = { [category] = amount },
    })
end

-- Olheiro ---------------------------------------------------------------------------------

---Quem está online numa gang que não a de `source` e que opera `product`.
---@param source number
---@param product string produto do noir_gangs
---@return integer[]
function Integrations.rivalsWithProduct(source, product)
    if not coreReady() or GetResourceState(GANGS) ~= 'started' then return {} end
    local own = exports[CORE]:GetGang(source)
    local ownName = own and own.name or nil
    local operates, targets = {}, {}
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target and target ~= source then
            local gang = exports[CORE]:GetGang(target)
            local name = gang and gang.name
            if name and name ~= ownName then
                if operates[name] == nil then
                    operates[name] = exports[GANGS]:HasGangProduct(name, product) == true
                end
                if operates[name] then targets[#targets + 1] = target end
            end
        end
    end
    return targets
end

---@param source number
---@param body string
function Integrations.phoneMessage(source, body)
    if not coreReady() then return end
    exports[CORE]:SendPhoneNotification(source, { title = Config.scout.title, body = body })
end

return Integrations
