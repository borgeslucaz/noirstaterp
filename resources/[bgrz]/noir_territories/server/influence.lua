-- Influência, lado servidor: o dono do registro.
--
-- O cliente tem uma cópia para desenhar e para responder sem viagem de rede, mas quem escreve
-- é só este arquivo, e só a pedido de outro resource do servidor. Nenhum evento de cliente
-- concede influência — seria o `TriggerServerEvent('tomeiOBairro')` que o §7 proíbe.
--
-- Isto é um livro-caixa, não um retrato: os pontos são persistidos e sobrevivem a restart,
-- reconstrução de graffiti e queda de banco. É a diferença que faz o modelo funcionar — se a
-- influência fosse recalculada a partir do mundo a cada start, ela só poderia refletir o que o
-- mundo ainda mostra, e uma venda feita ontem não teria deixado marca nenhuma.

local ready = false

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
-- Só DDL idempotente e não destrutivo passa. O arquivo roda a cada start, então nada aqui
-- pode apagar dado. É a mesma guarda do noir_gangs, e pela mesma razão.
local ALLOWED_STATEMENTS = {
    '^CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+',
    '^CREATE%s+INDEX%s+IF%s+NOT%s+EXISTS%s+',
    '^ALTER%s+TABLE%s+[%w_`]+%s+ADD%s+COLUMN%s+IF%s+NOT%s+EXISTS%s+',
}

local function isAllowedStatement(statement)
    local upper = statement:upper()
    for i = 1, #ALLOWED_STATEMENTS do
        if upper:match(ALLOWED_STATEMENTS[i]) then return true end
    end
    return false
end

---@return boolean ok
local function runSchema()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/noir_territories.sql')
    if not sql or sql == '' then
        lib.print.error('[noir_territories] migrations/noir_territories.sql não encontrado')
        return false
    end

    -- Tira comentários antes de separar por `;`, senão um ponto e vírgula dentro de comentário
    -- vira o começo de um statement falso.
    sql = sql:gsub('%-%-[^\r\n]*', '')

    for rawStatement in sql:gmatch('([^;]+);') do
        local statement = rawStatement:gsub('^%s*(.-)%s*$', '%1')
        if statement ~= '' then
            if not isAllowedStatement(statement) then
                lib.print.error(('[noir_territories] statement recusado: %s'):format(statement:sub(1, 80)))
                return false
            end
            MySQL.query.await(statement)
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Carga e escrita
-- ---------------------------------------------------------------------------

local function load()
    local zones = {}

    for _, row in ipairs(MySQL.query.await('SELECT zone, gang, points FROM noir_territory_influence') or {}) do
        zones[row.zone] = zones[row.zone] or {}
        zones[row.zone][row.gang] = row.points
    end

    NoirInfluence.replaceAll(zones)
end

---Grava o que mudou, e só o que mudou. Ponto zero vira DELETE: no registro em memória zero é
---a ausência do valor, e a tabela segue a mesma regra para não virar um cemitério de linhas
---com `points = 0`.
local function persist(zone, changes)
    local writes = {}

    for gang, points in pairs(changes) do
        if points > 0 then
            writes[#writes + 1] = {
                query = 'INSERT INTO noir_territory_influence (zone, gang, points) VALUES (?, ?, ?) '
                    .. 'ON DUPLICATE KEY UPDATE points = VALUES(points)',
                values = { zone, gang, points },
            }
        else
            writes[#writes + 1] = {
                query = 'DELETE FROM noir_territory_influence WHERE zone = ? AND gang = ?',
                values = { zone, gang },
            }
        end
    end

    if #writes == 0 then return end
    MySQL.transaction.await(writes)
end

local function broadcast(zone, changes)
    TriggerClientEvent('noir_territories:client:influence', -1, 'patch',
        { zone = zone, changes = changes })
end

-- ---------------------------------------------------------------------------
-- API
-- ---------------------------------------------------------------------------

---Bairro precisa existir para receber influência. Sem isto, um nome digitado errado do outro
---lado viraria uma linha no banco que ninguém nunca lê e um ponto que a gang nunca vê.
local function knownZone(zone)
    if type(zone) ~= 'string' or zone == '' then return false end
    return NoirTerritories.get(zone) ~= nil
end

---Move influência de uma gang num bairro. É a única porta de entrada do sistema: graffiti,
---venda, guerra e o que vier chamam aqui.
---
---@param zone string nome do bairro no Zone Manager
---@param gang string nome da gang
---@param amount number positivo ganha, negativo perde
---@param reason? string de onde veio, só para log
---@return boolean ok, number applied quanto entrou de fato — pode ser menos do que se pediu
---quando o pool não tinha de onde tirar, e é esse número que o graffiti guarda para devolver
---exatamente a mesma quantia quando a tag for apagada
---@return string? refusal `'protected'` quando a trava de domínio segurou o movimento — é o
---único motivo que quem chama tem como explicar para o jogador
local function addInfluence(zone, gang, amount, reason)
    if not ready then return false end
    if not knownZone(zone) then return false end
    if type(gang) ~= 'string' or gang == '' or gang == 'none' then return false end

    -- Bairro fixo não está em jogo, e é aqui que isso vira recusa em vez de enfeite de tela:
    -- sem esta linha, o mapa mostraria "ÁREA FIXA" enquanto o banco enchia de pontos.
    if not NoirClaims.isConquerable(zone) then return false end

    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return false end

    -- Teto por chamada. Não é anti-cheat — quem chama é outro resource do servidor —, é
    -- anti-engano: um `amount` vindo de conta errada não pode virar o mapa inteiro de uma vez.
    local cap = Config.Influence.Total
    if amount > cap then amount = cap elseif amount < -cap then amount = -cap end

    -- Trava de domínio: o dono não perde e ninguém de fora ganha. O cheque é antes do `grant`
    -- porque o ganho de um é a perda de todos os outros, e não há como desfazer depois.
    if NoirOwnership.protects(zone, gang, amount, os.time()) then return false, 0, 'protected' end

    local before = NoirInfluence.get(zone, gang)
    local changes = NoirInfluence.grant(zone, gang, amount)
    if next(changes) == nil then return false, 0 end

    persist(zone, changes)
    broadcast(zone, changes)

    -- A placa se decide a partir da influência, então ela é reavaliada depois de toda mudança —
    -- e não por um laço perguntando de tempos em tempos.
    NoirOwnershipServer.refresh(zone)

    -- Aconteceu alguma coisa aqui: o relógio do abandono volta a zero. Menos quando o que
    -- aconteceu foi o próprio esfriamento — ele não é notícia de rua, e carimbar aqui faria o
    -- bairro parado nunca esfriar uma segunda vez.
    if reason ~= 'decay' and NoirDecay then NoirDecay.touch(zone) end

    if Config.DebugTerritories then
        print(('[noir_territories] influencia %s %+d em %s (%s)'):format(
            gang, amount, zone, reason or 'sem motivo'))
    end

    return true, NoirInfluence.get(zone, gang) - before
end

---Escreve a fatia de uma gang sem tirar de ninguém. É ferramenta de administração e de
---correção, não de jogo: ela fura o pool de propósito, e por isso não tem atalho em jogo.
local function setInfluence(zone, gang, points)
    if not ready or not knownZone(zone) then return false end
    if type(gang) ~= 'string' or gang == '' or gang == 'none' then return false end

    local changes = { [gang] = NoirInfluence.set(zone, gang, points) }
    persist(zone, changes)
    broadcast(zone, changes)
    return true
end

---Concede o que um fato do mundo vale. É a porta que os outros resources usam: eles dizem o
---que aconteceu — `'graffiti'`, `'drug_sale'` —, não quanto isso vale. O número está no
---`Config.Influence.Rates`, deste lado, porque quem picha e quem vende não decidem o que é
---domínio; e um ajuste de balanceamento é uma linha no config daqui, não uma caçada por
---números soltos no código de três resources.
---@param reason string chave em `Config.Influence.Rates`
---@param sign? number 1 concede (padrão), -1 devolve
---@return boolean ok, number applied, string? refusal ver `addInfluence`
local function grantInfluence(zone, gang, reason, sign)
    local rate = Config.Influence.Rates[reason]
    if not rate then
        lib.print.error(('[noir_territories] motivo sem taxa: %s'):format(tostring(reason)))
        return false, 0
    end

    -- O bônus de azarão entra aqui e não no `addInfluence`: ele é uma propriedade do fato que
    -- aconteceu no mundo, não da aritmética do pool. Quem chama `addInfluence` com um número na
    -- mão é administração, e administração recebe o número que digitou.
    if (tonumber(sign) or 1) < 0 then return addInfluence(zone, gang, -rate, reason) end
    return addInfluence(zone, gang, NoirInfluence.effective(zone, gang, rate), reason)
end

-- ---------------------------------------------------------------------------
-- Concessões reversíveis
-- ---------------------------------------------------------------------------
-- Fato que pode ser desfeito — uma tag apagada, uma coisa cancelada — precisa devolver
-- exatamente o que rendeu, e não a taxa do config: com o bônus de azarão os dois números são
-- diferentes, e a diferença viraria lucro repetível. Cada concessão fica guardada pela chave de
-- quem a produziu.

local grants = {}    -- grant_key -> { zone, gang, points }

local function loadGrants()
    for _, row in ipairs(MySQL.query.await(
        'SELECT grant_key, zone, gang, points, revoked_at FROM noir_territory_grant') or {}) do
        grants[row.grant_key] = {
            zone = row.zone, gang = row.gang, points = row.points,
            -- Dívida pendente: a tag já sumiu, a devolução foi pedida e a trava recusou.
            revokedAt = row.revoked_at,
        }
    end
end

---Concede o que um fato vale e guarda quanto foi, pela chave dele.
---@param key string identificador do fato de quem o produziu, ex. 'graffiti:1734'
---@return boolean ok
local function grantOnce(key, zone, gang, reason)
    if type(key) ~= 'string' or key == '' then return false end

    -- Mesma chave duas vezes é a mesma coisa acontecendo duas vezes, e não acontece: sem esta
    -- guarda, um resource que reenvia o mesmo id depois de reconectar pagaria em dobro.
    if grants[key] then return false end

    local ok, applied = grantInfluence(zone, gang, reason)
    if not ok or applied <= 0 then return false end

    grants[key] = { zone = zone, gang = gang, points = applied }
    MySQL.query.await(
        'INSERT INTO noir_territory_grant (grant_key, zone, gang, points) VALUES (?, ?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE points = VALUES(points)',
        { key, zone, gang, applied })

    return true
end

local function forgetGrant(key)
    grants[key] = nil
    MySQL.query.await('DELETE FROM noir_territory_grant WHERE grant_key = ?', { key })
end

---Tenta devolver o que a concessão rendeu. Some do livro só quando a devolução acontece de fato.
---@return boolean settled
local function settleGrant(key, grant)
    local ok = addInfluence(grant.zone, grant.gang, -grant.points, 'revogado')
    if ok then
        forgetGrant(key)
        return true
    end

    -- Recusada: o bairro está travado. A linha fica, marcada como dívida, e o relógio volta aqui
    -- quando a trava cair. Apagá-la agora seria criar pontos do nada — a tag não existe mais e
    -- ninguém pediria a devolução de novo.
    if not grant.revokedAt then
        grant.revokedAt = os.time()
        MySQL.query.await('UPDATE noir_territory_grant SET revoked_at = ? WHERE grant_key = ?',
            { grant.revokedAt, key })
    end

    return false
end

---Devolve exatamente o que aquela concessão rendeu.
---@return boolean settled false quando a devolução ficou pendente, esperando a trava cair
local function revokeOnce(key)
    local grant = type(key) == 'string' and grants[key] or nil
    if not grant or grant.revokedAt then return false end
    return settleGrant(key, grant)
end

---Liquida o que ficou esperando. Roda sozinho porque ninguém vai pedir de novo: a tag que
---originou a dívida já não existe.
local function settlePending()
    for key, grant in pairs(grants) do
        if grant.revokedAt then settleGrant(key, grant) end
    end
end

---Apaga tudo que um bairro tem: a fatia de cada gang, as concessões e as dívidas pendentes.
---Ferramenta de teste — é o que devolve o bairro ao 1000 neutro para montar o caso seguinte.
---@return number quantas gangs foram zeradas
local function clearZone(zone)
    if not ready or not knownZone(zone) then return 0 end

    -- Os nomes primeiro: `setInfluence` mexe na tabela que o `pairs` está percorrendo.
    local gangs = {}
    for gang in pairs(NoirInfluence.of(zone)) do gangs[#gangs + 1] = gang end
    for i = 1, #gangs do setInfluence(zone, gangs[i], 0) end

    for key, grant in pairs(grants) do
        if grant.zone == zone then forgetGrant(key) end
    end

    return #gangs
end

---Uso interno do resource: o graffiti concede influência por aqui, sem passar pela tabela de
---exports do próprio resource só para falar consigo mesmo.
NoirInfluenceServer = {
    add = addInfluence,
    set = setInfluence,
    grant = grantInfluence,
    grantOnce = grantOnce,
    revokeOnce = revokeOnce,
    clearZone = clearZone,
    ---A placa de domínio se decide a partir da influência e não pode carregar antes dela.
    ready = function() return ready end,
}

exports('grantInfluence', grantInfluence)
exports('grantOnceInfluence', grantOnce)
exports('revokeOnceInfluence', revokeOnce)
exports('addInfluence', addInfluence)
exports('setInfluence', setInfluence)
exports('getInfluence', function(zone, gang) return NoirInfluence.get(zone, gang) end)
exports('getZoneInfluence', function(zone)
    local _, neutral = NoirInfluence.sumOf(zone)
    return { influence = NoirInfluence.of(zone), neutral = neutral, total = Config.Influence.Total }
end)

---Cliente entrando agora, ou resource dele reiniciando, pede o quadro inteiro.
RegisterNetEvent('noir_territories:server:requestInfluence', function()
    local source = source
    if not ready then return end
    TriggerClientEvent('noir_territories:client:influence', source, 'set', NoirInfluence.zones)
end)

CreateThread(function()
    if not runSchema() then
        lib.print.error('[noir_territories] influência desligada: o schema não subiu')
        return
    end

    load()
    loadGrants()
    ready = true

    -- As dívidas que sobraram da sessão anterior: a trava pode ter caído com o servidor fora do
    -- ar, e nesse caso elas já podem ser pagas agora.
    settlePending()

    CreateThread(function()
        while true do
            Wait(60000)
            settlePending()
        end
    end)

    -- Quem já estava conectado quando o resource reiniciou não vai pedir de novo.
    TriggerClientEvent('noir_territories:client:influence', -1, 'set', NoirInfluence.zones)
end)
