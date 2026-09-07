-- ============================================================
-- ROTATION — relógio canônico, geração do Mercado Global,
-- persistência e snapshot. O RNG roda apenas aqui.
-- ============================================================
Rotation = Rotation or {}

Rotation.current = nil          -- { number, id, startsAt, expiresAt, offers = {}, order = {} }
Rotation.startsByRotation = {}  -- [rotationId][identifier] = true
Rotation.refreshSalt = 0        -- sal extra aplicado apenas em regenerações admin
Rotation.ready = false

local TIERS = { 'low', 'medium', 'high' }
local FALLBACK_TIERS = {
    low    = { 'medium', 'high' },
    medium = { 'low', 'high' },
    high   = { 'medium', 'low' },
}

-- ------------------------------------------------------------
-- Relógio
-- ------------------------------------------------------------

function Rotation.Seconds()
    local minutes = tonumber(Config.ContractBoard and Config.ContractBoard.rotationMinutes) or 60
    if minutes < 1 then minutes = 1 end
    return math.floor(minutes * 60)
end

function Rotation.Now()
    return os.time()
end

function Rotation.NumberAt(unixTime)
    return math.floor(unixTime / Rotation.Seconds())
end

function Rotation.IdFor(number)
    return tostring(number)
end

-- ------------------------------------------------------------
-- PRNG local determinístico (não mexe no math.random global)
-- ------------------------------------------------------------

local function NewRng(seed)
    local state = (seed * 2654435761 + 1013904223) % 4294967296
    local function nextFloat()
        state = (state * 1664525 + 1013904223) % 4294967296
        return state / 4294967296
    end
    return {
        float = nextFloat,
        int = function(minV, maxV)
            if maxV < minV then minV, maxV = maxV, minV end
            return minV + math.floor(nextFloat() * (maxV - minV + 1))
        end,
    }
end

-- ------------------------------------------------------------
-- Pools do catálogo
-- ------------------------------------------------------------

local poolsCache = nil

--- Constrói os pools por tier a partir de Config.Routes validado
--- contra Config.RouteSource. Nunca cria rota nem altera coordenadas.
function Rotation.BuildPools()
    if poolsCache then return poolsCache end
    local pools = { low = {}, medium = {}, high = {} }
    for _, route in ipairs(Config.Routes or {}) do
        if pools[route.tier] then pools[route.tier][#pools[route.tier] + 1] = route end
    end
    for _, tier in ipairs(TIERS) do table.sort(pools[tier], function(a, b) return a.id < b.id end) end
    poolsCache = pools
    return pools
end

-- ------------------------------------------------------------
-- Geração
-- ------------------------------------------------------------

--- Retorna um conjunto {'missionId:routeIndex' = true} das rotas usadas
--- nas duas rotações globais anteriores.
local function LoadRecentRouteKeys(rotationNumber)
    local recent = {}
    local rows = ExecuteSqlSafe(
        'SELECT route_id FROM noir_truckjob_offers WHERE rotation_id IN (?, ?)',
        { Rotation.IdFor(rotationNumber - 1), Rotation.IdFor(rotationNumber - 2) }
    )
    for _, row in ipairs(rows or {}) do
        recent[row.route_id] = true
    end
    return recent
end

local function WeightedPick(rng, candidates, recent, used)
    local repeatWeight = tonumber(Config.ContractBoard.global.repeatWeight) or 0.25
    local total = 0
    local weights = {}
    for i, cand in ipairs(candidates) do
        local w = 0
        if not used[cand.id] then
            w = recent[cand.id] and repeatWeight or 1.0
        end
        weights[i] = w
        total = total + w
    end
    if total <= 0 then return nil end

    local roll = rng.float() * total
    local acc = 0
    for i, cand in ipairs(candidates) do
        acc = acc + weights[i]
        if weights[i] > 0 and roll <= acc then
            return cand
        end
    end
    -- Guarda contra imprecisão de ponto flutuante
    for i = #candidates, 1, -1 do
        if weights[i] > 0 then return candidates[i] end
    end
    return nil
end

--- Gera a lista determinística de ofertas para uma rotação.
--- @param rotationNumber number
--- @return table offers (lista ordenada de {missionId, routeIndex, tier})
function Rotation.Generate(rotationNumber)
    local pools = Rotation.BuildPools()
    local cfg = Config.ContractBoard.global
    local seedSalt = tonumber(Config.ContractBoard.seedSalt) or 7919
    local rng = NewRng(rotationNumber + seedSalt + (Rotation.refreshSalt or 0))
    local recent = LoadRecentRouteKeys(rotationNumber)

    local used = {}
    local offers = {}

    for _, tier in ipairs(TIERS) do
        local range = cfg[tier] or { min = 1, max = 1 }
        local count = rng.int(range.min or 1, range.max or 1)

        for _ = 1, count do
            local pick = WeightedPick(rng, pools[tier], recent, used)
            if not pick then
                for _, fallback in ipairs(FALLBACK_TIERS[tier]) do
                    pick = WeightedPick(rng, pools[fallback], recent, used)
                    if pick then
                        Peak.Utils.Warn(('Pool "%s" esgotado na rotação %s — usando rota %s do tier "%s".'):format(tier, rotationNumber, pick.id, fallback))
                        break
                    end
                end
            end
            if pick then
                used[pick.id] = true
                offers[#offers + 1] = { routeId = pick.id, tier = tier }
            else
                Peak.Utils.Warn(('Sem candidatos para tier "%s" na rotação %s.'):format(tier, rotationNumber))
            end
        end
    end

    return offers
end

-- ------------------------------------------------------------
-- Persistência / carga
-- ------------------------------------------------------------

local function RowToOffer(row)
    local route = GetRoute(row.route_id)
    return {
        offerId = row.offer_id,
        rotationId = row.rotation_id,
        routeId = row.route_id,
        -- Somente para o adaptador de fluxo físico da V1; nunca persiste nem é projetado.
        missionId = route and route.sourceId or nil,
        routeIndex = route and route.sourceIndex or nil,
        tier = row.tier,
        status = row.status,
        driverIdentifier = row.driver_identifier,
    }
end

--- Garante que a rotação `number` exista no banco e carrega seu estado.
--- @return table|nil rotation
function Rotation.Load(number)
    local rotationId = Rotation.IdFor(number)
    local seconds = Rotation.Seconds()

    local rows = ExecuteSqlSafe(
        'SELECT offer_id, rotation_id, route_id, tier, status, driver_identifier FROM noir_truckjob_offers WHERE rotation_id = ? ORDER BY offer_id',
        { rotationId }
    )
    if rows == nil then
        Peak.Utils.Warn('Banco indisponível ao carregar a rotação ' .. rotationId)
        return nil
    end

    if #rows == 0 then
        local generated = Rotation.Generate(number)
        for i, off in ipairs(generated) do
            local offerId = ('%s-g-%d'):format(rotationId, i)
            ExecuteSqlUpdate(
                'INSERT IGNORE INTO noir_truckjob_offers (offer_id, rotation_id, route_id, tier, status) VALUES (?, ?, ?, ?, ?)',
                { offerId, rotationId, off.routeId, off.tier, 'available' }
            )
        end
        rows = ExecuteSqlSafe(
            'SELECT offer_id, rotation_id, route_id, tier, status, driver_identifier FROM noir_truckjob_offers WHERE rotation_id = ? ORDER BY offer_id',
            { rotationId }
        ) or {}

        local perTier = { low = 0, medium = 0, high = 0 }
        for _, off in ipairs(generated) do perTier[off.tier] = perTier[off.tier] + 1 end
        Peak.Utils.print(('Rotação %s gerada: %d ofertas (low %d / medium %d / high %d)'):format(
            rotationId, #generated, perTier.low, perTier.medium, perTier.high))
    end

    local rotation = {
        number = number,
        id = rotationId,
        startsAt = number * seconds,
        expiresAt = (number + 1) * seconds,
        offers = {},
        order = {},
    }

    local starts = {}
    for _, row in ipairs(rows) do
        local offer = RowToOffer(row)
        -- Ofertas cujo catálogo não resolve nunca são publicadas.
        local mission, route = ResolveCatalogRoute(offer.routeId)
        if mission and route then
            rotation.offers[offer.offerId] = offer
            rotation.order[#rotation.order + 1] = offer.offerId
            if offer.driverIdentifier then
                starts[offer.driverIdentifier] = true
            end
        else
            Peak.Utils.Warn(('Oferta %s aponta para rota inexistente %s:%s — ignorada.'):format(offer.offerId, offer.routeId))
        end
    end
    Rotation.startsByRotation[rotationId] = starts

    return rotation
end

--- Garante que Rotation.current corresponda à hora atual.
--- @return table|nil rotation
function Rotation.Ensure()
    local number = Rotation.NumberAt(Rotation.Now())
    if Rotation.current and Rotation.current.number == number then
        return Rotation.current
    end

    local previous = Rotation.current
    local loaded = Rotation.Load(number)
    if not loaded then
        return Rotation.current -- mantém a anterior até o banco voltar; nunca inventa lista
    end

    Rotation.current = loaded

    -- Limpa índices de rotações antigas
    for id in pairs(Rotation.startsByRotation) do
        if tonumber(id) and tonumber(id) < number - 2 then
            Rotation.startsByRotation[id] = nil
        end
    end

    if previous then
        -- Ofertas não iniciadas da rotação anterior expiram.
        ExecuteSqlAsync(
            "UPDATE noir_truckjob_offers SET status = 'expired', finished_at = NOW() WHERE rotation_id = ? AND status = 'available'",
            { previous.id }
        )
        local expired = 0
        for _, off in pairs(previous.offers) do
            if off.status == 'available' then expired = expired + 1 end
        end
        Peak.Utils.print(('Rotação %s encerrada: %d ofertas expiraram sem uso.'):format(previous.id, expired))

        TriggerClientEvent('noir-truckjob:rotationChanged', -1, {
            rotationId = loaded.id,
            expiresAt = loaded.expiresAt,
            serverNow = Rotation.Now(),
        })
    end

    return Rotation.current
end

--- Retorna a oferta pelo id (somente da rotação atual).
function Rotation.GetOffer(rotationId, offerId)
    local current = Rotation.Ensure()
    if not current or current.id ~= rotationId then return nil end
    return current.offers[offerId]
end

--- Regeneração excepcional da rotação atual (admin, auditada).
--- Recusa quando há contratos em andamento; o histórico de entregas
--- (noir_truckjob_deliveries) permanece intacto. Reinicia o limite de
--- uma oferta por jogador nesta rotação.
--- @return table|nil rotation, string|nil err
function Rotation.Refresh()
    local current = Rotation.Ensure()
    if not current then return nil, 'banco indisponível' end

    for _, off in pairs(current.offers) do
        if off.status == 'starting' or off.status == 'in_progress' then
            return nil, ('oferta %s está em andamento — conclua ou cancele antes de regenerar'):format(off.offerId)
        end
    end

    -- Sal temporal garante ofertas diferentes dentro da mesma janela.
    Rotation.refreshSalt = Rotation.Now()

    local affected = ExecuteSqlUpdate('DELETE FROM noir_truckjob_offers WHERE rotation_id = ?', { current.id })
    if affected == nil then return nil, 'falha ao limpar as ofertas da rotação' end

    Rotation.current = nil
    local loaded = Rotation.Ensure()
    if not loaded then return nil, 'falha ao recarregar a rotação' end

    TriggerClientEvent('noir-truckjob:rotationChanged', -1, {
        rotationId = loaded.id,
        expiresAt = loaded.expiresAt,
        serverNow = Rotation.Now(),
    })
    return loaded
end

--- Atualiza o status em memória e publica para todos os viewers
--- (payload mínimo, sem identifier).
function Rotation.PublishStatus(rotationId, offerId, status)
    local current = Rotation.current
    if current and current.id == rotationId and current.offers[offerId] then
        current.offers[offerId].status = status
    end
    TriggerClientEvent('noir-truckjob:globalOfferClaimed', -1, {
        rotationId = rotationId,
        offerId = offerId,
        status = status,
    })
end

function Rotation.HasStarted(rotationId, identifier)
    local starts = Rotation.startsByRotation[rotationId]
    return starts ~= nil and starts[identifier] == true
end

function Rotation.MarkStarted(rotationId, identifier)
    Rotation.startsByRotation[rotationId] = Rotation.startsByRotation[rotationId] or {}
    Rotation.startsByRotation[rotationId][identifier] = true
end

-- ------------------------------------------------------------
-- Economia / preview
-- ------------------------------------------------------------

--- basePay da rota segundo Config.Economy (sem bônus, sem nota).
function Rotation.BasePay(routeId, tier)
    local meta = GetRoute(routeId) or {}
    local eco = Config.Economy
    local minutes = tonumber(meta.estimatedMinutes) or 20
    local mult = (eco.difficultyMultiplier or {})[tier] or 1.0
    local base = (tonumber(eco.targetIncomePerHour) or 9000) * minutes / 60 * mult

    if eco.includeRouteExtraPayment then
        local _, route = ResolveCatalogRoute(routeId)
        if route and route.extraPayment then
            base = base + (tonumber(route.extraPayment) or 0)
        end
    end
    return math.floor(base)
end

function Rotation.Bonuses(tier)
    local b = (Config.ContractBoard.global.bonuses or {})[tier] or { money = 0, xp = 0 }
    local cap = tonumber(Config.ContractBoard.global.maxMoneyBonus) or 0.25
    return {
        money = math.min(tonumber(b.money) or 0, cap),
        xp = tonumber(b.xp) or 0,
    }
end

-- ------------------------------------------------------------
-- Snapshot
-- ------------------------------------------------------------

local function TruckByName(name)
    for _, truck in ipairs(Config.Trucks) do
        if truck.name == name then return truck end
    end
    return nil
end

--- Projeção de uma oferta para a NUI, com elegibilidade calculada no servidor.
function Rotation.ProjectOffer(offer, profile, identifier, activeSession)
    local _, route = ResolveCatalogRoute(offer.routeId)
    local meta = GetRoute(offer.routeId) or {}
    local bonuses = Rotation.Bonuses(offer.tier)
    local basePay = Rotation.BasePay(offer.routeId, offer.tier)
    local baseXP = tonumber(meta.baseXP) or 400
    local level = tonumber(profile.level) or 1

    local compatible = {}
    for _, name in ipairs(route.vehicle or {}) do
        local truck = TruckByName(name)
        if truck then
            compatible[#compatible + 1] = {
                name = truck.name,
                label = truck.label,
                image = truck.image,
                level = truck.level,
                unlocked = level >= (tonumber(truck.level) or 1),
            }
        end
    end
    table.sort(compatible, function(a, b)
        if a.level ~= b.level then return (tonumber(a.level) or 1) < (tonumber(b.level) or 1) end
        return a.name < b.name
    end)

    local eligible, reasons, _ = Contracts.CheckEligibility(profile, identifier, offer, activeSession)

    local status = offer.status
    if status == 'available' and not eligible then
        status = 'locked'
    end

    return {
        offerId = offer.offerId,
        rotationId = offer.rotationId,
        routeId = offer.routeId,
        tier = offer.tier,
        title = meta.title, image = meta.image, smallImage = meta.smallImage,
        routeLabel = meta.routeLabel, cargoType = meta.cargoType,
        reqLevel = meta.reqLevel,
        specialFlow = ((not route.trailerSpawnAvaliableCoords) and 'no_trailer') or 'trailer',
        estimatedMinutes = tonumber(meta.estimatedMinutes) or 20,
        paymentPreview = math.floor(basePay * (1 + bonuses.money)),
        basePayPreview = basePay,
        xpPreview = math.floor(baseXP * (1 + bonuses.xp)),
        moneyBonusPercent = math.floor(bonuses.money * 100 + 0.5),
        xpBonusPercent = math.floor(bonuses.xp * 100 + 0.5),
        status = status,
        eligible = eligible,
        lockReasons = reasons,
        mine = offer.driverIdentifier ~= nil and offer.driverIdentifier == identifier,
        compatibleTrucks = compatible,
    }
end

--- Snapshot completo para um jogador.
function Rotation.BuildSnapshot(src, profile)
    local current = Rotation.Ensure()
    local identifier = profile.identifier
    local activeSession = Contracts.GetSession(src)

    local offers = {}
    if current then
        for _, offerId in ipairs(current.order) do
            local offer = current.offers[offerId]
            offers[#offers + 1] = Rotation.ProjectOffer(offer, profile, identifier, activeSession)
        end
    end

    table.sort(offers, function(a, b)
        if a.xpPreview ~= b.xpPreview then return a.xpPreview < b.xpPreview end
        if a.reqLevel ~= b.reqLevel then return a.reqLevel < b.reqLevel end
        return a.routeId < b.routeId
    end)

    return {
        serverNow = Rotation.Now(),
        rotation = current and {
            id = current.id,
            expiresAt = current.expiresAt,
            refreshSeconds = Rotation.Seconds(),
        } or nil,
        player = {
            name = profile.name,
            level = tonumber(profile.level) or 1,
            xp = tonumber(profile.xp) or 0,
            usedThisRotation = current ~= nil and Rotation.HasStarted(current.id, identifier),
            activeSessionId = activeSession and activeSession.sessionId or nil,
        },
        offers = offers,
    }
end

-- ------------------------------------------------------------
-- Relógio de fundo
-- ------------------------------------------------------------

CreateThread(function()
    while not Peak.Server.Ready do Wait(100) end
    while not Rotation.ready do Wait(100) end

    Rotation.Ensure()
    while true do
        Wait(5000)
        Rotation.Ensure()
    end
end)
