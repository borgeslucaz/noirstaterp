/* Noir Taxi — apresentação pura.
 * HUD: recebe o estado inteiro (taxi:setState) e snapshots numéricos.
 * Central: recebe o bootstrap (taxiMenu:open) e só envia ids/ações; nível, Confiança e recompensa vêm do servidor. */
(function () {
    "use strict"

    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_taxijob"
    const reducedMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches

    const post = (name, body) =>
        fetch("https://" + resource + "/" + name, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(body || {}),
        })
            .then((r) => r.json())
            .catch(() => null)

    const $ = (id) => document.getElementById(id)

    // ───────────── formatação (pt-BR) ─────────────

    const money = (v) => {
        const n = Number(v) || 0
        return "$" + n.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    }
    const moneyInt = (v) => "$" + Math.floor(Number(v) || 0).toLocaleString("pt-BR")
    const int = (v) => Math.floor(Number(v) || 0).toLocaleString("pt-BR")
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
    const ordinal = (v) => int(v) + "º"
    const show = (node, visible) => { node.hidden = !visible }

    // ═══════════════════════════════ HUD ═══════════════════════════════

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
    const SUB = { AVAILABLE: "AGUARDANDO CHAMADA", PAUSED: "CHAMADAS PAUSADAS" }
    const MOOD = {
        none: "SEM PASSAGEIRO",
        happy: "CONFORTÁVEL",
        neutral: "ACOMODANDO",
        hot: "COM CALOR",
        cold: "COM FRIO",
        unhappy: "INSATISFEITO",
    }
    const FEAR = {
        calm: "TRANQUILO",
        nervous: "MEDO",
        scared: "ASSUSTADO",
        desperate: "DESESPERADO",
    }

    const hud = {
        root: $("taxi-hud"),
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
        resultBonus: $("result-bonus"),
        resultConfidence: $("result-confidence"),
        climate: $("climate"),
        climateValue: $("climate-value"),
        fanDots: $("fan-dots"),
        passenger: $("passenger"),
        passengerLabel: $("passenger-label"),
        passengerFear: $("passenger-fear"),
        passengerFearLabel: $("passenger-fear-label"),
        hintPause: $("hint-pause"),
        keyFan: $("key-fan"),
        keyAccept: $("key-accept"),
        keyPause: $("key-pause"),
    }

    let currentState = "HIDDEN"
    let hudVisible = false

    function setBody(state) {
        show(hud.bodyMeter, state === "AVAILABLE" || state === "PAUSED" || state === "HIRED")
        show(hud.sub, state === "AVAILABLE" || state === "PAUSED")
        show(hud.bodyOffer, state === "OFFER")
        show(hud.bodyRoute, state === "EN_ROUTE" || state === "BOARDING")
        show(hud.bodyResult, state === "COMPLETING")
        hud.sub.textContent = SUB[state] || ""
    }

    function renderMeter(data) {
        hud.fare.textContent = money(data.fare)
        hud.distance.textContent = km(data.distance)
    }

    function renderClimate(data) {
        hud.climateValue.textContent = temperature(data.temperature)
        const fan = Math.max(0, Math.min(5, Number(data.fan) || 0))
        const dots = hud.fanDots.children
        for (let i = 0; i < dots.length; i++) dots[i].classList.toggle("on", i < fan)
        hud.fanDots.setAttribute("aria-label", "FAN nível " + fan)
        if (typeof data.mode === "string") hud.climate.dataset.mode = data.mode
    }

    function renderPassenger(data) {
        const mood = data && MOOD[data.mood] ? data.mood : "none"
        hud.passenger.dataset.mood = mood
        hud.passengerLabel.textContent = MOOD[mood]
        const fear = data && data.fear && (data.fear.label || FEAR[data.fear.level]) ? data.fear : null
        show(hud.passengerFear, mood !== "none" && !!fear)
        if (fear) {
            hud.passenger.dataset.fear = fear.level
            hud.passengerFearLabel.textContent = fear.label || FEAR[fear.level]
        }
    }

    function renderOffer(offer) {
        if (!offer) return
        hud.offerOrigin.textContent = offer.origin || "—"
        hud.offerDistance.textContent = routeDistance(offer.distance)
        hud.offerEstimate.textContent = moneyInt(offer.estimateMin) + " — " + moneyInt(offer.estimateMax)
        hud.offerCountdown.textContent = seconds(offer.remaining)
    }

    function renderRoute(route) {
        if (!route) return
        hud.routeOrigin.textContent = route.origin || "—"
        hud.routeDistance.textContent = routeDistance(route.distance)
    }

    function renderResult(result) {
        if (!result) return
        hud.resultFare.textContent = moneyInt(result.fare)
        hud.resultBonus.textContent = moneyInt(Number(result.bonus) || 0)
        const c = Number(result.confidence) || 0
        hud.resultConfidence.textContent = (c >= 0 ? "+" : "") + int(c)
    }

    function renderKeys(keys) {
        if (!keys) return
        hud.keyFan.textContent = keys.fan || "G"
        hud.keyAccept.textContent = keys.accept || "E"
        hud.keyPause.textContent = keys.pause || "J"
    }

    function setState(state, data) {
        currentState = state || "HIDDEN"
        data = data || {}
        hud.meter.dataset.state = currentState
        hud.status.textContent = STATUS[currentState] || currentState
        setBody(currentState)
        renderMeter(data)
        renderClimate(data)
        renderPassenger(data.passenger)
        renderOffer(data.offer)
        renderRoute(data.route)
        renderResult(data.result)
        renderKeys(data.keys)
        show(hud.hintPause, currentState === "AVAILABLE" || currentState === "PAUSED")
    }

    function applyHudVisibility() {
        hud.root.hidden = !hudVisible || menu.open
    }

    // ═══════════════════════════════ CENTRAL ═══════════════════════════════

    const ERROR_TEXT = {
        not_loaded: "Personagem não carregado.",
        not_near: "Aproxime-se do atendente para alugar um veículo.",
        invalid_session: "Sua sessão na central expirou. Abra o atendimento novamente.",
        session_expired: "Sua sessão na central expirou. Abra o atendimento novamente.",
        activity_restricted: "A central de táxi está indisponível para seu personagem neste momento.",
        invalid_vehicle: "Este veículo não está disponível na central.",
        vehicle_locked: "Este veículo exige Nível de Confiança {level}.",
        already_rented: "Devolva seu táxi atual antes de alugar outro.",
        request_in_progress: "Aguarde a solicitação anterior terminar.",
        rate_limited: "Aguarde um instante antes de tentar novamente.",
        no_spawn_space: "As vagas da central estão ocupadas. Tente novamente em instantes.",
        insufficient_funds: "Você não possui dinheiro suficiente para este aluguel.",
        spawn_failed: "Não foi possível preparar o veículo. Nenhum valor foi cobrado.",
        internal_error: "Não foi possível concluir a solicitação. Tente novamente.",
    }

    const RETURN_ERRORS = {
        not_near: "Estacione o táxi no ponto da central para devolvê-lo.",
        not_yours: "Você não possui um táxi alugado no momento.",
    }

    const LOCK_SVG =
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="1"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>'

    const CHEV_SVG =
        '<svg class="veh-card__chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 18l6-6-6-6"/></svg>'

    const CAR_SVG =
        '<svg class="veh-card__fallback" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 17h-2v-5l2-5h14l2 5v5h-2" /><path d="M7 17a2 2 0 1 0 4 0 2 2 0 1 0-4 0" /><path d="M13 17a2 2 0 1 0 4 0 2 2 0 1 0-4 0" /><path d="M9 7v-2h6v2" /><path d="M3 12h18" /></svg>'

    const m = {
        root: $("taxi-menu"),
        main: $("wnd-main"),
        brand: $("menu-brand"),
        context: $("menu-context"),
        close: $("menu-close"),
        nav: Array.from(document.querySelectorAll(".nav-item")),
        drvName: $("drv-name"),
        drvLevel: $("drv-level"),
        // hero
        greeting: $("hero-greeting"),
        heroShift: $("hero-shift"),
        heroCta: $("hero-cta"),
        heroStatus: $("hero-status"),
        statEarned: $("stat-earned"),
        statRides: $("stat-rides"),
        statPosition: $("stat-position"),
        // progressão
        ring: $("lvl-ring"),
        ringNum: $("lvl-ring-num"),
        lvlLabel: $("lvl-label"),
        progBar: $("ov-progress"),
        progFill: $("ov-progress-fill"),
        progPct: $("ov-progress-pct"),
        progFraction: $("prog-fraction"),
        progNext: $("prog-next"),
        progRemaining: $("prog-remaining"),
        useValue: $("use-value"),
        useSub: $("use-sub"),
        // veículos
        vehSection: $("veh-section"),
        vehSub: $("veh-sub"),
        vehNotice: $("veh-notice"),
        vehList: $("veh-list"),
        vehMessage: $("veh-message"),
        vehRentMessage: $("veh-rent-message"),
        // ranking
        rankLoading: $("rank-loading"),
        rankError: $("rank-error"),
        rankEmpty: $("rank-empty"),
        rankList: $("rank-list"),
        rankSelf: $("rank-self"),
        rankSelfRow: $("rank-self-row"),
        rankUpdated: $("rank-updated"),
        // erro / modal
        error: $("menu-error"),
        retry: $("menu-retry"),
        modal: $("menu-modal"),
        modalTitle: $("modal-title"),
        modalText: $("modal-text"),
        modalCancel: $("modal-cancel"),
        modalConfirm: $("modal-confirm"),
    }

    const menu = {
        open: false,
        state: "closed", // closed | ready | renting | closing | error
        data: null,
        tab: "overview",
        selected: null,
        ranking: null, // null | "loading" | { generatedAt, entries, self } | "error"
        openedAt: 0,
        timers: [],
    }

    const later = (fn, ms) => {
        const id = setTimeout(fn, reducedMotion ? 0 : ms)
        menu.timers.push(id)
        return id
    }
    const clearTimers = () => {
        menu.timers.forEach(clearTimeout)
        menu.timers = []
    }

    // ───────────── perfil / hero / progressão ─────────────

    function firstName(fullName) {
        const part = String(fullName || "").trim().split(/\s+/)[0]
        return part || "Motorista"
    }

    function greetingPrefix() {
        const h = new Date().getHours()
        if (h >= 5 && h < 12) return "BOM DIA"
        if (h >= 12 && h < 18) return "BOA TARDE"
        return "BOA NOITE"
    }

    function renderProfile(profile) {
        if (!profile) return
        m.drvName.textContent = profile.displayName || "Motorista"
        m.drvLevel.textContent = "NÍVEL " + int(profile.level) + " · " + String(profile.levelLabel || "").toUpperCase()
        m.greeting.textContent = greetingPrefix() + ", " + firstName(profile.displayName)
    }

    function renderShift(data) {
        const active = !!(data && data.activeRental)
        m.heroShift.dataset.state = active ? "active" : "idle"
        m.heroCta.className = active ? "btn" : "btn btn--fill"
        const returning = menu.state === "returning"
        m.heroCta.disabled = returning
        m.heroCta.setAttribute("aria-disabled", String(returning))
        m.heroCta.dataset.pending = returning ? "true" : "false"
        m.heroCta.textContent = returning ? "DEVOLVENDO VEÍCULO" : active ? "DEVOLVER VEÍCULO" : "ALUGAR VEÍCULO"
        m.heroStatus.textContent = active ? "EM SERVIÇO" : "FORA DE SERVIÇO"
    }

    function renderStats(profile) {
        if (!profile) return
        m.statEarned.textContent = moneyInt(profile.earnedToday)
        m.statRides.textContent = int(profile.completedRides)
        renderPosition()
    }

    function renderPosition() {
        const r = menu.ranking
        const pos = r && typeof r === "object" && r.self && r.self.position != null ? ordinal(r.self.position) : "—"
        m.statPosition.textContent = pos
    }

    function renderProgression(profile) {
        if (!profile) return
        const pct = Math.max(0, Math.min(100, Number(profile.progressPercent) || 0))
        const deg = Math.round(pct * 3.6)
        m.ring.style.background =
            "conic-gradient(var(--taxi-accent) 0deg, var(--taxi-accent) " + deg + "deg, var(--taxi-track) " + deg + "deg)"
        m.ringNum.textContent = int(profile.level)
        m.lvlLabel.textContent = String(profile.levelLabel || "").toUpperCase()
        m.progFill.style.width = pct + "%"
        m.progPct.textContent = pct + "%"
        m.progBar.setAttribute("aria-valuenow", String(pct))
        if (profile.maxLevel) {
            m.progFraction.textContent = int(profile.confidence) + " CONFIANÇA"
            m.progNext.textContent = "NÍVEL MÁXIMO · " + String(profile.levelLabel || "").toUpperCase()
            show(m.progRemaining, false)
        } else {
            const span = Math.max(0, Number(profile.nextLevelAt) - Number(profile.levelStart))
            m.progFraction.textContent = int(Number(profile.confidence) - Number(profile.levelStart)) + " / " + int(span)
            const nextName = profile.nextLevelLabel ? String(profile.nextLevelLabel).toUpperCase() : "NÍVEL " + int(profile.level + 1)
            m.progNext.textContent = "PRÓXIMO NÍVEL · " + nextName
            m.progRemaining.textContent = "FALTAM " + int(profile.confidenceRemaining) + " DE CONFIANÇA"
            show(m.progRemaining, true)
        }
    }

    function renderSide(data) {
        const id = data && data.activeRental
        const v = id ? vehicleById(id) : null
        m.useValue.textContent = v ? v.label : id ? id : "NENHUM"
        m.useValue.dataset.active = String(!!id)
        m.useSub.textContent = id
            ? "Devolva o táxi no ponto da central para trocar."
            : "Alugue um veículo para iniciar o turno."
    }

    // ───────────── veículos ─────────────

    const failedImages = new Set()

    function vehicleById(id) {
        const list = (menu.data && menu.data.vehicles) || []
        return list.find((v) => v.id === id) || null
    }

    function firstAvailableVehicle() {
        const list = (menu.data && menu.data.vehicles) || []
        return list.find((v) => v.status === "available") || list[0] || null
    }

    function vehicleStatusText(v) {
        if (v.status === "locked") return "NÍVEL " + int(v.requiredLevel)
        if (v.status === "in_use") return "EM USO"
        if (v.status === "unavailable") return "INDISPONÍVEL"
        return "DISPONÍVEL"
    }

    function renderVehicleList() {
        const list = (menu.data && menu.data.vehicles) || []
        m.vehList.innerHTML = ""
        show(m.vehNotice, !!(menu.data && menu.data.activeRental))
        list.forEach((v) => {
            const card = document.createElement("div")
            card.className = "veh-card"
            card.setAttribute("role", "option")
            card.dataset.id = v.id
            card.dataset.status = v.status
            const selected = menu.selected === v.id
            card.setAttribute("aria-selected", String(selected))
            card.tabIndex = selected ? 0 : -1

            const statusIcon = v.status === "locked" ? LOCK_SVG : '<span class="veh-card__dot" aria-hidden="true"></span>'
            const mediaImg = failedImages.has(v.image) ? "" : '<img alt="" ' + (v.image ? 'src="' + v.image + '"' : "") + " />"
            const feeRow = Number(v.rentalFee) > 0
                ? '<span class="veh-card__fee"><span class="data-label">TAXA DE ALUGUEL</span><span class="veh-card__fee-value">' + moneyInt(v.rentalFee) + "</span></span>"
                : ""

            card.innerHTML =
                '<span class="veh-card__status">' + statusIcon + "<span></span></span>" +
                '<span class="veh-card__media">' + mediaImg + CAR_SVG + "</span>" +
                '<span class="veh-card__name"><span></span>' + CHEV_SVG + "</span>" +
                '<span class="veh-card__desc"></span>' +
                feeRow +
                '<button class="btn btn--primary veh-card__rent" type="button">ALUGAR VEÍCULO</button>'

            card.querySelector(".veh-card__status span").textContent = vehicleStatusText(v)
            card.querySelector(".veh-card__name span").textContent = v.label
            card.querySelector(".veh-card__desc").textContent = v.description || ""
            if (v.status === "locked") {
                card.setAttribute("aria-label", v.label + ", bloqueado, desbloqueia no nível " + v.requiredLevel)
                const img = card.querySelector("img")
                if (img) {
                    img.alt = ""
                    img.addEventListener("error", () => {
                        failedImages.add(v.image)
                        card.dataset.noimg = "true"
                    }, { once: true })
                }
            } else {
                const img = card.querySelector("img")
                if (img) {
                    img.alt = v.label
                    img.addEventListener("error", () => {
                        failedImages.add(v.image)
                        card.dataset.noimg = "true"
                    }, { once: true })
                }
            }
            if (!v.image || failedImages.has(v.image)) card.dataset.noimg = "true"

            card.addEventListener("click", () => selectVehicle(v.id, false))
            card.querySelector(".veh-card__rent").addEventListener("click", (ev) => {
                ev.stopPropagation()
                selectVehicle(v.id, false)
                onRentClick(v.id)
            })
            m.vehList.appendChild(card)
        })
        updateVehActions()
    }

    function canRent(v) {
        return !!v && v.status === "available" && !(menu.data && menu.data.activeRental) && menu.state === "ready"
    }

    function vehRentLabel(v) {
        if (menu.state === "renting") return "PREPARANDO VEÍCULO"
        if (v.status === "locked") return "DISPONÍVEL NO NÍVEL " + int(v.requiredLevel)
        return "ALUGAR VEÍCULO"
    }

    function updateVehActions() {
        Array.from(m.vehList.children).forEach((card) => {
            const v = vehicleById(card.dataset.id)
            const btn = card.querySelector(".veh-card__rent")
            if (!v || !btn) return
            const rentable = canRent(v)
            btn.disabled = !rentable
            btn.setAttribute("aria-disabled", String(!rentable))
            btn.dataset.pending = menu.state === "renting" ? "true" : "false"
            btn.textContent = vehRentLabel(v)
        })
    }

    function selectVehicle(id, focusCard) {
        if (!vehicleById(id)) return
        menu.selected = id
        hideMessage(m.vehRentMessage)
        Array.from(m.vehList.children).forEach((card) => {
            const sel = card.dataset.id === id
            card.setAttribute("aria-selected", String(sel))
            card.tabIndex = sel ? 0 : -1
            if (sel && focusCard) card.focus()
        })
        updateVehActions()
    }

    function moveVehicleSelection(delta) {
        const list = (menu.data && menu.data.vehicles) || []
        if (!list.length) return
        let idx = list.findIndex((v) => v.id === menu.selected)
        idx = idx < 0 ? 0 : Math.max(0, Math.min(list.length - 1, idx + delta))
        selectVehicle(list[idx].id, true)
    }

    function showMessage(el, text, kind) {
        if (!el) return
        const target = el.querySelector(".hero__alert-text") || el
        target.textContent = text
        el.dataset.kind = kind || "error"
        show(el, true)
    }
    function hideMessage(el) {
        if (el) show(el, false)
    }

    // ───────────── ranking ─────────────

    function rankRow(entry, extraClass, asDiv) {
        const li = document.createElement(asDiv ? "div" : "li")
        li.className = "rank-row" + (extraClass ? " " + extraClass : "")
        li.innerHTML =
            '<span class="rank-row__pos"></span><span class="rank-row__name"></span>' +
            '<span class="rank-row__level"></span><span class="rank-row__confidence"></span><span class="rank-row__rides"></span>'
        li.querySelector(".rank-row__pos").textContent = entry.position != null ? ordinal(entry.position) : "—"
        const name = li.querySelector(".rank-row__name")
        name.textContent = entry.displayName || "Motorista"
        name.title = entry.displayName || ""
        li.querySelector(".rank-row__level").textContent = "NÍVEL " + int(entry.level)
        li.querySelector(".rank-row__confidence").textContent = int(entry.confidence)
        li.querySelector(".rank-row__rides").textContent = int(entry.completedRides) + " CORRIDAS"
        return li
    }

    function renderRanking() {
        const r = menu.ranking
        show(m.rankLoading, r === "loading")
        show(m.rankError, r === "error")
        m.rankList.innerHTML = ""
        m.rankSelfRow.innerHTML = ""
        show(m.rankEmpty, false)
        show(m.rankSelf, false)
        show(m.rankUpdated, false)
        renderPosition()
        if (!r || typeof r !== "object") return

        const entries = Array.isArray(r.entries) ? r.entries : []
        show(m.rankEmpty, entries.length === 0)
        entries.forEach((e, i) => {
            const cls = i < 3 ? "rank-row--podium" + (i === 0 ? " rank-row--first" : "") : ""
            m.rankList.appendChild(rankRow(e, cls))
        })

        show(m.rankSelf, true)
        if (r.self && r.self.position != null) {
            const row = rankRow(r.self, "rank-row--self", true)
            m.rankSelfRow.replaceWith(row)
            row.id = "rank-self-row"
            m.rankSelfRow = row
        } else {
            m.rankSelfRow.className = "rank-row rank-row--none"
            m.rankSelfRow.textContent = "Ainda sem classificação"
        }

        const serverNow = (menu.data && menu.data.serverTime ? menu.data.serverTime : 0) + (Date.now() - menu.openedAt) / 1000
        const ago = Math.max(0, Math.round(serverNow - (Number(r.generatedAt) || serverNow)))
        m.rankUpdated.textContent = "ATUALIZADO HÁ " + int(ago) + " S"
        show(m.rankUpdated, true)
    }

    let rankingRequest = 0
    function loadRanking() {
        if (menu.ranking && menu.ranking !== "error") return
        menu.ranking = "loading"
        renderRanking()
        const req = ++rankingRequest
        post("requestRanking").then((res) => {
            if (!menu.open || req !== rankingRequest) return
            menu.ranking = res && res.ok && res.data ? res.data : "error"
            renderRanking()
        })
    }

    // ───────────── navegação ─────────────

    const SECTIONS = ["tab-overview", "veh-section", "tab-ranking"]
    const TAB_SECTIONS = {
        overview: ["tab-overview", "veh-section"],
        vehicles: ["veh-section"],
        ranking: ["tab-ranking"],
    }

    function setTab(tab, focusNav) {
        if (!TAB_SECTIONS[tab]) return
        menu.tab = tab
        m.main.dataset.tab = tab
        m.nav.forEach((btn) => {
            const sel = btn.dataset.tab === tab
            btn.setAttribute("aria-selected", String(sel))
            btn.tabIndex = sel ? 0 : -1
            if (sel && focusNav) btn.focus()
        })
        SECTIONS.forEach((id) => {
            const panel = document.getElementById(id)
            const visible = menu.state !== "error" && TAB_SECTIONS[tab].includes(id)
            if (visible && panel.hidden) {
                panel.hidden = false
                panel.style.animation = "none"
                void panel.offsetWidth
                panel.style.animation = ""
            } else if (!visible) {
                panel.hidden = true
            }
        })
        m.vehSection.dataset.mode = tab === "vehicles" ? "focus" : "compact"
        m.vehSub.textContent =
            tab === "vehicles"
                ? "Escolha um veículo liberado pelo seu Nível de Confiança."
                : "Escolha um veículo para iniciar o turno."
        if (tab === "vehicles" && !menu.selected) {
            const first = firstAvailableVehicle()
            if (first) menu.selected = first.id
            renderVehicleList()
        }
        updateVehActions()
        if (tab === "ranking") loadRanking()
    }

    function moveTab(delta) {
        const order = ["overview", "vehicles", "ranking"]
        const idx = order.indexOf(menu.tab)
        setTab(order[(idx + delta + order.length) % order.length], true)
    }

    // ───────────── ciclo de vida ─────────────

    function applyBootstrap(data) {
        menu.data = data
        menu.ranking = null
        m.root.dataset.status = "ready"
        show(m.error, false)
        if (data.header) {
            m.brand.textContent = data.header.brand || "NOIR CAB CO."
            m.context.textContent = data.header.context || "CENTRAL · LOS SANTOS"
        }
        renderProfile(data.profile)
        renderShift(data)
        renderStats(data.profile)
        renderProgression(data.profile)
        renderSide(data)
        if (!menu.selected || !vehicleById(menu.selected)) {
            const first = firstAvailableVehicle()
            menu.selected = first ? first.id : null
        }
        renderVehicleList()
        updateVehActions()
        loadRanking()
    }

    function openMenu(data) {
        clearTimers()
        menu.open = true
        menu.state = "ready"
        menu.openedAt = Date.now()
        menu.tab = "overview"
        menu.selected = null
        menu.ranking = null
        hideMessage(m.vehMessage)
        hideMessage(m.vehRentMessage)
        show(m.modal, false)
        document.getElementById("root").dataset.mode = "menu"
        applyHudVisibility()
        applyBootstrap(data || {})
        m.root.hidden = false
        m.root.dataset.anim = "enter"
        setTab("overview", false)
        later(() => m.nav[0].focus(), 50)
    }

    function hideMenu() {
        clearTimers()
        menu.open = false
        menu.state = "closed"
        menu.data = null
        menu.ranking = null
        show(m.modal, false)
        m.root.dataset.anim = "idle"
        m.root.hidden = true
        document.getElementById("root").dataset.mode = "closed"
        applyHudVisibility()
    }

    // Coreografia de saída: 240ms de fade; depois avisa o client para liberar o foco.
    function playExitAndComplete() {
        m.root.dataset.anim = "exit"
        later(() => {
            post("closeComplete")
            hideMenu()
        }, 300)
    }

    function requestClose() {
        if (!menu.open || menu.state === "closing" || menu.state === "renting" || menu.state === "returning") return
        if (!m.modal.hidden) {
            closeModal()
            return
        }
        menu.state = "closing"
        post("closeMenu", { reason: "user" }).then((res) => {
            if (!menu.open) return
            if (res && res.ok === false) {
                menu.state = "ready"
                return
            }
            playExitAndComplete()
        })
    }

    // ───────────── aluguel ─────────────

    let rateLock = false

    function startRent(vehicleId) {
        const v = vehicleById(vehicleId)
        if (!canRent(v) || rateLock) return
        menu.state = "renting"
        hideMessage(m.vehRentMessage)
        updateVehActions()
        post("rentVehicle", { vehicleId: v.id }).then((res) => {
            if (!menu.open) return
            if (res && res.ok) {
                menu.state = "closing"
                showMessage(m.vehRentMessage, "Veículo liberado. Boa corrida.", "success")
                playExitAndComplete()
                return
            }
            menu.state = "ready"
            const code = (res && res.code) || "internal_error"
            if (code === "rate_limited") {
                rateLock = true
                later(() => { rateLock = false; updateVehActions() }, 1500)
            } else if (code === "vehicle_locked") {
                showMessage(m.vehRentMessage, ERROR_TEXT.vehicle_locked.replace("{level}", int(res.requiredLevel || v.requiredLevel)))
            } else {
                showMessage(m.vehRentMessage, ERROR_TEXT[code] || ERROR_TEXT.internal_error)
            }
            if (code === "invalid_session" || code === "session_expired") {
                m.vehList.querySelectorAll(".veh-card__rent").forEach((b) => { b.disabled = true })
                return
            }
            updateVehActions()
        })
    }

    function openModal(v) {
        m.modalTitle.textContent = "ALUGAR " + String(v.label).toUpperCase()
        m.modalText.textContent = "O aluguel custa " + moneyInt(v.rentalFee) + " e será cobrado da sua conta definida pela central."
        m.modal.dataset.vehicle = v.id
        show(m.modal, true)
        m.modalCancel.focus()
    }

    function closeModal() {
        show(m.modal, false)
        const card = m.vehList.querySelector('[aria-selected="true"]')
        if (card) card.focus()
    }

    function onRentClick(id) {
        const v = vehicleById(id != null ? id : menu.selected)
        if (!canRent(v)) return
        if (Number(v.rentalFee) > 0) openModal(v)
        else startRent(v.id)
    }

    function requestReturn() {
        if (menu.state !== "ready" || !(menu.data && menu.data.activeRental)) return
        menu.state = "returning"
        hideMessage(m.vehMessage)
        renderShift(menu.data)
        updateVehActions()
        post("returnVehicle").then((res) => {
            if (!menu.open) return
            if (res && res.ok) {
                menu.state = "ready"
                if (res.data) {
                    applyBootstrap(res.data)
                } else {
                    menu.data.activeRental = null
                    renderShift(menu.data)
                    renderSide(menu.data)
                    renderVehicleList()
                }
                showMessage(m.vehMessage, "Veículo devolvido. Turno finalizado.", "success")
                return
            }
            menu.state = "ready"
            const code = (res && res.code) || "internal_error"
            showMessage(m.vehMessage, RETURN_ERRORS[code] || ERROR_TEXT[code] || ERROR_TEXT.internal_error)
            renderShift(menu.data)
            updateVehActions()
        })
    }

    // ───────────── retry do bootstrap ─────────────

    let retryLock = false
    function retryBootstrap() {
        if (retryLock || !menu.open) return
        retryLock = true
        m.retry.disabled = true
        m.root.dataset.status = "loading"
        post("retryBootstrap").then((res) => {
            later(() => { retryLock = false; m.retry.disabled = false }, 2000)
            if (!menu.open) return
            if (res && res.ok) {
                menu.state = "ready"
                applyBootstrap(res)
                setTab(menu.tab, true)
            } else {
                setErrorState()
            }
        })
    }

    function setErrorState() {
        menu.state = "error"
        m.root.dataset.status = "error"
        SECTIONS.forEach((id) => { document.getElementById(id).hidden = true })
        show(m.error, true)
    }

    // ───────────── eventos DOM ─────────────

    m.nav.forEach((btn) => btn.addEventListener("click", () => setTab(btn.dataset.tab, true)))
    m.close.addEventListener("click", requestClose)
    m.heroCta.addEventListener("click", () => {
        if (menu.data && menu.data.activeRental) {
            requestReturn()
            return
        }
        const first = firstAvailableVehicle()
        if (first) menu.selected = first.id
        setTab("vehicles", false)
        renderVehicleList()
        if (first) selectVehicle(first.id, true)
    })
    m.modalCancel.addEventListener("click", closeModal)
    m.modalConfirm.addEventListener("click", () => {
        const id = m.modal.dataset.vehicle
        show(m.modal, false)
        startRent(id)
    })
    m.retry.addEventListener("click", retryBootstrap)

    document.addEventListener("keydown", (ev) => {
        if (!menu.open) return
        const modalOpen = !m.modal.hidden
        if (ev.key === "Escape") {
            ev.preventDefault()
            if (modalOpen) closeModal()
            else requestClose()
            return
        }
        if (modalOpen || menu.state !== "ready") return

        const inList = ev.target && ev.target.classList && ev.target.classList.contains("veh-card")
        const inNav = ev.target && ev.target.classList && ev.target.classList.contains("nav-item")
        if (ev.key === "ArrowLeft") { ev.preventDefault(); moveTab(-1) }
        else if (ev.key === "ArrowRight") { ev.preventDefault(); moveTab(1) }
        else if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
            if (inNav) { ev.preventDefault(); moveTab(ev.key === "ArrowDown" ? 1 : -1) }
            else if (menu.tab !== "ranking" && (inList || ev.target === document.body)) {
                ev.preventDefault()
                moveVehicleSelection(ev.key === "ArrowDown" ? 1 : -1)
            }
        } else if (ev.key === "Enter" && inList) {
            ev.preventDefault()
            onRentClick()
        }
    })

    // ───────────── mensagens do client ─────────────

    const handlers = {
        "taxi:setVisible": (visible) => {
            hudVisible = !!visible
            applyHudVisibility()
        },
        "taxi:setState": (payload) => setState(payload.state, payload.data),
        "taxi:updateMeter": (payload) => { if (currentState === "HIRED") renderMeter(payload) },
        "taxi:updateClimate": (payload) => renderClimate(payload),
        "taxi:updatePassenger": (payload) => renderPassenger(payload),
        "taxi:updateOffer": (payload) => { if (currentState === "OFFER") hud.offerCountdown.textContent = seconds(payload.remaining) },
        "taxi:updateRoute": (payload) => {
            if (currentState === "EN_ROUTE" || currentState === "BOARDING") hud.routeDistance.textContent = routeDistance(payload.distance)
        },
        "taxiMenu:open": (payload) => openMenu(payload),
        "taxiMenu:close": () => hideMenu(),
    }

    window.addEventListener("message", (event) => {
        const msg = event.data || {}
        const handler = handlers[msg.action]
        if (handler) handler(msg.data)
    })

    // Avisa o client que a página carregou, para receber o estado atual.
    post("uiReady")
})()
