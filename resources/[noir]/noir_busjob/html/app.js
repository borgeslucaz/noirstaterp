(() => {
    "use strict"

    const $ = (id) => document.getElementById(id)
    const reducedMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_busjob"

    const PREVIEW_LIMIT = 3
    const TAB_ORDER = ["overview", "routes", "progression", "ranking"]
    const SECTIONS = ["tab-overview", "overview-progression", "routes-section", "tab-progression", "tab-ranking"]
    const TAB_SECTIONS = {
        overview: ["tab-overview", "overview-progression", "routes-section"],
        routes: ["routes-section"],
        progression: ["tab-progression"],
        ranking: ["tab-ranking"],
    }

    const menu = {
        lifecycle: "closed", // closed | ready | submitting | closing
        tab: "overview",
        railOpen: false,
        selectedId: null,
        data: null,
        failed: false,
        timers: [],
        modalInvoker: null,
    }

    const dom = {
        root: $("root"),
        menu: $("bus-menu"),
        window: $("bus-window"),
        main: $("window-main"),
        railToggle: $("rail-toggle"),
        close: $("menu-close"),
        nav: Array.from(document.querySelectorAll(".nav-item")),

        profileName: $("profile-name"),
        profileLevel: $("profile-level"),
        headerShift: $("header-shift"),
        headerShiftText: $("header-shift-text"),

        heroGreeting: $("hero-greeting"),
        heroNote: $("hero-note"),
        actionMessage: $("action-message"),
        metricLevel: $("metric-level"),
        metricRoutes: $("metric-routes"),
        metricRank: $("metric-rank"),

        overviewRing: $("overview-ring"),
        overviewRingNum: $("overview-ring-num"),
        overviewTitle: $("overview-title"),
        overviewProgress: $("overview-progress"),
        overviewProgressFill: $("overview-progress-fill"),
        overviewProgressPct: $("overview-progress-pct"),
        overviewFraction: $("overview-fraction"),
        overviewNext: $("overview-next"),
        activeValue: $("active-value"),
        activeSub: $("active-sub"),
        returnVehicle: $("return-vehicle"),

        routesSection: $("routes-section"),
        routesSub: $("routes-sub"),
        routesNotice: $("routes-notice"),
        routeList: $("route-list"),
        routeDetail: $("route-detail"),

        levelRing: $("level-ring"),
        ringLevel: $("ring-level"),
        progressTitle: $("progress-title"),
        progressBar: $("progress-bar"),
        progressFill: $("progress-fill"),
        progressPercent: $("progress-percent"),
        progressFraction: $("progress-fraction"),
        progressNext: $("progress-next"),
        levelList: $("level-list"),

        rankSelf: $("rank-self"),
        rankHead: $("rank-head"),
        rankSelfRow: $("rank-self-row"),
        rankingList: $("ranking-list"),
        rankingEmpty: $("ranking-empty"),

        menuError: $("menu-error"),
        returnModal: $("return-modal"),
        returnCancel: $("return-cancel"),
        returnConfirm: $("return-confirm"),
        returnMessage: $("return-message"),

        hud: $("route-hud"),
        hudCode: $("hud-code"),
        hudTitle: $("hud-title"),
        hudProgress: $("hud-progress"),
        hudPassengers: $("hud-passengers"),
        hudService: $("hud-service"),
        hudServiceFill: $("hud-service-fill"),

        summary: $("route-summary"),
        summaryScore: $("summary-score"),
        summaryService: $("summary-service"),
        summaryDetails: $("summary-details"),
    }

    const ERROR_TEXT = {
        invalid_session: "A sessão da Central expirou. Feche e abra novamente.",
        route_locked: "Esta linha ainda não foi liberada para seu nível.",
        spawn_failed: "Não foi possível preparar o ônibus. Tente novamente.",
        no_active_route: "Você não possui um ônibus ativo para devolver.",
        request_in_progress: "Aguarde a operação atual terminar.",
        profile_unavailable: "Não foi possível atualizar seu perfil.",
        internal_error: "Não foi possível concluir a operação. Tente novamente.",
        transport_error: "A Central não respondeu. Tente novamente.",
    }

    async function post(name, body = {}) {
        try {
            const response = await fetch(`https://${resource}/${name}`, {
                method: "POST",
                headers: { "Content-Type": "application/json; charset=UTF-8" },
                body: JSON.stringify(body),
            })
            return await response.json()
        } catch (_) {
            return { ok: false, code: "transport_error" }
        }
    }

    function later(fn, ms) {
        const id = setTimeout(fn, reducedMotion ? 0 : ms)
        menu.timers.push(id)
        return id
    }

    function clearTimers() {
        menu.timers.forEach(clearTimeout)
        menu.timers = []
    }

    function show(element, visible) {
        if (element) element.hidden = !visible
    }

    function int(value) {
        return Math.floor(Number(value) || 0).toLocaleString("pt-BR")
    }

    function decimal(value) {
        return (Number(value) || 0).toLocaleString("pt-BR", {
            minimumFractionDigits: 1,
            maximumFractionDigits: 1,
        })
    }

    function element(tag, className, text) {
        const node = document.createElement(tag)
        if (className) node.className = className
        if (text !== undefined) node.textContent = text
        return node
    }

    function routeShortName(route) {
        return String((route && route.name) || "Linha").replace(/^.*?·\s*/, "")
    }

    function firstName(full) {
        return String(full || "").trim().split(/\s+/)[0] || ""
    }

    function sortedRoutes() {
        const routes = Array.isArray(menu.data && menu.data.routes) ? [...menu.data.routes] : []
        return routes.sort((a, b) => {
            const level = (Number(a.minimumLevel) || 0) - (Number(b.minimumLevel) || 0)
            if (level) return level
            const aNumber = Number((String(a.code || "").match(/\d+/) || [Number.MAX_SAFE_INTEGER])[0])
            const bNumber = Number((String(b.code || "").match(/\d+/) || [Number.MAX_SAFE_INTEGER])[0])
            return aNumber - bNumber || String(a.code || "").localeCompare(String(b.code || ""), "pt-BR")
        })
    }

    function visibleRoutes() {
        const routes = sortedRoutes()
        return menu.tab === "overview" ? routes.slice(0, PREVIEW_LIMIT) : routes
    }

    function selectedRoute() {
        return sortedRoutes().find((route) => route.id === menu.selectedId) || null
    }

    function activeRoute() {
        return (menu.data && menu.data.activeRoute) || null
    }

    function setActionMessage(text, kind = "error") {
        dom.actionMessage.textContent = text || ""
        dom.actionMessage.dataset.kind = kind
        show(dom.actionMessage, !!text)
    }

    // ───────────── cabeçalho e resumo ─────────────

    function renderProfile() {
        const profile = menu.data && menu.data.profile
        if (!profile) return
        const title = String(profile.title || "Motorista").toUpperCase()
        dom.profileName.textContent = profile.displayName || "Motorista"
        dom.profileLevel.textContent = `NÍVEL ${int(profile.level)} · ${title}`
        dom.metricLevel.textContent = int(profile.level)
        dom.metricRoutes.textContent = int(profile.routes)
        dom.metricRank.textContent = `#${int(profile.rank)}`

        const greeting = firstName(profile.displayName)
        dom.heroGreeting.textContent = greeting ? `BEM-VINDO, ${greeting.toUpperCase()}` : "BEM-VINDO"
    }

    function renderShift() {
        const active = activeRoute()
        const short = active ? routeShortName(active) : ""

        dom.headerShift.dataset.state = active ? "active" : "idle"
        dom.headerShiftText.textContent = active ? `EM SERVIÇO · ${active.code}` : "FORA DE SERVIÇO"

        dom.heroNote.textContent = active
            ? `Conclua as paradas da linha ${active.code} e devolva o ônibus à garagem para receber.`
            : "Escolha uma linha, opere o serviço com segurança e devolva o ônibus à garagem para concluir."

        dom.activeValue.dataset.active = String(!!active)
        dom.activeValue.textContent = active ? `${active.code} · ${short}` : "NENHUMA"
        dom.activeSub.textContent = active
            ? "Devolver o veículo cancela a linha sem pagamento ou XP."
            : "Escolha uma linha para iniciar o serviço."

        show(dom.returnVehicle, !!active)
        dom.returnVehicle.disabled = menu.lifecycle !== "ready"
        dom.returnVehicle.dataset.pending = menu.lifecycle === "submitting" ? "true" : "false"
    }

    // ───────────── progressão ─────────────

    function progressView() {
        const profile = menu.data && menu.data.profile
        const progression = Array.isArray(menu.data && menu.data.progression) ? menu.data.progression : []
        if (!profile) return null

        const level = Number(profile.level) || 1
        const current = progression.find((tier) => Number(tier.level) === level) || progression[0] || { xp: 0 }
        const next = progression.find((tier) => Number(tier.level) === level + 1)
        const startXp = Number(current.xp) || 0
        const span = next ? Math.max(1, Number(next.xp) - startXp) : 1
        const earned = Math.max(0, (Number(profile.xp) || 0) - startXp)
        const percent = next ? Math.max(0, Math.min(100, Math.round((earned / span) * 100))) : 100

        return {
            level,
            percent,
            title: String(profile.title || "Motorista").toUpperCase(),
            fraction: next ? `${int(profile.xp)} / ${int(next.xp)} XP` : `${int(profile.xp)} XP`,
            next: next
                ? `PRÓXIMO NÍVEL · ${String(next.title || "").toUpperCase()}`
                : "NÍVEL MÁXIMO ALCANÇADO",
            progression,
        }
    }

    function paintProgress(view, nodes) {
        const degrees = Math.round(view.percent * 3.6)
        nodes.ring.style.background = `conic-gradient(var(--noir-accent) ${degrees}deg, rgba(255, 255, 255, 0.10) ${degrees}deg)`
        nodes.ring.setAttribute("aria-label", `Nível ${int(view.level)}, progresso ${view.percent}%`)
        nodes.ringNum.textContent = int(view.level)
        nodes.title.textContent = view.title
        nodes.fill.style.width = `${view.percent}%`
        nodes.pct.textContent = `${view.percent}%`
        nodes.bar.setAttribute("aria-valuenow", String(view.percent))
        nodes.fraction.textContent = view.fraction
        nodes.next.textContent = view.next
    }

    function renderProgression() {
        const view = progressView()
        if (!view) return

        paintProgress(view, {
            ring: dom.overviewRing,
            ringNum: dom.overviewRingNum,
            title: dom.overviewTitle,
            bar: dom.overviewProgress,
            fill: dom.overviewProgressFill,
            pct: dom.overviewProgressPct,
            fraction: dom.overviewFraction,
            next: dom.overviewNext,
        })

        paintProgress(view, {
            ring: dom.levelRing,
            ringNum: dom.ringLevel,
            title: dom.progressTitle,
            bar: dom.progressBar,
            fill: dom.progressFill,
            pct: dom.progressPercent,
            fraction: dom.progressFraction,
            next: dom.progressNext,
        })

        const rows = view.progression.map((tier) => {
            const level = Number(tier.level) || 0
            const row = element("div", "level-row")
            row.dataset.state = level < view.level ? "complete" : level === view.level ? "current" : "locked"

            const unlocks = Array.isArray(tier.unlocks) ? tier.unlocks.join(" · ") : ""
            const unlocksNode = element("span", "level-row__unlocks", unlocks)
            unlocksNode.title = unlocks

            row.append(
                element("span", "level-row__number", String(level).padStart(2, "0")),
                element("span", "level-row__title", tier.title || "Motorista"),
                unlocksNode,
                element(
                    "span",
                    "level-row__state",
                    level < view.level ? "CONCLUÍDO" : level === view.level ? "ATUAL" : `${int(tier.xp)} XP`
                )
            )
            return row
        })
        dom.levelList.replaceChildren(...rows)
    }

    // ───────────── linhas ─────────────

    function createRouteCard(route) {
        const selected = route.id === menu.selectedId
        const card = element("button", "route-card")
        card.type = "button"
        card.dataset.route = route.id
        card.dataset.available = String(!!route.available)
        card.setAttribute("role", "option")
        card.setAttribute("aria-selected", String(selected))
        card.setAttribute("aria-disabled", String(!route.available))
        card.disabled = !route.available
        card.tabIndex = selected ? 0 : -1

        const body = element("span", "route-card__body")
        body.append(
            element("span", "route-card__name", routeShortName(route)),
            element("span", "route-card__meta", `${int(route.stopCount)} PARADAS · ${String(route.vehicle || "").toUpperCase()}`)
        )

        card.append(
            element("span", "route-card__code", route.code || "—"),
            body,
            element(
                "span",
                "route-card__status",
                route.available ? `NÍVEL ${int(route.minimumLevel)}` : `BLOQUEADA · NÍVEL ${int(route.minimumLevel)}`
            )
        )

        if (route.available) card.addEventListener("click", () => onRouteCardClick(route.id))
        return card
    }

    function renderRouteList() {
        dom.routeList.replaceChildren(...visibleRoutes().map(createRouteCard))
    }

    function appendPair(container, label, value) {
        const pair = element("span", "pair")
        pair.append(element("span", "data-label", label), element("span", "pair__value", value))
        container.appendChild(pair)
    }

    function renderRouteDetail() {
        const route = selectedRoute()
        dom.routeDetail.replaceChildren()
        if (!route) {
            dom.routeDetail.appendChild(element("p", "empty-state", "Nenhuma linha disponível para seleção."))
            return
        }

        const stats = element("div", "route-detail__stats")
        appendPair(stats, "TIPO", String(route.vehicle || "—").toUpperCase())
        appendPair(stats, "PARADAS", int(route.stopCount))
        appendPair(stats, "XP BASE", int(route.baseXp))
        appendPair(stats, "NÍVEL", int(route.minimumLevel))

        const stops = element("ol", "stop-list")
        const routeStops = Array.isArray(route.stops) ? route.stops : []
        routeStops.forEach((stop) => stops.appendChild(element("li", null, stop || "Parada")))

        const active = activeRoute()
        const start = element("button", "btn btn--fill route-detail__action")
        start.type = "button"
        start.disabled = !route.available || !!active || menu.lifecycle !== "ready"
        start.setAttribute("aria-disabled", String(start.disabled))
        start.dataset.pending = menu.lifecycle === "submitting" ? "true" : "false"
        start.textContent = menu.lifecycle === "submitting"
            ? "PREPARANDO ÔNIBUS"
            : active
                ? "SERVIÇO JÁ INICIADO"
                : route.available
                    ? "INICIAR LINHA"
                    : `NÍVEL ${int(route.minimumLevel)} NECESSÁRIO`
        start.addEventListener("click", startRoute)

        dom.routeDetail.append(
            element("p", "route-detail__eyebrow", `${route.code} · DETALHES DA LINHA`),
            element("h2", "route-detail__title", routeShortName(route)),
            stats,
            element("span", "data-label route-detail__stops-label", "ITINERÁRIO"),
            stops,
            start
        )

        if (!route.available) {
            dom.routeDetail.appendChild(
                element("p", "route-detail__lock", `BLOQUEADA · NÍVEL ${int(route.minimumLevel)} NECESSÁRIO`)
            )
        }
    }

    function renderRoutesSection() {
        const focus = menu.tab === "routes"
        dom.routesSection.dataset.mode = focus ? "focus" : "compact"
        dom.routesSub.textContent = focus
            ? "Ordenadas pelo nível necessário"
            : `Prévia · ${Math.min(PREVIEW_LIMIT, sortedRoutes().length)} de ${int(sortedRoutes().length)} linhas`
        show(dom.routesNotice, !!activeRoute())
        renderRouteList()
        renderRouteDetail()
    }

    function selectRoute(id, focusCard) {
        const route = sortedRoutes().find((item) => item.id === id && item.available)
        if (!route) return
        menu.selectedId = route.id
        setActionMessage("")
        Array.from(dom.routeList.children).forEach((card) => {
            const selected = card.dataset.route === route.id
            card.setAttribute("aria-selected", String(selected))
            card.tabIndex = selected ? 0 : -1
            if (selected && focusCard) card.focus()
        })
        renderRouteDetail()
    }

    // Na Central o cartão é uma prévia: seleciona e leva ao catálogo, onde está o detalhe.
    function onRouteCardClick(id) {
        if (menu.tab === "overview") {
            menu.selectedId = id
            setTab("routes", false)
            selectRoute(id, true)
            return
        }
        selectRoute(id, false)
    }

    function moveRoute(delta) {
        const available = visibleRoutes().filter((route) => route.available)
        if (!available.length) return
        const current = available.findIndex((route) => route.id === menu.selectedId)
        const index = Math.max(0, Math.min(available.length - 1, (current < 0 ? 0 : current) + delta))
        selectRoute(available[index].id, true)
    }

    async function startRoute() {
        const route = selectedRoute()
        if (!route || !route.available || activeRoute() || menu.lifecycle !== "ready") return
        menu.lifecycle = "submitting"
        setActionMessage("")
        renderShift()
        renderRouteDetail()

        const response = await post("startRoute", { routeId: route.id })
        if (!menu.data || menu.lifecycle === "closing") return
        if (response && response.ok) return

        menu.lifecycle = "ready"
        renderShift()
        renderRouteDetail()
        const code = (response && response.code) || "internal_error"
        setActionMessage(ERROR_TEXT[code] || ERROR_TEXT.internal_error)
    }

    // ───────────── ranking ─────────────

    function rankRow(entry, className) {
        const row = element("li", className)
        row.append(
            element("span", "rank-row__pos", `#${int(entry.rank)}`),
            element("span", "rank-row__name", entry.name || "Motorista"),
            element("span", "rank-row__level", `NÍVEL ${int(entry.level)}`),
            element("span", "rank-row__xp", `${int(entry.xp)} XP`),
            element("span", "rank-row__routes", `${int(entry.routes)} LINHAS`),
            element("span", "rank-row__score", decimal(entry.averageScore))
        )
        return row
    }

    function renderRanking() {
        const entries = Array.isArray(menu.data && menu.data.leaderboard) ? menu.data.leaderboard.slice(0, 50) : []
        const rows = entries.map((entry) => {
            const position = Number(entry.rank) || 0
            let className = "rank-row"
            if (position >= 1 && position <= 3) className += " rank-row--podium"
            if (position === 1) className += " rank-row--first"
            return rankRow(entry, className)
        })
        dom.rankingList.replaceChildren(...rows)
        show(dom.rankHead, rows.length > 0)
        show(dom.rankingEmpty, rows.length === 0)

        const profile = (menu.data && menu.data.profile) || {}
        const own = entries.find((entry) => Number(entry.rank) === Number(profile.rank))
        dom.rankSelfRow.replaceChildren()
        dom.rankSelfRow.className = "rank-row rank-row--self"

        if (own) {
            dom.rankSelfRow.append(...Array.from(rankRow(own, "").childNodes))
            return
        }

        dom.rankSelfRow.className = "rank-row rank-row--self rank-row--none"
        dom.rankSelfRow.textContent = `#${int(profile.rank)} · ${profile.displayName || "Motorista"} · ${int(profile.xp)} XP`
    }

    // ───────────── navegação ─────────────

    function renderRail() {
        dom.window.dataset.rail = menu.railOpen ? "open" : "closed"
        dom.railToggle.setAttribute("aria-expanded", String(menu.railOpen))
        dom.railToggle.setAttribute("aria-label", menu.railOpen ? "Fechar menu lateral" : "Abrir menu lateral")
    }

    function toggleRail() {
        menu.railOpen = !menu.railOpen
        renderRail()
    }

    function setTab(tab, focusNav) {
        if (!TAB_SECTIONS[tab]) return
        menu.tab = tab
        dom.main.dataset.tab = tab

        dom.nav.forEach((button) => {
            const selected = button.dataset.tab === tab
            button.setAttribute("aria-selected", String(selected))
            button.tabIndex = selected ? 0 : -1
            if (selected && focusNav) button.focus()
        })

        SECTIONS.forEach((id) => {
            const panel = document.getElementById(id)
            const visible = !menu.failed && TAB_SECTIONS[tab].includes(id)
            if (visible && panel.hidden) {
                panel.hidden = false
                panel.style.animation = "none"
                void panel.offsetWidth
                panel.style.animation = ""
            } else if (!visible) {
                panel.hidden = true
            }
        })

        if (!menu.failed && (tab === "overview" || tab === "routes")) renderRoutesSection()
    }

    function moveTab(delta) {
        const index = TAB_ORDER.indexOf(menu.tab)
        setTab(TAB_ORDER[(index + delta + TAB_ORDER.length) % TAB_ORDER.length], true)
    }

    // ───────────── ciclo de vida ─────────────

    function renderAll() {
        const routes = sortedRoutes()
        const active = activeRoute()
        const current = routes.find((route) => route.id === menu.selectedId && route.available)
        if (!current) {
            const preferred = active && routes.find((route) => route.id === active.id)
            menu.selectedId = ((preferred || routes.find((route) => route.available) || routes[0] || {}).id) || null
        }
        renderProfile()
        renderShift()
        renderProgression()
        renderRoutesSection()
        renderRanking()
    }

    function applySnapshot(data) {
        if (!data || !data.profile || !Array.isArray(data.routes)) {
            menu.failed = true
            show(dom.menuError, true)
            setTab(menu.tab, false)
            return false
        }
        menu.data = data
        menu.failed = false
        show(dom.menuError, false)
        renderAll()
        setTab(menu.tab, false)
        return true
    }

    function openMenu(data) {
        clearTimers()
        menu.lifecycle = "ready"
        menu.tab = "overview"
        menu.selectedId = null
        menu.modalInvoker = null
        menu.failed = false
        show(dom.returnModal, false)
        setActionMessage("")
        dom.root.dataset.mode = "menu"
        dom.menu.hidden = false
        dom.menu.dataset.anim = "enter"
        dom.menu.dataset.status = "ready"
        renderRail()
        applySnapshot(data)
        later(() => dom.nav[0].focus(), 60)
    }

    function hideMenu() {
        clearTimers()
        menu.lifecycle = "closed"
        menu.data = null
        menu.selectedId = null
        menu.modalInvoker = null
        menu.failed = false
        show(dom.returnModal, false)
        dom.menu.dataset.anim = "idle"
        dom.menu.hidden = true
        dom.root.dataset.mode = "closed"
    }

    function playExitAndComplete() {
        if (menu.lifecycle === "closed") return
        menu.lifecycle = "closing"
        dom.menu.dataset.anim = "exit"
        later(async () => {
            await post("closeComplete")
            hideMenu()
        }, 280)
    }

    async function requestClose() {
        if (menu.lifecycle !== "ready") return
        if (!dom.returnModal.hidden) {
            closeReturnModal()
            return
        }
        menu.lifecycle = "closing"
        const response = await post("closeMenu", { reason: "user" })
        if (response && response.ok === false) {
            menu.lifecycle = "ready"
            return
        }
        playExitAndComplete()
    }

    // ───────────── devolução do veículo ─────────────

    function openReturnModal() {
        if (menu.lifecycle !== "ready" || !activeRoute()) return
        menu.modalInvoker = document.activeElement
        dom.returnMessage.textContent = ""
        show(dom.returnMessage, false)
        show(dom.returnModal, true)
        dom.returnCancel.focus()
    }

    function closeReturnModal() {
        if (menu.lifecycle === "submitting") return
        show(dom.returnModal, false)
        const invoker = menu.modalInvoker
        menu.modalInvoker = null
        if (invoker && typeof invoker.focus === "function") invoker.focus()
    }

    function resetReturnControls() {
        dom.returnConfirm.disabled = false
        dom.returnCancel.disabled = false
        dom.returnConfirm.dataset.pending = "false"
        dom.returnConfirm.textContent = "DEVOLVER ÔNIBUS"
    }

    async function returnVehicle() {
        if (menu.lifecycle !== "ready" || !activeRoute()) return
        menu.lifecycle = "submitting"
        dom.returnConfirm.disabled = true
        dom.returnCancel.disabled = true
        dom.returnConfirm.dataset.pending = "true"
        dom.returnConfirm.textContent = "DEVOLVENDO VEÍCULO"

        const response = await post("returnVehicle")
        if (!menu.data || menu.lifecycle === "closing") return

        if (response && response.ok) {
            menu.lifecycle = "ready"
            resetReturnControls()
            show(dom.returnModal, false)
            menu.modalInvoker = null
            applySnapshot(response.data || { ...menu.data, activeRoute: null })
            setActionMessage("Ônibus devolvido. Serviço cancelado sem pagamento ou XP.", "success")
            dom.nav[0].focus()
            return
        }

        menu.lifecycle = "ready"
        resetReturnControls()
        const code = (response && response.code) || "internal_error"
        dom.returnMessage.textContent = ERROR_TEXT[code] || ERROR_TEXT.internal_error
        show(dom.returnMessage, true)
        dom.returnCancel.focus()
    }

    // ───────────── HUD e resumo ─────────────

    let serviceHudTimer = null

    function hideServiceHud() {
        if (serviceHudTimer) clearTimeout(serviceHudTimer)
        serviceHudTimer = null
        show(dom.hudService, false)
    }

    function showServiceHud(timeoutMs) {
        if (serviceHudTimer) clearTimeout(serviceHudTimer)
        const duration = Math.max(1, Number(timeoutMs) || 25000)
        show(dom.hudService, true)
        dom.hudServiceFill.style.transition = "none"
        dom.hudServiceFill.style.width = "100%"
        requestAnimationFrame(() => requestAnimationFrame(() => {
            dom.hudServiceFill.style.transition = `width ${duration}ms linear`
            dom.hudServiceFill.style.width = "0%"
        }))
        serviceHudTimer = setTimeout(hideServiceHud, duration)
    }

    function renderHud(data) {
        if (!data || !data.visible) {
            hideServiceHud()
            show(dom.hud, false)
            return
        }

        dom.hudCode.textContent = data.routeCode || "SERVIÇO"
        if (data.mode === "returning") dom.hudTitle.textContent = "RETORNE À GARAGEM"
        else if (data.mode === "docked") dom.hudTitle.textContent = `${data.stopName || "PARADA"} · ATENDIMENTO INICIANDO`
        else dom.hudTitle.textContent = data.stopName || "PRÓXIMA PARADA"

        dom.hudProgress.textContent = data.mode === "returning"
            ? "PARADAS CONCLUÍDAS"
            : data.stopIndex
                ? `${int(data.stopIndex)} / ${int(data.stopCount)}${data.distance != null ? ` · ${int(data.distance)} M` : ""}`
                : "SERVIÇO EM PREPARO"
        dom.hudPassengers.textContent = `${int(data.passengers)} / ${int(data.capacity)}`

        if (data.service) showServiceHud(data.serviceTimeoutMs)
        else hideServiceHud()
        show(dom.hud, true)
    }

    let summaryTimer = null

    function summaryDetail(label, value) {
        const item = element("span")
        item.append(document.createTextNode(`${label} `), element("strong", null, value))
        return item
    }

    function renderSummary(data) {
        if (!data) return
        if (summaryTimer) clearTimeout(summaryTimer)

        dom.summaryScore.textContent = `${Math.round(Number(data.finalScore) || 0)} PONTOS`
        dom.summaryService.textContent = data.leveledUp ? `NOVO NÍVEL · ${int(data.level)}` : "SERVIÇO FINALIZADO"
        dom.summaryDetails.replaceChildren(
            summaryDetail("PARADAS", int(data.stops)),
            summaryDetail("PASSAGEIROS", int(data.passengers)),
            summaryDetail("PAGAMENTO", `$${int(data.payout)}`),
            summaryDetail("EXPERIÊNCIA", `+${int(data.xp)} XP`)
        )

        show(dom.summary, true)
        summaryTimer = setTimeout(() => show(dom.summary, false), 10000)
    }

    // ───────────── eventos ─────────────

    dom.nav.forEach((button) => button.addEventListener("click", () => setTab(button.dataset.tab, true)))
    dom.railToggle.addEventListener("click", toggleRail)
    dom.close.addEventListener("click", requestClose)
    dom.returnVehicle.addEventListener("click", openReturnModal)
    dom.returnCancel.addEventListener("click", closeReturnModal)
    dom.returnConfirm.addEventListener("click", returnVehicle)

    document.addEventListener("keydown", (event) => {
        if (menu.lifecycle === "closed") return
        const modalOpen = !dom.returnModal.hidden

        if (event.key === "Escape") {
            event.preventDefault()
            if (modalOpen) closeReturnModal()
            else requestClose()
            return
        }

        if (modalOpen) {
            if (event.key === "Tab") {
                const controls = [dom.returnCancel, dom.returnConfirm].filter((button) => !button.disabled)
                if (!controls.length) return
                const index = controls.indexOf(document.activeElement)
                event.preventDefault()
                controls[(index + (event.shiftKey ? -1 : 1) + controls.length) % controls.length].focus()
            }
            return
        }

        if (menu.lifecycle !== "ready") return
        const target = event.target
        const inNav = target && target.classList && target.classList.contains("nav-item")
        const inRoutes = target && target.classList && target.classList.contains("route-card")

        if (inNav && (event.key === "Home" || event.key === "End")) {
            event.preventDefault()
            setTab(event.key === "Home" ? TAB_ORDER[0] : TAB_ORDER[TAB_ORDER.length - 1], true)
        } else if (event.key === "ArrowDown" || event.key === "ArrowUp") {
            if (inNav) {
                event.preventDefault()
                moveTab(event.key === "ArrowDown" ? 1 : -1)
            } else if (inRoutes) {
                event.preventDefault()
                moveRoute(event.key === "ArrowDown" ? 1 : -1)
            }
        } else if (inRoutes && (event.key === "Enter" || event.key === " ")) {
            event.preventDefault()
            onRouteCardClick(target.dataset.route)
        }
    })

    const handlers = {
        "busMenu:open": openMenu,
        "busMenu:close": (data) => (data && data.immediate ? hideMenu() : playExitAndComplete()),
        "busMenu:update": applySnapshot,
        "bus:setRouteHud": renderHud,
        "bus:summary": renderSummary,
    }

    window.addEventListener("message", (event) => {
        const message = event.data || {}
        const handler = handlers[message.action]
        if (handler) handler(message.data)
    })

    post("uiReady")
})()
