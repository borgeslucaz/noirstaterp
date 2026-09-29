// Editor de ônibus (/editoronibus): Menu Lateral da v4, variação editor (§ML.7).
// A tela monta o rascunho; o client executa os modos no mundo e o servidor valida tudo.
(() => {
    "use strict"

    const $ = (id) => document.getElementById(id)
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_busjob"
    const root = $("bus-editor")
    const menusEl = $("ed-menus")
    const keysEl = $("ed-keys")
    const modalEl = $("ed-modal")

    const ERROR_TEXT = {
        invalid_payload: "Dados inválidos.",
        invalid_name: "Nome vazio ou longo demais (até 48 caracteres).",
        invalid_dock: "Marque onde o ônibus encosta.",
        invalid_zone: "Área inválida: cada lado entre 0,5 e 40 m, altura até 10 m.",
        invalid_code: "Código com letras e números, até 6 caracteres.",
        invalid_level: "Nível entre 1 e 99.",
        invalid_reward: "Pagamento e XP entre 0 e 100.000.",
        invalid_stops: "A linha precisa de 2 a 40 paradas.",
        unknown_stop: "A linha usa uma parada que não existe.",
        repeated_stop: "A mesma parada não pode vir duas vezes seguidas.",
        invalid_vehicles: "Escolha de 1 a 12 veículos.",
        unknown_vehicle: "Veículo fora do catálogo.",
        invalid_access: "Grupo inválido.",
        route_exists: "Já existe uma linha com essa chave.",
        code_in_use: "Outra linha já usa esse código.",
        unknown_route: "A linha não existe mais.",
        stop_in_use: "A parada está em uso",
        vehicle_in_use: "O veículo está em uso",
        vehicle_exists: "Esse modelo já está no catálogo.",
        invalid_model: "Modelo inválido ou inexistente neste build.",
        invalid_capacity: "Capacidade entre 1 e 60.",
        invalid_doors: "Portas: números de 0 a 7 separados por vírgula.",
        invalid_levels: "Níveis inválidos (título até 32 caracteres).",
        first_level_xp: "O nível 1 começa em 0 XP.",
        levels_order: "O XP precisa crescer a cada nível.",
        invalid_depot: "Central inválida: posição, vaga, raio (5–100 m) e modelo do atendente.",
        invalid_stop_settings: "Ajustes de parada fora da faixa.",
        invalid_demand: "Demanda mínima maior que a máxima.",
        invalid_passenger_settings: "Ajustes de passageiro fora da faixa.",
        invalid_payout: "Ajustes de pagamento fora da faixa.",
        invalid_timing: "Ajustes de tempo fora da faixa.",
        invalid_peak: "Janelas de pico inválidas (ex.: 7-9, 17-19).",
        storage_failed: "O banco recusou a gravação. Nada mudou.",
        storage_unavailable: "O banco ainda não está pronto.",
        not_allowed: "Sem permissão para o editor.",
        busy: "Devagar: aguarde um instante.",
        too_far: "Só dá para ir até perto de uma parada ou da Central.",
        no_hit: "A mira não acertou o chão. Chegue mais perto.",
        transport_error: "O jogo não respondeu.",
        internal_error: "Não foi possível concluir.",
    }

    const state = {
        visible: false,
        hidden: false,
        catalog: null,
        columns: [],
        modal: null,
        pending: null,
        lastDraft: "",
        show: { world: true, always: false },
        mapVisible: false,
    }

    // ───────────── utilitários ─────────────

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

    const request = (method, ...args) => post("editor:request", { method, args })
    const clone = (value) => JSON.parse(JSON.stringify(value))
    const num = (value) => (value === "" || value === null || value === undefined ? NaN : Number(String(value).replace(",", ".")))
    const fmt = (value, digits = 0) => Number(value || 0).toLocaleString("pt-BR", { maximumFractionDigits: digits, minimumFractionDigits: 0 })
    const coords = (p) => (p ? `${fmt(p.x, 1)}, ${fmt(p.y, 1)}, ${fmt(p.z, 1)}${p.w !== undefined ? ` · ${fmt(p.w)}°` : ""}` : "—")

    function errorText(response) {
        const code = (response && response.code) || "internal_error"
        let text = ERROR_TEXT[code] || `Erro: ${code}`
        if (response && Array.isArray(response.usedBy) && response.usedBy.length) text += `: ${response.usedBy.join(", ")}.`
        return text
    }

    function el(tag, className, text) {
        const node = document.createElement(tag)
        if (className) node.className = className
        if (text !== undefined && text !== null) node.textContent = String(text)
        return node
    }

    // Área com os números convertidos (os campos guardam texto).
    function numericZone(zone) {
        if (!zone) return null
        return { x: num(zone.x), y: num(zone.y), z: num(zone.z), length: num(zone.length), width: num(zone.width), height: num(zone.height), rotation: num(zone.rotation) }
    }

    function stopById(id) {
        return (state.catalog.stops || []).find((stop) => stop.id === id)
    }

    function vehicleByModel(model) {
        return (state.catalog.vehicles || []).find((vehicle) => vehicle.model === model)
    }

    // Mesma conta do shared/rules.lua (routeDistance/expectedSeconds/reward), só para a
    // estimativa na tela.
    function routeEstimate(draft) {
        const settings = state.catalog.settings
        const depot = settings.depot
        let previous = depot.spawn
        let distance = 0
        for (const id of draft.stops) {
            const stop = stopById(id)
            if (!stop) continue
            distance += Math.hypot(stop.dock.x - previous.x, stop.dock.y - previous.y)
            previous = stop.dock
        }
        distance += Math.hypot(depot.ped.x - previous.x, depot.ped.y - previous.y)
        const seconds = (distance / 1000) * settings.timing.secondsPerKm + draft.stops.length * settings.timing.secondsPerStop
        const vehicle = vehicleByModel(draft.vehicles[0])
        const capacity = vehicle ? vehicle.capacity : 10
        const passengers = Math.min(2.5 * Math.max(0, draft.stops.length - 1), capacity * 2)
        const payout = settings.payout
        const basePay = num(draft.basePay) || 0
        const baseXp = num(draft.baseXp) || 0
        const pay = basePay + Math.min(basePay * payout.passengerCap, passengers * payout.perPassenger) + basePay * 0.05
        const xp = baseXp + Math.min(baseXp * payout.xpCap, passengers * payout.xpPerPassenger)
        // + 1 min entre uma volta e outra (falar com o atendente, sair da garagem).
        const minutes = seconds / 60 + 1
        return {
            km: distance / 1000,
            minutes,
            perHour: minutes > 0 ? (pay / minutes) * 60 : 0,
            xpPerHour: minutes > 0 ? (xp / minutes) * 60 : 0,
        }
    }

    // ───────────── colunas ─────────────

    function activeColumn() {
        return state.columns[state.columns.length - 1]
    }

    function column(desc) {
        return Object.assign({ index: 0, notice: null, dirty: false }, desc)
    }

    function hasDirty(fromDepth) {
        return state.columns.slice(fromDepth).some((col) => col.dirty)
    }

    function markDirty(col) {
        col.dirty = true
    }

    // Fecha as colunas a partir de `depth`. Rascunho alterado pede confirmação uma vez.
    function truncate(depth, then) {
        if (hasDirty(depth)) {
            confirmDialog({
                title: "Descartar alterações",
                body: "As alterações que ainda não foram salvas serão perdidas.",
                confirm: "Descartar",
                danger: true,
                onConfirm: () => {
                    state.columns = state.columns.slice(0, depth)
                    then && then()
                    render()
                },
            })
            return
        }
        state.columns = state.columns.slice(0, depth)
        then && then()
        render()
    }

    function openColumn(depth, desc) {
        truncate(depth, () => state.columns.push(column(desc)))
    }

    function back() {
        if (state.columns.length <= 1) return requestClose()
        truncate(state.columns.length - 1)
    }

    function requestClose() {
        const close = () => {
            state.columns = []
            post("editor:close")
            hide()
        }
        if (hasDirty(0)) {
            confirmDialog({ title: "Descartar alterações", body: "O editor vai fechar sem salvar o que mudou.", confirm: "Descartar", danger: true, onConfirm: close })
            return
        }
        close()
    }

    function selectable(item) {
        return item && item.kind !== "info" && item.kind !== "section" && !item.disabled
    }

    function activate(depth, index) {
        const col = state.columns[depth]
        const items = col.items || []
        const item = items[index]
        if (!item || !selectable(item)) return
        // Clique numa coluna de trás: fecha as da esquerda e escolhe o item (§ML.5).
        if (depth < state.columns.length - 1) {
            if (item.kind === "submenu" && col.openKey === item.key) {
                truncate(depth + 1, () => { col.openKey = null })
                return
            }
            col.index = index
            if (item.kind === "submenu") {
                truncate(depth + 1, () => {
                    col.openKey = item.key
                    state.columns.push(column(item.open()))
                })
            } else {
                truncate(depth + 1, () => { col.openKey = null; runItem(item) })
            }
            return
        }
        col.index = index
        if (item.kind === "submenu") {
            col.openKey = item.key
            state.columns.push(column(item.open()))
            render()
            return
        }
        runItem(item)
    }

    function runItem(item) {
        if (item.kind === "input") {
            const field = menusEl.querySelector(`[data-depth="${state.columns.length - 1}"] [data-key="${item.key}"] input`)
            if (field) field.focus()
            return
        }
        if (item.onSelect) item.onSelect()
        render()
    }

    function moveIndex(delta) {
        const col = activeColumn()
        const items = col.items || []
        if (!items.length) return
        let index = col.index
        for (let step = 0; step < items.length; step++) {
            index = (index + delta + items.length) % items.length
            if (selectable(items[index])) break
        }
        col.index = index
        render()
    }

    // ───────────── desenho ─────────────

    function renderItem(item, depth, index, col) {
        const active = col.index === index
        const node = el(item.kind === "input" ? "label" : "div", `ed-item${item.kind === "input" ? " ed-item--input" : ""}`)
        node.dataset.key = item.key
        node.dataset.kind = item.kind || "action"
        node.dataset.active = String(active && selectable(item))
        if (item.tone) node.dataset.tone = item.tone
        if (item.disabled) node.setAttribute("aria-disabled", "true")

        const body = el("span", "ed-item__body")
        body.appendChild(el("span", "ed-item__label", item.label))
        if (item.description) body.appendChild(el("span", "ed-item__description", item.description))

        if (item.kind === "input") {
            const input = el(item.input.multiline ? "textarea" : "input", "ed-field")
            if (!item.input.multiline) input.type = "text"
            input.inputMode = item.input.type === "number" ? "decimal" : "text"
            input.value = item.input.value === undefined || item.input.value === null ? "" : String(item.input.value)
            if (item.input.placeholder) input.placeholder = item.input.placeholder
            if (item.input.maxLength) input.maxLength = item.input.maxLength
            input.addEventListener("input", () => item.input.onChange(input.value))
            input.addEventListener("focus", () => {
                if (col.index !== index) { col.index = index; paintActive() }
            })
            body.appendChild(input)
        }
        node.appendChild(body)

        if (item.value !== undefined && item.value !== null && item.value !== "") {
            const value = el("span", "ed-item__value", item.value)
            if (item.valueTone) value.dataset.tone = item.valueTone
            node.appendChild(value)
        }

        if (item.kind !== "input") node.addEventListener("click", () => activate(depth, index))
        node.addEventListener("mouseenter", () => {
            if (depth === state.columns.length - 1 && selectable(item) && col.index !== index) {
                col.index = index
                paintActive()
            }
        })
        return node
    }

    // Só troca o destaque, sem recriar a coluna (o campo em foco continua em foco).
    function paintActive() {
        state.columns.forEach((col, depth) => {
            const nodes = menusEl.querySelectorAll(`[data-depth="${depth}"] .ed-item`)
            nodes.forEach((node, index) => {
                const item = (col.items || [])[index]
                node.dataset.active = String(col.index === index && selectable(item))
            })
        })
    }

    function renderColumn(col, depth) {
        col.items = col.build(col)
        if (col.index >= col.items.length || !selectable(col.items[col.index])) {
            col.index = Math.max(0, col.items.findIndex(selectable))
        }
        const isActive = depth === state.columns.length - 1
        const menu = el("section", "ed-menu")
        menu.dataset.depth = String(depth)
        menu.dataset.active = String(isActive)

        const header = el("header", "ed-menu__header")
        header.append(el("h2", "ed-menu__title", col.title), el("span", "ed-menu__subtitle", typeof col.subtitle === "function" ? col.subtitle(col) : col.subtitle || ""))
        const close = el("button", "ed-close")
        close.type = "button"
        close.setAttribute("aria-label", depth === 0 ? "Fechar editor" : "Fechar coluna")
        close.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>'
        close.addEventListener("click", () => (depth === 0 ? requestClose() : truncate(depth)))
        header.appendChild(close)
        menu.appendChild(header)

        if (col.summary) menu.appendChild(col.summary(col))
        if (col.notice) {
            const notice = el("div", "ed-notice", col.notice.text)
            notice.dataset.tone = col.notice.tone || "warning"
            menu.appendChild(notice)
        }

        const list = el("div", "ed-items")
        if (!col.items.length) list.appendChild(el("p", "ed-empty", col.empty || "Nada por aqui."))
        col.items.forEach((item, index) => {
            const node = renderItem(item, depth, index, col)
            // Item que abriu a coluna seguinte vira aba (§ML.5).
            if (!isActive && col.openKey === item.key) node.dataset.active = "true"
            list.appendChild(node)
        })
        menu.appendChild(list)
        return menu
    }

    function renderKeys() {
        keysEl.replaceChildren()
        if (!state.visible || state.hidden || state.modal || state.mapVisible) return
        const pairs = [["↵", "Escolher"], ["Esc", state.columns.length > 1 ? "Voltar" : "Fechar"]]
        pairs.forEach(([key, label], index) => {
            if (index) keysEl.appendChild(el("span", "ed-key-sep", "/"))
            const pill = el("span", "ed-key")
            pill.append(el("kbd", null, key), document.createTextNode(label))
            keysEl.appendChild(pill)
        })
    }

    function render() {
        if (!state.visible) return
        const focused = document.activeElement
        const focusKey = focused && focused.closest && focused.closest(".ed-item") ? focused.closest(".ed-item").dataset.key : null
        const focusDepth = focused && focused.closest && focused.closest(".ed-menu") ? focused.closest(".ed-menu").dataset.depth : null

        menusEl.replaceChildren(...state.columns.map(renderColumn))

        // O campo que estava sendo digitado continua em foco depois de redesenhar.
        if (focusKey && focusDepth !== null) {
            const field = menusEl.querySelector(`[data-depth="${focusDepth}"] [data-key="${focusKey}"] .ed-field`)
            if (field) {
                field.focus()
                const end = field.value.length
                try { field.setSelectionRange(end, end) } catch (_) { /* number */ }
            }
        }
        const active = activeColumn()
        if (active) {
            const node = menusEl.querySelector(`[data-depth="${state.columns.length - 1}"] .ed-item[data-active="true"]`)
            if (node) node.scrollIntoView({ block: "nearest" })
        }
        renderKeys()
        syncDraft()
    }

    // Parada aberta no editor: o client desenha o rascunho no mundo.
    function syncDraft() {
        const stopCol = [...state.columns].reverse().find((col) => col.stopDraft)
        let draft = null
        if (stopCol) {
            const zone = numericZone(stopCol.stopDraft.zone)
            const zoneOk = zone && Object.values(zone).every(Number.isFinite)
            draft = { id: stopCol.stopDraft.id, dock: stopCol.stopDraft.dock, zone: zoneOk ? zone : null }
        }
        const serialized = JSON.stringify(draft)
        if (serialized === state.lastDraft) return
        state.lastDraft = serialized
        post("editor:draft", draft || {})
    }

    // ───────────── janela central ─────────────

    function closeModal() {
        state.modal = null
        modalEl.replaceChildren()
        modalEl.hidden = true
        renderKeys()
    }

    function openModal(build) {
        state.modal = true
        modalEl.hidden = false
        modalEl.replaceChildren(build())
        const first = modalEl.querySelector("[data-autofocus]") || modalEl.querySelector("textarea, input, button")
        if (first) first.focus()
        renderKeys()
    }

    function modalShell(title, bodyNodes, footerNodes) {
        const box = el("div", "ed-modal")
        box.setAttribute("role", "dialog")
        box.setAttribute("aria-modal", "true")
        const header = el("header", "ed-modal__header")
        const close = el("button", "ed-close")
        close.type = "button"
        close.setAttribute("aria-label", "Fechar")
        close.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg>'
        close.addEventListener("click", closeModal)
        header.append(el("h3", "ed-modal__title", title), close)
        const body = el("div", "ed-modal__body")
        bodyNodes.forEach((node) => body.appendChild(node))
        box.append(header, body)
        if (footerNodes) {
            const footer = el("footer", "ed-modal__footer")
            footerNodes.forEach((node) => footer.appendChild(node))
            box.appendChild(footer)
        }
        // A tecla não vaza para o menu de trás (§6).
        box.addEventListener("keydown", (event) => {
            event.stopPropagation()
            if (event.key === "Escape") { event.preventDefault(); closeModal() }
        })
        return box
    }

    function button(label, variant, onClick) {
        const node = el("button", `ed-button${variant ? ` ed-button--${variant}` : ""}`, label)
        node.type = "button"
        node.addEventListener("click", onClick)
        return node
    }

    function confirmDialog({ title, object, body, confirm, danger, onConfirm }) {
        openModal(() => {
            const nodes = []
            if (object) nodes.push(el("p", "ed-modal__object", object))
            if (body) nodes.push(el("p", null, body))
            const cancel = button("Cancelar", null, closeModal)
            cancel.dataset.autofocus = "true"
            return modalShell(title, nodes, [cancel, button(confirm, danger ? "danger" : "confirm", () => { closeModal(); onConfirm() })])
        })
    }

    // Item com mais de uma ação (subir, descer, remover): janela com as ações lado a lado.
    function actionsDialog(title, object, actions) {
        openModal(() => {
            const list = el("div", "ed-modal__actions")
            actions.forEach((action, index) => {
                const node = button(action.label, action.danger ? "danger" : null, () => { closeModal(); action.run(); render() })
                if (index === 0) node.dataset.autofocus = "true"
                list.appendChild(node)
            })
            return modalShell(title, [el("p", "ed-modal__object", object), list], [button("Cancelar", null, closeModal), el("span")])
        })
    }

    function promptDialog({ title, fields, confirm, onSubmit, hint }) {
        openModal(() => {
            const nodes = []
            const inputs = fields.map((field, index) => {
                const wrap = el("label")
                wrap.appendChild(el("span", "ed-modal__label", field.label))
                const input = el(field.multiline ? "textarea" : "input", "ed-field")
                input.value = field.value || ""
                if (field.placeholder) input.placeholder = field.placeholder
                if (index === 0) input.dataset.autofocus = "true"
                wrap.appendChild(input)
                nodes.push(wrap)
                return input
            })
            if (hint) nodes.push(el("p", null, hint))
            const error = el("p", "ed-modal__error")
            error.hidden = true
            nodes.push(error)
            const submit = () => {
                const message = onSubmit(inputs.map((input) => input.value))
                if (message) {
                    error.textContent = message
                    error.hidden = false
                    return
                }
                closeModal()
                render()
            }
            const shell = modalShell(title, nodes, [button("Cancelar", null, closeModal), button(confirm, "confirm", submit)])
            shell.addEventListener("keydown", (event) => {
                if (event.key === "Enter" && event.target.tagName !== "TEXTAREA") { event.preventDefault(); submit() }
            })
            return shell
        })
    }

    // ───────────── modos no mundo ─────────────

    function startMode(mode, apply, extra = {}) {
        state.pending = { mode, apply }
        post("editor:mode", Object.assign({ mode }, extra)).then((response) => {
            if (!response || !response.ok) {
                state.pending = null
                const col = activeColumn()
                if (col) col.notice = { tone: "danger", text: errorText(response) }
                render()
            }
        })
    }

    // ───────────── salvar ─────────────

    async function save(col, method, args, onSaved) {
        col.notice = { tone: "info", text: "Salvando…" }
        render()
        const response = await request(method, ...args)
        if (!response || !response.ok) {
            col.notice = { tone: "danger", text: errorText(response) }
            render()
            return false
        }
        state.catalog = response.catalog
        col.dirty = false
        col.notice = { tone: "success", text: "Salvo." }
        if (onSaved) onSaved(response)
        render()
        return true
    }

    // ───────────── itens ─────────────

    const item = (key, label, extra = {}) => Object.assign({ key, label, kind: "action" }, extra)
    const section = (key, label) => ({ key, label, kind: "section" })
    const info = (key, label, extra = {}) => Object.assign({ key, label, kind: "info" }, extra)
    const sub = (key, label, open, extra = {}) => Object.assign({ key, label, kind: "submenu", open }, extra)

    function field(col, key, label, target, prop, opts = {}) {
        return {
            key,
            label,
            kind: "input",
            description: opts.description,
            input: {
                value: target[prop],
                type: opts.number ? "number" : "text",
                placeholder: opts.placeholder,
                maxLength: opts.maxLength,
                // Guarda o texto como digitado (campo vazio não vira "NaN"); converte ao salvar.
                onChange: (value) => {
                    target[prop] = value
                    markDirty(opts.dirtyCol || col)
                    syncDraft()
                },
            },
        }
    }

    function toggle(col, key, label, target, prop, opts = {}) {
        return item(key, label, {
            value: target[prop] ? "Sim" : "Não",
            description: opts.description,
            onSelect: () => {
                target[prop] = !target[prop]
                markDirty(opts.dirtyCol || col)
            },
        })
    }

    // ───────────── raiz ─────────────

    function rootColumn() {
        return {
            key: "root",
            title: "Ônibus",
            subtitle: "Editor de linhas",
            build: () => {
                const catalog = state.catalog
                const noZone = catalog.stops.filter((stop) => !stop.zone).length
                const broken = catalog.routes.filter((route) => !route.usable).length
                return [
                    sub("stops", "Paradas", () => stopsColumn(), { value: fmt(catalog.stops.length), description: noZone ? `${noZone} sem área de passageiros` : "Todas com área de passageiros", valueTone: noZone ? "warning" : undefined }),
                    sub("routes", "Linhas", () => routesColumn(), { value: fmt(catalog.routes.length), description: broken ? `${broken} inativa(s) ou incompleta(s)` : "Todas em operação" }),
                    sub("vehicles", "Veículos", () => vehiclesColumn(), { value: fmt(catalog.vehicles.length), description: "Modelos, capacidade e nível" }),
                    sub("levels", "Níveis", () => levelsColumn(), { value: fmt(catalog.levels.length), description: "XP e título de cada nível" }),
                    sub("depot", "Central", () => depotColumn(), { description: "Atendente, vaga do ônibus e blip" }),
                    sub("settings", "Ajustes", () => settingsColumn(), { description: "Parada, passageiros, pagamento, tempo e pico" }),
                    item("map", "Mapa das linhas", {
                        description: "Trajeto, paradas e áreas no mapa do GTA",
                        onSelect: async () => {
                            const response = await post("editor:openMap")
                            if (!response || !response.ok) {
                                activeColumn().notice = { tone: "danger", text: "O mapa precisa do noir_territories rodando." }
                                render()
                            }
                        },
                    }),
                    section("view", "No mundo"),
                    item("showWorld", "Mostrar paradas e áreas", {
                        description: "Encosto e área de tudo num raio de 150 m",
                        value: state.show.world ? "Sim" : "Não",
                        onSelect: () => setShow({ world: !state.show.world }),
                    }),
                    item("showAlways", "Mostrar com o editor fechado", {
                        description: "Para revisar andando pela cidade; desliga aqui",
                        value: state.show.always ? "Sim" : "Não",
                        disabled: !state.show.world,
                        onSelect: () => setShow({ always: !state.show.always }),
                    }),
                ]
            },
        }
    }

    async function setShow(change) {
        const response = await post("editor:show", change)
        if (response && response.ok) state.show = { world: response.world, always: response.always }
        render()
    }

    async function teleport(col, body) {
        const response = await post("editor:teleport", body)
        if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render() }
    }

    // ───────────── paradas ─────────────

    function stopsColumn() {
        return {
            key: "stops",
            title: "Paradas",
            subtitle: () => `${fmt(state.catalog.stops.length)} paradas`,
            query: "",
            onlyMissing: false,
            build: (col) => {
                const query = col.query.trim().toLowerCase()
                const items = [
                    { key: "search", label: "Buscar", kind: "input", input: { value: col.query, placeholder: "Buscar por nome, número ou linha", onChange: (value) => { col.query = value; render() } } },
                    item("missing", "Só sem área", {
                        description: "Para revisar as paradas uma a uma",
                        value: col.onlyMissing ? "Sim" : "Não",
                        onSelect: () => { col.onlyMissing = !col.onlyMissing },
                    }),
                    item("new", "Nova parada aqui", {
                        description: "Começa na sua posição atual",
                        onSelect: async () => {
                            const position = await post("editor:position")
                            const depth = state.columns.indexOf(col) + 1
                            col.openKey = "new"
                            openColumn(depth, stopColumn({ id: null, name: "", dock: position && position.x !== undefined ? position : null, zone: null, enabled: true, usedBy: [] }, true))
                        },
                    }),
                ]
                const stops = state.catalog.stops.filter((stop) => (!col.onlyMissing || !stop.zone) && (!query
                    || stop.name.toLowerCase().includes(query)
                    || String(stop.id) === query
                    || stop.usedBy.some((code) => code.toLowerCase().includes(query))))
                if (!stops.length) items.push(info("none", "Nenhuma parada", { description: "Nada com esse filtro." }))
                stops.forEach((stop) => {
                    items.push(sub(`stop-${stop.id}`, stop.name, () => stopColumn(clone(stop), false), {
                        description: `#${stop.id}${stop.usedBy.length ? ` · ${stop.usedBy.join(", ")}` : " · sem linha"}`,
                        value: !stop.enabled ? "Inativa" : stop.zone ? "" : "Sem área",
                        valueTone: !stop.enabled ? "danger" : stop.zone ? undefined : "warning",
                    }))
                })
                return items
            },
        }
    }

    function stopColumn(draft, isNew) {
        return {
            key: "stop",
            title: isNew ? "Nova parada" : "Parada",
            subtitle: isNew ? "Ainda não salva" : `#${draft.id}`,
            stopDraft: draft,
            dirty: isNew,
            notice: !isNew && draft.usedBy.length ? { tone: "info", text: `Usada por ${draft.usedBy.join(", ")}.` } : null,
            summary: () => {
                const box = el("div", "ed-summary")
                box.appendChild(el("span", "ed-summary__code", draft.id ? `#${draft.id}` : "NOVA"))
                const text = el("div", "ed-summary__text")
                text.appendChild(el("span", "ed-summary__name", draft.name || "Sem nome"))
                const tags = el("div", "ed-summary__tags")
                const tag = (label, tone) => { const node = el("span", "ed-tag", label); if (tone) node.dataset.tone = tone; tags.appendChild(node) }
                tag(draft.dock ? "Encosto ok" : "Sem encosto", draft.dock ? "success" : "danger")
                tag(draft.zone ? "Área ok" : "Sem área", draft.zone ? "success" : "warning")
                if (!draft.enabled) tag("Inativa", "danger")
                text.appendChild(tags)
                box.appendChild(text)
                return box
            },
            build: (col) => {
                const items = []
                if (draft.id) items.push(item("goto", "Ir até a parada", { description: "Teleporta para o encosto", onSelect: () => teleport(col, { kind: "stop", id: draft.id }) }))
                items.push(
                    field(col, "name", "Nome", draft, "name", { placeholder: "Ex.: Vespucci Blvd / Ginger St", maxLength: 48 }),
                    item("dock", "Onde o ônibus encosta", {
                        description: draft.dock ? coords(draft.dock) : "Pare o ônibus no lugar e aperte E",
                        value: draft.dock ? "Marcado" : "Falta",
                        valueTone: draft.dock ? "success" : "danger",
                        onSelect: () => startMode("dock", (value) => { draft.dock = value; markDirty(col) }),
                    }),
                    sub("zone", "Área dos passageiros", () => zoneColumn(draft, col), {
                        description: draft.zone ? `${fmt(draft.zone.length, 1)} × ${fmt(draft.zone.width, 1)} m · ${fmt(draft.zone.rotation)}°` : "Sem área: os NPCs nascem colados no encosto",
                        value: draft.zone ? "" : "Falta",
                        valueTone: draft.zone ? undefined : "warning",
                    }),
                    item("test", "Testar passageiros", {
                        description: "Cria 4 NPCs na área, só para você",
                        disabled: !draft.dock,
                        onSelect: async () => {
                            const response = await post("editor:testPassengers", { dock: draft.dock, zone: numericZone(draft.zone), count: 4 })
                            col.notice = response && response.ok ? { tone: "info", text: `${response.count} passageiros de teste criados.` } : { tone: "danger", text: "Não foi possível criar os passageiros." }
                            render()
                        },
                    }),
                    item("clear", "Limpar passageiros de teste", { onSelect: () => post("editor:clearPassengers") }),
                )
                items.push(toggle(col, "enabled", "Ativa", draft, "enabled", { description: "Parada inativa tira as linhas dela de operação" }))
                items.push(item("save", "Salvar parada", {
                    tone: "success",
                    onSelect: () => save(col, "saveStop", [draft.id || null, { name: draft.name, dock: draft.dock, zone: numericZone(draft.zone) || undefined, enabled: draft.enabled }], (response) => {
                        const saved = stopById(response.id)
                        if (saved) Object.assign(draft, clone(saved))
                        col.title = "Parada"
                        col.subtitle = `#${draft.id}`
                    }),
                }))
                if (draft.id) {
                    items.push(item("delete", "Apagar parada", {
                        tone: "danger",
                        onSelect: () => confirmDialog({
                            title: "Apagar parada",
                            object: `#${draft.id} · ${draft.name}`,
                            body: "A parada sai do catálogo. Linhas que usam a parada impedem a remoção.",
                            confirm: "Apagar",
                            danger: true,
                            onConfirm: async () => {
                                const response = await request("deleteStop", draft.id)
                                if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render(); return }
                                state.catalog = response.catalog
                                col.dirty = false
                                truncate(state.columns.indexOf(col))
                            },
                        }),
                    }))
                }
                return items
            },
        }
    }

    // Snippet colado do ShadowForge (ox_lib, ox_target, PolyZone ou JSON) vira a área.
    // ox_lib: size.x é a largura (eixo lateral) e size.y o comprimento (eixo do heading).
    function parseZoneSnippet(text) {
        const numberAt = (pattern) => {
            const match = text.match(pattern)
            return match ? Number(match[1]) : null
        }
        try {
            const json = JSON.parse(text)
            if (json && json.coords && json.size) {
                return { x: json.coords.x, y: json.coords.y, z: json.coords.z, width: json.size.x, length: json.size.y, height: json.size.z, rotation: Number(json.rotation || json.heading || 0) }
            }
        } catch (_) { /* não é JSON */ }

        const vectors = [...text.matchAll(/(?:vec3|vector3)\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)/g)].map((m) => m.slice(1, 4).map(Number))
        const sizeMatch = text.match(/size\s*=\s*(?:vec3|vector3)\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)/)
        const rotation = numberAt(/(?:rotation|heading)\s*=\s*(-?[\d.]+)/) || 0
        if (vectors.length && sizeMatch) {
            const [x, y, z] = vectors[0]
            return { x, y, z, width: Number(sizeMatch[1]), length: Number(sizeMatch[2]), height: Number(sizeMatch[3]), rotation }
        }
        // PolyZone: AddBoxZone(nome, vector3(...), length, width, { heading, minZ, maxZ }) ou
        // BoxZone:Create(vector3(...), length, width, {...}). O ShadowForge põe size.x no length.
        const poly = text.match(/(?:vec3|vector3)\(\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)\s*\)\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)/)
        if (poly) {
            const minZ = numberAt(/minZ\s*=\s*(-?[\d.]+)/)
            const maxZ = numberAt(/maxZ\s*=\s*(-?[\d.]+)/)
            const z = Number(poly[3])
            const low = minZ !== null ? minZ : z - 1.5
            const high = maxZ !== null ? maxZ : z + 1.5
            return { x: Number(poly[1]), y: Number(poly[2]), z: (low + high) / 2, width: Number(poly[4]), length: Number(poly[5]), height: high - low, rotation }
        }
        return null
    }

    // Área no molde do ZoneBuilder do ShadowForge: centro na posição ou na mira, tamanho e
    // rotação digitados, prévia no mundo o tempo todo. Grava direto na parada.
    const DEFAULT_ZONE = { length: 6, width: 2.5, height: 3 }

    function zoneColumn(draft, stopCol) {
        const dirty = () => { markDirty(stopCol); syncDraft() }

        // Ponto do chão vira o centro da caixa (a caixa vai de 0,5 m abaixo do chão para cima).
        async function centerAt(col, source) {
            const response = await post("editor:zoneCenter", { source })
            if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render(); return }
            const height = draft.zone ? num(draft.zone.height) || DEFAULT_ZONE.height : DEFAULT_ZONE.height
            const base = draft.zone || {
                length: DEFAULT_ZONE.length, width: DEFAULT_ZONE.width, height,
                rotation: draft.dock ? draft.dock.w : response.heading,
            }
            draft.zone = Object.assign({}, base, { x: response.x, y: response.y, z: response.z - 0.5 + height / 2 })
            col.notice = null
            dirty()
            render()
        }

        return {
            key: "zone",
            title: "Área",
            subtitle: "Onde os passageiros esperam",
            build: (col) => {
                const zone = draft.zone
                const items = [
                    section("create", zone ? "Centro" : "Criar"),
                    item("center-me", zone ? "Centro na minha posição" : "Criar na minha posição", {
                        description: zone ? coords({ x: num(zone.x), y: num(zone.y), z: num(zone.z) }) : "Caixa de 6 × 2,5 m alinhada com o encosto",
                        onSelect: () => centerAt(col, "player"),
                    }),
                    item("center-aim", zone ? "Centro na mira" : "Criar na mira", {
                        description: "Onde a câmera está apontando",
                        onSelect: () => centerAt(col, "aim"),
                    }),
                    item("draw", "Desenhar pela mira", {
                        description: "E nas duas pontas da calçada, roda ajusta a largura",
                        onSelect: () => startMode("zone", (value) => { draft.zone = value; dirty() }),
                    }),
                    item("paste", "Colar do ShadowForge", {
                        description: "Box de ox_lib, ox_target, PolyZone ou JSON",
                        onSelect: () => promptDialog({
                            title: "Colar área",
                            fields: [{ label: "Snippet do ZoneBuilder", multiline: true, placeholder: "lib.zones.box({ coords = vec3(...), size = vec3(...), rotation = ... })" }],
                            hint: "Depois de colar, confira o desenho no mundo. Se ficar atravessada, use Trocar comprimento e largura.",
                            confirm: "Usar área",
                            onSubmit: ([text]) => {
                                const parsed = parseZoneSnippet(text || "")
                                if (!parsed || [parsed.x, parsed.y, parsed.z, parsed.length, parsed.width, parsed.height].some((v) => !Number.isFinite(v))) return "Não reconheci uma box nesse texto."
                                draft.zone = parsed
                                dirty()
                                return null
                            },
                        }),
                    }),
                ]
                if (zone) {
                    items.push(item("goto", "Ir até a área", {
                        description: "Teleporta para o centro da área",
                        onSelect: () => teleport(col, { kind: "point", point: { x: num(zone.x), y: num(zone.y), z: num(zone.z) - num(zone.height) / 2 + 1.0, w: num(zone.rotation) } }),
                    }))
                    items.push(section("dims", "Tamanho e rotação"))
                    items.push(field(col, "length", "Comprimento (m)", zone, "length", { number: true, dirtyCol: stopCol, description: "Ao longo da calçada" }))
                    items.push(field(col, "width", "Largura (m)", zone, "width", { number: true, dirtyCol: stopCol }))
                    items.push(field(col, "height", "Altura (m)", zone, "height", { number: true, dirtyCol: stopCol }))
                    items.push(field(col, "rotation", "Rotação (°)", zone, "rotation", { number: true, dirtyCol: stopCol }))
                    items.push(item("align", "Alinhar com o encosto", {
                        description: "Rotação igual ao sentido da via",
                        disabled: !draft.dock,
                        onSelect: () => { zone.rotation = draft.dock.w; dirty() },
                    }))
                    items.push(item("turn", "Girar 90°", { onSelect: () => { zone.rotation = ((num(zone.rotation) || 0) + 90) % 360; dirty() } }))
                    items.push(item("swap", "Trocar comprimento e largura", {
                        onSelect: () => { [zone.length, zone.width] = [zone.width, zone.length]; dirty() },
                    }))
                    items.push(item("test", "Testar passageiros", {
                        description: "Cria 4 NPCs na área, só para você",
                        disabled: !draft.dock,
                        onSelect: async () => {
                            const response = await post("editor:testPassengers", { dock: draft.dock, zone: numericZone(zone), count: 4 })
                            col.notice = response && response.ok ? { tone: "info", text: `${response.count} passageiros de teste criados.` } : { tone: "danger", text: "Não foi possível criar os passageiros." }
                            render()
                        },
                    }))
                    items.push(item("remove", "Remover área", {
                        tone: "danger",
                        onSelect: () => { draft.zone = null; dirty() },
                    }))
                }
                return items
            },
        }
    }

    // ───────────── linhas ─────────────

    function routesColumn() {
        return {
            key: "routes",
            title: "Linhas",
            subtitle: () => `${fmt(state.catalog.routes.length)} linhas`,
            build: (col) => {
                const items = [item("new", "Nova linha", {
                    onSelect: () => {
                        const depth = state.columns.indexOf(col) + 1
                        col.openKey = "new"
                        openColumn(depth, routeColumn({ id: null, code: "", name: "", minLevel: 1, basePay: 0, baseXp: 0, stops: [], vehicles: [], access: { groups: {} }, enabled: true }, true))
                    },
                })]
                state.catalog.routes.forEach((route) => {
                    const minutes = Math.round((route.expected || 0) / 60)
                    items.push(sub(`route-${route.id}`, `${route.code} · ${route.name.replace(/^.*·\s*/, "")}`, () => routeColumn(clone(route), false), {
                        description: `${route.stops.length} paradas · ${route.road && route.road.current ? `${fmt(route.road.meters / 1000, 1)} km pela estrada` : `${fmt((route.distance || 0) / 1000, 1)} km reto`} · ~${minutes} min`,
                        value: !route.enabled ? "Inativa" : !route.usable ? "Incompleta" : `Nível ${route.minLevel}`,
                        valueTone: !route.enabled || !route.usable ? "warning" : undefined,
                    }))
                })
                return items
            },
        }
    }

    function routeColumn(draft, isNew) {
        return {
            key: "route",
            title: isNew ? "Nova linha" : draft.code,
            subtitle: isNew ? "Ainda não salva" : draft.name,
            dirty: isNew,
            summary: () => {
                const box = el("div", "ed-summary")
                box.appendChild(el("span", "ed-summary__code", draft.code || "—"))
                const text = el("div", "ed-summary__text")
                text.appendChild(el("span", "ed-summary__name", draft.name || "Sem nome"))
                const tags = el("div", "ed-summary__tags")
                const tag = (label, tone) => { const node = el("span", "ed-tag", label); if (tone) node.dataset.tone = tone; tags.appendChild(node) }
                tag(`Nível ${draft.minLevel || "?"}`)
                tag(`${draft.stops.length} paradas`, draft.stops.length >= 2 ? undefined : "danger")
                if (Object.keys(draft.access.groups).length) tag("Restrita", "warning")
                if (!draft.enabled) tag("Inativa", "danger")
                text.appendChild(tags)
                box.appendChild(text)
                return box
            },
            build: (col) => {
                const estimate = routeEstimate(draft)
                const groups = Object.keys(draft.access.groups)
                const items = [
                    field(col, "code", "Código", draft, "code", { placeholder: "Ex.: A07", maxLength: 6 }),
                    field(col, "name", "Nome", draft, "name", { placeholder: "Ex.: Linha A07 · Aeroporto", maxLength: 48 }),
                    field(col, "minLevel", "Nível mínimo", draft, "minLevel", { number: true }),
                    field(col, "basePay", "Pagamento base ($)", draft, "basePay", { number: true }),
                    field(col, "baseXp", "XP base", draft, "baseXp", { number: true }),
                    info("estimate", "Estimativa", {
                        description: draft.stops.length >= 2
                            ? `${fmt(estimate.km, 1)} km em linha reta · ~${fmt(estimate.minutes)} min · ~$${fmt(estimate.perHour)}/h · ~${fmt(estimate.xpPerHour)} XP/h`
                            : "Adicione paradas para estimar tempo e ganho",
                    }),
                    info("road", "Pela estrada", {
                        description: !draft.road
                            ? `Sem traçado · /onibusrota ${draft.code || "CÓDIGO"} save`
                            : draft.road.current
                                ? `${fmt(draft.road.meters / 1000, 1)} km${draft.road.failedLegs ? ` · ${draft.road.failedLegs} trecho(s) em reta` : ""}`
                                : `Desatualizado (paradas mudaram) · /onibusrota ${draft.code} save`,
                        value: !draft.road ? "Falta" : draft.road.current ? (draft.road.failedLegs ? "Parcial" : "Em dia") : "Refazer",
                        valueTone: !draft.road || !draft.road.current ? "warning" : draft.road.failedLegs ? "warning" : "success",
                    }),
                    sub("stops", "Paradas", () => routeStopsColumn(draft, col), { value: fmt(draft.stops.length), description: draft.stops.length ? draft.stops.map((id) => (stopById(id) || {}).name || `#${id}`).slice(0, 3).join(" → ") + (draft.stops.length > 3 ? " → …" : "") : "Nenhuma parada" }),
                    sub("vehicles", "Veículos", () => routeVehiclesColumn(draft, col), { value: fmt(draft.vehicles.length), description: draft.vehicles.map((model) => (vehicleByModel(model) || {}).label || model).join(", ") || "Nenhum veículo" }),
                    sub("access", "Quem pode fazer", () => accessColumn(draft, col), { value: groups.length ? `${groups.length} grupo(s)` : "Todos", description: groups.length ? groups.join(", ") : "Qualquer jogador com o nível" }),
                    item("map", "Mostrar no mapa", {
                        description: "Um blip numerado por parada",
                        disabled: !draft.stops.length,
                        onSelect: async () => {
                            const response = await post("editor:showRoute", { stops: draft.stops })
                            col.notice = { tone: "info", text: `${(response && response.count) || 0} paradas marcadas no mapa.` }
                            render()
                        },
                    }),
                    toggle(col, "enabled", "Ativa", draft, "enabled"),
                    item("save", "Salvar linha", {
                        tone: "success",
                        onSelect: () => save(col, "saveRoute", [draft.id || null, {
                            code: draft.code, name: draft.name, minLevel: num(draft.minLevel), basePay: num(draft.basePay), baseXp: num(draft.baseXp),
                            stops: draft.stops, vehicles: draft.vehicles, access: draft.access, enabled: draft.enabled,
                        }], (response) => {
                            const saved = state.catalog.routes.find((route) => route.id === response.id)
                            if (saved) Object.assign(draft, clone(saved))
                            col.title = draft.code
                            col.subtitle = draft.name
                        }),
                    }),
                ]
                if (draft.id) {
                    items.push(item("delete", "Apagar linha", {
                        tone: "danger",
                        onSelect: () => confirmDialog({
                            title: "Apagar linha",
                            object: `${draft.code} · ${draft.name}`,
                            body: "A linha sai da Central. O histórico de quem já rodou nela continua no banco.",
                            confirm: "Apagar",
                            danger: true,
                            onConfirm: async () => {
                                const response = await request("deleteRoute", draft.id)
                                if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render(); return }
                                state.catalog = response.catalog
                                col.dirty = false
                                truncate(state.columns.indexOf(col))
                            },
                        }),
                    }))
                }
                return items
            },
        }
    }

    function routeStopsColumn(draft, routeCol) {
        return {
            key: "route-stops",
            title: "Paradas",
            subtitle: "Na ordem da linha",
            build: (col) => {
                const items = [sub("add", "Adicionar parada", () => pickStopColumn(draft, routeCol), { description: "Entra no fim da lista" })]
                draft.stops.forEach((id, index) => {
                    const stop = stopById(id)
                    items.push(item(`s-${index}`, `${index + 1}. ${stop ? stop.name : "(não existe mais)"}`, {
                        tone: stop ? undefined : "danger",
                        description: stop ? `#${id}${stop.zone ? "" : " · sem área"}${stop.enabled ? "" : " · inativa"}` : `#${id}`,
                        onSelect: () => actionsDialog("Parada da linha", `${index + 1}. ${stop ? stop.name : `#${id}`}`, [
                            { label: "Subir", run: () => { if (index > 0) { [draft.stops[index - 1], draft.stops[index]] = [draft.stops[index], draft.stops[index - 1]]; markDirty(routeCol); col.index = Math.max(1, index) } } },
                            { label: "Descer", run: () => { if (index < draft.stops.length - 1) { [draft.stops[index + 1], draft.stops[index]] = [draft.stops[index], draft.stops[index + 1]]; markDirty(routeCol); col.index = index + 2 } } },
                            { label: "Remover", danger: true, run: () => { draft.stops.splice(index, 1); markDirty(routeCol) } },
                        ]),
                    }))
                })
                return items
            },
        }
    }

    function pickStopColumn(draft, routeCol) {
        return {
            key: "pick-stop",
            title: "Adicionar",
            subtitle: "Escolha a parada",
            query: "",
            build: (col) => {
                const query = col.query.trim().toLowerCase()
                const items = [{ key: "search", label: "Buscar", kind: "input", input: { value: col.query, placeholder: "Buscar por nome ou número", onChange: (value) => { col.query = value; render() } } }]
                state.catalog.stops
                    .filter((stop) => !query || stop.name.toLowerCase().includes(query) || String(stop.id) === query)
                    .forEach((stop) => {
                        items.push(item(`p-${stop.id}`, stop.name, {
                            description: `#${stop.id}${stop.zone ? "" : " · sem área"}${stop.enabled ? "" : " · inativa"}`,
                            value: draft.stops.includes(stop.id) ? "Na linha" : "",
                            onSelect: () => {
                                if (draft.stops[draft.stops.length - 1] === stop.id) {
                                    col.notice = { tone: "warning", text: "Essa já é a última parada da linha." }
                                    return
                                }
                                draft.stops.push(stop.id)
                                markDirty(routeCol)
                                col.notice = { tone: "success", text: `${stop.name} entrou como parada ${draft.stops.length}.` }
                            },
                        }))
                    })
                return items
            },
        }
    }

    function routeVehiclesColumn(draft, routeCol) {
        return {
            key: "route-vehicles",
            title: "Veículos",
            subtitle: "O primeiro liberado é o padrão",
            build: () => state.catalog.vehicles.map((vehicle) => {
                const position = draft.vehicles.indexOf(vehicle.model)
                return item(`v-${vehicle.model}`, vehicle.label, {
                    description: `${vehicle.model} · ${vehicle.capacity} lugares · nível ${vehicle.minLevel}${vehicle.enabled ? "" : " · inativo"}`,
                    value: position >= 0 ? `Sim · ${position + 1}º` : "Não",
                    onSelect: () => {
                        if (position >= 0) draft.vehicles.splice(position, 1)
                        else draft.vehicles.push(vehicle.model)
                        markDirty(routeCol)
                    },
                })
            }),
        }
    }

    function accessColumn(draft, routeCol) {
        return {
            key: "access",
            title: "Acesso",
            subtitle: "Quem pode fazer a linha",
            build: () => {
                const groups = draft.access.groups
                const items = [
                    info("hint", Object.keys(groups).length ? "Só estes grupos" : "Qualquer jogador", { description: "Sem grupo na lista, basta o nível. Job ou gang com cargo mínimo." }),
                    item("add", "Adicionar grupo", {
                        onSelect: () => promptDialog({
                            title: "Adicionar grupo",
                            fields: [{ label: "Job ou gang", placeholder: "Ex.: police" }, { label: "Cargo mínimo", value: "0" }],
                            confirm: "Adicionar",
                            onSubmit: ([name, grade]) => {
                                const key = String(name || "").trim().toLowerCase()
                                const minGrade = num(grade)
                                if (!/^[a-z0-9_]{1,32}$/.test(key)) return "Nome com letras, números e _ (até 32)."
                                if (!Number.isInteger(minGrade) || minGrade < 0 || minGrade > 20) return "Cargo mínimo entre 0 e 20."
                                groups[key] = minGrade
                                markDirty(routeCol)
                                return null
                            },
                        }),
                    }),
                ]
                Object.entries(groups).forEach(([name, grade]) => {
                    items.push(item(`g-${name}`, name, {
                        value: `Cargo ${grade}+`,
                        onSelect: () => confirmDialog({ title: "Remover grupo", object: name, body: "O grupo deixa de ter acesso exclusivo a esta linha.", confirm: "Remover", danger: true, onConfirm: () => { delete groups[name]; markDirty(routeCol); render() } }),
                    }))
                })
                return items
            },
        }
    }

    // ───────────── veículos ─────────────

    function vehiclesColumn() {
        return {
            key: "vehicles",
            title: "Veículos",
            subtitle: () => `${fmt(state.catalog.vehicles.length)} modelos`,
            build: (col) => {
                const items = [item("new", "Novo veículo", {
                    onSelect: () => {
                        const depth = state.columns.indexOf(col) + 1
                        col.openKey = "new"
                        openColumn(depth, vehicleColumn({ model: "", label: "", capacity: 10, doors: [0, 1], minLevel: 1, enabled: true }, true))
                    },
                })]
                state.catalog.vehicles.forEach((vehicle) => {
                    items.push(sub(`veh-${vehicle.model}`, vehicle.label, () => vehicleColumn(clone(vehicle), false), {
                        description: `${vehicle.model} · ${vehicle.capacity} lugares`,
                        value: vehicle.enabled ? `Nível ${vehicle.minLevel}` : "Inativo",
                        valueTone: vehicle.enabled ? undefined : "danger",
                    }))
                })
                return items
            },
        }
    }

    function vehicleColumn(draft, isNew) {
        const doors = { text: (draft.doors || []).join(", ") }
        return {
            key: "vehicle",
            title: isNew ? "Novo veículo" : draft.label,
            subtitle: isNew ? "Ainda não salvo" : draft.model,
            dirty: isNew,
            build: (col) => {
                const items = []
                if (isNew) items.push(field(col, "model", "Modelo (spawn name)", draft, "model", { placeholder: "Ex.: airbus", maxLength: 32 }))
                else items.push(info("model", "Modelo", { value: draft.model }))
                items.push(
                    item("check", "Conferir modelo no jogo", {
                        description: "Confirma que existe no build e conta os assentos",
                        onSelect: async () => {
                            const response = await post("editor:checkModel", { model: String(draft.model || "").toLowerCase() })
                            if (response && response.ok) {
                                if (response.seats > 0) draft.capacity = response.seats
                                markDirty(col)
                                col.notice = { tone: "success", text: `Modelo existe. ${response.seats} assentos de passageiro; capacidade ajustada.` }
                            } else {
                                col.notice = { tone: "danger", text: "Esse modelo não existe neste build. Não use: veículo ausente derruba o cliente." }
                            }
                            render()
                        },
                    }),
                    field(col, "label", "Nome na tela", draft, "label", { placeholder: "Ex.: Ônibus do aeroporto", maxLength: 32 }),
                    field(col, "capacity", "Capacidade (passageiros)", draft, "capacity", { number: true }),
                    { key: "doors", label: "Portas que abrem", kind: "input", description: "Índices das portas, ex.: 0, 1", input: { value: doors.text, onChange: (value) => { doors.text = value; draft.doors = value.split(/[,\s]+/).filter(Boolean).map(Number); markDirty(col) } } },
                    field(col, "minLevel", "Nível mínimo", draft, "minLevel", { number: true }),
                    toggle(col, "enabled", "Ativo", draft, "enabled"),
                    item("save", "Salvar veículo", {
                        tone: "success",
                        onSelect: () => save(col, "saveVehicle", [isNew, {
                            model: String(draft.model || "").toLowerCase(), label: draft.label, capacity: num(draft.capacity), doors: draft.doors, minLevel: num(draft.minLevel), enabled: draft.enabled,
                        }], () => {
                            isNew = false
                            col.title = draft.label
                            col.subtitle = draft.model
                        }),
                    }),
                )
                if (!isNew) {
                    items.push(item("delete", "Apagar veículo", {
                        tone: "danger",
                        onSelect: () => confirmDialog({
                            title: "Apagar veículo",
                            object: `${draft.label} · ${draft.model}`,
                            body: "Linhas que usam o veículo impedem a remoção.",
                            confirm: "Apagar",
                            danger: true,
                            onConfirm: async () => {
                                const response = await request("deleteVehicle", draft.model)
                                if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render(); return }
                                state.catalog = response.catalog
                                col.dirty = false
                                truncate(state.columns.indexOf(col))
                            },
                        }),
                    }))
                }
                return items
            },
        }
    }

    // ───────────── níveis ─────────────

    function levelsColumn() {
        const draft = clone(state.catalog.levels)
        return {
            key: "levels",
            title: "Níveis",
            subtitle: "XP acumulado de cada nível",
            build: (col) => {
                const items = [
                    item("save", "Salvar níveis", {
                        tone: "success",
                        onSelect: () => save(col, "saveLevels", [draft.map((level) => ({ xp: num(level.xp), title: level.title }))], () => {
                            draft.splice(0, draft.length, ...clone(state.catalog.levels))
                        }),
                    }),
                    item("add", "Adicionar nível", {
                        onSelect: () => {
                            const last = draft[draft.length - 1]
                            draft.push({ level: draft.length + 1, xp: (num(last.xp) || 0) + 10000, title: "Novo nível" })
                            markDirty(col)
                        },
                    }),
                ]
                draft.forEach((level, index) => {
                    const previous = index > 0 ? num(draft[index - 1].xp) : 0
                    items.push(sub(`l-${index}`, `Nível ${index + 1} · ${level.title}`, () => levelColumn(draft, index, col), {
                        value: `${fmt(level.xp)} XP`,
                        description: index ? `+${fmt(num(level.xp) - previous)} desde o nível ${index}` : "Começo da carreira",
                    }))
                })
                return items
            },
        }
    }

    function levelColumn(levels, index, levelsCol) {
        const level = levels[index]
        return {
            key: "level",
            title: `Nível ${index + 1}`,
            subtitle: level.title,
            build: (col) => {
                const items = [field(col, "title", "Título", level, "title", { maxLength: 32, dirtyCol: levelsCol })]
                if (index === 0) items.push(info("xp", "XP", { value: "0", description: "O nível 1 sempre começa em 0" }))
                else items.push(field(col, "xp", "XP acumulado", level, "xp", { number: true, dirtyCol: levelsCol }))
                if (index > 0 && index === levels.length - 1) {
                    items.push(item("remove", "Remover nível", {
                        tone: "danger",
                        onSelect: () => {
                            levels.splice(index, 1)
                            markDirty(levelsCol)
                            state.columns = state.columns.slice(0, state.columns.indexOf(col))
                        },
                    }))
                }
                return items
            },
        }
    }

    // ───────────── central e ajustes ─────────────

    function depotColumn() {
        const draft = clone(state.catalog.settings.depot)
        return {
            key: "depot",
            title: "Central",
            subtitle: "Onde o serviço começa e termina",
            build: (col) => [
                item("ped", "Atendente", {
                    description: coords(draft.ped),
                    value: "Posicionar",
                    onSelect: () => startMode("depotPed", (value) => { draft.ped = value; markDirty(col) }, { model: draft.pedModel, current: draft.ped }),
                }),
                field(col, "pedModel", "Modelo do atendente", draft, "pedModel", { maxLength: 32 }),
                item("spawn", "Vaga do ônibus", {
                    description: coords(draft.spawn),
                    value: "Posicionar",
                    onSelect: () => startMode("depotSpawn", (value) => { draft.spawn = value; markDirty(col) }, { model: "bus", current: draft.spawn }),
                }),
                field(col, "radius", "Raio da chegada (m)", draft, "radius", { number: true, description: "Distância do atendente para fechar a volta" }),
                section("blip", "Blip"),
                toggle(col, "blipOn", "Mostrar no mapa", draft.blip, "enabled"),
                field(col, "blipLabel", "Nome do blip", draft.blip, "label", { maxLength: 48 }),
                field(col, "blipSprite", "Ícone (sprite)", draft.blip, "sprite", { number: true }),
                field(col, "blipColor", "Cor", draft.blip, "color", { number: true }),
                field(col, "blipScale", "Tamanho", draft.blip, "scale", { number: true }),
                item("goto", "Ir até a Central", {
                    onSelect: async () => {
                        const response = await post("editor:teleport", { kind: "depot" })
                        if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render() }
                    },
                }),
                item("save", "Salvar Central", {
                    tone: "success",
                    onSelect: () => save(col, "saveSettings", [{ depot: {
                        ped: draft.ped, pedModel: String(draft.pedModel || "").toLowerCase(), spawn: draft.spawn, radius: num(draft.radius),
                        blip: { enabled: draft.blip.enabled, label: draft.blip.label, sprite: num(draft.blip.sprite), color: num(draft.blip.color), scale: num(draft.blip.scale) },
                    } }]),
                }),
            ],
        }
    }

    function settingsColumn() {
        const draft = clone(state.catalog.settings)
        const text = {
            models: draft.passenger.models.join(", "),
            windows: draft.peak.windows.map((w) => `${w.from}-${w.to}`).join(", "),
        }
        const payload = () => {
            const windows = text.windows.split(",").map((part) => part.trim()).filter(Boolean).map((part) => {
                const [from, to] = part.split("-").map((v) => num(v))
                return { from, to }
            })
            return {
                stop: Object.fromEntries(Object.entries(draft.stop).map(([k, v]) => [k, num(v)])),
                passenger: {
                    spawnDistance: num(draft.passenger.spawnDistance), minDemand: num(draft.passenger.minDemand), maxDemand: num(draft.passenger.maxDemand),
                    exitDespawnMs: num(draft.passenger.exitDespawnMs), models: text.models.split(/[,\s]+/).filter(Boolean).map((m) => m.toLowerCase()),
                },
                payout: Object.fromEntries(Object.entries(draft.payout).map(([k, v]) => [k, num(v)])),
                timing: Object.fromEntries(Object.entries(draft.timing).map(([k, v]) => [k, num(v)])),
                peak: { enabled: draft.peak.enabled, windows, demandMultiplier: num(draft.peak.demandMultiplier) },
                vehicleFailure: { engineHealth: num(draft.vehicleFailure.engineHealth) },
            }
        }
        const group = (key, title, subtitle, fields) => ({ key, title, subtitle, build: (col) => fields(col) })
        return {
            key: "settings",
            title: "Ajustes",
            subtitle: "Valem para todas as linhas",
            build: (col) => {
                const leaf = (key, title, subtitle, fields) => sub(key, title, () => group(key, title, subtitle, (inner) => fields(inner, col)), { description: subtitle })
                return [
                    item("save", "Salvar ajustes", { tone: "success", onSelect: () => save(col, "saveSettings", [payload()]) }),
                    leaf("stop", "Parada", "Raio, velocidades e tempos de embarque", (inner, parent) => [
                        field(inner, "radius", "Raio de chegada (m)", draft.stop, "radius", { number: true, dirtyCol: parent }),
                        field(inner, "dock", "Velocidade máx. para encostar (km/h)", draft.stop, "maxDockSpeedKmh", { number: true, dirtyCol: parent }),
                        field(inner, "door", "Velocidade máx. com porta aberta (km/h)", draft.stop, "maxDoorSpeedKmh", { number: true, dirtyCol: parent }),
                        field(inner, "timeout", "Tempo máximo na parada (ms)", draft.stop, "serviceTimeoutMs", { number: true, dirtyCol: parent }),
                        field(inner, "exit", "Espera do desembarque (ms)", draft.stop, "pedExitTimeoutMs", { number: true, dirtyCol: parent }),
                        field(inner, "enter", "Espera do embarque (ms)", draft.stop, "pedEnterTimeoutMs", { number: true, dirtyCol: parent }),
                    ]),
                    leaf("passenger", "Passageiros", "Demanda por parada e modelos", (inner, parent) => [
                        field(inner, "min", "Demanda mínima", draft.passenger, "minDemand", { number: true, dirtyCol: parent }),
                        field(inner, "max", "Demanda máxima", draft.passenger, "maxDemand", { number: true, dirtyCol: parent }),
                        field(inner, "distance", "Distância para aparecerem (m)", draft.passenger, "spawnDistance", { number: true, dirtyCol: parent }),
                        field(inner, "despawn", "Somem depois de descer (ms)", draft.passenger, "exitDespawnMs", { number: true, dirtyCol: parent }),
                        { key: "models", label: "Modelos", kind: "input", description: "Separados por vírgula", input: { value: text.models, onChange: (value) => { text.models = value; markDirty(parent) } } },
                    ]),
                    leaf("payout", "Pagamento", "Bônus de passageiro e de nota", (inner, parent) => [
                        field(inner, "per", "$ por passageiro", draft.payout, "perPassenger", { number: true, dirtyCol: parent }),
                        field(inner, "pcap", "Teto do bônus de passageiro (× base)", draft.payout, "passengerCap", { number: true, dirtyCol: parent }),
                        field(inner, "scap", "Teto do bônus de nota (× base)", draft.payout, "scoreCap", { number: true, dirtyCol: parent }),
                        field(inner, "xpp", "XP por passageiro", draft.payout, "xpPerPassenger", { number: true, dirtyCol: parent }),
                        field(inner, "xcap", "Teto do XP de passageiro (× base)", draft.payout, "xpCap", { number: true, dirtyCol: parent }),
                    ]),
                    leaf("timing", "Tempo", "Pontualidade e volta mínima", (inner, parent) => [
                        field(inner, "km", "Segundos por km (linha reta)", draft.timing, "secondsPerKm", { number: true, dirtyCol: parent }),
                        field(inner, "stop", "Segundos por parada", draft.timing, "secondsPerStop", { number: true, dirtyCol: parent }),
                        field(inner, "tol", "Tolerância (× esperado)", draft.timing, "tolerance", { number: true, dirtyCol: parent, description: "Pontualidade 100 até aqui" }),
                        field(inner, "min", "Volta mínima (× esperado)", draft.timing, "minFraction", { number: true, dirtyCol: parent, description: "Mais rápido que isso não paga" }),
                    ]),
                    leaf("peak", "Horário de pico", "Mais passageiros em certas horas", (inner, parent) => [
                        toggle(inner, "on", "Ligado", draft.peak, "enabled", { dirtyCol: parent }),
                        { key: "windows", label: "Janelas (hora do servidor)", kind: "input", description: "Ex.: 7-9, 17-19", input: { value: text.windows, onChange: (value) => { text.windows = value; markDirty(parent) } } },
                        field(inner, "mult", "Multiplicador da demanda máxima", draft.peak, "demandMultiplier", { number: true, dirtyCol: parent }),
                    ]),
                    leaf("failure", "Quebra do ônibus", "Quando o serviço é cancelado", (inner, parent) => [
                        field(inner, "engine", "Vida do motor para cancelar", draft.vehicleFailure, "engineHealth", { number: true, dirtyCol: parent }),
                    ]),
                ]
            },
        }
    }

    // ───────────── ciclo ─────────────

    function show(catalog) {
        state.catalog = catalog
        state.visible = true
        state.hidden = false
        state.columns = [column(rootColumn())]
        root.hidden = false
        root.dataset.hidden = "false"
        render()
    }

    function hide() {
        state.visible = false
        state.hidden = false
        state.pending = null
        state.lastDraft = ""
        closeModal()
        root.hidden = true
        menusEl.replaceChildren()
        keysEl.replaceChildren()
    }

    function onMessage(data) {
        if (!data) return
        if (data.visible === true && data.catalog) {
            if (data.show) state.show = data.show
            if (!state.visible) show(data.catalog)
            if (data.hidden) { state.hidden = true; root.dataset.hidden = "true" }
            return
        }
        if (data.visible === false) return hide()
        if (data.hidden === true) {
            state.hidden = true
            root.dataset.hidden = "true"
            renderKeys()
            return
        }
        if (data.hidden === false) {
            state.hidden = false
            root.dataset.hidden = "false"
            const pending = state.pending
            state.pending = null
            if (pending && data.result && data.result.kind !== "cancel" && data.result.value) pending.apply(data.result.value)
            render()
        }
    }

    // Mapa aberto por cima: o editor some e não responde ao teclado até o mapa fechar.
    document.addEventListener("busmap:visible", (event) => {
        state.mapVisible = event.detail === true
        if (!state.visible) return
        root.dataset.hidden = state.mapVisible || state.hidden ? "true" : "false"
        renderKeys()
    })

    document.addEventListener("keydown", (event) => {
        if (!state.visible || state.hidden || state.modal || state.mapVisible) return
        const inField = event.target && (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA")
        switch (event.key) {
            case "ArrowDown":
            case "ArrowUp":
                event.preventDefault()
                if (inField) event.target.blur()
                moveIndex(event.key === "ArrowDown" ? 1 : -1)
                break
            case "Home":
            case "End":
                if (inField) return
                event.preventDefault()
                {
                    const col = activeColumn()
                    const items = col.items || []
                    const order = event.key === "Home" ? items.map((_, i) => i) : items.map((_, i) => items.length - 1 - i)
                    const next = order.find((i) => selectable(items[i]))
                    if (next !== undefined) { col.index = next; render() }
                }
                break
            case "Enter":
                if (inField) { event.target.blur(); return }
                event.preventDefault()
                activate(state.columns.length - 1, activeColumn().index)
                break
            case "ArrowLeft":
                if (inField) return
                {
                    const col = activeColumn()
                    const current = (col.items || [])[col.index]
                    if (current && current.kind === "submenu") { event.preventDefault(); activate(state.columns.length - 1, col.index) }
                }
                break
            case "ArrowRight":
            case "Backspace":
                if (inField) return
                event.preventDefault()
                back()
                break
            case "Escape":
                event.preventDefault()
                if (inField) event.target.blur()
                back()
                break
            default:
                break
        }
    })

    window.addEventListener("message", (event) => {
        const message = event.data || {}
        if (message.action === "editor") onMessage(message.data)
    })

    // Preview no navegador (dev/preview.js) e testes.
    window.busEditorDebug = { parseZoneSnippet, routeEstimate: (draft) => (state.catalog ? routeEstimate(draft) : null), state }
})()
