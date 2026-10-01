Stages = { types = {}, order = {} }

local function define(id, def)
    def.id = id
    Stages.types[id] = def
    Stages.order[#Stages.order + 1] = id
end

Stages.commonFields = {
    { key = 'label',        label = 'Nome',            type = 'text',   default = '' },
    { key = 'duration',     label = 'Duração',        type = 'number', default = 10, min = 1, max = 900, unit = 's' },
    { key = 'requiredItem', label = 'Item necessário',   type = 'item',   default = '' },
    { key = 'consumeItem',  label = 'Consumir',      type = 'toggle', default = false },
    { key = 'itemDamage',   label = 'Desgaste do item',       type = 'number', default = 0, min = 0, max = 100, unit = '%', advanced = true },
    { key = 'optional',     label = 'Etapa opcional',  type = 'toggle', default = false, advanced = true },
    { key = 'reach',        label = 'Alcance da interação', type = 'number', default = 1.5, min = 0.5, max = 6,
      unit = 'm', advanced = true, hint = 'Quão perto é preciso estar para ver a interação. Aumente se o ponto for difícil de mirar.' },
    { key = 'notifyPolice', label = 'Alertar a polícia',    type = 'toggle', default = false, advanced = true },
    { key = 'prop',         label = 'Modelo de prop',      type = 'text',   default = '', advanced = true,
      hint = 'Criado no ponto e usado como alvo da interação. Deixe vazio para um marcador invisível.' },
    -- Noir: alvo num objeto que já existe no mapa, em vez da esfera.
    { key = 'worldModel',   label = 'Objeto do mapa',      type = 'text',   default = '', advanced = true,
      hint = 'A interação vai para o objeto do mapa com esse modelo mais perto do ponto (até 1,5 m), sem criar nada. Nome (prop_till_01) ou o número que a tecla G captura no posicionamento. Vazio usa a esfera.' },
    { key = 'propZ',        label = 'Altura do prop',     type = 'number', default = 0, min = -5, max = 5, unit = 'm', advanced = true },
    { key = 'handProp',     label = 'Prop na mão',       type = 'text',   default = '', advanced = true,
      hint = 'Fica na mão direita enquanto trabalham. Uma furadeira, um pé de cabra, um notebook.' },
    { key = 'animDict',     label = 'Dicionário da animação',  type = 'text',   default = '', advanced = true,
      hint = 'Deixe os dois vazios para usar a animação padrão do tipo de etapa.' },
    { key = 'animClip',     label = 'Clipe da animação',  type = 'text',   default = '', advanced = true },
    { key = 'animFlag',     label = 'Flag da animação',  type = 'number', default = 16, min = 0, max = 63, advanced = true,
      hint = '16 toca uma vez e congela no fim. 1 repete. 49 repete só no tronco, então dá para andar.' },
    { key = 'scenario',     label = 'Cenário',        type = 'text',   default = '', advanced = true,
      hint = 'Usado no lugar de dicionário e clipe. WORLD_HUMAN_WELDING, WORLD_HUMAN_HAMMERING, PROP_HUMAN_PARKING_METER.' },
    { key = 'handBone',     label = 'Osso do prop na mão',  type = 'number', default = 57005, min = 0, max = 65535, advanced = true,
      hint = '57005 é a mão direita, 18905 a esquerda, 28422 a cabeça.' },
    { key = 'handOffset',   label = 'Posição do prop na mão', type = 'text',  default = '', advanced = true,
      hint = 'x,y,z e, se quiser, três rotações. Vazio usa um padrão razoável para a mão.' },
    { key = 'progressStyle', label = 'Estilo do progresso', type = 'select', default = 'circle', advanced = true,
      options = {
          { value = 'circle', label = 'Círculo' },
          { value = 'bar',    label = 'Barra' },
      } },
    { key = 'freezePlayer', label = 'Imobilizar o jogador', type = 'toggle', default = true, advanced = true,
      hint = 'Desligado permite andar enquanto o tempo corre.' },
    { key = 'canCancel',    label = 'Pode ser cancelado', type = 'toggle', default = true, advanced = true },
    { key = 'loudness',     label = 'Ouvido a até',      type = 'number', default = 0, min = 0, max = 300, unit = 'm', advanced = true,
      hint = 'Quem estiver a essa distância e não for da equipe é avisado de que ouviu algo. 0 para silencioso.' },
    { key = 'difficulty',   label = 'Dificuldade',      type = 'select', default = '2', advanced = true,
      options = {
          { value = '1', label = 'Fácil' },
          { value = '2', label = 'Normal' },
          { value = '3', label = 'Difícil' },
      } },
    { key = 'penalty',      label = 'Punição ao errar', type = 'select', default = 'none', advanced = true,
      hint = 'O que acontece com o jogador quando erra, além do que Ao falhar já faz.',
      options = {
          { value = 'none',        label = 'Nada' },
          { value = 'shock',       label = 'Choque elétrico' },
          { value = 'fire',        label = 'Pegar fogo' },
          { value = 'gas',         label = 'Nuvem de gás' },
          { value = 'explosion',   label = 'Explosão' },
      } },
    { key = 'loseItemChance', label = 'Chance de perder o item', type = 'number', default = 0, min = 0, max = 100,
      unit = '%', advanced = true, hint = 'Ao falhar, a chance de a ferramenta usada ser destruída.' },
    { key = 'onFail',       label = 'Ao falhar',      type = 'select', default = 'retry', advanced = true,
      options = {
          { value = 'retry',    label = 'Deixar tentar de novo' },
          { value = 'escalate', label = 'Aumentar a resposta' },
          { value = 'fail',     label = 'Falhar o assalto' },
      } },
}

local MARKER = {
    entry   = { 25, 229, 140 },
    tool    = { 245, 165, 36 },
    puzzle  = { 76, 154, 255 },
    loot    = { 48, 209, 88 },
    people  = { 255, 90, 95 },
    control = { 168, 130, 255 },
}

define('hack', {
    label = 'Hackear',
    group = 'puzzle',
    icon = 'terminal',
    colour = MARKER.puzzle,
    blurb = 'Ponto com minigame. Terminais, painéis de alarme, consoles de segurança.',
    fields = {
        { key = 'minigame', label = 'Minigame',  type = 'minigame', default = 'xs:signal_lock' },
        { key = 'attempts', label = 'Tentativas',  type = 'number', default = 3, min = 1, max = 10 },
        { key = 'revealCode', label = 'Revela um código', type = 'number', default = 0, min = 0, max = 8,
          advanced = true, hint = 'Quantos dígitos. 0 para nenhum. Um teclado numérico em outro ponto pode pedir esse código.' },
    },
})

define('tool', {
    label = 'Ação com ferramenta',
    group = 'tool',
    icon = 'screwdriver-wrench',
    colour = MARKER.tool,
    blurb = 'Ação cronometrada que exige um item. Lockpick, furadeira, termite, esmerilhadeira, maçarico.',
    fields = {
        { key = 'toolKind', label = 'Ferramenta', type = 'select', default = 'drill',
          options = {
              { value = 'lockpick', label = 'Lockpick' },
              { value = 'drill',    label = 'Furadeira' },
              { value = 'thermite', label = 'Termite' },
              { value = 'grinder',  label = 'Esmerilhadeira' },
              { value = 'torch',    label = 'Maçarico' },
              { value = 'crowbar',  label = 'Pé de cabra' },
          } },
        { key = 'minigame', label = 'Teste de habilidade', type = 'minigame', default = 'none' },
    },
})

define('keypad', {
    label = 'Teclado numérico',
    group = 'puzzle',
    icon = 'grip',
    colour = MARKER.puzzle,
    blurb = 'Entrada de código. O código vem de outra etapa, então a equipe precisa se dividir.',
    fields = {
        { key = 'digits',   label = 'Tamanho do código', type = 'number', default = 4, min = 3, max = 8 },
        { key = 'codeFrom', label = 'Código encontrado em', type = 'stage', default = '' },
        { key = 'attempts', label = 'Tentativas',    type = 'number', default = 3, min = 1, max = 10 },
    },
})

define('camera', {
    label = 'Câmera / segurança',
    group = 'control',
    icon = 'video',
    colour = MARKER.control,
    blurb = 'Desative para mudar o que o alarme faz. A mudança em si é definida em Resposta da Polícia.',
    fields = {
        { key = 'minigame', label = 'Minigame', type = 'minigame', default = 'xs:wire_trace' },
    },
})

define('power', {
    label = 'Caixa de força',
    group = 'control',
    icon = 'bolt',
    colour = MARKER.control,
    blurb = 'Corta a energia. Apaga as luzes do interior e pode abrandar o alarme.',
    fields = {
        { key = 'killLights', label = 'Escurecer o interior', type = 'toggle', default = true },
        { key = 'shockRisk',  label = 'Choque ao falhar', type = 'toggle', default = true, advanced = true },
    },
})

define('register', {
    label = 'Caixa registradora',
    group = 'loot',
    icon = 'cash-register',
    colour = MARKER.loot,
    blurb = 'Pegada rápida para um pagamento pequeno.',
    fields = {
        { key = 'minigame', label = 'Minigame', type = 'minigame', default = 'xs:tumbler' },
        { key = 'restock',  label = 'Repõe depois de', type = 'number', default = 1800, min = 0, max = 86400, unit = 's' },
    },
})

define('safe', {
    label = 'Cofre / caixa-forte',
    group = 'loot',
    icon = 'vault',
    colour = MARKER.loot,
    blurb = 'Demorado, barulhento e vale a pena.',
    fields = {
        { key = 'minigame', label = 'Minigame', type = 'minigame', default = 'xs:circuit' },
        { key = 'restock',  label = 'Repõe depois de', type = 'number', default = 7200, min = 0, max = 86400, unit = 's' },
        { key = 'revealCode', label = 'Revela um código', type = 'number', default = 0, min = 0, max = 8,
          advanced = true, hint = 'Quantos dígitos. 0 para nenhum. Um teclado numérico em outro ponto pode pedir esse código.' },
    },
})

define('container', {
    label = 'Recipiente de saque',
    group = 'loot',
    icon = 'box-open',
    colour = MARKER.loot,
    blurb = 'Pegue para a bolsa, um punhado por vez, até o limite de peso.',
    fields = {
        { key = 'grabs',     label = 'Pegadas disponíveis', type = 'number', default = 6, min = 1, max = 40 },
        { key = 'grabTime',  label = 'Por pegada',        type = 'number', default = 4, min = 1, max = 60, unit = 's' },
        { key = 'needsBag',  label = 'Exige uma bolsa',  type = 'toggle', default = false, advanced = true },
    },
})

define('twoman', {
    label = 'Ponto em dupla',
    group = 'control',
    icon = 'users',
    colour = MARKER.control,
    blurb = 'Dois jogadores precisam segurar ao mesmo tempo. Pareie com um segundo ponto em outro lugar.',
    fields = {
        { key = 'pairWith', label = 'Pareado com', type = 'stage', default = '' },
        { key = 'holdTime', label = 'Segurar por',    type = 'number', default = 6, min = 1, max = 120, unit = 's' },
    },
})

define('hostage', {
    label = 'Refém / atendente',
    group = 'people',
    icon = 'user-lock',
    colour = MARKER.people,
    blurb = 'Intimide quem estiver atrás do balcão. Atrasa a resposta enquanto durar.',
    fields = {
        { key = 'ped',        label = 'Modelo do ped',    type = 'text',   default = 'mp_m_shopkeep_01' },
        { key = 'needsAim',   label = 'Exige mirar', type = 'toggle', default = true },
        { key = 'stallFor',   label = 'Atrasa o alerta',  type = 'number', default = 60, min = 0, max = 600, unit = 's' },
        { key = 'panicChance', label = 'Chance de pânico', type = 'number', default = 15, min = 0, max = 100, unit = '%', advanced = true },
    },
})

define('hold', {
    label = 'Ponto de resistência',
    group = 'control',
    icon = 'hourglass-half',
    colour = MARKER.control,
    blurb = 'Fique aqui enquanto o tempo corre. Bom para obrigar a equipe a se expor.',
    fields = {
        { key = 'radius',      label = 'Raio',        type = 'number', default = 3.0, min = 1.0, max = 30.0, unit = 'm' },
        { key = 'breakOnLeave', label = 'Reinicia se sair', type = 'toggle', default = true },
    },
})

define('doorlock', {
    label = 'Porta',
    group = 'control',
    icon = 'door-closed',
    colour = MARKER.control,
    blurb = 'Destranca uma porta do seu resource de portas. Informe o id da porta e ela abre quando esta etapa terminar.',
    fields = {
        { key = 'doorId',      label = 'Id da porta',        type = 'text',   default = '',
          hint = 'Exatamente como o seu resource de portas a chama. O ox_doorlock usa um número ou um nome.' },
        { key = 'doorAction',  label = 'Ação',        type = 'select', default = 'unlock',
          options = {
              { value = 'unlock', label = 'Destrancar' },
              { value = 'lock',   label = 'Trancar' },
          } },
        { key = 'relockOnEnd', label = 'Restaurar quando o assalto acabar', type = 'toggle', default = true },
        { key = 'minigame',    label = 'Minigame',       type = 'minigame', default = 'xs:signal_lock' },
        { key = 'attempts',    label = 'Tentativas',       type = 'number', default = 3, min = 1, max = 10 },
    },
})

define('guard', {
    label = 'Segurança armado',
    group = 'people',
    icon = 'user-shield',
    colour = MARKER.people,
    blurb = 'Um segurança que reage. Não há o que apertar: a etapa termina quando ele cai.',
    fields = {
        { key = 'ped',         label = 'Modelo do ped',      type = 'text',   default = 's_m_m_security_01' },
        { key = 'weapon',      label = 'Arma',         type = 'text',   default = 'WEAPON_PISTOL' },
        { key = 'accuracy',    label = 'Precisão',       type = 'number', default = 40, min = 1, max = 100, unit = '%' },
        { key = 'guardHealth', label = 'Vida',         type = 'number', default = 200, min = 100, max = 1000 },
        { key = 'armour',      label = 'Colete',         type = 'number', default = 0, min = 0, max = 100 },
        { key = 'hostile',     label = 'Começa hostil', type = 'toggle', default = false,
          hint = 'Desligado, ele só reage quando o alarme dispara, então uma equipe discreta passa por ele.' },
        { key = 'alertOnDeath', label = 'Matá-lo aciona a polícia', type = 'toggle', default = true },
        { key = 'guardScenario', label = 'Cenário parado', type = 'text', default = 'WORLD_HUMAN_GUARD_STAND', advanced = true },
    },
})

define('laser', {
    label = 'Grade de laser',
    group = 'control',
    icon = 'grip-lines',
    colour = MARKER.control,
    blurb = 'Feixes atravessando uma passagem. Passe com eles ligados e o alarme dispara. Desative aqui ou ligue à caixa de força.',
    fields = {
        { key = 'span',        label = 'Largura',          type = 'number', default = 2.0, min = 0.5, max = 12.0, unit = 'm' },
        { key = 'beams',       label = 'Feixes',          type = 'number', default = 4, min = 1, max = 12 },
        { key = 'tripAlarm',   label = 'Atravessar dispara o alarme', type = 'toggle', default = true },
        { key = 'minigame',    label = 'Minigame',       type = 'minigame', default = 'xs:frequency' },
        { key = 'attempts',    label = 'Tentativas',       type = 'number', default = 2, min = 1, max = 10 },
    },
})

define('escape', {
    label = 'Zona de fuga',
    group = 'entry',
    icon = 'flag-checkered',
    colour = MARKER.entry,
    blurb = 'Onde o assalto se encerra e tudo é pago. Todo roubo precisa de uma.',
    fields = {
        { key = 'radius',    label = 'Raio',       type = 'number', default = 25.0, min = 5.0, max = 300.0, unit = 'm' },
        { key = 'inVehicle', label = 'Precisa estar em veículo', type = 'toggle', default = false },
        { key = 'timeLimit', label = 'Tempo limite',   type = 'number', default = 0, min = 0, max = 3600, unit = 's', advanced = true },
    },
})

function Stages.Get(typeId)
    return Stages.types[typeId]
end

function Stages.FieldsFor(typeId)
    local def = Stages.types[typeId]
    if not def then return Stages.commonFields end

    local out = {}
    for _, f in ipairs(Stages.commonFields) do out[#out + 1] = f end
    for _, f in ipairs(def.fields or {}) do out[#out + 1] = f end
    return out
end

function Stages.Catalogue()
    local out = {}
    for _, id in ipairs(Stages.order) do
        local d = Stages.types[id]
        out[#out + 1] = {
            id = id, label = d.label, group = d.group, icon = d.icon,
            colour = d.colour, blurb = d.blurb, fields = Stages.FieldsFor(id),
        }
    end
    return out
end

function Stages.Defaults(typeId)
    local out = {}
    for _, f in ipairs(Stages.FieldsFor(typeId)) do
        out[f.key] = f.default
    end
    return out
end
