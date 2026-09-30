// Editor do táxi (/editortaxi): Menu Lateral da v4, variação editor (§ML.7). O motor de
// colunas é o do noir_busjob; as colunas são do táxi. A tela monta o rascunho; o client executa
// os modos no mundo e o servidor valida tudo.
(() => {
    "use strict"

    const $ = (id) => document.getElementById(id)
    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_taxijob"
    const root = $("taxi-editor")
    const menusEl = $("ed-menus")
    const keysEl = $("ed-keys")
    const modalEl = $("ed-modal")

    const ERROR_TEXT = {
        invalid_payload: "Dados inválidos.",
        invalid_region: "Escolha a região do ponto.",
        invalid_point: "Marque onde o passageiro espera.",
        unknown_point: "O ponto não existe mais.",
        invalid_id: "Chave com letras minúsculas, números e _, até 24 caracteres.",
        vehicle_exists: "Já existe um carro com essa chave.",
        unknown_vehicle: "O carro não existe mais.",
        invalid_model: "Modelo inválido ou inexistente neste build.",
        invalid_label: "Nome vazio ou longo demais (até 32 caracteres).",
        invalid_class: "Escolha o tipo de passageiro.",
        invalid_level: "Nível fora da tabela de níveis.",
        invalid_fee: "Taxa de aluguel entre $0 e $100.000.",
        invalid_image: "Imagem: caminho dentro de html/, ex.: img/vehicles/taxi-fixed.png.",
        invalid_description: "Descrição longa demais (até 160 caracteres).",
        invalid_appearance: "Visual grande demais para salvar.",
        last_vehicle: "A central precisa de pelo menos um carro.",
        invalid_levels: "Níveis inválidos (nome até 32 caracteres).",
        first_level_zero: "O nível 1 começa em 0 de confiança.",
        levels_order: "A confiança precisa crescer a cada nível.",
        vehicle_level_missing: "Um carro pede um nível que deixaria de existir.",
        invalid_depot: "Central inválida: posição, modelo do atendente, distância (2–50 m) e raio da devolução (5–150 m).",
        invalid_spawns: "A Central precisa de 1 a 12 vagas.",
        invalid_blip: "Blip inválido (ícone 0–900, cor 0–85, tamanho 0,3–2).",
        invalid_meter: "Taxímetro fora da faixa.",
        invalid_dispatch: "Chamadas fora da faixa (mínimo ≤ ideal ≤ máximo; atraso máximo ≥ mínimo).",
        invalid_payout: "Pagamento fora da faixa.",
        storage_failed: "O banco recusou a gravação. Nada mudou.",
        storage_unavailable: "O catálogo ainda não carregou.",
        not_allowed: "Sem permissão para o editor.",
        busy: "Devagar: aguarde um instante.",
        too_far: "Só dá para ir até perto de um ponto ou da Central.",
        not_in_vehicle: "Entre no carro montado para copiar o visual.",
        other_model: "Você está em outro modelo de carro.",
        read_failed: "Não foi possível ler o visual do carro.",
        map_unavailable: "O mapa precisa do noir_territories rodando.",
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

    function regionLabel(key) {
        const region = (state.catalog.regions || []).find((r) => r.key === key)
        return region ? region.label : key
    }

    // Tipos de passageiro (Config.VehicleClasses): o nome mostrado ao admin.
    const CLASS_LABEL = {
        standard: "Padrão", executive: "Executivo", van: "Van (grupos)", suv: "SUV (Sandy e Paleto)",
        luxury: "Luxo (VIP)", limousine: "Limousine (eventos)",
    }
    const classLabel = (key) => CLASS_LABEL[key] || key

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

    // Ponto (ou vaga) aberto no editor: o client desenha o rascunho no mundo.
    function syncDraft() {
        const col = [...state.columns].reverse().find((c) => c.pointDraft)
        const draft = col && col.pointDraft.value ? { kind: col.pointDraft.kind, id: col.pointDraft.id || null, value: col.pointDraft.value } : null
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
            title: "Táxi",
            subtitle: "Editor da central",
            build: () => {
                const catalog = state.catalog
                const off = catalog.points.filter((p) => !p.enabled).length
                return [
                    sub("points", "Pontos", () => pointsColumn(), { value: fmt(catalog.points.length), description: off ? `Coleta e destino · ${off} inativo(s)` : "Coleta e destino das corridas" }),
                    sub("vehicles", "Carros", () => vehiclesColumn(), { value: fmt(catalog.vehicles.length), description: "Catálogo da central, nível e visual" }),
                    sub("levels", "Níveis", () => levelsColumn(), { value: fmt(catalog.levels.length), description: "Confiança e nome de cada nível" }),
                    sub("depot", "Central", () => depotColumn(), { description: "Atendente, vagas do táxi e blip" }),
                    sub("settings", "Ajustes", () => settingsColumn(), { description: "Taxímetro, chamadas e pagamento" }),
                    item("map", "Mapa dos pontos", {
                        description: "Todos os pontos por região no mapa do GTA",
                        onSelect: async () => {
                            const response = await post("editor:openMap")
                            if (!response || !response.ok) { activeColumn().notice = { tone: "danger", text: errorText(response) }; render() }
                        },
                    }),
                    section("view", "No mundo"),
                    item("showWorld", "Mostrar pontos e Central", {
                        description: "Tudo num raio de 250 m, na cor da região",
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

    // ───────────── pontos ─────────────

    // Região sugerida pela posição (o admin pode trocar antes de salvar).
    function guessRegion(p) {
        if (!p) return "downtown"
        if (p.y >= 5300) return "paleto bay"
        if (p.y >= 2500) return "sandy shores"
        return "downtown"
    }

    function pointsColumn() {
        return {
            key: "points",
            title: "Pontos",
            subtitle: () => `${fmt(state.catalog.points.length)} pontos de coleta e destino`,
            build: (col) => {
                const items = [
                    item("new", "Novo ponto aqui", {
                        description: "Começa na sua posição; a região sai dela",
                        onSelect: async () => {
                            const position = await post("editor:position")
                            const value = position && position.x !== undefined ? position : null
                            col.openKey = "new"
                            openColumn(state.columns.indexOf(col) + 1, pointColumn({ id: null, region: guessRegion(value), value, enabled: true }, true))
                        },
                    }),
                    section("regions", "Regiões"),
                ]
                state.catalog.regions.forEach((region) => {
                    const list = state.catalog.points.filter((p) => p.region === region.key)
                    const off = list.filter((p) => !p.enabled).length
                    items.push(sub(`r-${region.key}`, region.label, () => regionColumn(region), {
                        value: fmt(list.length),
                        description: off ? `${off} inativo(s)` : "Todos ativos",
                        valueTone: list.length ? undefined : "warning",
                    }))
                })
                return items
            },
        }
    }

    function regionColumn(region) {
        return {
            key: "region",
            title: region.label,
            subtitle: () => `${fmt(state.catalog.points.filter((p) => p.region === region.key).length)} pontos`,
            build: () => {
                const list = state.catalog.points.filter((p) => p.region === region.key)
                if (!list.length) return [info("none", "Nenhum ponto", { description: "Crie em Pontos → Novo ponto aqui." })]
                return list.map((p) => sub(`p-${p.id}`, `Ponto #${p.id}`, () => pointColumn({ id: p.id, region: p.region, value: { x: p.x, y: p.y, z: p.z, w: p.w }, enabled: p.enabled }, false), {
                    description: coords(p),
                    value: p.enabled ? "" : "Inativo",
                    valueTone: p.enabled ? undefined : "danger",
                }))
            },
        }
    }

    function pointColumn(draft, isNew) {
        const regions = state.catalog.regions
        return {
            key: "point",
            title: isNew ? "Novo ponto" : `Ponto #${draft.id}`,
            subtitle: isNew ? "Ainda não salvo" : regionLabel(draft.region),
            pointDraft: Object.assign(draft, { kind: "point" }),
            dirty: isNew,
            build: (col) => {
                const items = []
                if (draft.id) items.push(item("goto", "Ir até o ponto", { description: "Teleporta para onde o passageiro espera", onSelect: () => teleport(col, { kind: "point", id: draft.id }) }))
                items.push(
                    item("where", "Onde o passageiro espera", {
                        description: draft.value ? coords(draft.value) : "Fique na calçada, virado para a rua, e aperte E",
                        value: draft.value ? "Marcado" : "Falta",
                        valueTone: draft.value ? "success" : "danger",
                        onSelect: () => startMode("point", (value) => { draft.value = value; markDirty(col) }),
                    }),
                    item("region", "Região", {
                        description: "A SUV recebe mais chamadas em Sandy Shores e Paleto Bay",
                        value: regionLabel(draft.region),
                        onSelect: () => {
                            const index = regions.findIndex((r) => r.key === draft.region)
                            draft.region = regions[(index + 1) % regions.length].key
                            markDirty(col)
                        },
                    }),
                    toggle(col, "enabled", "Ativo", draft, "enabled", { description: "Ponto inativo sai do sorteio das corridas" }),
                    item("save", "Salvar ponto", {
                        tone: "success",
                        onSelect: () => {
                            if (!draft.value) { col.notice = { tone: "danger", text: ERROR_TEXT.invalid_point }; render(); return }
                            save(col, "savePoint", [draft.id || null, Object.assign({ region: draft.region, enabled: draft.enabled }, draft.value)], (response) => {
                                draft.id = response.id
                                isNew = false
                                col.title = `Ponto #${draft.id}`
                                col.subtitle = regionLabel(draft.region)
                            })
                        },
                    }),
                )
                if (draft.id) {
                    items.push(item("delete", "Apagar ponto", {
                        tone: "danger",
                        onSelect: () => confirmDialog({
                            title: "Apagar ponto",
                            object: `Ponto #${draft.id} · ${regionLabel(draft.region)}`,
                            body: "O ponto sai do sorteio das corridas. Para tirar só por um tempo, desative.",
                            confirm: "Apagar",
                            danger: true,
                            onConfirm: async () => {
                                const response = await request("deletePoint", draft.id)
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

    // ───────────── carros ─────────────

    function vehiclesColumn() {
        return {
            key: "vehicles",
            title: "Carros",
            subtitle: () => `${fmt(state.catalog.vehicles.length)} na central, na ordem da tela`,
            build: (col) => {
                const items = [item("new", "Novo carro", {
                    onSelect: () => {
                        col.openKey = "new"
                        openColumn(state.columns.indexOf(col) + 1, vehicleColumn({
                            id: "", model: "", label: "", class: "standard", requiredLevel: 1, rentalFee: 0, image: "", description: "", enabled: true, appearance: null,
                        }, true))
                    },
                })]
                state.catalog.vehicles.forEach((v) => {
                    items.push(sub(`v-${v.id}`, v.label, () => vehicleColumn(clone(v), false), {
                        description: `${v.model} · ${classLabel(v.class)}`,
                        value: v.enabled ? `Nível ${v.requiredLevel}` : "Inativo",
                        valueTone: v.enabled ? undefined : "danger",
                    }))
                })
                return items
            },
        }
    }

    // Resumo do visual salvo no carro (appearance).
    function appearanceText(appearance) {
        if (!appearance) return "De fábrica (o jogo sorteia cor e extras)"
        const parts = []
        if (appearance.props) parts.push("copiado de um carro")
        if (appearance.color !== undefined) parts.push(`cor ${appearance.color}`)
        if (appearance.mods) parts.push(`${Object.keys(appearance.mods).length} peça(s)`)
        if (appearance.livery !== undefined) parts.push(`livery ${appearance.livery}`)
        if (appearance.extras) parts.push(`extras ${appearance.extras.join(", ")}`)
        return parts.length ? parts.join(" · ") : "De fábrica"
    }

    function vehicleColumn(draft, isNew) {
        const classes = state.catalog.classes.map((c) => c.key)
        const payload = () => ({
            id: String(draft.id || "").toLowerCase(), model: String(draft.model || "").toLowerCase(), label: draft.label, class: draft.class,
            requiredLevel: num(draft.requiredLevel), rentalFee: num(draft.rentalFee), image: draft.image || "", description: draft.description || "",
            enabled: draft.enabled, appearance: draft.appearance || null,
        })
        return {
            key: "vehicle",
            title: isNew ? "Novo carro" : draft.label,
            subtitle: isNew ? "Ainda não salvo" : `${draft.id} · ${draft.model}`,
            dirty: isNew,
            build: (col) => {
                const items = []
                if (isNew) items.push(field(col, "id", "Chave (única)", draft, "id", { placeholder: "Ex.: economy", maxLength: 24, description: "Fica no aluguel dos jogadores; não muda depois" }))
                items.push(
                    field(col, "model", "Modelo (spawn name)", draft, "model", { placeholder: "Ex.: taxi", maxLength: 32 }),
                    item("check", "Conferir modelo no jogo", {
                        description: "Confirma que existe no build antes de salvar",
                        onSelect: async () => {
                            const response = await post("editor:checkModel", { model: String(draft.model || "").toLowerCase() })
                            col.notice = response && response.ok
                                ? { tone: "success", text: `Modelo existe. ${response.seats} assentos de passageiro.` }
                                : { tone: "danger", text: "Esse modelo não existe neste build. Não use: veículo ausente derruba o cliente." }
                            render()
                        },
                    }),
                    field(col, "label", "Nome na central", draft, "label", { placeholder: "Ex.: Táxi Standard", maxLength: 32 }),
                    item("class", "Tipo de passageiro", {
                        description: "Muda gorjeta, exigência de clima, grupos e região das chamadas",
                        value: classLabel(draft.class),
                        onSelect: () => {
                            draft.class = classes[(classes.indexOf(draft.class) + 1) % classes.length]
                            markDirty(col)
                        },
                    }),
                    field(col, "level", "Nível mínimo", draft, "requiredLevel", { number: true }),
                    field(col, "fee", "Taxa de aluguel ($)", draft, "rentalFee", { number: true, description: "0 = sem taxa" }),
                    field(col, "description", "Descrição na central", draft, "description", { maxLength: 160 }),
                    field(col, "image", "Imagem", draft, "image", { placeholder: "img/vehicles/taxi-fixed.png", maxLength: 96, description: "Caminho dentro de html/" }),
                    section("look", "Visual"),
                    info("appearance", "Visual do aluguel", { description: appearanceText(draft.appearance) }),
                    item("copy", "Copiar do carro em que estou", {
                        description: "Monte no qbx_customs e copie: pintura, peças, rodas e extras",
                        onSelect: async () => {
                            const response = await post("editor:copyVisual", { model: String(draft.model || "").toLowerCase() })
                            if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render(); return }
                            draft.appearance = { props: response.props }
                            markDirty(col)
                            col.notice = { tone: "success", text: "Visual copiado. Salve o carro para valer no aluguel." }
                            render()
                        },
                    }),
                    item("reset", "Voltar ao de fábrica", {
                        disabled: !draft.appearance,
                        onSelect: () => { draft.appearance = null; markDirty(col) },
                    }),
                    section("state", "Central"),
                    toggle(col, "enabled", "Ativo", draft, "enabled", { description: "Inativo aparece como indisponível" }),
                )
                if (!isNew) {
                    items.push(
                        item("up", "Subir na lista", { onSelect: () => move(col, draft, -1) }),
                        item("down", "Descer na lista", { onSelect: () => move(col, draft, 1) }),
                    )
                }
                items.push(item("save", "Salvar carro", {
                    tone: "success",
                    onSelect: () => save(col, "saveVehicle", [isNew, payload()], () => {
                        isNew = false
                        col.title = draft.label
                        col.subtitle = `${draft.id} · ${draft.model}`
                    }),
                }))
                if (!isNew) {
                    items.push(item("delete", "Apagar carro", {
                        tone: "danger",
                        onSelect: () => confirmDialog({
                            title: "Apagar carro",
                            object: `${draft.label} · ${draft.model}`,
                            body: "O carro sai da central. Quem estiver com ele alugado termina o turno normalmente.",
                            confirm: "Apagar",
                            danger: true,
                            onConfirm: async () => {
                                const response = await request("deleteVehicle", draft.id)
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

    async function move(col, draft, delta) {
        const response = await request("moveVehicle", draft.id, delta)
        if (!response || !response.ok) { col.notice = { tone: "danger", text: errorText(response) }; render(); return }
        state.catalog = response.catalog
        col.notice = { tone: "success", text: delta < 0 ? "Subiu na lista." : "Desceu na lista." }
        render()
    }

    // ───────────── níveis ─────────────

    function levelsColumn() {
        const draft = clone(state.catalog.levels)
        return {
            key: "levels",
            title: "Níveis",
            subtitle: "Confiança acumulada de cada nível",
            build: (col) => {
                const items = [
                    item("save", "Salvar níveis", {
                        tone: "success",
                        onSelect: () => save(col, "saveLevels", [draft.map((l) => ({ min: num(l.min), label: l.label }))], () => {
                            draft.splice(0, draft.length, ...clone(state.catalog.levels))
                        }),
                    }),
                    item("add", "Adicionar nível", {
                        onSelect: () => {
                            const last = draft[draft.length - 1]
                            draft.push({ level: draft.length + 1, min: (num(last.min) || 0) + 5000, label: "Novo nível" })
                            markDirty(col)
                        },
                    }),
                ]
                draft.forEach((level, index) => {
                    const previous = index > 0 ? num(draft[index - 1].min) : 0
                    items.push(sub(`l-${index}`, `Nível ${index + 1} · ${level.label}`, () => levelColumn(draft, index, col), {
                        value: fmt(num(level.min)),
                        description: index ? `+${fmt(num(level.min) - previous)} desde o nível ${index}` : "Começo da carreira",
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
            subtitle: level.label,
            build: (col) => {
                const items = [field(col, "label", "Nome", level, "label", { maxLength: 32, dirtyCol: levelsCol })]
                if (index === 0) items.push(info("min", "Confiança", { value: "0", description: "O nível 1 sempre começa em 0" }))
                else items.push(field(col, "min", "Confiança acumulada", level, "min", { number: true, dirtyCol: levelsCol }))
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

    // ───────────── Central ─────────────

    function depotColumn() {
        const draft = clone(state.catalog.depot)
        const payload = () => ({
            ped: draft.ped, pedModel: String(draft.pedModel || "").toLowerCase(),
            interactDistance: num(draft.interactDistance), returnRadius: num(draft.returnRadius), spawnPoints: draft.spawnPoints,
            blip: { sprite: num(draft.blip.sprite), color: num(draft.blip.color), scale: num(draft.blip.scale), label: draft.blip.label },
        })
        return {
            key: "depot",
            title: "Central",
            subtitle: "Onde o turno começa e termina",
            build: (col) => [
                item("ped", "Atendente", {
                    description: coords(draft.ped),
                    value: "Posicionar",
                    onSelect: () => startMode("depotPed", (value) => { draft.ped = value; markDirty(col) }, { model: draft.pedModel, current: draft.ped }),
                }),
                field(col, "pedModel", "Modelo do atendente", draft, "pedModel", { maxLength: 32 }),
                field(col, "interact", "Distância para abrir a central (m)", draft, "interactDistance", { number: true }),
                field(col, "return", "Raio da devolução do táxi (m)", draft, "returnRadius", { number: true }),
                sub("spawns", "Vagas do táxi", () => spawnsColumn(draft, col), { value: fmt(draft.spawnPoints.length), description: "Onde o carro alugado nasce" }),
                section("blip", "Blip"),
                field(col, "blipLabel", "Nome do blip", draft.blip, "label", { maxLength: 48 }),
                field(col, "blipSprite", "Ícone (sprite)", draft.blip, "sprite", { number: true }),
                field(col, "blipColor", "Cor", draft.blip, "color", { number: true }),
                field(col, "blipScale", "Tamanho", draft.blip, "scale", { number: true }),
                item("goto", "Ir até a Central", { onSelect: () => teleport(col, { kind: "depot" }) }),
                item("save", "Salvar Central", { tone: "success", onSelect: () => save(col, "saveDepot", [payload()]) }),
            ],
        }
    }

    function spawnsColumn(depot, depotCol) {
        return {
            key: "spawns",
            title: "Vagas do táxi",
            subtitle: () => `${fmt(depot.spawnPoints.length)} vagas · a primeira livre é usada`,
            build: (col) => {
                const items = [item("add", "Adicionar vaga", {
                    description: "Posicione um táxi de teste pela mira",
                    disabled: depot.spawnPoints.length >= 12,
                    onSelect: () => startMode("depotSpawn", (value) => { depot.spawnPoints.push(value); markDirty(depotCol) }, { model: "taxi" }),
                })]
                depot.spawnPoints.forEach((spawn, index) => {
                    items.push(item(`s-${index}`, `Vaga ${index + 1}`, {
                        description: coords(spawn),
                        onSelect: () => actionsDialog(`Vaga ${index + 1}`, coords(spawn), [
                            { label: "Reposicionar", run: () => startMode("depotSpawn", (value) => { depot.spawnPoints[index] = value; markDirty(depotCol) }, { model: "taxi", current: spawn }) },
                            { label: "Ir até a vaga", run: () => teleport(col, { kind: "free", point: spawn }) },
                            { label: "Remover", danger: true, run: () => {
                                if (depot.spawnPoints.length <= 1) { col.notice = { tone: "danger", text: ERROR_TEXT.invalid_spawns }; return }
                                depot.spawnPoints.splice(index, 1)
                                markDirty(depotCol)
                            } },
                        ]),
                    }))
                })
                items.push(info("hint", "Salve na coluna Central", { description: "As vagas entram junto com o resto da Central" }))
                return items
            },
        }
    }

    // ───────────── ajustes ─────────────

    function settingsColumn() {
        const draft = clone(state.catalog.settings)
        const numeric = (group) => Object.fromEntries(Object.entries(draft[group]).map(([k, v]) => [k, num(v)]))
        const payload = () => ({ meter: numeric("meter"), dispatch: numeric("dispatch"), payout: numeric("payout") })
        const group = (key, title, subtitle, fields) => ({ key, title, subtitle, build: (col) => fields(col) })
        return {
            key: "settings",
            title: "Ajustes",
            subtitle: "Valem para todos os carros",
            build: (col) => {
                const leaf = (key, title, subtitle, fields) => sub(key, title, () => group(key, title, subtitle, (inner) => fields(inner, col)), { description: subtitle })
                return [
                    item("save", "Salvar ajustes", { tone: "success", onSelect: () => save(col, "saveSettings", [payload()]) }),
                    leaf("meter", "Taxímetro", "Bandeirada, preço por km e teto", (inner, parent) => [
                        field(inner, "start", "Bandeirada ($)", draft.meter, "StartingFare", { number: true, dirtyCol: parent }),
                        field(inner, "km", "Preço por km ($)", draft.meter, "PricePerKm", { number: true, dirtyCol: parent }),
                        field(inner, "max", "Tarifa máxima ($)", draft.meter, "MaxFare", { number: true, dirtyCol: parent }),
                    ]),
                    leaf("dispatch", "Chamadas", "Tempo, intervalo e distâncias", (inner, parent) => [
                        field(inner, "offer", "Tempo para aceitar (ms)", draft.dispatch, "OfferTimeout", { number: true, dirtyCol: parent }),
                        field(inner, "minDelay", "Intervalo mínimo entre chamadas (ms)", draft.dispatch, "MinDelay", { number: true, dirtyCol: parent }),
                        field(inner, "maxDelay", "Intervalo máximo entre chamadas (ms)", draft.dispatch, "MaxDelay", { number: true, dirtyCol: parent }),
                        field(inner, "minPick", "Coleta: distância mínima (m)", draft.dispatch, "MinPickupDistance", { number: true, dirtyCol: parent }),
                        field(inner, "idealPick", "Coleta: distância ideal (m)", draft.dispatch, "IdealPickupDistance", { number: true, dirtyCol: parent }),
                        field(inner, "maxPick", "Coleta: distância máxima (m)", draft.dispatch, "MaxPickupDistance", { number: true, dirtyCol: parent }),
                        field(inner, "minTrip", "Corrida: distância mínima (m)", draft.dispatch, "MinTripDistance", { number: true, dirtyCol: parent }),
                        field(inner, "maxTrip", "Corrida: distância máxima (m)", draft.dispatch, "MaxTripDistance", { number: true, dirtyCol: parent, description: "O tipo de carro pode ter a própria faixa" }),
                    ]),
                    leaf("payout", "Pagamento", "Gorjeta, humor e bônus de calma", (inner, parent) => [
                        field(inner, "tip", "Gorjeta do satisfeito (%)", draft.payout, "SatisfiedTipPercent", { number: true, dirtyCol: parent, description: "O tipo de carro pode ter a própria gorjeta" }),
                        field(inner, "neutral", "Multiplicador do neutro", draft.payout, "NeutralMultiplier", { number: true, dirtyCol: parent }),
                        field(inner, "unhappy", "Multiplicador do insatisfeito", draft.payout, "UnhappyMultiplier", { number: true, dirtyCol: parent }),
                        field(inner, "calm", "Bônus de calma (%)", draft.payout, "CalmBonusPercent", { number: true, dirtyCol: parent }),
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
    document.addEventListener("taximap:visible", (event) => {
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

})()
