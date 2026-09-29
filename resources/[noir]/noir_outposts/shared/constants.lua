NoirOutposts = NoirOutposts or {}

NoirOutposts.Constants = {
    -- Marcador de versão dos arquivos em execução. Aparece no `/outpostsdebug` e no log de start
    -- do servidor, e serve para uma coisa só: saber se o que está rodando é o que está em disco.
    -- Sem ele, um `restart` esquecido se lê como mudança que não funcionou.
    --
    -- INCREMENTAR A CADA MUDANÇA NO RESOURCE. Vive aqui, em `shared_scripts`, porque client e
    -- servidor carregam este mesmo arquivo no mesmo restart: um número só responde pelos dois.
    Iteration = 19,

    OutpostStatus = {
        INACTIVE = 'inactive',
        AVAILABLE = 'available',
        CLAIMING = 'claiming',
        CONTROLLED = 'controlled',
        CONTESTED = 'contested',
        COOLDOWN = 'cooldown',
    },

    OperationType = {
        DRUG = 'drug',
        MONEY = 'money',
    },

    -- Estado persistido do corredor.
    DealerStatus = {
        DEPLOYED = 'deployed',
        RECOVERING = 'recovering',
    },

    -- Estado transitório de abordagem, só em memória e no state bag.
    HoldupState = {
        SURRENDERED = 'surrendered',
        HOSTILE = 'hostile',
        -- Passada a abordagem, o corredor fica abalado enquanto o cooldown corre. Serve para o
        -- client mostrar por que a arma apontada de novo não produz reação nenhuma.
        SHAKEN = 'shaken',
    },

    OperationKind = {
        DEPOSIT = 'deposit',
        SALE = 'sale',
        COLLECT = 'collect',
        ROBBERY = 'robbery',
        DOWN = 'dealer_down',
        HIRE = 'hire',
        FIRE = 'fire',
        CLAIM = 'claim',
        RELEASE = 'release',
        FORFEIT = 'forfeit',
    },

    OperationStatus = {
        PREPARED = 'prepared',
        COMMITTED = 'committed',
        COMPENSATED = 'compensated',
        PENDING = 'pending',
        PAID = 'paid',
        FAILED = 'failed',
    },

    SessionState = {
        OPENING = 'OPENING',
        READY = 'READY',
        PROCESSING = 'PROCESSING',
        CLOSING = 'CLOSING',
        CLOSED = 'CLOSED',
        ABORTED = 'ABORTED',
    },

    SessionAction = {
        CLAIM = 'claim',
        ROBBERY = 'robbery',
        HOLDUP = 'holdup',
    },

    StateBag = {
        OUTPOST = 'noir:outpostId',
        DEALER = 'noir:dealerId',
        DEALER_STATE = 'noir:dealerState',
        DEALER_CORNER = 'noir:dealerCorner',
    },

    Events = {
        SYNC = 'noir_outposts:client:syncOutposts',
        -- Um posto só. Quase toda mudança é de um posto, e mandar a lista inteira para o servidor
        -- inteiro a cada corredor que morre ou volta era o evento mais falador do resource.
        SYNC_OUTPOST = 'noir_outposts:client:syncOutpost',
        PANEL_UPDATE = 'noir_outposts:client:panelUpdate',
        PANEL_CLOSE = 'noir_outposts:client:panelClose',
        SESSION_ABORTED = 'noir_outposts:client:sessionAborted',
        -- Servidor mandando o jogador sair do interior: queda do resource, expiração do controle,
        -- perda de acesso. O client desmonta o shell e se teleporta de volta.
        INTERIOR_EVICT = 'noir_outposts:client:interiorEvict',
        DEALER_REACTION = 'noir_outposts:client:dealerReaction',
        -- Client -> servidor: o dono de rede informa onde os corredores dele estão.
        DEALER_POSITION = 'noir_outposts:server:dealerPosition',
    },

    Callbacks = {
        GET_CONTEXT = 'noir_outposts:server:getContext',
        OPEN_PANEL = 'noir_outposts:server:openPanel',
        CLOSE_PANEL = 'noir_outposts:server:closePanel',
        REFRESH_PANEL = 'noir_outposts:server:refreshPanel',
        CLAIM_START = 'noir_outposts:server:claimStart',
        CLAIM_COMPLETE = 'noir_outposts:server:claimComplete',
        CLAIM_CANCEL = 'noir_outposts:server:claimCancel',
        HIRE = 'noir_outposts:server:hireDealer',
        FIRE = 'noir_outposts:server:fireDealer',
        DEPOSIT = 'noir_outposts:server:deposit',
        COLLECT = 'noir_outposts:server:collect',
        INSPECT = 'noir_outposts:server:inspectDealer',
        HOLDUP = 'noir_outposts:server:holdup',
        ROBBERY_START = 'noir_outposts:server:robberyStart',
        ROBBERY_COMPLETE = 'noir_outposts:server:robberyComplete',
        ROBBERY_CANCEL = 'noir_outposts:server:robberyCancel',
        ENTER_INTERIOR = 'noir_outposts:server:enterInterior',
        LEAVE_INTERIOR = 'noir_outposts:server:leaveInterior',
        DEBUG_TARGET = 'noir_outposts:server:debugTarget',
        DEBUG_OUTPOST = 'noir_outposts:server:debugOutpost',
        PHONE_STATE = 'noir_outposts:server:phoneState',
        PHONE_FEED = 'noir_outposts:server:phoneFeed',
        PHONE_FEED_CLEAR = 'noir_outposts:server:phoneFeedClear',
        PHONE_SETTINGS = 'noir_outposts:server:phoneSettings',
        PHONE_SETTINGS_SET = 'noir_outposts:server:phoneSettingsSet',
    },

    PermissionKeys = { 'view', 'stock', 'hire', 'fire', 'collect', 'claim' },

    Limits = {
        maxIdentifierLength = 40,
        maxRequestIdLength = 64,
        maxSessionIdLength = 64,
        -- Corredores por reporte de posição. O teto por posto é 4, e o cliente só reporta os
        -- que ele possui, então isto é só o freio contra payload inflado.
        maxPositionReports = 16,
    },
}
