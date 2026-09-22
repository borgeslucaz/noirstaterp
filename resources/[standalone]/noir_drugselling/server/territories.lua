-- Alerta de invasão: venda de droga dentro de bairro dominado por gang.
--
-- Quem não é da gang dona vender ali dispara uma mensagem no celular de todos os membros
-- dela, com o pino do lugar. É o que dá à gang a chance de responder — sem isso, tomar a
-- rua só aparece no mapa, depois, sem ninguém para reagir.
--
-- O domínio vem do noir_territories e o celular do sd-phone. Os dois são opcionais: sem eles a
-- venda acontece igual, só não avisa ninguém. É o oposto do noir_skills, que é dependency
-- dura — lá a falta quebraria a progressão em silêncio, aqui ela só desliga um aviso.
--
-- A venda também move influência: vender num bairro é trabalhar a rua, e a rua responde. O
-- quanto vale não está aqui de propósito — este arquivo diz que uma venda fechou, e o
-- noir_territories decide o que isso significa no mapa (`Config.Influence.Rates.drug_sale`).
-- É a mesma fronteira que o noir_graffiti respeita: quem vende não decide o que é domínio.

NoirDrugTerritory = {}

-- ['gang:bairro'] = os.time() do último alerta. Sem isto uma tarde de trabalho vira uma
-- enxurrada de SMS para cada membro: dá ~149 vendas fechadas só para subir ao nível 15.
local lastAlert = {}

---A venda rende influência sempre que o noir_territories estiver de pé. O aviso é outra
---história e tem outras condições — foram coisas separadas desde que a influência entrou, e
---juntá-las de novo faria desligar o SMS parar de mover o mapa.
local function canCredit()
    return GetResourceState('noir_territories') == 'started'
end

local function canAlert()
    local cfg = Config.TerritoryAlert
    if not cfg or not cfg.Enable then return false end
    if GetResourceState('sd-phone') ~= 'started' then return false end
    return true
end

---Situação do bairro onde a venda aconteceu, dominado ou não.
---@return table? status { zone, state, conquerable, gang?, influence, neutral, total, required }
local function zoneAt(coords)
    local ok, status = pcall(function()
        return exports.noir_territories:getTerritoryAt(coords)
    end)
    if not ok or type(status) ~= 'table' or type(status.zone) ~= 'string' then return end
    return status
end

---A venda rende influência para a gang de quem vendeu, no bairro onde ela aconteceu.
---
---Vale em bairro neutro também — é assim que uma gang começa a tomar a rua trabalhando nela,
---sem depender de pichar. Bairro fixo e bairro fora do mapa não rendem nada, e quem recusa é
---o noir_territories: a regra de o que está em jogo é dele, não deste arquivo.
---@return boolean gained, string? refusal
local function creditInfluence(zone, gang)
    if type(gang) ~= 'string' or gang == '' or gang == 'none' then return false end

    local ok, gained, _, refusal = pcall(function()
        return exports.noir_territories:grantInfluence(zone, gang, 'drug_sale')
    end)
    if not ok then return false end

    return gained == true, refusal
end

---Nome apresentável do bairro ('vespucci_beach' -> 'Vespucci Beach').
local function zoneLabel(zone)
    local ok, territory = pcall(function() return exports.noir_territories:GetTerritory(zone) end)
    if ok and type(territory) == 'table' and type(territory.label) == 'string' then
        return territory.label
    end
    return (zone or '?'):gsub('_', ' ')
end

---Quem vendeu fica sabendo o que a venda fez pelo território.
---
---Sem isto, a influência é invisível: o jogador vende trinta vezes e não tem como saber se
---aquilo mexeu no mapa, se a área estava protegida, ou se ele está trabalhando de graça. Dois
---avisos só — ganhou, e não ganhou porque a área está travada. O resto (bairro fixo, fora do
---mapa, sistema fora do ar) é silêncio: são casos em que nunca houve disputa para explicar.
local function tellSeller(source, zone, gained, refusal)
    local label = zoneLabel(zone)

    if gained then
        TriggerClientEvent('op-drugselling:sendNotify', source,
            TranslateIt('territory_influence_gained', label), 'success', 5)
    elseif refusal == 'protected' then
        TriggerClientEvent('op-drugselling:sendNotify', source,
            TranslateIt('territory_influence_locked', label), 'info', 5)
    end
end

local function sellerGangName(source)
    if GetResourceState('noir_gangs') ~= 'started' then return end
    local ok, gang = pcall(function() return exports.noir_gangs:GetGang(source) end)
    if not ok or type(gang) ~= 'table' then return end
    return gang.name
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
    if not canCredit() then return end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local status = zoneAt(coords)
    if not status then return end

    local seller = sellerGangName(source)
    local gained, refusal = creditInfluence(status.zone, seller)

    -- Só quem tem gang recebe o retorno: para quem não tem, influência não é um assunto, e um
    -- aviso sobre território a cada venda seria ruído num sistema do qual ele não participa.
    if seller then tellSeller(source, status.zone, gained, refusal) end

    -- Daqui para baixo é só o aviso de invasão, que é outra pergunta: bairro sem dono não tem
    -- a quem avisar. Bairro sob desafio tem — o dono continua dono até a trava cair, e é
    -- justamente ele que precisa saber que estão trabalhando a rua dele.
    if not canAlert() then return end
    if status.state ~= 'controlled' or type(status.gang) ~= 'string' then return end

    -- Vender na própria área é o negócio da gang, não invasão.
    if seller == status.gang then return end

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
