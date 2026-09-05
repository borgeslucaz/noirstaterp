/* Noir Taxi HUD — apresentação pura. Recebe o estado inteiro (taxi:setState) e snapshots numéricos. */
(function () {
    "use strict"

    const STATUS = {
        HIDDEN: "—",
        AVAILABLE: "DISPONÍVEL",
        OFFER: "NOVA CORRIDA",
        EN_ROUTE: "A CAMINHO",
        BOARDING: "EMBARCANDO",
        HIRED: "OCUPADO",
        COMPLETING: "CORRIDA FINALIZADA",
        PAUSED: "INDISPONÍVEL",
    }

    const SUB = {
        AVAILABLE: "AGUARDANDO CHAMADA",
        PAUSED: "CHAMADAS PAUSADAS",
    }

    const MOOD = {
        none: "SEM PASSAGEIRO",
        happy: "CONFORTÁVEL",
        neutral: "ACOMODANDO",
        hot: "COM CALOR",
        cold: "COM FRIO",
        unhappy: "INSATISFEITO",
    }

    const $ = (id) => document.getElementById(id)

    const el = {
        hud: $("taxi-hud"),
        meter: $("meter"),
        status: $("meter-status"),
        bodyMeter: $("body-meter"),
        bodyOffer: $("body-offer"),
        bodyRoute: $("body-route"),
        bodyResult: $("body-result"),
        sub: $("meter-sub"),
        fare: $("meter-fare"),
        distance: $("meter-distance"),
        offerOrigin: $("offer-origin"),
        offerDistance: $("offer-distance"),
        offerEstimate: $("offer-estimate"),
        offerCountdown: $("offer-countdown"),
        routeOrigin: $("route-origin"),
        routeDistance: $("route-distance"),
        resultFare: $("result-fare"),
        resultRep: $("result-rep"),
        climate: $("climate"),
        climateIcon: $("climate-icon"),
        climateValue: $("climate-value"),
        fanDots: $("fan-dots"),
        passenger: $("passenger"),
        passengerLabel: $("passenger-label"),
        hintPause: $("hint-pause"),
        keyFan: $("key-fan"),
        keyAccept: $("key-accept"),
        keyPause: $("key-pause"),
    }

    let currentState = "HIDDEN"

    // ───────────── formatação (pt-BR) ─────────────

    const money = (v) => {
        const n = Number(v) || 0
        return "$" + n.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    }

    const moneyInt = (v) => "$" + Math.floor(Number(v) || 0).toLocaleString("pt-BR")

    const km = (meters) => {
        const n = (Number(meters) || 0) / 1000
        return n.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 }) + " km"
    }

    const routeDistance = (meters) => {
        const n = Number(meters) || 0
        if (n < 1000) return Math.round(n) + " m"
        return km(n)
    }

    const seconds = (ms) => Math.max(0, Math.ceil((Number(ms) || 0) / 1000)) + " s"

    const temperature = (t) => Math.round(Number(t) || 0) + "°C"

    // ───────────── renderização ─────────────

    function show(node, visible) {
        node.hidden = !visible
    }

    function setBody(state) {
        show(el.bodyMeter, state === "AVAILABLE" || state === "PAUSED" || state === "HIRED")
        show(el.sub, state === "AVAILABLE" || state === "PAUSED")
        show(el.bodyOffer, state === "OFFER")
        show(el.bodyRoute, state === "EN_ROUTE" || state === "BOARDING")
        show(el.bodyResult, state === "COMPLETING")
        el.sub.textContent = SUB[state] || ""
    }

    function renderMeter(data) {
        el.fare.textContent = money(data.fare)
        el.distance.textContent = km(data.distance)
    }

    function renderClimate(data) {
        el.climateValue.textContent = temperature(data.temperature)
        const fan = Math.max(0, Math.min(5, Number(data.fan) || 0))
        const dots = el.fanDots.children
        for (let i = 0; i < dots.length; i++) {
            dots[i].classList.toggle("on", i < fan)
        }
        el.fanDots.setAttribute("aria-label", "FAN nível " + fan)
        if (typeof data.mode === "string") {
            el.climate.dataset.mode = data.mode
        }
    }

    function renderPassenger(data) {
        const mood = data && MOOD[data.mood] ? data.mood : "none"
        el.passenger.dataset.mood = mood
        el.passengerLabel.textContent = MOOD[mood]
    }

    function renderOffer(offer) {
        if (!offer) return
        el.offerOrigin.textContent = offer.origin || "—"
        el.offerDistance.textContent = routeDistance(offer.distance)
        el.offerEstimate.textContent = moneyInt(offer.estimateMin) + " — " + moneyInt(offer.estimateMax)
        el.offerCountdown.textContent = seconds(offer.remaining)
    }

    function renderRoute(route) {
        if (!route) return
        el.routeOrigin.textContent = route.origin || "—"
        el.routeDistance.textContent = routeDistance(route.distance)
    }

    function renderResult(result) {
        if (!result) return
        el.resultFare.textContent = moneyInt(result.fare)
        const rep = Number(result.reputation) || 0
        el.resultRep.textContent = (rep >= 0 ? "+" : "") + rep
    }

    function renderKeys(keys) {
        if (!keys) return
        el.keyFan.textContent = keys.fan || "G"
        el.keyAccept.textContent = keys.accept || "E"
        el.keyPause.textContent = keys.pause || "J"
    }

    function setState(state, data) {
        currentState = state || "HIDDEN"
        data = data || {}

        el.meter.dataset.state = currentState
        el.status.textContent = STATUS[currentState] || currentState
        setBody(currentState)

        renderMeter(data)
        renderClimate(data)
        renderPassenger(data.passenger)
        renderOffer(data.offer)
        renderRoute(data.route)
        renderResult(data.result)
        renderKeys(data.keys)

        show(el.hintPause, currentState === "AVAILABLE" || currentState === "PAUSED")
    }

    // ───────────── mensagens do client ─────────────

    const handlers = {
        "taxi:setVisible": (visible) => {
            el.hud.hidden = !visible
        },
        "taxi:setState": (payload) => {
            setState(payload.state, payload.data)
        },
        "taxi:updateMeter": (payload) => {
            if (currentState === "HIRED") renderMeter(payload)
        },
        "taxi:updateClimate": (payload) => {
            renderClimate(payload)
        },
        "taxi:updatePassenger": (payload) => {
            renderPassenger(payload)
        },
        "taxi:updateOffer": (payload) => {
            if (currentState === "OFFER") el.offerCountdown.textContent = seconds(payload.remaining)
        },
        "taxi:updateRoute": (payload) => {
            if (currentState === "EN_ROUTE" || currentState === "BOARDING") {
                el.routeDistance.textContent = routeDistance(payload.distance)
            }
        },
    }

    window.addEventListener("message", (event) => {
        const msg = event.data || {}
        const handler = handlers[msg.action]
        if (handler) handler(msg.data)
    })

    // Avisa o client que a página carregou, para receber o estado atual.
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_taxijob"
    fetch("https://" + resource + "/uiReady", {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify({}),
    }).catch(() => {})
})()
