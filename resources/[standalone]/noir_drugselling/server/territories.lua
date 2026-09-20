-- Alerta de invasão: venda de droga dentro de bairro dominado por gang.
--
-- Quem não é da gang dona vender ali dispara uma mensagem no celular de todos os membros
-- dela, com o pino do lugar. É o que dá à gang a chance de responder — sem isso, tomar a
-- rua só aparece no mapa, depois, sem ninguém para reagir.
--
-- O domínio vem do noir_territories (5 tags de graffiti no bairro) e o celular do sd-phone.
-- Os dois são opcionais: sem eles a venda acontece igual, só não avisa ninguém. É o oposto
-- do noir_skills, que é dependency dura — lá a falta quebraria a progressão em silêncio,
-- aqui ela só desliga um aviso.

NoirDrugTerritory = {}

-- ['gang:bairro'] = os.time() do último alerta. Sem isto uma tarde de trabalho vira uma
-- enxurrada de SMS para cada membro: dá ~149 vendas fechadas só para subir ao nível 15.
local lastAlert = {}

local function ready()
    local cfg = Config.TerritoryAlert
    if not cfg or not cfg.Enable then return false end
    if GetResourceState('noir_territories') ~= 'started' then return false end
    if GetResourceState('sd-phone') ~= 'started' then return false end
    return true
end

---Bairro sob domínio de uma gang. Bairro neutro não tem quem avisar, e bairro em disputa
---não tem dono — o próprio noir_territories trata empate no topo como terra de ninguém.
---@return table? status { zone, gang, state, counts, required }
local function controlledZoneAt(coords)
    local ok, status = pcall(function()
        return exports.noir_territories:getTerritoryAt(coords)
    end)
    if not ok or type(status) ~= 'table' then return end
    if status.state ~= 'controlled' or type(status.gang) ~= 'string' then return end
    return status
end

local function sellerGangName(source)
    if GetResourceState('noir_gangs') ~= 'started' then return end
    local ok, gang = pcall(function() return exports.noir_gangs:GetGang(source) end)
    if not ok or type(gang) ~= 'table' then return end
    return gang.name
end

---Nome apresentável do bairro ('vespucci_beach' -> 'Vespucci Beach').
local function zoneLabel(zone)
    local ok, territory = pcall(function() return exports.noir_territories:GetTerritory(zone) end)
    if ok and type(territory) == 'table' and type(territory.label) == 'string' then
        return territory.label
    end
    return (zone or '?'):gsub('_', ' ')
end

---Membros da gang, inclusive quem está offline: a mensagem fica guardada e aparece no
---próximo login. Passa pelo bgrz_core, que é a fronteira com o Qbox.
local function membersOf(gang)
    local ok, members = pcall(function() return exports.bgrz_core:GetGangMembers(gang) end)
    if not ok or type(members) ~= 'table' then return {} end
    return members
end

---Chamado a cada venda fechada. Silencioso quando a venda foi em casa ou em terra de
---ninguém, que é o caso da maioria delas.
---@param source number
function NoirDrugTerritory.onSale(source)
    if not ready() then return end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local status = controlledZoneAt(coords)
    if not status then return end

    -- Vender na própria área é o negócio da gang, não invasão.
    if sellerGangName(source) == status.gang then return end

    local cfg = Config.TerritoryAlert
    local cooldown = tonumber(cfg.CooldownSeconds) or 300
    local key = ('%s:%s'):format(status.gang, status.zone or '?')
    local now = os.time()
    if lastAlert[key] and (now - lastAlert[key]) < cooldown then return end
    lastAlert[key] = now

    local label = zoneLabel(status.zone)
    local body = TranslateIt('territory_alert_body', label)
    local sent = 0

    for _, member in ipairs(membersOf(status.gang)) do
        local number = exports['sd-phone']:getPhoneNumberByIdentifier(member.citizenId)
        if number then
            exports['sd-phone']:sendLocation(
                cfg.SenderNumber, cfg.SenderName, number,
                coords.x, coords.y,
                { label = label, body = body }
            )
            sent = sent + 1
        end
    end

    debugPrint('territory alert', status.gang, label, ('%d membros'):format(sent))
end
