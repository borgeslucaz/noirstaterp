// Mapa de debug dos pontos do táxi ("Mapa dos pontos" no /editortaxi). Leaflet sobre os tiles
// do /territorymap: projeção e caminho dos tiles chegam do Lua (noir_territories). Mesmo CRS do
// mapa do noir_busjob.
(() => {
    "use strict"

    const $ = (id) => document.getElementById(id)
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_taxijob"
    const root = $("taxi-map")
    const listEl = $("bm-list")
    const legendEl = $("bm-legend")
    const subtitleEl = $("bm-subtitle")

    // Mesmas cores do desenho no mundo (client/editor.lua).
    const REGION_COLOR = { "downtown": "#f2c42b", "sandy shores": "#d78c3c", "paleto bay": "#6e9fbd" }

    const state = { catalog: null, cfg: null, map: null, layer: null, hidden: {}, showDisabled: true, player: null }

    const fmt = (value, digits = 0) => Number(value || 0).toLocaleString("pt-BR", { maximumFractionDigits: digits })

    function el(tag, className, text) {
        const node = document.createElement(tag)
        if (className) node.className = className
        if (text !== undefined && text !== null) node.textContent = String(text)
        return node
    }

    // ───────────── mapa ─────────────

    let toLatLng = () => L.latLng(0, 0)

    function initMap() {
        if (state.map) return
        const cfg = state.cfg
        const minResolution = Math.pow(2, cfg.maxZoom) * cfg.maxResolution
        // CRS próprio com a escala e a conta inversa: sem o `zoom`, o fitBounds nunca aproxima.
        const crs = L.extend({}, L.CRS.Simple, {
            scale: (zoom) => Math.pow(2, zoom) / minResolution,
            zoom: (scale) => Math.log(scale * minResolution) / Math.LN2,
        })
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

    function regionLabel(key) {
        const region = (state.catalog.regions || []).find((r) => r.key === key)
        return region ? region.label : key
    }

    function draw() {
        initMap()
        state.layer.clearLayers()
        const catalog = state.catalog
        const visible = catalog.points.filter((p) => !state.hidden[p.region] && (state.showDisabled || p.enabled))
        visible.forEach((p) => {
            const color = p.enabled ? REGION_COLOR[p.region] || "#bdbdbd" : "#6b6b6b"
            L.circleMarker(toLatLng(p.x, p.y), { radius: 6, color: "#111113", weight: 1, fillColor: color, fillOpacity: 0.95 })
                .bindTooltip(`#${p.id} · ${regionLabel(p.region)}${p.enabled ? "" : "<br>Inativo"}`, { className: "bm-tip", direction: "top" })
                .addTo(state.layer)
        })
        const depot = catalog.depot
        const icon = L.divIcon({ className: "", html: '<div class="bm-stop" style="--bm-color:#f2f2f2">C</div>', iconSize: [22, 22], iconAnchor: [11, 11] })
        L.marker(toLatLng(depot.ped.x, depot.ped.y), { icon, zIndexOffset: 900 }).bindTooltip("Central (atendente)", { className: "bm-tip", direction: "top" }).addTo(state.layer)
        if (state.player) {
            L.circleMarker(toLatLng(state.player.x, state.player.y), { radius: 6, color: "#111113", weight: 2, fillColor: "#ffffff", fillOpacity: 1 }).bindTooltip("Você", { className: "bm-tip", direction: "top" }).addTo(state.layer)
        }
        subtitleEl.textContent = `${fmt(visible.length)} de ${fmt(catalog.points.length)} pontos`

        const legend = (catalog.regions || []).map((r) => [REGION_COLOR[r.key] || "#bdbdbd", r.label])
        legend.push(["#6b6b6b", "Inativo"], ["#f2f2f2", "Central"])
        legendEl.replaceChildren(...legend.map(([color, text]) => {
            const span = el("span")
            const dot = el("i")
            dot.style.background = color
            span.append(dot, document.createTextNode(text))
            return span
        }))

        const bounds = state.layer.getBounds()
        if (bounds.isValid()) state.map.fitBounds(bounds, { padding: [40, 40] })
    }

    // ───────────── menu ─────────────

    function menuItem({ key, label, meta, value, color, pressed, onClick }) {
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
        node.append(swatch, body, el("span", "bm__value", value || ""))
        node.addEventListener("click", onClick)
        return node
    }

    function renderList() {
        const catalog = state.catalog
        const nodes = [el("div", "bm__section", "Regiões")]
        ;(catalog.regions || []).forEach((r) => {
            const list = catalog.points.filter((p) => p.region === r.key)
            nodes.push(menuItem({
                key: r.key, label: r.label, color: REGION_COLOR[r.key],
                meta: `${fmt(list.length)} pontos · ${fmt(list.filter((p) => !p.enabled).length)} inativos`,
                value: state.hidden[r.key] ? "Oculta" : "", pressed: !state.hidden[r.key],
                onClick: () => { state.hidden[r.key] = !state.hidden[r.key]; renderList(); draw() },
            }))
        })
        nodes.push(el("div", "bm__section", "Ver"))
        nodes.push(menuItem({ key: "disabled", label: "Pontos inativos", value: state.showDisabled ? "Sim" : "Não", onClick: () => { state.showDisabled = !state.showDisabled; renderList(); draw() } }))
        listEl.replaceChildren(...nodes)
    }

    // ───────────── ciclo ─────────────

    function open(message) {
        state.catalog = message.catalog
        state.player = message.player || null
        if (!state.map) state.cfg = message.map
        root.hidden = false
        document.dispatchEvent(new CustomEvent("taximap:visible", { detail: true }))
        renderList()
        // Leaflet mede o contêiner na criação: com a tela escondida ele nasce com tamanho zero.
        requestAnimationFrame(() => {
            draw()
            state.map.invalidateSize()
        })
    }

    function hide() {
        root.hidden = true
        document.dispatchEvent(new CustomEvent("taximap:visible", { detail: false }))
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

    window.addEventListener("message", (event) => {
        const message = event.data || {}
        if (message.action !== "taxiMap" || !message.data) return
        if (message.data.visible) open(message.data)
        else hide()
    })
})()
