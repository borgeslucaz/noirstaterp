(() => {
    "use strict"

    const $ = (id) => document.getElementById(id)
    const reducedMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_busjob"

    const menu = {
        lifecycle: "closed", // closed | ready | submitting | closing
        tab: "routes",
        selectedId: null,
        data: null,
        timers: [],
        modalInvoker: null,
    }

    const dom = {
        root: $("root"),
        menu: $("bus-menu"),
        close: $("menu-close"),
        nav: Array.from(document.querySelectorAll(".nav-item")),
        tabs: {
            routes: $("tab-routes"),
            progression: $("tab-progression"),
            ranking: $("tab-ranking"),
        },
        profileName: $("profile-name"),
        profileLevel: $("profile-level"),
        heroTitle: $("hero-title"),
        heroNote: $("hero-note"),
        heroService: $("hero-service"),
        serviceLabel: $("service-label"),
        returnVehicle: $("return-vehicle"),
        actionMessage: $("action-message"),
        metricLevel: $("metric-level"),
        metricRank: $("metric-rank"),
        metricRoutes: $("metric-routes"),
        routeList: $("route-list"),
        routeDetail: $("route-detail"),
        levelRing: $("level-ring"),
        ringLevel: $("ring-level"),
        progressTitle: $("progress-title"),
        progressBar: $("progress-bar"),
        progressFill: $("progress-fill"),
        progressPercent: $("progress-percent"),
        progressFraction: $("progress-fraction"),
        levelList: $("level-list"),
        rankingList: $("ranking-list"),
        rankingEmpty: $("ranking-empty"),
        rankingSelf: $("ranking-self"),
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

    function routeShortName(route) {
        return String(route && route.name || "Linha").replace(/^.*?·\s*/, "")
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

    function selectedRoute() {
        return sortedRoutes().find((route) => route.id === menu.selectedId) || null
    }

    function setActionMessage(text, kind = "error") {
        dom.actionMessage.textContent = text || ""
        dom.actionMessage.dataset.kind = kind
        show(dom.actionMessage, !!text)
    }

    function renderProfile() {
        const profile = menu.data && menu.data.profile
        if (!profile) return
        dom.profileName.textContent = profile.displayName || "Motorista"
        dom.profileLevel.textContent = `NÍVEL ${int(profile.level)} · ${String(profile.title || "").toUpperCase()}`
        dom.metricLevel.textContent = int(profile.level)
        dom.metricRank.textContent = `#${int(profile.rank)}`
        dom.metricRoutes.textContent = int(profile.routes)
    }

    function renderHero() {
        const active = menu.data && menu.data.activeRoute
        dom.heroService.dataset.active = String(!!active)
        show(dom.returnVehicle, !!active)
        dom.returnVehicle.disabled = menu.lifecycle !== "ready"
        dom.returnVehicle.dataset.pending = menu.lifecycle === "submitting" ? "true" : "false"

        if (active) {
            dom.heroTitle.textContent = "SERVIÇO EM ANDAMENTO"
            dom.heroNote.textContent = `${active.code} · ${routeShortName(active)} — devolva o veículo para cancelar esta linha.`
            dom.serviceLabel.textContent = `${active.code} · ${String(active.state || "ATIVO").replaceAll("_", " ")}`
            dom.returnVehicle.textContent = menu.lifecycle === "submitting" ? "DEVOLVENDO VEÍCULO" : "DEVOLVER VEÍCULO"
        } else {
            dom.heroTitle.textContent = "ESCOLHA SUA PRÓXIMA LINHA"
            dom.heroNote.textContent = "Opere o serviço com segurança e devolva o ônibus à garagem para concluir."
            dom.serviceLabel.textContent = "DISPONÍVEL PARA SERVIÇO"
            dom.returnVehicle.textContent = "DEVOLVER VEÍCULO"
        }
    }

    function createRouteCard(route) {
        const button = document.createElement("button")
        button.type = "button"
        button.className = "route-card"
        button.dataset.route = route.id
        button.setAttribute("role", "option")
        button.setAttribute("aria-selected", String(route.id === menu.selectedId))
        button.setAttribute("aria-disabled", String(!route.available))
        button.disabled = !route.available
        button.tabIndex = route.id === menu.selectedId ? 0 : -1

        const code = document.createElement("span")
        code.className = "route-card__code"
        code.textContent = route.code || "—"

        const body = document.createElement("span")
        body.className = "route-card__body"
        const name = document.createElement("span")
        name.className = "route-card__name"
        name.textContent = routeShortName(route)
        const meta = document.createElement("span")
        meta.className = "route-card__meta"
        meta.textContent = `${int(route.stopCount)} PARADAS · ${String(route.vehicle || "").toUpperCase()}`
        body.append(name, meta)

        const status = document.createElement("span")
        status.className = "route-card__status"
        status.textContent = route.available ? `NÍVEL ${int(route.minimumLevel)}` : `BLOQUEADA · NÍVEL ${int(route.minimumLevel)}`

        button.append(code, body, status)
        if (route.available) button.addEventListener("click", () => selectRoute(route.id, false))
        return button
    }

    function renderRouteList() {
        const routes = sortedRoutes()
        dom.routeList.replaceChildren(...routes.map(createRouteCard))
    }

    function appendDetailStat(container, label, value) {
        const item = document.createElement("span")
        item.append(document.createTextNode(`${label} · `))
        const strong = document.createElement("strong")
        strong.textContent = value
        item.appendChild(strong)
        container.appendChild(item)
    }

    function renderRouteDetail() {
        const route = selectedRoute()
        dom.routeDetail.replaceChildren()
        if (!route) {
            const empty = document.createElement("p")
            empty.className = "empty-state"
            empty.textContent = "Nenhuma linha disponível para seleção."
            dom.routeDetail.appendChild(empty)
            return
        }

        const eyebrow = document.createElement("p")
        eyebrow.className = "route-detail__eyebrow"
        eyebrow.textContent = `${route.code} · DETALHES DA LINHA`
        const title = document.createElement("h2")
        title.textContent = routeShortName(route)
        const stats = document.createElement("div")
        stats.className = "route-detail__stats"
        appendDetailStat(stats, "TIPO", String(route.vehicle || "").toUpperCase())
        appendDetailStat(stats, "PARADAS", int(route.stopCount))
        appendDetailStat(stats, "XP BASE", int(route.baseXp))
        appendDetailStat(stats, "NÍVEL", int(route.minimumLevel))

        const stops = document.createElement("ol")
        stops.className = "stop-list"
        const routeStops = Array.isArray(route.stops) ? route.stops : []
        routeStops.forEach((stop) => {
            const item = document.createElement("li")
            item.textContent = stop || "Parada"
            stops.appendChild(item)
        })

        const active = !!(menu.data && menu.data.activeRoute)
        const start = document.createElement("button")
        start.type = "button"
        start.className = "btn btn--fill"
        start.id = "start-route"
        start.disabled = !route.available || active || menu.lifecycle !== "ready"
        start.setAttribute("aria-disabled", String(start.disabled))
        start.dataset.pending = menu.lifecycle === "submitting" ? "true" : "false"
        start.textContent = menu.lifecycle === "submitting" ? "PREPARANDO ÔNIBUS" : active ? "SERVIÇO JÁ INICIADO" : route.available ? "INICIAR LINHA" : `NÍVEL ${int(route.minimumLevel)} NECESSÁRIO`
        start.addEventListener("click", startRoute)

        dom.routeDetail.append(eyebrow, title, stats, stops, start)
        if (!route.available) {
            const lock = document.createElement("p")
            lock.className = "route-detail__lock"
            lock.textContent = `BLOQUEADA · NÍVEL ${int(route.minimumLevel)} NECESSÁRIO`
            dom.routeDetail.appendChild(lock)
        }
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

    function moveRoute(delta) {
        const available = sortedRoutes().filter((route) => route.available)
        if (!available.length) return
        const current = available.findIndex((route) => route.id === menu.selectedId)
        const index = Math.max(0, Math.min(available.length - 1, (current < 0 ? 0 : current) + delta))
        selectRoute(available[index].id, true)
    }

    async function startRoute() {
        const route = selectedRoute()
        if (!route || !route.available || (menu.data && menu.data.activeRoute) || menu.lifecycle !== "ready") return
        menu.lifecycle = "submitting"
        setActionMessage("")
        renderHero()
        renderRouteDetail()
        const response = await post("startRoute", { routeId: route.id })
        if (!menu.data || menu.lifecycle === "closing") return
        if (response && response.ok) return
        menu.lifecycle = "ready"
        renderHero()
        renderRouteDetail()
        const code = response && response.code || "internal_error"
        setActionMessage(ERROR_TEXT[code] || ERROR_TEXT.internal_error)
    }

    function renderProgression() {
        const profile = menu.data && menu.data.profile
        const progression = Array.isArray(menu.data && menu.data.progression) ? menu.data.progression : []
        if (!profile) return

        const current = progression.find((tier) => Number(tier.level) === Number(profile.level)) || progression[0] || { xp: 0 }
        const next = progression.find((tier) => Number(tier.level) === Number(profile.level) + 1)
        const startXp = Number(current.xp) || 0
        const span = next ? Math.max(1, Number(next.xp) - startXp) : 1
        const earned = Math.max(0, Number(profile.xp) - startXp)
        const percent = next ? Math.max(0, Math.min(100, Math.round(earned / span * 100))) : 100

        dom.ringLevel.textContent = int(profile.level)
        dom.progressTitle.textContent = String(profile.title || "Motorista").toUpperCase()
        dom.levelRing.style.background = `conic-gradient(var(--bus-accent) 0deg, var(--bus-accent) ${Math.round(percent * 3.6)}deg, var(--bus-track) ${Math.round(percent * 3.6)}deg)`
        dom.levelRing.setAttribute("aria-label", `Nível ${int(profile.level)}, progresso ${percent}%`)
        dom.progressFill.style.width = `${percent}%`
        dom.progressPercent.textContent = `${percent}%`
        dom.progressBar.setAttribute("aria-valuenow", String(percent))
        dom.progressFraction.textContent = next ? `${int(profile.xp)} / ${int(next.xp)} XP` : `${int(profile.xp)} XP · NÍVEL MÁXIMO`

        const rows = progression.map((tier) => {
            const row = document.createElement("div")
            row.className = "level-row"
            const level = Number(tier.level) || 0
            row.dataset.state = level < profile.level ? "complete" : level === profile.level ? "current" : "locked"

            const number = document.createElement("span")
            number.className = "level-row__number"
            number.textContent = String(level).padStart(2, "0")
            const title = document.createElement("span")
            title.className = "level-row__title"
            title.textContent = tier.title || "Motorista"
            const unlocks = document.createElement("span")
            unlocks.className = "level-row__unlocks"
            unlocks.textContent = Array.isArray(tier.unlocks) ? tier.unlocks.join(" · ") : ""
            unlocks.title = unlocks.textContent
            const status = document.createElement("span")
            status.className = "level-row__state"
            status.textContent = level < profile.level ? "CONCLUÍDO" : level === profile.level ? "ATUAL" : `${int(tier.xp)} XP`
            row.append(number, title, unlocks, status)
            return row
        })
        dom.levelList.replaceChildren(...rows)
    }

    function renderRanking() {
        const entries = Array.isArray(menu.data && menu.data.leaderboard) ? menu.data.leaderboard.slice(0, 20) : []
        const rows = entries.map((entry) => {
            const row = document.createElement("li")
            row.className = "ranking-row"
            const values = [
                [`#${int(entry.rank)}`, "ranking-row__position"],
                [entry.name || "Motorista", "ranking-row__name"],
                [int(entry.level), ""],
                [int(entry.xp), ""],
                [int(entry.routes), ""],
                [decimal(entry.averageScore), ""],
            ]
            values.forEach(([value, className]) => {
                const span = document.createElement("span")
                if (className) span.className = className
                span.textContent = value
                row.appendChild(span)
            })
            return row
        })
        dom.rankingList.replaceChildren(...rows)
        show(dom.rankingEmpty, rows.length === 0)
        dom.rankingSelf.textContent = `#${int(menu.data && menu.data.profile && menu.data.profile.rank)}`
    }

    function renderAll() {
        const routes = sortedRoutes()
        const active = menu.data && menu.data.activeRoute
        const currentSelection = routes.find((route) => route.id === menu.selectedId && route.available)
        if (!currentSelection) {
            const preferred = active && routes.find((route) => route.id === active.id)
            menu.selectedId = (preferred || routes.find((route) => route.available) || routes[0] || {}).id || null
        }
        renderProfile()
        renderHero()
        renderRouteList()
        renderRouteDetail()
        renderProgression()
        renderRanking()
    }

    function applySnapshot(data) {
        if (!data || !data.profile || !Array.isArray(data.routes)) {
            show(dom.menuError, true)
            return false
        }
        menu.data = data
        show(dom.menuError, false)
        renderAll()
        return true
    }

    function setTab(tab, focusNav) {
        if (!dom.tabs[tab]) return
        menu.tab = tab
        dom.nav.forEach((button) => {
            const selected = button.dataset.tab === tab
            button.setAttribute("aria-selected", String(selected))
            button.tabIndex = selected ? 0 : -1
            if (selected && focusNav) button.focus()
        })
        Object.entries(dom.tabs).forEach(([id, panel]) => {
            const visible = id === tab
            panel.hidden = !visible
            if (visible) {
                panel.style.animation = "none"
                void panel.offsetWidth
                panel.style.animation = ""
            }
        })
    }

    function moveTab(delta) {
        const order = ["routes", "progression", "ranking"]
        const index = order.indexOf(menu.tab)
        setTab(order[(index + delta + order.length) % order.length], true)
    }

    function openMenu(data) {
        clearTimers()
        menu.lifecycle = "ready"
        menu.tab = "routes"
        menu.selectedId = null
        menu.modalInvoker = null
        show(dom.returnModal, false)
        setActionMessage("")
        dom.root.dataset.mode = "menu"
        dom.menu.hidden = false
        dom.menu.dataset.anim = "enter"
        dom.menu.dataset.status = "ready"
        applySnapshot(data)
        setTab("routes", false)
        later(() => dom.nav[0].focus(), 60)
    }

    function hideMenu() {
        clearTimers()
        menu.lifecycle = "closed"
        menu.data = null
        menu.selectedId = null
        menu.modalInvoker = null
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

    function openReturnModal() {
        if (menu.lifecycle !== "ready" || !(menu.data && menu.data.activeRoute)) return
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

    async function returnVehicle() {
        if (menu.lifecycle !== "ready" || !(menu.data && menu.data.activeRoute)) return
        menu.lifecycle = "submitting"
        dom.returnConfirm.disabled = true
        dom.returnCancel.disabled = true
        dom.returnConfirm.dataset.pending = "true"
        dom.returnConfirm.textContent = "DEVOLVENDO VEÍCULO"
        const response = await post("returnVehicle")
        if (!menu.data || menu.lifecycle === "closing") return

        if (response && response.ok) {
            menu.lifecycle = "ready"
            dom.returnConfirm.disabled = false
            dom.returnCancel.disabled = false
            dom.returnConfirm.dataset.pending = "false"
            dom.returnConfirm.textContent = "CONFIRMAR DEVOLUÇÃO"
            show(dom.returnModal, false)
            menu.modalInvoker = null
            applySnapshot(response.data || { ...menu.data, activeRoute: null })
            setActionMessage("Ônibus devolvido. Serviço cancelado sem pagamento ou XP.", "success")
            dom.nav[0].focus()
            return
        }

        menu.lifecycle = "ready"
        dom.returnConfirm.disabled = false
        dom.returnCancel.disabled = false
        dom.returnConfirm.dataset.pending = "false"
        dom.returnConfirm.textContent = "CONFIRMAR DEVOLUÇÃO"
        const code = response && response.code || "internal_error"
        dom.returnMessage.textContent = ERROR_TEXT[code] || ERROR_TEXT.internal_error
        show(dom.returnMessage, true)
        dom.returnCancel.focus()
    }

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
        else if (data.mode === "boarding") dom.hudTitle.textContent = data.stopName || "PRÓXIMA PARADA"
        else if (data.mode === "docked") dom.hudTitle.textContent = `${data.stopName || "PARADA"} · ATENDIMENTO INICIANDO`
        else dom.hudTitle.textContent = data.stopName || "PRÓXIMA PARADA"

        dom.hudProgress.textContent = data.stopIndex ? `${int(data.stopIndex)} / ${int(data.stopCount)}${data.distance != null ? ` · ${int(data.distance)} m` : ""}` : "SERVIÇO ENCERRADO"
        dom.hudPassengers.textContent = `PASSAGEIROS · ${int(data.passengers)} / ${int(data.capacity)}`
        if (data.service) showServiceHud(data.serviceTimeoutMs)
        else hideServiceHud()
        show(dom.hud, true)
    }

    let summaryTimer = null
    function renderSummary(data) {
        if (!data) return
        if (summaryTimer) clearTimeout(summaryTimer)
        dom.summaryScore.textContent = `${Math.round(Number(data.finalScore) || 0)} PONTOS`
        dom.summaryService.textContent = data.leveledUp ? `NOVO NÍVEL · ${int(data.level)}` : "SERVIÇO FINALIZADO"
        dom.summaryDetails.textContent = `PARADAS · ${int(data.stops)}   PASSAGEIROS · ${int(data.passengers)}   PAGAMENTO · $${int(data.payout)}   EXPERIÊNCIA · +${int(data.xp)} XP`
        show(dom.summary, true)
        summaryTimer = setTimeout(() => show(dom.summary, false), 10000)
    }

    dom.nav.forEach((button) => button.addEventListener("click", () => setTab(button.dataset.tab, true)))
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
        const inNav = event.target && event.target.classList && event.target.classList.contains("nav-item")
        const inRoutes = event.target && event.target.classList && event.target.classList.contains("route-card")
        if (inNav && (event.key === "ArrowLeft" || event.key === "ArrowRight")) {
            event.preventDefault()
            moveTab(event.key === "ArrowRight" ? 1 : -1)
        } else if (inRoutes && (event.key === "ArrowDown" || event.key === "ArrowUp")) {
            event.preventDefault()
            moveRoute(event.key === "ArrowDown" ? 1 : -1)
        } else if (inRoutes && (event.key === "Enter" || event.key === " ")) {
            event.preventDefault()
            selectRoute(event.target.dataset.route, true)
        }
    })

    const handlers = {
        "busMenu:open": openMenu,
        "busMenu:close": (data) => data && data.immediate ? hideMenu() : playExitAndComplete(),
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
