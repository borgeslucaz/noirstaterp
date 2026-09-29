-- Harness: carrega o territories.lua real com os exports stubados.
local RES = (os.getenv('RES') or './')

Config = {
    TerritoryAlert = { Enable = true, SenderNumber = '0800', SenderName = 'Rua', CooldownSeconds = 300 },
}
function TranslateIt(key, label) return key .. ':' .. tostring(label) end
function debugPrint() end

local started = { noir_territories = true, ['sd-phone'] = true, noir_gangs = true, bgrz_core = true }
function GetResourceState(n) return started[n] and 'started' or 'missing' end
function GetPlayerPed() return 1 end
function GetEntityCoords() return { x = 100.0, y = 200.0, z = 30.0 } end

-- Aviso na tela de quem vendeu. Guardar o texto e nao so a contagem: foi um `zoneLabel` fora
-- de escopo que quase passou, e ele so aparece quando alguem olha o que saiu escrito.
function TriggerClientEvent(event, target, text, kind)
    if event == 'op-drugselling:sendNotify' then
        notified[#notified + 1] = { target = target, text = text, kind = kind }
    end
end

-- Estado que cada caso ajusta
local world = { status = nil, sellerGang = nil, members = {}, numbers = {}, refusal = nil }
sent = {}
granted = {}
notified = {}

exports = {
    noir_territories = {
        getTerritoryAt = function(_, _) return world.status end,
        GetTerritory = function(_, zone) return { label = 'Vespucci Beach', name = zone } end,
        -- Quanto vale uma venda é decisão do noir_territories; daqui sai só o fato.
        grantInfluence = function(_, zone, gang, reason)
            granted[#granted + 1] = { zone = zone, gang = gang, reason = reason }
            -- O terceiro retorno é a recusa: o mundo do teste decide se a area esta travada.
            if world.refusal then return false, 0, world.refusal end
            return true, 150, nil
        end,
    },
    noir_gangs = {
        GetGang = function(_, _) return world.sellerGang and { name = world.sellerGang } or nil end,
    },
    bgrz_core = {
        GetGangMembers = function(_, _) return world.members end,
    },
    ['sd-phone'] = {
        getPhoneNumberByIdentifier = function(_, cid) return world.numbers[cid] end,
        sendLocation = function(_, _, _, number, x, y, opts)
            sent[#sent + 1] = { number = number, x = x, y = y, body = opts.body }
            return true
        end,
    },
}

dofile(RES .. 'server/territories.lua')

local fails = 0
local function check(cond, msg)
    print((cond and '  ok   ' or '  FALHA ') .. msg)
    if not cond then fails = fails + 1 end
end

local function reset(status, sellerGang)
    world.status = status
    world.sellerGang = sellerGang
    world.members = { { citizenId = 'A' }, { citizenId = 'B' }, { citizenId = 'C' } }
    world.numbers = { A = '5551111', B = '5552222' } -- C nunca pegou numero
    sent = {}
    granted = {}
    notified = {}
    world.refusal = nil
    -- zera o cooldown recarregando o modulo
    dofile(RES .. 'server/territories.lua')
end

local controlled = { state = 'controlled', gang = 'ballas', zone = 'vespucci_beach' }

print('bairro dominado, vendedor de fora:')
reset(controlled, 'vagos')
NoirDrugTerritory.onSale(1)
check(#sent == 2, 'avisa os membros com numero (2 de 3)')
check(sent[1] and sent[1].body == 'territory_alert_body:Vespucci Beach',
    'corpo sai da locale certa e traz o bairro apresentavel')
check(sent[1] and sent[1].x == 100.0, 'pino na coordenada da venda')

print('vendedor sem gang nenhuma:')
reset(controlled, nil)
NoirDrugTerritory.onSale(1)
check(#sent == 2, 'tambem avisa: quem nao tem gang tambem esta invadindo')

print('vendedor da propria gang dona:')
reset(controlled, 'ballas')
NoirDrugTerritory.onSale(1)
check(#sent == 0, 'nao avisa ninguem')

print('bairro em disputa:')
reset({ state = 'contested', gangs = { 'ballas', 'vagos' }, zone = 'vespucci_beach' }, 'lostmc')
NoirDrugTerritory.onSale(1)
check(#sent == 0, 'empate no topo nao tem dono para avisar')

print('bairro neutro:')
reset({ state = 'neutral', zone = 'vespucci_beach' }, 'vagos')
NoirDrugTerritory.onSale(1)
check(#sent == 0, 'sem dominio, sem aviso')
check(#granted == 1 and granted[1].gang == 'vagos', 'mas a venda rende influencia igual')

print('influencia:')
reset(controlled, 'vagos')
NoirDrugTerritory.onSale(1)
check(#granted == 1 and granted[1].reason == 'drug_sale' and granted[1].zone == 'vespucci_beach',
    'o fato sai daqui, sem numero junto')

reset(controlled, nil)
NoirDrugTerritory.onSale(1)
check(#granted == 0, 'quem nao tem gang nao rende influencia para ninguem')

reset(nil, 'vagos')
NoirDrugTerritory.onSale(1)
check(#granted == 0, 'venda fora de bairro mapeado nao rende nada')

print('aviso para quem vendeu:')
reset(controlled, 'vagos')
NoirDrugTerritory.onSale(1)
check(#notified == 1 and notified[1].text == 'territory_influence_gained:Vespucci Beach',
    'ganhou influencia -> a tela diz em que area')
check(notified[1].target == 1 and notified[1].kind == 'success', 'para quem vendeu, como sucesso')

reset(controlled, 'vagos')
world.refusal = 'protected'
NoirDrugTerritory.onSale(1)
check(#notified == 1 and notified[1].text == 'territory_influence_locked:Vespucci Beach',
    'area protegida -> a tela diz por que nao rendeu')

reset(controlled, nil)
NoirDrugTerritory.onSale(1)
check(#notified == 0, 'quem nao tem gang nao recebe aviso de territorio')

print('sd-phone desligado nao para a influencia:')
reset(controlled, 'vagos')
started['sd-phone'] = false
NoirDrugTerritory.onSale(1)
started['sd-phone'] = true
check(#granted == 1 and #sent == 0, 'o mapa anda mesmo com o celular fora do ar')

print('cooldown:')
reset(controlled, 'vagos')
NoirDrugTerritory.onSale(1)
local first = #sent
NoirDrugTerritory.onSale(1)
NoirDrugTerritory.onSale(1)
check(first == 2 and #sent == 2, 'vendas seguidas no mesmo bairro nao repetem o aviso')

print('outro bairro, mesma gang:')
reset(controlled, 'vagos')
NoirDrugTerritory.onSale(1)
world.status = { state = 'controlled', gang = 'ballas', zone = 'grove_street' }
NoirDrugTerritory.onSale(1)
check(#sent == 4, 'cooldown e por bairro, nao por gang')

print('sd-phone desligado:')
reset(controlled, 'vagos')
started['sd-phone'] = false
NoirDrugTerritory.onSale(1)
started['sd-phone'] = true
check(#sent == 0, 'nao estoura, so nao avisa')

print('')
print(fails == 0 and 'alert_spec: ok' or ('alert_spec: ' .. fails .. ' falha(s)'))
os.exit(fails == 0 and 0 or 1)
