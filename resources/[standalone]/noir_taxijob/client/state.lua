-- Máquina de estados do Taxi Job (client). Toda transição passa por SetTaxiState.
TAXI_STATE = {
    HIDDEN = 'HIDDEN',         -- fora de um táxi válido / sem emprego
    AVAILABLE = 'AVAILABLE',   -- no táxi, aceitando chamadas
    OFFER = 'OFFER',           -- chamada recebida, aguardando E
    EN_ROUTE = 'EN_ROUTE',     -- a caminho da coleta
    BOARDING = 'BOARDING',     -- passageiro embarcando
    HIRED = 'HIRED',           -- corrida em andamento
    COMPLETING = 'COMPLETING', -- destino alcançado, pagamento e desembarque
    PAUSED = 'PAUSED',         -- chamadas pausadas pelo taxista
}

Taxi = {
    state = TAXI_STATE.HIDDEN,
    vehicle = 0,        -- táxi do serviço
    inVehicle = false,  -- taxista no banco do motorista do táxi
    fare = nil,         -- { id, pickup, heading, origin, dropoff, destination, npc, npcNetId }
    offer = nil,        -- { id, pickup, origin, distanceToPickup, estimateMin, estimateMax, expiresAt }
    routeDistance = 0,  -- metros até a coleta (EN_ROUTE)
    meter = { fare = 0, distance = 0 },
    passenger = { mood = 'none', comfort = 100 },
    result = nil,       -- { fare, reputation, mood, satisfaction }
}

local listeners = {}

---Registra um handler executado ao entrar no estado.
---@param state string
---@param fn fun(previous: string, data: any)
function Taxi.onEnter(state, fn)
    listeners[state] = listeners[state] or {}
    listeners[state][#listeners[state] + 1] = fn
end

---@param ... string
---@return boolean
function Taxi.is(...)
    for i = 1, select('#', ...) do
        if Taxi.state == select(i, ...) then return true end
    end
    return false
end

---@return boolean
function Taxi.inMission()
    return Taxi.is(TAXI_STATE.EN_ROUTE, TAXI_STATE.BOARDING, TAXI_STATE.HIRED, TAXI_STATE.COMPLETING)
end

---@param newState string
---@param data? any
function SetTaxiState(newState, data)
    local previous = Taxi.state
    Taxi.state = newState
    if Config.Debug then
        print(('[noir_taxijob] %s → %s'):format(previous, newState))
    end
    for _, fn in ipairs(listeners[newState] or {}) do
        fn(previous, data)
    end
    UI.render()
end
