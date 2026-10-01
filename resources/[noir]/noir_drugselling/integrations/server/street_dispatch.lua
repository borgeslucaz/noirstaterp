-- Chamado da polícia na venda de rua (ServerConfig.StreetDispatch). Decidido no servidor,
-- depois da venda fechada: o cliente não tem como pular o aviso.

NoirDrugDispatch = {}

local CORE = 'bgrz_core'
local recent = {} ---@type { x: number, y: number, at: integer }[]

---Chance do chamado, dado quantas vendas recentes já houve no mesmo ponto.
---@param nearbySales integer
---@return number percent
function NoirDrugDispatch.chanceFor(nearbySales)
    local cfg = ServerConfig.StreetDispatch
    return math.min(cfg.maxChance, cfg.baseChance + cfg.stepPerSale * nearbySales)
end

---Conta as vendas recentes perto e registra esta. Vendas fora da janela saem da lista.
---@param x number
---@param y number
---@param now integer
---@return integer nearbySales
function NoirDrugDispatch.track(x, y, now)
    local cfg = ServerConfig.StreetDispatch
    local radiusSq = cfg.radius * cfg.radius
    local nearby = 0
    for index = #recent, 1, -1 do
        local sale = recent[index]
        if now - sale.at > cfg.windowSeconds then
            table.remove(recent, index)
        else
            local dx, dy = sale.x - x, sale.y - y
            if dx * dx + dy * dy <= radiusSq then nearby = nearby + 1 end
        end
    end
    recent[#recent + 1] = { x = x, y = y, at = now }
    return nearby
end

---@param source integer vendedor
---@param pedCfg table Config.PedTypes do comprador
---@return boolean called
function NoirDrugDispatch.onSale(source, pedCfg)
    local cfg = ServerConfig.StreetDispatch
    local coords = GetEntityCoords(GetPlayerPed(source))
    local nearby = NoirDrugDispatch.track(coords.x, coords.y, os.time())
    if pedCfg.dispatchCall == false then return false end
    if math.random() * 100 >= NoirDrugDispatch.chanceFor(nearby) then return false end
    if GetResourceState(CORE) ~= 'started' then return false end

    local angle = math.random() * 2 * math.pi
    local offset = math.random() * cfg.jitter
    local ok, sent, result = pcall(function()
        return exports[CORE]:SendDispatch({
            code = cfg.code,
            title = cfg.title,
            message = cfg.message,
            coords = { x = coords.x + math.cos(angle) * offset, y = coords.y + math.sin(angle) * offset, z = coords.z },
            jobs = cfg.jobs,
            priority = cfg.priority,
            duration = cfg.duration,
        })
    end)
    if not (ok and sent) then
        print(('[op-drugselling] chamado da polícia falhou: %s'):format(tostring(ok and result or sent)))
        return false
    end
    return true
end
