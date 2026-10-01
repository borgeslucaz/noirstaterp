-- Teto do que a gang ganha numa janela móvel (Config.Organization): um total para todas as
-- fontes e, por baixo, o `dailyCap` de cada activity. Só ganho positivo em `gang` conta e é
-- cortado; perda nunca é cortada.

local Service = {}
NoirIllegal.Services.OrganizationCap = Service

---Quanto do ganho cabe. Puro: é o que os testes exercitam.
---@param delta number ganho pedido
---@param gainedActivity number o que esta activity já deu à gang na janela
---@param activityCap number? teto da activity na janela
---@param gainedTotal number o que todas as fontes já deram na janela
---@param totalCap number teto total da janela
---@return number
function Service.clamp(delta, gainedActivity, activityCap, gainedTotal, totalCap)
    if delta <= 0 then return delta end
    local room = totalCap - gainedTotal
    if activityCap then room = math.min(room, activityCap - gainedActivity) end
    return math.max(0, math.min(delta, room))
end

---Corta o ganho de `gang` de uma organização pelo que ela já ganhou na janela.
---@return number
function Service.apply(organizationId, activityKey, activity, delta, query)
    if delta <= 0 then return delta end
    local cfg = NoirIllegal.Config.Organization
    local Repository = NoirIllegal.Repositories.Activity
    local total = Repository.sumOrganizationGain(organizationId, nil, cfg.windowSeconds, query)
    local own = activity.dailyCap
        and Repository.sumOrganizationGain(organizationId, activityKey, cfg.windowSeconds, query) or 0
    return NoirIllegal.Validators.round(
        Service.clamp(delta, own, activity.dailyCap, total, cfg.dailyCap), 4)
end
