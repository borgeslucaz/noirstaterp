-- Bridge para a NUI. A NUI só apresenta: recebe o estado inteiro e snapshots numéricos.
UI = {}

local visible = false

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function vecTable(v)
    if not v then return nil end
    return { x = v.x, y = v.y, z = v.z }
end

---@param show boolean
function UI.setVisible(show)
    visible = show == true
    send('taxi:setVisible', visible)
end

function UI.isVisible()
    return visible
end

---Envia o estado completo. A NUI consegue renderizar tudo a partir desta mensagem.
function UI.render()
    local offer = Taxi.offer
    local fare = Taxi.fare
    send('taxi:setState', {
        state = Taxi.state,
        data = {
            fare = Taxi.meter.fare,
            distance = Taxi.meter.distance,
            temperature = Climate.temp,
            fan = Climate.fan,
            mode = Climate.mode(),
            passenger = { mood = Taxi.passenger.mood, comfort = Taxi.passenger.comfort },
            offer = offer and {
                origin = offer.origin,
                distance = offer.distanceToPickup,
                estimateMin = offer.estimateMin,
                estimateMax = offer.estimateMax,
                remaining = math.max(0, offer.expiresAt - GetGameTimer()),
            } or nil,
            route = fare and {
                origin = fare.origin,
                destination = fare.destination,
                distance = Taxi.routeDistance,
                pickup = vecTable(fare.pickup),
            } or nil,
            result = Taxi.result,
            keys = {
                fan = Config.Keybinds.fan.key,
                accept = Config.Keybinds.accept.key,
                pause = Config.Keybinds.pause.key,
            },
        },
    })
end

function UI.updateMeter(fareValue, distanceMeters)
    send('taxi:updateMeter', { fare = fareValue, distance = distanceMeters })
end

function UI.updateClimate(temperature, fan)
    send('taxi:updateClimate', { temperature = temperature, fan = fan, mode = Climate.mode() })
end

function UI.updatePassenger(mood, comfort)
    send('taxi:updatePassenger', { mood = mood, comfort = comfort })
end

function UI.updateOffer(remainingMs)
    send('taxi:updateOffer', { remaining = remainingMs })
end

function UI.updateRoute(distanceMeters)
    send('taxi:updateRoute', { distance = distanceMeters })
end

RegisterNUICallback('uiReady', function(_, cb)
    cb({})
    UI.setVisible(visible)
    UI.render()
end)
