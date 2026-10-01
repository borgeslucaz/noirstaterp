-- Polícia em serviço no preço da venda (ServerConfig.PolicePrice). A contagem vem do
-- noir_police, a mesma do placar (noir_scoreboard). Sem ele de pé, conta como zero: a venda
-- continua, pelo preço mais baixo.

NoirDrugPolice = {}

local POLICE = 'noir_police'

---@param police integer
---@return number
function NoirDrugPolice.multiplierFor(police)
    local multiplier = 1.0
    local reached = -1
    for _, tier in ipairs(ServerConfig.PolicePrice or {}) do
        if police >= tier.minimumPolice and tier.minimumPolice > reached then
            multiplier, reached = tier.multiplier, tier.minimumPolice
        end
    end
    return multiplier
end

---@return integer
function NoirDrugPolice.count()
    if GetResourceState(POLICE) ~= 'started' then return 0 end
    local ok, count = pcall(function() return exports[POLICE]:GetCopCount() end)
    return ok and math.type(count) == 'integer' and count or 0
end

---@return number
function NoirDrugPolice.multiplier()
    return NoirDrugPolice.multiplierFor(NoirDrugPolice.count())
end
