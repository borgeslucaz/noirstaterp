NoirOutposts = NoirOutposts or {}

NoirOutposts.Constants = {
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
        PANEL_UPDATE = 'noir_outposts:client:panelUpdate',
        PANEL_CLOSE = 'noir_outposts:client:panelClose',
        SESSION_ABORTED = 'noir_outposts:client:sessionAborted',
        DEALER_REACTION = 'noir_outposts:client:dealerReaction',
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
        DEBUG_TARGET = 'noir_outposts:server:debugTarget',
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
    },
}
