// Mapa de debug das linhas (/onibusmap ou "Mapa das linhas" no editor). Leaflet sobre os
// tiles do /territorymap: projeção e caminho dos tiles chegam do Lua (noir_territories).
(() => {
    "use strict"

    const $ = (id) => document.getElementById(id)
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_busjob"
    const root = $("bus-map")
    const listEl = $("bm-list")
    const legendEl = $("bm-legend")
    const subtitleEl = $("bm-subtitle")

    const PALETTE = ["#39df45", "#6e9fbd", "#d7a84b", "#e0569b", "#9b7cf2", "#3fbfbc", "#f07a3a", "#c9d34a", "#ef2929", "#4a8cf0", "#b0b0b0", "#f2c6a0"]

    const state = { roads: {}, data: null, cfg: null, map: null, layer: null, selected: "all", showZones: true, showLoose: true, fromEditor: false, player: null }

    const fmt = (value, digits = 0) => Number(value || 0).toLocaleString("pt-BR", { maximumFractionDigits: digits })
    const shortName = (route) => String(route.name || "").replace(/^.*·\s*/, "") || route.code

    function el(tag, className, text) {
        const node = document.createElement(tag)
        if (className) node.className = className
        if (text !== undefined && text !== null) node.textContent = String(text)
        return node
    }

    function routeColor(index) {
        return PALETTE[index % PALETTE.length]
    }

    // ───────────── mapa ─────────────

    let toLatLng = () => L.latLng(0, 0)

    function initMap() {
        if (state.map) return
        const cfg = state.cfg
        const minResolution = Math.pow(2, cfg.maxZoom) * cfg.maxResolution
        // CRS próprio (não mexe no L.CRS.Simple global) com a escala e a conta inversa: sem o
        // `zoom`, o fitBounds calcula com a escala padrão e nunca aproxima numa linha.
        const crs = L.extend({}, L.CRS.Simple, {
            scale: (zoom) => Math.pow(2, zoom) / minResolution,
            zoom: (scale) => Math.log(scale * minResolution) / Math.LN2,
        })
        // Mesma conta do /territorymap: onde a pirâmide de tiles acaba (sem 404 no F8).
        const world = Math.pow(2, cfg.maxZoom) * 256 / (Math.pow(2, cfg.maxZoom) / minResolution)
        const bounds = L.latLngBounds([[-world, 0], [0, world]])
        toLatLng = (x, y) => L.latLng(y * cfg.offset + cfg.centerLat, x * cfg.offset + cfg.centerLng)

        state.map = L.map("bm-map", {
            crs,
            center: [cfg.centerLat, cfg.centerLng],
            zoom: 3,
            minZoom: 2,
            maxZoom: cfg.maxZoom,
            zoomControl: false,
            attributionControl: false,
            maxBounds: bounds,
            maxBoundsViscosity: 1.0,
            layers: [L.tileLayer(cfg.tiles, { minZoom: 0, maxZoom: cfg.maxZoom, maxNativeZoom: cfg.maxNativeZoom, noWrap: true, tms: true, bounds })],
        })
        state.layer = L.featureGroup().addTo(state.map)
    }

    function zoneRing(zone) {
        const angle = (zone.rotation * Math.PI) / 180
        const fx = -Math.sin(angle), fy = Math.cos(angle)
        const rx = Math.cos(angle), ry = Math.sin(angle)
        const hl = zone.length / 2, hw = zone.width / 2
        return [[1, 1], [1, -1], [-1, -1], [-1, 1]].map(([a, b]) => toLatLng(zone.x + fx * hl * a + rx * hw * b, zone.y + fy * hl * a + ry * hw * b))
    }

    function stopTip(stop, index) {
        const lines = [`${index ? `${index}. ` : ""}#${stop.id} · ${stop.name}`]
        if (!stop.zone) lines.push("Sem área de passageiros")
        if (!stop.enabled) lines.push("Inativa")
        if (stop.usedBy && stop.usedBy.length) lines.push(`Linhas: ${stop.usedBy.join(", ")}`)
        return lines.join("<br>")
    }

    function addZone(stop, color) {
        if (!stop.zone || !state.showZones) return
        L.polygon(zoneRing(stop.zone), { color, weight: 1, opacity: 0.9, fillColor: color, fillOpacity: 0.35 }).addTo(state.layer)
    }

    function addLooseStop(stop) {
        const icon = L.divIcon({ className: "", html: `<div class="bm-stop" data-kind="loose" data-zone="${!!stop.zone}"></div>`, iconSize: [12, 12], iconAnchor: [6, 6] })
        L.marker(toLatLng(stop.dock.x, stop.dock.y), { icon }).bindTooltip(stopTip(stop), { className: "bm-tip", direction: "top" }).addTo(state.layer)
        addZone(stop, stop.zone ? "#bdbdbd" : "#d7a84b")
    }

    function addDepot() {
        const depot = state.data.depot
        const icon = L.divIcon({ className: "", html: '<div class="bm-stop" style="--bm-color:#f2f2f2">C</div>', iconSize: [22, 22], iconAnchor: [11, 11] })
        L.marker(toLatLng(depot.ped.x, depot.ped.y), { icon, zIndexOffset: 900 }).bindTooltip("Central (atendente)", { className: "bm-tip", direction: "top" }).addTo(state.layer)
        L.circleMarker(toLatLng(depot.spawn.x, depot.spawn.y), { radius: 5, color: "#f2f2f2", weight: 2, fillOpacity: 0 }).bindTooltip("Saída do ônibus", { className: "bm-tip", direction: "top" }).addTo(state.layer)
    }

    function addPlayer() {
        if (!state.player) return
        L.circleMarker(toLatLng(state.player.x, state.player.y), { radius: 6, color: "#111113", weight: 2, fillColor: "#ffffff", fillOpacity: 1 }).bindTooltip("Você", { className: "bm-tip", direction: "top" }).addTo(state.layer)
    }

    // Trajeto em linha reta: saída do ônibus → paradas na ordem → Central. Não é o caminho das
    // ruas; serve para ver a ordem e o sentido.
    function addRoute(route, color, emphasis) {
        const stops = route.stops.map((id) => state.data.stops.find((stop) => stop.id === id)).filter(Boolean)
        const depot = state.data.depot
        const points = [depot.spawn, ...stops.map((stop) => stop.dock), depot.ped].map((p) => toLatLng(p.x, p.y))
        const road = state.roads[route.id]
        if (road && road.length > 1) {
            // Traçado pelo GPS do jogo (/onibusrota): a reta fica só como referência apagada.
            L.polyline(points, { color, weight: 1, opacity: 0.35, dashArray: "4 6" }).addTo(state.layer)
            L.polyline(road.map((p) => toLatLng(p.x, p.y)), { color, weight: emphasis ? 4 : 2, opacity: emphasis ? 0.95 : 0.6 }).addTo(state.layer)
        } else {
            L.polyline(points, { color, weight: emphasis ? 4 : 2, opacity: emphasis ? 0.95 : 0.55, dashArray: route.enabled && route.usable ? null : "6 6" }).addTo(state.layer)
        }
        if (!emphasis) return
        state.focus = L.latLngBounds(points)
        const seen = new Map()
        stops.forEach((stop, index) => {
            // Parada repetida (terminal no começo e no fim) vira um marcador com os dois números.
            const numbers = seen.get(stop.id) || []
            numbers.push(index + 1)
            seen.set(stop.id, numbers)
        })
        seen.forEach((numbers, id) => {
            const stop = stops.find((item) => item.id === id)
            const label = numbers.join("/")
            const width = Math.max(22, 10 + label.length * 7)
            const icon = L.divIcon({ className: "", html: `<div class="bm-stop" style="--bm-color:${color};width:${width}px!important;border-radius:11px">${label}</div>`, iconSize: [width, 22], iconAnchor: [width / 2, 11] })
            L.marker(toLatLng(stop.dock.x, stop.dock.y), { icon, zIndexOffset: 800 }).bindTooltip(stopTip(stop, numbers[0]), { className: "bm-tip", direction: "top" }).addTo(state.layer)
            addZone(stop, color)
        })
    }

    function draw() {
        initMap()
        state.layer.clearLayers()
        state.focus = null
        const routes = state.data.routes
        const legend = []

        if (state.selected === "all") {
            routes.forEach((route, index) => addRoute(route, routeColor(index), false))
            state.data.stops.forEach(addLooseStop)
            legend.push(["#bdbdbd", "Parada com área"], ["#d7a84b", "Parada sem área"])
            subtitleEl.textContent = `${fmt(state.data.stops.length)} paradas · ${fmt(routes.length)} linhas`
        } else {
            const index = routes.findIndex((route) => route.id === state.selected)
            const route = routes[index]
            if (state.showLoose) state.data.stops.filter((stop) => !route.stops.includes(stop.id)).forEach(addLooseStop)
            addRoute(route, routeColor(index), true)
            legend.push([routeColor(index), `${route.code} · ${route.stops.length} paradas`])
            subtitleEl.textContent = `${route.code} · ${fmt(route.distance / 1000, 1)} km em linha reta · ~${fmt(route.expected / 60)} min`
        }
        addDepot()
        addPlayer()
        legend.push(["#f2f2f2", "Central"])

        legendEl.replaceChildren(...legend.map(([color, text]) => {
            const span = el("span")
            const dot = el("i")
            dot.style.background = color
            span.append(dot, document.createTextNode(text))
            return span
        }))

        // Com uma linha escolhida, enquadra só o trajeto dela (as outras paradas ficam de fundo).
        const bounds = state.focus || state.layer.getBounds()
        if (bounds.isValid()) state.map.fitBounds(bounds, { padding: [40, 40] })
    }

    // ───────────── menu ─────────────

    function menuItem({ key, label, meta, value, tone, color, pressed, onClick }) {
        const node = el("button", "bm__item")
        node.type = "button"
        node.dataset.key = key
        node.setAttribute("aria-pressed", String(!!pressed))
        const swatch = el("span", "bm__swatch")
        if (color) swatch.style.setProperty("--bm-color", color)
        else swatch.style.visibility = "hidden"
        const body = el("span")
        body.append(el("span", "bm__label", label))
        if (meta) body.appendChild(el("span", "bm__meta", meta))
        node.append(swatch, body)
        const valueNode = el("span", "bm__value", value || "")
        if (tone) valueNode.dataset.tone = tone
        node.appendChild(valueNode)
        node.addEventListener("click", onClick)
        return node
    }

    function renderList() {
        const nodes = [el("div", "bm__section", "Ver")]
        const missing = state.data.stops.filter((stop) => !stop.zone).length
        nodes.push(menuItem({
            key: "all", label: "Todas as linhas", meta: `${fmt(state.data.stops.length)} paradas${missing ? ` · ${missing} sem área` : ""}`,
            pressed: state.selected === "all", onClick: () => select("all"),
        }))
        nodes.push(menuItem({ key: "zones", label: "Mostrar áreas", value: state.showZones ? "Sim" : "Não", onClick: () => { state.showZones = !state.showZones; renderList(); draw() } }))
        nodes.push(menuItem({ key: "loose", label: "Paradas de outras linhas", meta: "Com uma linha escolhida", value: state.showLoose ? "Sim" : "Não", onClick: () => { state.showLoose = !state.showLoose; renderList(); draw() } }))
        nodes.push(el("div", "bm__section", "Linhas"))
        state.data.routes.forEach((route, index) => {
            nodes.push(menuItem({
                key: route.id,
                label: `${route.code} · ${shortName(route)}`,
                meta: `${route.stops.length} paradas · ${fmt(route.distance / 1000, 1)} km · nível ${route.minLevel}`,
                value: !route.enabled ? "Inativa" : !route.usable ? "Incompleta" : "",
                tone: !route.enabled || !route.usable ? "warning" : undefined,
                color: routeColor(index),
                pressed: state.selected === route.id,
                onClick: () => select(route.id),
            }))
        })
        listEl.replaceChildren(...nodes)
    }

    function select(key) {
        state.selected = key
        renderList()
        draw()
    }

    // ───────────── ciclo ─────────────

    function open(message) {
        state.data = message.data
        state.player = message.player || null
        state.fromEditor = !!message.fromEditor
        // Traçados salvos no banco (em dia) + os que acabaram de ser traçados nesta passada.
        state.roads = Object.assign({}, message.data.roads || {}, message.roads || {})
        if (message.select) state.selected = message.select
        // A projeção só troca antes do mapa existir: depois o Leaflet já segurou o CRS.
        if (!state.map) state.cfg = message.map
        if (state.selected !== "all" && !state.data.routes.some((route) => route.id === state.selected)) state.selected = "all"
        root.hidden = false
        document.dispatchEvent(new CustomEvent("busmap:visible", { detail: true }))
        renderList()
        // Leaflet mede o contêiner na criação: com a tela escondida ele nasce com tamanho zero.
        requestAnimationFrame(() => {
            draw()
            state.map.invalidateSize()
        })
    }

    function hide() {
        root.hidden = true
        document.dispatchEvent(new CustomEvent("busmap:visible", { detail: false }))
    }

    function requestClose() {
        hide()
        fetch(`https://${resource}/map:close`, { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" }).catch(() => {})
    }

    $("bm-close").addEventListener("click", requestClose)
    document.addEventListener("keydown", (event) => {
        if (root.hidden) return
        if (event.key === "Escape" || event.key === "Backspace") {
            event.preventDefault()
            event.stopImmediatePropagation()
            requestClose()
        }
    }, true)

    // Preview no navegador.
    window.busMapDebug = state

    window.addEventListener("message", (event) => {
        const message = event.data || {}
        if (message.action !== "busMap" || !message.data) return
        if (message.data.visible) open(message.data)
        else hide()
    })
})()
