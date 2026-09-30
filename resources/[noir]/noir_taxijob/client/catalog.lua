---Catálogo publicado pelo servidor (server/catalog.lua, editável pelo /editortaxi): carros da
---central, modelos aceitos, a Central e o tempo da oferta. Aplicado no lugar em Config, para os
---`local D = Config.Depot` dos outros arquivos continuarem valendo.

local STATE_KEY = 'noir_taxijob:catalog'

---Assinatura do que o atendente e o blip usam (posição, modelo, blip).
local function depotSignature(p, model, blip)
    blip = blip or {}
    return ('%.2f|%.2f|%.2f|%.1f|%s|%s|%s|%s|%s'):format(p.x, p.y, p.z, p.w or 0, model, blip.sprite, blip.color, blip.scale, blip.label)
end

-- Começa com o config.lua: é com ele que o atendente nasce se o catálogo ainda não chegou.
local lastDepot = depotSignature(Config.Depot.coords, Config.Depot.pedModel, Config.Depot.blip)

local function vec4Of(p) return vec4(p.x, p.y, p.z, p.w) end

local function apply(catalog)
    if type(catalog) ~= 'table' or type(catalog.vehicles) ~= 'table' then return end
    for i = #Config.RentalVehicles, 1, -1 do Config.RentalVehicles[i] = nil end
    for _, v in ipairs(catalog.vehicles) do Config.RentalVehicles[#Config.RentalVehicles + 1] = v end
    for i = #Config.AllowedVehicles, 1, -1 do Config.AllowedVehicles[i] = nil end
    for _, model in ipairs(catalog.allowed or {}) do Config.AllowedVehicles[#Config.AllowedVehicles + 1] = model end
    if catalog.offerTimeout then Config.Dispatch.OfferTimeout = catalog.offerTimeout end

    local depot = catalog.depot
    if type(depot) ~= 'table' then return end
    local D = Config.Depot
    D.coords = vec4Of(depot.ped)
    D.pedModel = depot.pedModel
    D.interactDistance = depot.interactDistance
    D.returnRadius = depot.returnRadius
    D.spawnPoints = {}
    for _, p in ipairs(depot.spawnPoints or {}) do D.spawnPoints[#D.spawnPoints + 1] = vec4Of(p) end
    D.blip = depot.blip

    -- Atendente e blip só são recriados quando a Central mudou de fato.
    local signature = depotSignature(depot.ped, depot.pedModel, depot.blip)
    if signature ~= lastDepot and Depot and Depot.spawn then CreateThread(Depot.spawn) end
    lastDepot = signature
end

apply(GlobalState[STATE_KEY])

AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    apply(value)
end)
