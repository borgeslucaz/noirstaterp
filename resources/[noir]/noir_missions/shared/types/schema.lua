---Esquema da definição de missão: o que existe, com que campos, e como o editor desenha cada
---campo. É o contrato entre o editor (NUI), a validação (`shared/types/definition.lua`) e o
---runtime (`server/components/*`).
---
---Componente novo = uma entrada aqui + um handler registrado no servidor. A NUI é genérica:
---ela desenha o formulário a partir destes campos, sem saber o que é um "reforço".
---
---Tipos de campo que a NUI entende:
---  text, textarea, number, bool, select, position, positions, model, ref, refs, actions,
---  condition, list, item, weapon, minigame, strings, var
---
---`showIf = { key = 'mode', is = { 'carry' } }` esconde o campo quando o irmão `key` não tem
---um dos valores. Esconder não apaga o valor; a validação ignora campo escondido.
local Schema = {}

local function field(fieldType, key, label, extra)
    local out = { type = fieldType, key = key, label = label }
    if extra then for name, value in pairs(extra) do out[name] = value end end
    return out
end

local F = {}
function F.text(key, label, extra) return field('text', key, label, extra) end
function F.textarea(key, label, extra) return field('textarea', key, label, extra) end
function F.number(key, label, extra) return field('number', key, label, extra) end
function F.bool(key, label, extra) return field('bool', key, label, extra) end
function F.select(key, label, options, extra)
    extra = extra or {}
    extra.options = options
    return field('select', key, label, extra)
end
function F.position(key, label, extra) return field('position', key, label, extra) end
function F.positions(key, label, extra) return field('positions', key, label, extra) end
function F.model(key, label, kind, extra)
    extra = extra or {}
    extra.kind = kind
    return field('model', key, label, extra)
end
function F.ref(key, label, collection, extra)
    extra = extra or {}
    extra.ref = collection
    return field('ref', key, label, extra)
end
function F.refs(key, label, collection, extra)
    extra = extra or {}
    extra.ref = collection
    return field('refs', key, label, extra)
end
function F.actions(key, label, extra) return field('actions', key, label, extra) end
function F.condition(key, label, extra) return field('condition', key, label, extra) end
function F.list(key, label, fields, extra)
    extra = extra or {}
    extra.fields = fields
    return field('list', key, label, extra)
end
function F.item(key, label, extra) return field('item', key, label, extra) end
function F.weapon(key, label, extra) return field('weapon', key, label, extra) end
function F.minigame(key, label, extra) return field('minigame', key, label, extra) end
function F.strings(key, label, extra) return field('strings', key, label, extra) end
function F.var(key, label, extra) return field('var', key, label, extra) end

Schema.F = F

local function showIf(key, ...)
    return { key = key, is = { ... } }
end

-- Opções reutilizadas --------------------------------------------------------------------

local WHO = {
    { value = 'any', label = 'Qualquer participante' },
    { value = 'all', label = 'Todos os participantes' },
}

local BLIP_COLORS = {
    { value = 1, label = 'Vermelho' }, { value = 2, label = 'Verde' }, { value = 3, label = 'Azul' },
    { value = 5, label = 'Amarelo' }, { value = 17, label = 'Laranja' }, { value = 27, label = 'Roxo' },
    { value = 0, label = 'Branco' }, { value = 40, label = 'Cinza escuro' },
}

local DRIVING = {
    { value = 'normal', label = 'Normal' },
    { value = 'rushed', label = 'Com pressa' },
    { value = 'aggressive', label = 'Agressivo' },
}

local NOTIFY = {
    { value = 'inform', label = 'Informação' },
    { value = 'success', label = 'Sucesso' },
    { value = 'warning', label = 'Alerta' },
    { value = 'error', label = 'Erro' },
}

-- Ped individual: usado em grupos, tripulação de reforço e de perseguição.
local function pedFields(withPosition)
    local fields = {
        F.model('model', 'Modelo', 'ped', { default = 'g_m_y_mexgoon_01', required = true }),
    }
    if withPosition then
        fields[#fields + 1] = F.position('coords', 'Posição', {
            heading = true, preview = { kind = 'ped', modelKey = 'model' }, required = true,
        })
    end
    local rest = {
        F.weapon('weapon', 'Arma', { default = 'WEAPON_PISTOL' }),
        F.number('armor', 'Colete', { min = 0, max = 100, default = 0 }),
        F.number('health', 'Vida', { min = 100, max = 1000, default = 200 }),
        F.number('accuracy', 'Precisão', { min = 0, max = 100, default = 35 }),
        F.select('combatAbility', 'Habilidade de combate', {
            { value = 0, label = 'Fraca' }, { value = 1, label = 'Média' }, { value = 2, label = 'Profissional' },
        }, { default = 1 }),
        F.select('combatRange', 'Distância de combate', {
            { value = 0, label = 'Perto' }, { value = 1, label = 'Média' }, { value = 2, label = 'Longe' },
        }, { default = 1 }),
    }
    for index = 1, #rest do fields[#fields + 1] = rest[index] end
    if withPosition then
        fields[#fields + 1] = F.select('movement', 'Movimento', {
            { value = 'static', label = 'Parado' },
            { value = 'scenario', label = 'Cenário (animação)' },
            { value = 'patrol', label = 'Patrulha na área' },
        }, { default = 'static' })
        fields[#fields + 1] = F.text('scenario', 'Cenário', {
            default = 'WORLD_HUMAN_GUARD_STAND', showIf = showIf('movement', 'scenario'),
            help = 'Nome do cenário do jogo, ex.: WORLD_HUMAN_GUARD_STAND, WORLD_HUMAN_SMOKING.',
        })
        fields[#fields + 1] = F.number('patrolRadius', 'Raio da patrulha', {
            min = 2, max = 60, default = 10, showIf = showIf('movement', 'patrol'),
        })
    end
    return fields
end

Schema.pedFields = pedFields

-- Metadados ------------------------------------------------------------------------------

Schema.general = {
    F.text('name', 'Nome', { required = true, maxLength = 64 }),
    F.text('id', 'ID interno', { readonly = true }),
    F.textarea('description', 'Descrição', { maxLength = 500 }),
    F.text('category', 'Categoria', { default = 'geral', maxLength = 24, help = 'Ex.: meth, coke.' }),
    F.select('difficulty', 'Dificuldade', {
        { value = 'easy', label = 'Fácil' }, { value = 'medium', label = 'Média' }, { value = 'hard', label = 'Difícil' },
    }, { default = 'medium' }),
    F.number('minPlayers', 'Mínimo de jogadores', { min = 1, max = 16, default = 1 }),
    F.number('maxPlayers', 'Máximo de jogadores', { min = 1, max = 16, default = 4 }),
    F.number('cooldownMinutes', 'Cooldown (minutos)', { min = 0, max = 10080, default = 60 }),
    F.number('timeLimitMinutes', 'Tempo limite (minutos)', { min = 0, max = 240, default = 60, help = '0 = sem limite.' }),
    F.bool('gangRequired', 'Exige gang', { default = false }),
    F.number('gangMinGrade', 'Cargo mínimo na gang', { min = 0, max = 20, default = 0, showIf = showIf('gangRequired', true) }),
    F.number('participantRadius', 'Raio para puxar membros', {
        min = 0, max = 500, default = 60,
        help = 'Membros da mesma gang até esta distância de quem aceitou entram na missão. 0 = só quem aceitou.',
    }),
}

Schema.start = {
    F.select('type', 'Como começa', {
        { value = 'phone', label = 'Ligação (oferta)' },
        { value = 'npc', label = 'NPC' },
        { value = 'zone', label = 'Entrar numa zona' },
        { value = 'command', label = 'Comando de admin' },
        { value = 'export', label = 'Export / evento de outro resource' },
    }, { default = 'phone' }),
    F.text('caller', 'Quem liga', { default = 'Desconhecido', showIf = showIf('type', 'phone', 'npc', 'zone') }),
    F.textarea('text', 'Texto da oferta', { maxLength = 300, showIf = showIf('type', 'phone', 'npc', 'zone') }),
    F.model('npcModel', 'Modelo do NPC', 'ped', { default = 'g_m_m_chicold_01', showIf = showIf('type', 'npc') }),
    F.position('npcCoords', 'Posição do NPC', {
        heading = true, preview = { kind = 'ped', modelKey = 'npcModel' }, showIf = showIf('type', 'npc'),
    }),
    F.text('npcScenario', 'Cenário do NPC', { default = 'WORLD_HUMAN_SMOKING', showIf = showIf('type', 'npc') }),
    F.text('npcLabel', 'Texto do alvo', { default = 'Conversar', showIf = showIf('type', 'npc') }),
    F.position('zoneCoords', 'Centro da zona', { showIf = showIf('type', 'zone') }),
    F.number('zoneRadius', 'Raio da zona', { min = 2, max = 200, default = 10, showIf = showIf('type', 'zone') }),
}

-- Coleções -------------------------------------------------------------------------------
-- Toda coleção é uma lista de objetos com `id` único dentro dela. Passos, ações e gatilhos
-- referenciam itens pelo id.

Schema.collections = {
    {
        key = 'variables', label = 'Variáveis', singular = 'variável', itemLabel = 'id',
        help = 'Estado da execução. Use {{nome}} em textos e nas condições.',
        fields = {
            F.select('type', 'Tipo', {
                { value = 'boolean', label = 'Sim/Não' }, { value = 'number', label = 'Número' },
                { value = 'string', label = 'Texto' },
            }, { default = 'boolean' }),
            F.text('default', 'Valor inicial', { help = 'true/false, número ou texto.' }),
            F.strings('random', 'Sortear entre', { help = 'Se tiver valores, um deles é sorteado no início de cada execução.' }),
        },
    },
    {
        key = 'zones', label = 'Zonas', singular = 'zona', itemLabel = 'label',
        help = 'Áreas usadas por gatilhos (entrar/sair) e pela hostilidade dos NPCs.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.position('coords', 'Centro', { required = true }),
            F.number('radius', 'Raio', { min = 1, max = 2000, default = 25 }),
        },
    },
    {
        key = 'pedGroups', label = 'NPCs', singular = 'grupo de NPC', itemLabel = 'label',
        help = 'Grupos de NPC com comportamento comum. A hostilidade é do grupo inteiro.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.bool('spawnOnStart', 'Aparece no início da missão', { default = false }),
            F.select('behavior', 'Comportamento', {
                { value = 'passive', label = 'Passivo' },
                { value = 'guard', label = 'Guarda (avisa antes)' },
                { value = 'hostile', label = 'Hostil de imediato' },
            }, { default = 'guard' }),
            F.ref('hostileZone', 'Fica hostil se entrarem na zona', 'zones', { optional = true }),
            F.bool('hostileOnAlarm', 'Fica hostil com o alarme', { default = true }),
            F.var('alarmVar', 'Variável do alarme', { default = 'alarm_active', showIf = showIf('hostileOnAlarm', true) }),
            F.bool('hostileOnShot', 'Fica hostil com tiro por perto', { default = true }),
            F.number('shotRadius', 'Raio do tiro', { min = 5, max = 300, default = 60, showIf = showIf('hostileOnShot', true) }),
            F.bool('hostileOnDamage', 'Fica hostil se um for ferido', { default = true }),
            F.bool('alarmOnHostile', 'Hostilidade liga o alarme', { default = false }),
            F.number('warnRadius', 'Raio do aviso', { min = 0, max = 60, default = 12, showIf = showIf('behavior', 'guard') }),
            F.strings('warnText', 'Falas de aviso', { showIf = showIf('behavior', 'guard') }),
            F.list('peds', 'NPCs', pedFields(true), { itemLabel = 'model', min = 1, max = 24 }),
        },
    },
    {
        key = 'vehicles', label = 'Veículos', singular = 'veículo', itemLabel = 'label',
        help = 'Veículos de missão (a van da carga, um barco). Para veículo com NPC dirigindo, use Reforços.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.model('model', 'Modelo', 'vehicle', { default = 'speedo', required = true }),
            F.position('coords', 'Posição', { heading = true, preview = { kind = 'vehicle', modelKey = 'model' }, required = true }),
            F.bool('spawnOnStart', 'Aparece no início da missão', { default = true }),
            F.bool('locked', 'Trancado', { default = false }),
            F.bool('giveKeys', 'Participantes recebem a chave', { default = true }),
            F.bool('required', 'Destruído = missão falha', { default = true }),
            F.number('cargoCapacity', 'Capacidade de carga', { min = 0, max = 50, default = 4 }),
            F.text('plate', 'Placa', { maxLength = 8, help = 'Vazio = aleatória.' }),
        },
    },
    {
        key = 'props', label = 'Objetos', singular = 'objeto', itemLabel = 'label',
        help = 'Cenário: caixas, mesas, computadores. Carga e interações têm os próprios objetos.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.model('model', 'Modelo', 'object', { required = true }),
            F.position('coords', 'Posição', { heading = true, preview = { kind = 'object', modelKey = 'model' }, required = true }),
            F.bool('spawnOnStart', 'Aparece no início da missão', { default = true }),
            F.bool('frozen', 'Fixo no lugar', { default = true }),
        },
    },
    {
        key = 'cargo', label = 'Carga', singular = 'grupo de carga', itemLabel = 'label',
        help = 'Objetos que os jogadores pegam, carregam, põem no veículo e entregam.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.model('model', 'Modelo', 'object', { default = 'prop_barrel_02a', required = true }),
            F.select('mode', 'Modo', {
                { value = 'carry', label = 'Carregar nas mãos' },
                { value = 'inventory', label = 'Vai para o inventário' },
                { value = 'interact', label = 'Só interação' },
            }, { default = 'carry' }),
            F.number('quantity', 'Quantidade certa', { min = 1, max = 50, default = 4 }),
            F.positions('pieces', 'Posições', {
                heading = true, preview = { kind = 'object', modelKey = 'model' }, min = 1, max = 50,
                help = 'Mais posições que a quantidade = as que sobram são iscas.',
            }),
            F.bool('randomizeCorrect', 'Sortear quais são as certas', { default = true }),
            F.bool('revealed', 'Visível desde o início', { default = false }),
            F.bool('inspect', 'Precisa inspecionar a etiqueta', { default = false }),
            F.text('correctLabel', 'Etiqueta da certa', { default = 'Lote {{cargo_batch}}', showIf = showIf('inspect', true) }),
            F.var('decoyVar', 'Iscas mostram outro valor de', { showIf = showIf('inspect', true),
                help = 'Variável com lista de sorteio. As iscas mostram um valor diferente do sorteado.' }),
            F.item('item', 'Item', { showIf = showIf('mode', 'inventory') }),
            F.number('amount', 'Quantidade do item', { min = 1, max = 100, default = 1, showIf = showIf('mode', 'inventory') }),
            F.select('carryPreset', 'Jeito de carregar', {
                { value = 'barrel', label = 'Tambor' }, { value = 'box', label = 'Caixa' },
                { value = 'package', label = 'Pacote' }, { value = 'custom', label = 'Personalizado' },
            }, { default = 'barrel', showIf = showIf('mode', 'carry') }),
            F.text('carryDict', 'Dicionário da animação', { showIf = showIf('carryPreset', 'custom') }),
            F.text('carryAnim', 'Animação', { showIf = showIf('carryPreset', 'custom') }),
            F.number('carryBone', 'Osso', { default = 28422, showIf = showIf('carryPreset', 'custom') }),
            F.text('carryOffset', 'Deslocamento (x,y,z)', { default = '0.0,0.0,0.0', showIf = showIf('carryPreset', 'custom') }),
            F.text('carryRotation', 'Rotação (x,y,z)', { default = '0.0,0.0,0.0', showIf = showIf('carryPreset', 'custom') }),
            F.bool('canSprint', 'Pode correr carregando', { default = false, showIf = showIf('mode', 'carry') }),
            F.bool('requireVehicle', 'Precisa ir num veículo', { default = true, showIf = showIf('mode', 'carry') }),
            F.select('vehicleMode', 'Veículos aceitos', {
                { value = 'mission', label = 'Só o veículo da missão' },
                { value = 'any', label = 'Qualquer veículo' },
                { value = 'class', label = 'Classes' },
                { value = 'models', label = 'Modelos' },
            }, { default = 'mission', showIf = showIf('requireVehicle', true) }),
            F.ref('vehicleId', 'Veículo da missão', 'vehicles', { showIf = showIf('vehicleMode', 'mission') }),
            F.strings('vehicleClasses', 'Classes (número)', { showIf = showIf('vehicleMode', 'class'), help = '12 = vans, 20 = comerciais, 14 = barcos.' }),
            F.strings('vehicleModels', 'Modelos', { showIf = showIf('vehicleMode', 'models') }),
        },
    },
    {
        key = 'interactions', label = 'Interações', singular = 'interação', itemLabel = 'label',
        help = 'Computador para hackear, gaveta para revistar, painel para desligar.',
        fields = {
            F.text('label', 'Texto do alvo', { required = true, default = 'Hackear computador' }),
            F.select('kind', 'Tipo', {
                { value = 'hack', label = 'Hack' }, { value = 'search', label = 'Revistar' },
                { value = 'generic', label = 'Genérica' },
            }, { default = 'hack' }),
            F.position('coords', 'Posição', { heading = true, preview = { kind = 'object', modelKey = 'model' }, required = true }),
            F.model('model', 'Objeto (opcional)', 'object', { help = 'Vazio = usa o que já existe no mapa nesta posição.' }),
            F.number('distance', 'Distância', { min = 0.5, max = 5, default = 1.5, step = 0.1 }),
            F.bool('revealed', 'Visível desde o início', { default = true }),
            F.item('requiredItem', 'Item necessário'),
            F.bool('consumeItem', 'Consome o item', { default = false }),
            F.minigame('minigame', 'Minigame'),
            F.select('difficulty', 'Dificuldade do minigame', {
                { value = 1, label = 'Fácil' }, { value = 2, label = 'Normal' }, { value = 3, label = 'Difícil' },
            }, { default = 2 }),
            F.number('duration', 'Duração (segundos)', { min = 0, max = 120, default = 5 }),
            F.bool('once', 'Só uma vez', { default = true }),
            F.bool('retry', 'Pode tentar de novo após falha', { default = false }),
            F.text('infoTitle', 'Título da informação revelada', { help = 'Mostrado no sucesso. Vazio = não mostra.' }),
            F.list('infoLines', 'Linhas da informação', {
                F.text('label', 'Rótulo'),
                F.text('value', 'Valor', { help = 'Aceita {{variável}}.' }),
            }, { itemLabel = 'label', max = 12 }),
            F.actions('onSuccess', 'No sucesso'),
            F.actions('onFailure', 'Na falha'),
        },
    },
    {
        key = 'reinforcements', label = 'Reforços', singular = 'reforço', itemLabel = 'label',
        help = 'Veículo que nasce longe, dirige até o local, e a tripulação desce para lutar.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.model('model', 'Veículo', 'vehicle', { default = 'granger', required = true }),
            F.position('spawn', 'Onde nasce', { heading = true, preview = { kind = 'vehicle', modelKey = 'model' }, required = true }),
            F.position('destination', 'Destino', { required = true }),
            F.positions('route', 'Rota (opcional)', { help = 'Pontos intermediários, em ordem.' }),
            F.number('arrivalDistance', 'Distância de chegada', { min = 3, max = 80, default = 15 }),
            F.number('speed', 'Velocidade (m/s)', { min = 5, max = 60, default = 25 }),
            F.select('drivingStyle', 'Direção', DRIVING, { default = 'rushed' }),
            F.bool('exitOnArrival', 'Descem ao chegar', { default = true }),
            F.bool('engage', 'Atacam os jogadores', { default = true }),
            F.number('maxTravelSeconds', 'Tempo máximo de viagem', { min = 20, max = 600, default = 150,
                help = 'Passou disso, descem onde estiverem.' }),
            F.list('crew', 'Tripulação', pedFields(false), { itemLabel = 'model', min = 1, max = 8,
                help = 'O primeiro dirige. Os outros ocupam os bancos em ordem.' }),
        },
    },
    {
        key = 'chases', label = 'Perseguições', singular = 'perseguição', itemLabel = 'label',
        help = 'Veículos inimigos que nascem fora da vista e perseguem os jogadores.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.model('model', 'Veículo', 'vehicle', { default = 'granger', required = true }),
            F.number('countMin', 'Veículos (mínimo)', { min = 1, max = 4, default = 1 }),
            F.number('countMax', 'Veículos (máximo)', { min = 1, max = 4, default = 2 }),
            F.select('spawnMode', 'Onde nascem', {
                { value = 'road', label = 'Só aleatório na estrada' },
                { value = 'points', label = 'Só pontos cadastrados' },
                { value = 'both', label = 'Pontos cadastrados + aleatório' },
            }, { default = 'both',
                help = 'Aleatório: numa via atrás de quem dirige, fora da vista de todos, nunca em calçada, telhado ou água. '
                    .. 'Com os dois, tenta os pontos primeiro e usa a estrada quando nenhum serve.' }),
            F.positions('spawnPoints', 'Pontos de nascimento', { heading = true, max = 24, showIf = showIf('spawnMode', 'points', 'both'),
                help = 'O sistema escolhe o melhor: longe, atrás e fora da vista dos jogadores.' }),
            F.number('minSpawnDistance', 'Distância mínima', { min = 40, max = 600, default = 120 }),
            F.number('maxSpawnDistance', 'Distância máxima', { min = 80, max = 2000, default = 450 }),
            F.number('maxSpeed', 'Velocidade máxima (m/s)', { min = 10, max = 80, default = 45 }),
            F.select('drivingStyle', 'Direção', DRIVING, { default = 'aggressive' }),
            F.bool('passengersShoot', 'Passageiros atiram', { default = true }),
            F.bool('driverShoots', 'Motorista atira', { default = false }),
            F.bool('ram', 'Bate no carro dos jogadores', { default = true }),
            F.number('durationSeconds', 'Duração máxima (s)', { min = 0, max = 900, default = 240, help = '0 = sem limite.' }),
            F.number('loseDistance', 'Distância para despistar', { min = 100, max = 2000, default = 400 }),
            F.list('crew', 'Tripulação de cada veículo', pedFields(false), { itemLabel = 'model', min = 1, max = 6 }),
            F.list('waves', 'Ondas seguintes', {
                F.model('model', 'Veículo', 'vehicle', { default = 'bati' }),
                F.number('countMin', 'Veículos (mínimo)', { min = 1, max = 4, default = 1 }),
                F.number('countMax', 'Veículos (máximo)', { min = 1, max = 4, default = 2 }),
                F.number('delaySeconds', 'Espera depois da anterior (s)', { min = 0, max = 300, default = 20 }),
            }, { itemLabel = 'model', max = 4, help = 'Começa quando a onda anterior acaba sem os jogadores despistarem.' }),
        },
    },
    {
        key = 'deliveryGroups', label = 'Entregas', singular = 'grupo de entrega', itemLabel = 'label',
        help = 'Locais de entrega. A ação "Sortear entrega" escolhe um deles.',
        fields = {
            F.text('label', 'Nome', { required = true }),
            F.list('points', 'Locais', {
                F.text('label', 'Nome', { required = true }),
                F.position('coords', 'Posição', { heading = true, required = true }),
                F.number('radius', 'Raio', { min = 2, max = 60, default = 8 }),
                F.position('parkCoords', 'Vaga do veículo', { heading = true,
                    help = 'Onde a van tem que parar. Vazio = qualquer lugar dentro do raio.' }),
                F.position('npcCoords', 'Onde o NPC espera', { heading = true,
                    help = 'Vazio = alguns metros à frente do local.' }),
            }, { itemLabel = 'label', min = 1, max = 24 }),
        },
    },
}

Schema.collectionByKey = {}
for index = 1, #Schema.collections do
    Schema.collectionByKey[Schema.collections[index].key] = Schema.collections[index]
end

-- Passos ---------------------------------------------------------------------------------

---Campos de todo passo, desenhados antes dos campos do tipo.
Schema.stepCommon = {
    F.text('label', 'Nome do passo', { required = true }),
    F.text('objective', 'Objetivo na tela', { help = 'Aceita {{variável}}. Vazio = nome do passo.' }),
    F.bool('enabled', 'Ativo', { default = true }),
    F.condition('condition', 'Só executa se', { help = 'Falso quando o passo chega = ele é pulado.' }),
    F.actions('onStart', 'Ao começar'),
    F.actions('onComplete', 'Ao concluir'),
}

Schema.steps = {
    {
        type = 'vehicle_enter', label = 'Pegar veículo',
        description = 'Conclui quando um participante entra no veículo da missão. Blip e rota até ele.',
        fields = {
            F.ref('vehicle', 'Veículo', 'vehicles', { required = true }),
            F.select('who', 'Quem precisa entrar', {
                { value = 'driver', label = 'Alguém no volante' },
                { value = 'any', label = 'Alguém em qualquer banco' },
            }, { default = 'driver' }),
            F.bool('showGps', 'Rota no GPS até o veículo', { default = true }),
        },
    },
    {
        type = 'goto', label = 'Ir até local',
        description = 'Conclui quando os participantes entram no raio.',
        fields = {
            F.position('coords', 'Local', { required = true }),
            F.number('radius', 'Raio', { min = 2, max = 1000, default = 100 }),
            F.select('who', 'Quem precisa chegar', WHO, { default = 'any' }),
            F.bool('showGps', 'Rota no GPS', { default = true }),
            F.bool('showBlip', 'Blip no mapa', { default = true }),
            F.text('blipLabel', 'Nome do blip', { default = 'Destino' }),
            F.number('blipSprite', 'Ícone do blip', { default = 1 }),
            F.select('blipColor', 'Cor do blip', BLIP_COLORS, { default = 5 }),
            F.bool('blipArea', 'Mostrar área do raio', { default = false }),
        },
    },
    {
        type = 'interact', label = 'Interação',
        description = 'Conclui quando a interação acontece (hack, revistar).',
        fields = {
            F.ref('interaction', 'Interação', 'interactions', { required = true }),
            F.select('complete', 'Conclui com', {
                { value = 'success', label = 'Só sucesso' }, { value = 'any', label = 'Sucesso ou falha' },
            }, { default = 'any' }),
            F.bool('showBlip', 'Blip no local', { default = false }),
        },
    },
    {
        type = 'eliminate', label = 'Neutralizar NPCs',
        description = 'Conclui quando os grupos escolhidos não têm ninguém vivo.',
        fields = {
            F.refs('groups', 'Grupos', 'pedGroups', { required = true }),
        },
    },
    {
        type = 'cargo', label = 'Carga',
        description = 'Conclui quando a quantidade de carga chega no estado escolhido.',
        fields = {
            F.ref('cargo', 'Carga', 'cargo', { required = true }),
            F.select('target', 'Estado', {
                { value = 'picked', label = 'Pegas' }, { value = 'loaded', label = 'No veículo' },
                { value = 'delivered', label = 'Entregues' },
            }, { default = 'loaded' }),
            F.number('count', 'Quantidade', { min = 0, max = 50, default = 0, help = '0 = toda a quantidade certa.' }),
            F.bool('reveal', 'Revela a carga ao começar', { default = true }),
        },
    },
    {
        type = 'leave_area', label = 'Sair da área',
        description = 'Conclui quando os participantes (ou o veículo) saem do raio.',
        fields = {
            F.position('coords', 'Centro da área', { required = true }),
            F.number('radius', 'Raio', { min = 10, max = 3000, default = 300 }),
            F.select('who', 'Quem precisa sair', {
                { value = 'any', label = 'Qualquer participante' }, { value = 'all', label = 'Todos os participantes' },
                { value = 'vehicle', label = 'O veículo com a carga' },
            }, { default = 'vehicle' }),
            F.ref('cargo', 'Carga exigida', 'cargo', { optional = true }),
            F.number('cargoCount', 'Quantidade exigida no veículo', { min = 0, max = 50, default = 0, help = '0 = toda a quantidade certa.' }),
            F.bool('showArea', 'Mostrar área no mapa', { default = true }),
        },
    },
    {
        type = 'deliver', label = 'Entregar',
        description = 'Leva a carga (ou o item) até o local de entrega.',
        fields = {
            F.select('source', 'Local', {
                { value = 'var', label = 'Sorteado (variável)' }, { value = 'fixed', label = 'Fixo' },
            }, { default = 'var' }),
            F.var('var', 'Variável do local', { default = 'delivery_location', showIf = showIf('source', 'var') }),
            F.position('coords', 'Local fixo', { showIf = showIf('source', 'fixed') }),
            F.number('radius', 'Raio (local fixo)', { min = 2, max = 60, default = 8, showIf = showIf('source', 'fixed') }),
            F.position('parkCoords', 'Vaga do veículo (local fixo)', { heading = true, showIf = showIf('source', 'fixed') }),
            F.position('npcCoords', 'Onde o NPC espera (local fixo)', { heading = true, showIf = showIf('source', 'fixed') }),
            F.select('mode', 'Tipo de entrega', {
                { value = 'vehicle', label = 'Veículo com a carga' },
                { value = 'item', label = 'Item no inventário' },
                { value = 'presence', label = 'Só chegar' },
            }, { default = 'vehicle' }),
            F.ref('cargo', 'Carga', 'cargo', { showIf = showIf('mode', 'vehicle') }),
            F.number('parkRadius', 'Tolerância da vaga (m)', { min = 1, max = 15, default = 4, step = 0.5, showIf = showIf('mode', 'vehicle') }),
            F.bool('handoff', 'NPC leva o veículo embora', { default = true, showIf = showIf('mode', 'vehicle'),
                help = 'Com a van parada e vazia, o NPC entra, sai dirigindo e some longe da vista. Só veículo da missão.' }),
            F.number('driveAwaySeconds', 'Some depois de (s)', { min = 10, max = 300, default = 45, showIf = showIf('handoff', true) }),
            F.number('required', 'Quantidade', { min = 0, max = 100, default = 0, help = '0 = toda a quantidade certa.' }),
            F.item('item', 'Item', { showIf = showIf('mode', 'item') }),
            F.bool('consume', 'Consome a carga/item', { default = true }),
            F.number('holdSeconds', 'Segundos parado no local', { min = 0, max = 60, default = 3 }),
            F.model('npcModel', 'NPC que recebe (opcional)', 'ped'),
            F.number('npcOffset', 'NPC a quantos metros do centro', { min = 0, max = 20, default = 3 }),
            F.strings('npcText', 'Falas do NPC na chegada'),
            F.text('blipLabel', 'Nome do blip', { default = 'Entrega' }),
        },
    },
    {
        type = 'wait', label = 'Esperar',
        description = 'Conclui depois de um tempo.',
        fields = {
            F.number('seconds', 'Segundos (mínimo)', { min = 0, max = 3600, default = 10 }),
            F.number('secondsMax', 'Segundos (máximo)', { min = 0, max = 3600, default = 0, help = 'Maior que o mínimo = sorteia no intervalo.' }),
        },
    },
    {
        type = 'condition', label = 'Esperar condição',
        description = 'Conclui quando a condição fica verdadeira.',
        fields = {
            F.condition('until', 'Até que', { required = true }),
        },
    },
    {
        type = 'actions', label = 'Só ações',
        description = 'Executa "Ao começar" e conclui na hora. Bom para organizar ramificações.',
        fields = {},
    },
}

Schema.stepByType = {}
for index = 1, #Schema.steps do Schema.stepByType[Schema.steps[index].type] = Schema.steps[index] end

-- Ações ----------------------------------------------------------------------------------

Schema.actions = {
    { type = 'set_var', label = 'Definir variável', group = 'Variáveis', fields = {
        F.var('var', 'Variável', { required = true }), F.text('value', 'Valor'),
    } },
    { type = 'add_var', label = 'Somar na variável', group = 'Variáveis', fields = {
        F.var('var', 'Variável', { required = true }), F.number('amount', 'Quanto', { default = 1 }),
    } },
    { type = 'random_var', label = 'Sortear variável', group = 'Variáveis', fields = {
        F.var('var', 'Variável', { required = true }), F.strings('values', 'Valores'),
    } },
    { type = 'spawn_group', label = 'Criar grupo de NPC', group = 'Entidades', fields = {
        F.ref('group', 'Grupo', 'pedGroups', { required = true }),
    } },
    { type = 'despawn_group', label = 'Remover grupo de NPC', group = 'Entidades', fields = {
        F.ref('group', 'Grupo', 'pedGroups', { required = true }),
    } },
    { type = 'set_hostile', label = 'Hostilidade do grupo', group = 'Entidades', fields = {
        F.ref('group', 'Grupo', 'pedGroups', { required = true }), F.bool('hostile', 'Hostil', { default = true }),
    } },
    { type = 'spawn_vehicle', label = 'Criar veículo', group = 'Entidades', fields = {
        F.ref('vehicle', 'Veículo', 'vehicles', { required = true }),
    } },
    { type = 'despawn_vehicle', label = 'Remover veículo', group = 'Entidades', fields = {
        F.ref('vehicle', 'Veículo', 'vehicles', { required = true }),
    } },
    { type = 'spawn_prop', label = 'Criar objeto', group = 'Entidades', fields = {
        F.ref('prop', 'Objeto', 'props', { required = true }),
    } },
    { type = 'despawn_prop', label = 'Remover objeto', group = 'Entidades', fields = {
        F.ref('prop', 'Objeto', 'props', { required = true }),
    } },
    { type = 'reveal_interaction', label = 'Mostrar interação', group = 'Interação', fields = {
        F.ref('interaction', 'Interação', 'interactions', { required = true }),
    } },
    { type = 'hide_interaction', label = 'Esconder interação', group = 'Interação', fields = {
        F.ref('interaction', 'Interação', 'interactions', { required = true }),
    } },
    { type = 'reveal_cargo', label = 'Mostrar carga', group = 'Interação', fields = {
        F.ref('cargo', 'Carga', 'cargo', { required = true }),
    } },
    { type = 'send_sms', label = 'Enviar SMS', group = 'Comunicação', fields = {
        F.textarea('text', 'Texto', { required = true, maxLength = 300 }),
        F.number('delaySeconds', 'Enviar depois de (s)', { min = 0, max = 600, default = 0,
            help = 'Só a mensagem espera; as ações seguintes continuam na hora.' }),
    } },
    { type = 'notify', label = 'Aviso na tela', group = 'Comunicação', fields = {
        F.text('text', 'Texto', { required = true }), F.select('kind', 'Tipo', NOTIFY, { default = 'inform' }),
        F.number('delaySeconds', 'Mostrar depois de (s)', { min = 0, max = 600, default = 0 }),
    } },
    { type = 'show_info', label = 'Mostrar informação', group = 'Comunicação', fields = {
        F.text('title', 'Título', { required = true }),
        F.list('lines', 'Linhas', { F.text('label', 'Rótulo'), F.text('value', 'Valor') }, { itemLabel = 'label', max = 12 }),
    } },
    { type = 'create_blip', label = 'Criar blip', group = 'Mapa', fields = {
        F.text('blip', 'ID do blip', { required = true }),
        F.select('source', 'Posição', { { value = 'fixed', label = 'Fixa' }, { value = 'var', label = 'Variável' } }, { default = 'fixed' }),
        F.position('coords', 'Posição', { showIf = showIf('source', 'fixed') }),
        F.var('var', 'Variável', { showIf = showIf('source', 'var') }),
        F.text('label', 'Nome', { default = 'Local' }),
        F.number('sprite', 'Ícone', { default = 1 }),
        F.select('color', 'Cor', BLIP_COLORS, { default = 5 }),
        F.bool('route', 'Rota no GPS', { default = false }),
    } },
    { type = 'remove_blip', label = 'Remover blip', group = 'Mapa', fields = {
        F.text('blip', 'ID do blip', { required = true }),
    } },
    { type = 'pick_delivery', label = 'Sortear entrega', group = 'Mapa', fields = {
        F.ref('group', 'Grupo de entrega', 'deliveryGroups', { required = true }),
        F.var('var', 'Guardar em', { default = 'delivery_location' }),
    } },
    { type = 'send_reinforcement', label = 'Mandar reforço', group = 'Combate', fields = {
        F.ref('reinforcement', 'Reforço', 'reinforcements', { required = true }),
    } },
    { type = 'start_chase', label = 'Começar perseguição', group = 'Combate', fields = {
        F.ref('chase', 'Perseguição', 'chases', { required = true }),
    } },
    { type = 'stop_chase', label = 'Encerrar perseguição', group = 'Combate', fields = {
        F.ref('chase', 'Perseguição', 'chases', { required = true }),
    } },
    { type = 'dispatch', label = 'Alerta para a polícia', group = 'Combate', fields = {
        F.text('code', 'Código', { default = '10-90' }), F.text('title', 'Título', { default = 'Atividade suspeita' }),
        F.text('message', 'Mensagem'), F.position('coords', 'Posição', { required = true }),
    } },
    { type = 'start_timer', label = 'Iniciar timer', group = 'Fluxo', fields = {
        F.text('timer', 'ID do timer', { required = true }),
        F.number('seconds', 'Segundos', { min = 1, max = 3600, default = 30 }),
        F.bool('show', 'Mostrar contagem na tela', { default = false }),
    } },
    { type = 'cancel_timer', label = 'Cancelar timer', group = 'Fluxo', fields = {
        F.text('timer', 'ID do timer', { required = true }),
    } },
    { type = 'wait', label = 'Esperar', group = 'Fluxo', fields = {
        F.number('seconds', 'Segundos (mínimo)', { min = 0, max = 600, default = 5 }),
        F.number('secondsMax', 'Segundos (máximo)', { min = 0, max = 600, default = 0 }),
    } },
    { type = 'if', label = 'Se', group = 'Fluxo', fields = {
        F.condition('condition', 'Condição', { required = true }),
        F.actions('then', 'Então'), F.actions('else', 'Senão'),
    } },
    { type = 'chance', label = 'Chance', group = 'Fluxo', fields = {
        F.number('percent', 'Chance (%)', { min = 0, max = 100, default = 50 }),
        F.actions('then', 'Se sair'), F.actions('else', 'Se não sair'),
    } },
    { type = 'goto_step', label = 'Ir para o passo', group = 'Fluxo', fields = {
        F.ref('step', 'Passo', 'steps', { required = true }),
    } },
    { type = 'give_item', label = 'Dar item', group = 'Itens', fields = {
        F.item('item', 'Item', { required = true }), F.number('amount', 'Quantidade', { min = 1, max = 100, default = 1 }),
        F.select('to', 'Para', { { value = 'all', label = 'Todos' }, { value = 'actor', label = 'Quem causou' } }, { default = 'all' }),
    } },
    { type = 'take_item', label = 'Tirar item', group = 'Itens', fields = {
        F.item('item', 'Item', { required = true }), F.number('amount', 'Quantidade', { min = 1, max = 100, default = 1 }),
        F.select('from', 'De', { { value = 'all', label = 'Todos' }, { value = 'actor', label = 'Quem causou' } }, { default = 'actor' }),
    } },
    { type = 'play_sound', label = 'Tocar som', group = 'Comunicação', fields = {
        F.text('name', 'Som', { default = 'Beep_Red' }), F.text('set', 'Conjunto', { default = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' }),
    } },
    { type = 'complete_mission', label = 'Concluir missão', group = 'Fluxo', fields = {} },
    { type = 'fail_mission', label = 'Falhar missão', group = 'Fluxo', fields = {
        F.text('reason', 'Motivo', { default = 'A missão falhou.' }),
    } },
}

Schema.actionByType = {}
for index = 1, #Schema.actions do Schema.actionByType[Schema.actions[index].type] = Schema.actions[index] end

-- Gatilhos -------------------------------------------------------------------------------
-- `match` diz qual campo do evento precisa bater com o filtro do gatilho.

Schema.events = {
    { value = 'mission_started', label = 'Missão começou' },
    { value = 'step_started', label = 'Passo começou', match = { key = 'step', ref = 'steps' } },
    { value = 'step_completed', label = 'Passo concluído', match = { key = 'step', ref = 'steps' } },
    { value = 'zone_enter', label = 'Entraram na zona', match = { key = 'zone', ref = 'zones' } },
    { value = 'zone_exit', label = 'Saíram da zona', match = { key = 'zone', ref = 'zones' } },
    { value = 'cargo_picked', label = 'Carga pega', match = { key = 'cargo', ref = 'cargo' } },
    { value = 'cargo_loaded', label = 'Carga no veículo', match = { key = 'cargo', ref = 'cargo' } },
    { value = 'cargo_delivered', label = 'Carga entregue', match = { key = 'cargo', ref = 'cargo' } },
    { value = 'cargo_dropped', label = 'Carga largada', match = { key = 'cargo', ref = 'cargo' } },
    { value = 'interaction_success', label = 'Interação com sucesso', match = { key = 'interaction', ref = 'interactions' } },
    { value = 'interaction_failed', label = 'Interação falhou', match = { key = 'interaction', ref = 'interactions' } },
    { value = 'group_hostile', label = 'Grupo ficou hostil', match = { key = 'group', ref = 'pedGroups' } },
    { value = 'group_dead', label = 'Grupo neutralizado', match = { key = 'group', ref = 'pedGroups' } },
    { value = 'ped_killed', label = 'NPC do grupo morreu', match = { key = 'group', ref = 'pedGroups' } },
    { value = 'shot_fired', label = 'Tiro na área da missão' },
    { value = 'var_changed', label = 'Variável mudou', match = { key = 'var', ref = 'variables' } },
    { value = 'timer', label = 'Timer acabou', match = { key = 'timer' } },
    { value = 'reinforcement_arrived', label = 'Reforço chegou', match = { key = 'reinforcement', ref = 'reinforcements' } },
    { value = 'chase_started', label = 'Perseguição começou', match = { key = 'chase', ref = 'chases' } },
    { value = 'chase_ended', label = 'Perseguição acabou', match = { key = 'chase', ref = 'chases' } },
    { value = 'vehicle_destroyed', label = 'Veículo destruído', match = { key = 'vehicle', ref = 'vehicles' } },
    { value = 'participant_left', label = 'Participante saiu' },
}

Schema.eventByValue = {}
for index = 1, #Schema.events do Schema.eventByValue[Schema.events[index].value] = Schema.events[index] end

Schema.trigger = {
    F.text('label', 'Nome', { required = true }),
    F.select('on', 'Quando', Schema.events, { default = 'cargo_picked' }),
    -- `eventMatch`: a NUI desenha um seletor da coleção que o evento escolhido em `on` aponta
    -- (Schema.events[].match.ref), ou texto livre quando o evento não tem coleção (timer).
    field('eventMatch', 'match', 'Filtro', { eventKey = 'on', help = 'Vazio = qualquer um.' }),
    F.condition('condition', 'Só se'),
    F.number('delay', 'Espera (s, mínimo)', { min = 0, max = 600, default = 0 }),
    F.number('delayMax', 'Espera (s, máximo)', { min = 0, max = 600, default = 0 }),
    F.number('chance', 'Chance (%)', { min = 0, max = 100, default = 100 }),
    F.bool('once', 'Só uma vez', { default = true }),
    F.actions('actions', 'Ações'),
}

Schema.reward = {
    F.select('type', 'Tipo', { { value = 'item', label = 'Item' }, { value = 'money', label = 'Dinheiro' } }, { default = 'item' }),
    F.item('item', 'Item', { showIf = showIf('type', 'item') }),
    F.select('account', 'Conta', { { value = 'cash', label = 'Dinheiro vivo' }, { value = 'bank', label = 'Banco' } },
        { default = 'cash', showIf = showIf('type', 'money') }),
    F.number('amount', 'Quantidade', { min = 1, max = 1000000, default = 1 }),
    F.select('split', 'Distribuição', {
        { value = 'each', label = 'Cada participante recebe' }, { value = 'split', label = 'Dividido entre todos' },
    }, { default = 'each' }),
}

---Valores calculados que condições e textos podem ler, além das variáveis.
---`{id}` é trocado pelo id de cada item da coleção.
Schema.computed = {
    { name = 'cargo.{id}.picked', collection = 'cargo', label = 'pegas' },
    { name = 'cargo.{id}.loaded', collection = 'cargo', label = 'no veículo' },
    { name = 'cargo.{id}.delivered', collection = 'cargo', label = 'entregues' },
    { name = 'cargo.{id}.total', collection = 'cargo', label = 'quantidade certa' },
    { name = 'group.{id}.alive', collection = 'pedGroups', label = 'vivos' },
    { name = 'group.{id}.dead', collection = 'pedGroups', label = 'mortos' },
    { name = 'group.{id}.hostile', collection = 'pedGroups', label = 'hostil' },
    { name = 'interaction.{id}.done', collection = 'interactions', label = 'feita' },
    { name = 'participants', label = 'participantes' },
    { name = 'elapsed', label = 'segundos desde o início' },
}

---Snapshot serializável para a NUI. Sem funções e sem índices auxiliares.
---@return table
function Schema.export()
    return {
        general = Schema.general,
        start = Schema.start,
        collections = Schema.collections,
        stepCommon = Schema.stepCommon,
        steps = Schema.steps,
        actions = Schema.actions,
        events = Schema.events,
        trigger = Schema.trigger,
        reward = Schema.reward,
        computed = Schema.computed,
    }
end

return Schema
