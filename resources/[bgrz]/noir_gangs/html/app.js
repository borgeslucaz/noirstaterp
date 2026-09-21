/* Noir Gangs — apresentação pura.
 *
 * A página recebe o snapshot inteiro (`gang:open`) e devolve intenção: quem promover, quem
 * desligar, convidar, sair. Ela esconde o que a pessoa não pode fazer, mas isso é cortesia —
 * quem decide é o servidor, que valida tudo de novo e responde com um código estável. A
 * tradução desses códigos mora aqui, e só aqui.
 *
 * Depois de qualquer ação o servidor devolve o snapshot novo junto com a resposta: a lista
 * nunca fica mostrando o mundo de antes da ação que a pessoa acabou de tomar. */
(function () {
    "use strict"

    const resource = typeof GetParentResourceName === "function" ? GetParentResourceName() : "noir_gangs"
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
    const show = (node, visible) => { node.hidden = !visible }

    // ───────────── formatação (pt-BR) ─────────────

    const int = (v) => Math.floor(Number(v) || 0).toLocaleString("pt-BR")
    const signed = (v) => (Number(v) > 0 ? "+" : "") + int(v)

    /// Nome de bairro e de gang chegam em minúsculo com underline.
    const pretty = (name) => String(name || "").replace(/_/g, " ").toUpperCase()

    const pad = (n) => String(n).padStart(2, "0")
    const stamp = (seconds) => {
        const n = Number(seconds)
        if (!n) return "—"
        const d = new Date(n * 1000)
        return pad(d.getDate()) + "/" + pad(d.getMonth() + 1) + "/" + d.getFullYear() + " " + pad(d.getHours()) + ":" + pad(d.getMinutes())
    }

    // ───────────── textos ─────────────

    const ERROR_TEXT = {
        no_gang: "Você não está mais em uma gang.",
        no_permission: "Seu cargo não permite essa ação.",
        self_action: "Você não pode fazer isso consigo mesmo.",
        invalid_member: "Essa pessoa não está mais na gang.",
        invalid_action: "Ação desconhecida.",
        boss_protected: "O chefe não pode ser desligado nem mudar de cargo.",
        boss_not_promotable: "Ninguém é promovido a chefe por aqui. Isso é com a administração.",
        no_rank_available: "Não existe cargo para onde mover essa pessoa.",
        same_rank: "Essa pessoa já está nesse cargo.",
        no_one_near: "Ninguém por perto para convidar.",
        invalid_target: "Ninguém por perto para convidar.",
        already_in_gang: "Essa pessoa já pertence a uma gang.",
        cooldown: "Aguarde um pouco antes de enviar outro convite.",
        pending_invite: "Essa pessoa já tem um convite pendente.",
        busy: "Aguarde a ação anterior terminar.",
        not_open: "A gestão foi fechada.",
        failed: "Não foi possível concluir. Tente de novo.",
        // editor de cargos
        own_rank: "Você não edita o próprio cargo.",
        rank_not_found: "Esse cargo não existe mais.",
        rank_limit: "A gang chegou ao limite de cargos.",
        last_rank: "A gang precisa de pelo menos um cargo além do chefe.",
        invalid_label: "O nome do cargo não pode ficar em branco.",
        invalid_permission: "Permissão desconhecida.",
        no_boss: "A gang não tem cargo de chefe. Isso é com a administração.",
        not_ready: "O sistema de gangs não subiu neste servidor. Avise a administração.",
    }

    /// `boss_protected` chega das duas telas e quer dizer coisas diferentes em cada uma:
    /// numa é a pessoa do chefe, na outra é o cargo. O código é o mesmo, a frase não.
    const ERROR_IN_RANKS = {
        boss_protected: "O cargo de chefe não é editável.",
        no_permission: "Seu cargo não gere os cargos da gang.",
    }

    const errorText = (code, context) =>
        (context === "ranks" && ERROR_IN_RANKS[code]) || ERROR_TEXT[code] || ERROR_TEXT.failed

    /// O que cada permissão do catálogo quer dizer, em português. O servidor manda os ids;
    /// as frases moram aqui, como todo texto da tela. Um teste exige uma entrada por
    /// permissão do catálogo — permissão sem frase apareceria como o id cru.
    const PERMISSION_TEXT = {
        view_members: ["Ver membros", "A lista de quem está na gang"],
        view_offline_members: ["Ver quem está ausente", "Mostra também quem não está acordado"],
        invite: ["Convidar", "Chamar alguém que esteja ao lado"],
        remove_member: ["Desligar", "Tirar alguém da gang"],
        promote: ["Promover", "Subir alguém para o cargo seguinte"],
        demote: ["Rebaixar", "Descer alguém para o cargo anterior"],
        view_reputation: ["Ver reputação", "O placar da gang"],
        view_products: ["Ver operação", "O que a gang movimenta"],
        manage_ranks: ["Gerir cargos", "Criar, renomear e definir o que cada cargo pode"],
    }

    const ACTIVITY_TITLE = {
        invitation_sent: "Convite enviado",
        invitation_declined: "Convite recusado",
        member_joined: "Entrada na gang",
        member_promoted: "Promoção",
        member_demoted: "Rebaixamento",
        member_removed: "Desligamento",
        member_left: "Saída da gang",
        reputation_changed: "Reputação ajustada",
        management_point_created: "Ponto de gestão criado",
        management_point_moved: "Ponto de gestão movido",
        management_point_deleted: "Ponto de gestão removido",
        rank_created: "Cargo criado",
        rank_updated: "Cargo alterado",
        rank_deleted: "Cargo excluído",
    }

    const SOMEONE = "alguém"

    function activityDetail(entry) {
        const actor = entry.actorName || SOMEONE
        const target = entry.targetName || SOMEONE
        const meta = entry.meta || {}

        switch (entry.action) {
            case "invitation_sent": return actor + " convidou " + target
            case "invitation_declined": return target + " recusou o convite de " + actor
            case "member_joined": return target + " entrou, a convite de " + actor
            case "member_promoted": return actor + " promoveu " + target
            case "member_demoted": return actor + " rebaixou " + target
            case "member_removed": return actor + " desligou " + target
            case "member_left": return actor + " saiu por conta própria"
            case "rank_created":
            case "rank_updated":
            case "rank_deleted": return meta.label ? actor + " · " + meta.label : "Por " + actor
            case "reputation_changed": {
                const base = actor + " ajustou em " + signed(meta.delta) + ", total de " + int(meta.total)
                const reason = String(meta.reason || "").trim()
                return reason ? base + " · " + reason : base
            }
            default: return "Por " + actor
        }
    }

    // ───────────── ícones ─────────────

    const svg = (paths, extraClass) =>
        '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"' +
        (extraClass ? ' class="' + extraClass + '"' : "") + ">" + paths + "</svg>"

    const ICON = {
        crown: '<path d="m2 4 3 12h14l3-12-6 7-4-7-4 7-6-7z"/><path d="M5 20h14"/>',
        up: '<path d="m18 15-6-6-6 6"/>',
        down: '<path d="m6 9 6 6 6-6"/>',
        remove: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 11h-6"/>',
        lock: '<rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
        pin: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
        move: '<path d="M5 9 2 12l3 3"/><path d="m9 5 3-3 3 3"/><path d="m15 19-3 3-3-3"/><path d="m19 9 3 3-3 3"/><path d="M2 12h20"/><path d="M12 2v20"/>',
        trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14H6L5 6"/>',
    }

    // ───────────── elementos ─────────────

    const m = {
        root: $("gang-menu"),
        shell: $("gang-window"),
        // As duas janelas são irmãs dentro do mesmo root: mostrar uma sem esconder a outra
        // deixa a de baixo vazando atrás.
        gangWindow: $("gang-window"),
        railToggle: $("rail-toggle"),
        railGang: $("rail-gang"),
        railLeave: $("rail-leave"),
        nav: Array.prototype.slice.call(document.querySelectorAll(".nav-item")),
        main: $("wnd-main"),
        close: $("menu-close"),
        // cabeçalho
        gangLabel: $("gang-label"),
        gangContext: $("gang-context"),
        meName: $("me-name"),
        meRank: $("me-rank"),
        footerBrand: $("footer-brand"),
        // central
        statReputationCard: $("stat-reputation-card"),
        statReputation: $("stat-reputation"),
        statActive: $("stat-active"),
        statTerritory: $("stat-territory"),
        statMembers: $("stat-members"),
        operationSub: $("operation-sub"),
        operationChips: $("operation-chips"),
        ranksList: $("ranks-list"),
        overviewZones: $("overview-zones"),
        onlinePreview: $("online-preview"),
        // membros
        membersSub: $("members-sub"),
        membersSearch: $("members-search"),
        membersInvite: $("members-invite"),
        membersMessage: $("members-message"),
        membersList: $("members-list"),
        // cargos
        navRanks: $("nav-ranks"),
        ranksSub: $("ranks-sub"),
        ranksMessage: $("ranks-message"),
        rankCreate: $("rank-create"),
        rankList: $("rank-list"),
        modalRankField: $("modal-rank-field"),
        modalRank: $("modal-rank"),
        rankLocked: $("rank-locked"),
        rankLockedTitle: $("rank-locked-title"),
        rankLockedNote: $("rank-locked-note"),
        rankEditor: $("rank-editor"),
        rankLabel: $("rank-label"),
        rankLabelError: $("rank-label-error"),
        rankLabelErrorText: $("rank-label-error-text"),
        rankPerms: $("rank-perms"),
        rankBank: $("rank-bank"),
        rankDelete: $("rank-delete"),
        rankSave: $("rank-save"),
        // território
        territoryMap: $("territory-map"),
        territoryCount: $("territory-count"),
        territoryHint: $("territory-hint"),
        territoryEmpty: $("territory-empty"),
        zoneList: $("zone-list"),
        legend: $("territory-legend"),
        // atividade
        history: $("history-list"),
        // modal
        modal: $("gang-modal"),
        modalTitle: $("modal-title"),
        modalText: $("modal-text"),
        modalCancel: $("modal-cancel"),
        modalConfirm: $("modal-confirm"),
        modalField: $("modal-field"),
        modalInput: $("modal-input"),
    }

    const state = {
        open: false,
        busy: false,
        data: null,
        tab: "overview",
        railOpen: false,
        search: "",
        selectedRank: null,
        timers: [],
    }
    let modalReturnFocus = null
    let pendingAction = null

    const later = (fn, ms) => {
        const id = setTimeout(fn, reducedMotion ? 0 : ms)
        state.timers.push(id)
        return id
    }
    const clearTimers = () => {
        state.timers.forEach(clearTimeout)
        state.timers = []
    }

    function message(node, text, kind) {
        node.textContent = text
        node.dataset.kind = kind || "error"
        show(node, true)
    }

    function hideMessage(node) {
        node.textContent = ""
        show(node, false)
    }

    function emptyState(title, note) {
        const box = document.createElement("div")
        box.className = "empty"
        const t = document.createElement("p")
        t.className = "empty__title"
        t.textContent = title
        box.appendChild(t)
        if (note) {
            const n = document.createElement("p")
            n.className = "empty__note"
            n.textContent = note
            box.appendChild(n)
        }
        return box
    }

    // ═══════════════════════════════ Cabeçalho ═══════════════════════════════

    function me() {
        const data = state.data
        if (!data || !data.actorCitizenId) return null
        return (data.members || []).find((x) => x.citizenid === data.actorCitizenId) || null
    }

    function renderHeader() {
        const data = state.data
        const gang = (data && data.gang) || {}
        const label = gang.label || pretty(gang.name)

        m.gangLabel.textContent = label
        m.railGang.textContent = String(label).toUpperCase()
        m.footerBrand.textContent = "NOIR STATE · " + String(label).toUpperCase()

        const rank = data.rankLabel || gang.gradeName || "—"
        m.gangContext.textContent = "SEU CARGO · " + String(rank).toUpperCase()

        const mine = me()
        m.meName.textContent = mine ? mine.name : "—"
        m.meRank.textContent = String(rank).toUpperCase()
    }

    // ═══════════════════════════════ Central ═══════════════════════════════

    function renderOverview() {
        const data = state.data
        const members = data.members || []
        const online = members.filter((x) => x.online)

        m.statMembers.textContent = int(data.memberCount || members.length)
        m.statActive.textContent = int(data.onlineCount || online.length)

        // Reputação é leitura, e só para quem tem a permissão. Quem não tem não vê o número
        // em branco: não vê o cartão. A linha se fecha com três, porque as colunas nascem do
        // número de cartões visíveis.
        const hasReputation = typeof data.reputation === "number"
        show(m.statReputationCard, hasReputation)
        if (hasReputation) m.statReputation.textContent = int(data.reputation)

        // Operação
        m.operationChips.replaceChildren()
        if (!data.permissions.view_products) {
            m.operationSub.textContent = "Seu cargo não acompanha a operação."
            m.operationChips.appendChild(chip("SEM ACESSO", true))
        } else if (!data.products || data.products.length === 0) {
            m.operationSub.textContent = "Nada definido para esta gang."
            m.operationChips.appendChild(chip("SEM PRODUTO", true))
        } else {
            m.operationSub.textContent = "O que a gang movimenta."
            data.products.forEach((p) => m.operationChips.appendChild(chip(p.label)))
        }

        // Cargos
        const myGrade = data.gang ? Number(data.gang.grade) : null
        m.ranksList.replaceChildren()
        const ranks = data.ranks || []
        if (ranks.length === 0) {
            m.ranksList.appendChild(emptyState("Nenhum cargo definido"))
        } else {
            ranks.forEach((rank) => {
                const row = document.createElement("li")
                row.className = "rank-row"
                row.dataset.boss = String(rank.isBoss === true)
                row.dataset.mine = String(rank.level === myGrade)

                const name = document.createElement("span")
                name.className = "rank-row__name"
                if (rank.isBoss) name.innerHTML = svg(ICON.crown, "boss-mark")
                const text = document.createElement("span")
                text.textContent = rank.label
                name.appendChild(text)

                const count = document.createElement("span")
                count.className = "rank-row__count"
                count.textContent = rank.count === 1 ? "1 pessoa" : int(rank.count) + " pessoas"

                row.append(name, count)
                m.ranksList.appendChild(row)
            })
        }

        // Bairros: a prévia da Central mostra no máximo três; o mapa inteiro é a aba
        // Território.
        const owned = ownedZones()
        m.overviewZones.replaceChildren()
        if (!data.territory) {
            m.overviewZones.appendChild(emptyState("Mapa indisponível"))
        } else if (owned.length === 0) {
            m.overviewZones.appendChild(emptyState("Nenhum bairro dominado", "Marque as ruas para tomar um."))
        } else {
            owned.slice(0, 3).forEach((zone) => {
                const row = document.createElement("li")
                const flag = document.createElement("span")
                flag.className = "mini-list__flag"
                if (zone.color) flag.style.background = zone.color
                const name = document.createElement("span")
                name.textContent = pretty(zone.name)
                row.append(flag, name)
                m.overviewZones.appendChild(row)
            })
        }

        // Prévia: no máximo três. A lista completa é a aba Membros.
        m.onlinePreview.replaceChildren()
        if (online.length === 0) {
            m.onlinePreview.appendChild(emptyState("Ninguém acordado", "Quando alguém entrar, aparece aqui."))
        } else {
            online.slice(0, 3).forEach((member) => {
                const card = document.createElement("div")
                card.className = "preview__card"
                const name = document.createElement("span")
                name.className = "preview__name"
                name.textContent = member.name
                const rank = document.createElement("span")
                rank.className = "preview__rank"
                rank.textContent = member.gradeName
                card.append(name, rank)
                m.onlinePreview.appendChild(card)
            })
        }
    }

    function chip(label, muted) {
        const node = document.createElement("span")
        node.className = muted ? "chip chip--empty" : "chip"
        node.textContent = label
        return node
    }

    // ═══════════════════════════════ Membros ═══════════════════════════════

    function actionButton(label, icon, danger, onClick) {
        const btn = document.createElement("button")
        btn.type = "button"
        btn.className = danger ? "action action--danger" : "action"
        btn.innerHTML = svg(icon)
        const text = document.createElement("span")
        text.textContent = label
        btn.appendChild(text)
        btn.addEventListener("click", onClick)
        return btn
    }

    function renderMembers() {
        const data = state.data
        const all = data.members || []
        const term = state.search.trim().toLowerCase()
        const list = term ? all.filter((x) => x.name.toLowerCase().includes(term)) : all

        m.membersSub.textContent = data.permissions.view_offline_members
            ? int(data.memberCount || all.length) + " no total, " + int(data.onlineCount || 0) + " acordados agora."
            : "Seu cargo vê quem está acordado agora."

        show(m.membersInvite, data.permissions.invite === true)

        m.membersList.replaceChildren()
        if (list.length === 0) {
            m.membersList.appendChild(
                term
                    ? emptyState("Nenhum membro com esse nome", "Tente outro trecho do nome.")
                    : emptyState("Nenhum membro visível", "Ninguém da gang está acordado agora.")
            )
            return
        }

        list.forEach((member) => {
            const row = document.createElement("div")
            row.className = "member-row"
            row.setAttribute("role", "row")
            row.dataset.online = String(member.online === true)
            row.dataset.me = String(member.citizenid === data.actorCitizenId)

            const name = document.createElement("span")
            name.className = "member-row__name"
            if (member.isBoss) name.innerHTML = svg(ICON.crown, "boss-mark")
            const nameText = document.createElement("span")
            nameText.textContent = member.name
            nameText.title = member.name
            name.appendChild(nameText)

            const rank = document.createElement("span")
            rank.className = "member-row__rank"
            rank.textContent = member.gradeName

            const status = document.createElement("span")
            status.className = "member-row__status"
            const dot = document.createElement("span")
            dot.className = "status-dot"
            const statusText = document.createElement("span")
            statusText.textContent = member.online ? "ACORDADO" : "AUSENTE"
            status.append(dot, statusText)

            const actions = document.createElement("span")
            actions.className = "member-row__actions"
            fillActions(actions, member)

            row.append(name, rank, status, actions)
            m.membersList.appendChild(row)
        })
    }

    /// O chefe não é desligado nem muda de cargo, e ninguém é promovido até ele. A tela nem
    /// oferece a ação: um botão que o servidor vai recusar é uma promessa falsa.
    function fillActions(container, member) {
        const data = state.data
        const permissions = data.permissions || {}

        if (member.citizenid === data.actorCitizenId) {
            container.appendChild(lockedNote("VOCÊ"))
            return
        }
        if (member.isBoss) {
            container.appendChild(lockedNote("CHEFE"))
            return
        }

        let added = 0
        // Um botão só. Antes eram dois -- promover e rebaixar -- e cada um movia UM degrau,
        // o que deixou de querer dizer alguma coisa quando a escada deixou de ser contígua:
        // com um cargo no meio, "promover" podia significar mandar alguém para um cargo que
        // ninguém queria. Agora quem manda escolhe o destino, e o servidor decide qual
        // permissão exigir pela direção.
        if (permissions.changeGrade && member.canChangeGrade) {
            container.appendChild(actionButton("ALTERAR CARGO", ICON.up, false, () => askAction(member, "setGrade")))
            added++
        }
        if (permissions.remove_member) {
            container.appendChild(actionButton("DESLIGAR", ICON.remove, true, () => askAction(member, "remove")))
            added++
        }
        if (added === 0) container.appendChild(lockedNote("SEM AÇÃO"))
    }

    function lockedNote(label) {
        const node = document.createElement("span")
        node.className = "member-row__locked"
        node.innerHTML = svg(ICON.lock)
        const text = document.createElement("span")
        text.textContent = label
        node.appendChild(text)
        return node
    }

    // ═══════════════════════════════ Cargos ═══════════════════════════════

    const canManageRanks = () => !!(state.data && state.data.permissions && state.data.permissions.manage_ranks)
    const rankList = () => (state.data && state.data.ranks) || []
    const rankByLevel = (level) => rankList().find((r) => r.level === level) || null
    const myLevel = () => (state.data && state.data.gang ? Number(state.data.gang.grade) : null)

    /// O chefe e o cargo de quem está olhando não são editáveis — o primeiro porque é o que
    /// torna a chefia intocável, o segundo porque editar o próprio cargo seria marcar todas
    /// as permissões para si mesmo. A tela diz qual dos dois é, em vez de só não abrir.
    function rankLock(rank) {
        if (rank.isBoss) return ["O cargo de chefe não é editável", "É ele que torna a chefia intocável. Trocar quem lidera é com a administração."]
        if (rank.level === myLevel()) return ["Este é o seu cargo", "Ninguém edita o próprio cargo. Peça a quem também gere os cargos."]
        return null
    }

    function renderRankList() {
        const ranks = rankList()
        const limits = (state.data && state.data.rankLimits) || { max: 0 }

        m.ranksSub.textContent = ranks.length === 1
            ? "1 cargo. O nome e o que ele pode são definidos aqui."
            : int(ranks.length) + " cargos, do topo para a base. Cargo novo nasce logo abaixo do chefe."

        m.rankCreate.disabled = ranks.length >= limits.max
        m.rankCreate.title = ranks.length >= limits.max
            ? "A gang chegou ao limite de " + int(limits.max) + " cargos"
            : ""

        m.rankList.replaceChildren()
        ranks.forEach((rank) => {
            const locked = rankLock(rank)
            const option = document.createElement("button")
            option.type = "button"
            option.className = "rank-option"
            option.setAttribute("role", "option")
            option.dataset.level = String(rank.level)
            option.dataset.locked = String(!!locked)
            option.setAttribute("aria-selected", String(state.selectedRank === rank.level))

            const name = document.createElement("span")
            name.className = "rank-option__name"
            if (rank.isBoss) name.innerHTML = svg(ICON.crown, "boss-mark")
            const nameText = document.createElement("span")
            nameText.textContent = rank.label
            name.appendChild(nameText)

            const count = document.createElement("span")
            count.className = "rank-option__count"
            count.textContent = rank.count === 1 ? "1 pessoa" : int(rank.count) + " pessoas"

            const meta = document.createElement("span")
            meta.className = "rank-option__meta"
            meta.textContent = rankSummary(rank, locked)

            option.append(name, count, meta)
            option.addEventListener("click", () => selectRank(rank.level))
            m.rankList.appendChild(option)
        })
    }

    function rankSummary(rank, locked) {
        if (locked) return rank.isBoss ? "CHEFE · NÃO EDITÁVEL" : "SEU CARGO"
        const total = (rank.permissions || []).length
        const parts = [total === 1 ? "1 permissão" : int(total) + " permissões"]
        if (rank.bankAuth) parts.push("banco")
        return parts.join(" · ").toUpperCase()
    }

    function renderPermissionChoices(rank) {
        const catalog = (state.data && state.data.permissionCatalog) || []
        const granted = new Set(rank.permissions || [])
        m.rankPerms.replaceChildren()

        catalog.forEach((id) => {
            const text = PERMISSION_TEXT[id] || [id, ""]
            const label = document.createElement("label")
            label.className = "check"

            const input = document.createElement("input")
            input.type = "checkbox"
            input.value = id
            input.checked = granted.has(id)

            const box = document.createElement("span")
            box.className = "check__box"
            box.setAttribute("aria-hidden", "true")

            const copy = document.createElement("span")
            copy.className = "check__text"
            const title = document.createElement("span")
            title.className = "check__title"
            title.textContent = text[0]
            // Em tela estreita o rótulo trunca; o título devolve a frase inteira.
            title.title = text[1] ? text[0] + " — " + text[1] : text[0]
            const note = document.createElement("span")
            note.className = "check__note"
            note.textContent = text[1]
            copy.append(title, note)

            label.append(input, box, copy)
            m.rankPerms.appendChild(label)
        })
    }

    function selectRank(level) {
        state.selectedRank = level
        hideMessage(m.ranksMessage)
        showLabelError(null)
        renderRankList()
        renderRankForm()
    }

    function renderRankForm() {
        const rank = state.selectedRank != null ? rankByLevel(state.selectedRank) : null

        if (!rank) {
            m.rankLockedTitle.textContent = "Escolha um cargo"
            m.rankLockedNote.textContent = "A lista ao lado tem a escada da gang, do topo para a base."
            show(m.rankLocked, true)
            show(m.rankEditor, false)
            return
        }

        const locked = rankLock(rank)
        if (locked) {
            m.rankLockedTitle.textContent = locked[0]
            m.rankLockedNote.textContent = locked[1]
            show(m.rankLocked, true)
            show(m.rankEditor, false)
            return
        }

        show(m.rankLocked, false)
        show(m.rankEditor, true)
        m.rankLabel.value = rank.label
        m.rankLabel.maxLength = (state.data.rankLimits && state.data.rankLimits.labelMaxLength) || 32
        m.rankBank.checked = rank.bankAuth === true
        renderPermissionChoices(rank)

        // Excluir um cargo ocupado deixaria essas pessoas num nível sem cargo, então o
        // servidor recusa. A tela já diz o porquê em vez de deixar tentar.
        const occupied = rank.count > 0
        m.rankDelete.disabled = occupied
        m.rankDelete.title = occupied
            ? "Mova as " + int(rank.count) + " pessoas deste cargo antes de excluí-lo"
            : ""
    }

    function showLabelError(text) {
        m.rankLabelErrorText.textContent = text || ""
        show(m.rankLabelError, !!text)
        m.rankLabel.setAttribute("aria-invalid", String(!!text))
    }

    function collectPermissions() {
        return Array.prototype.slice
            .call(m.rankPerms.querySelectorAll("input:checked"))
            .map((input) => input.value)
    }

    function saveRank() {
        const rank = state.selectedRank != null ? rankByLevel(state.selectedRank) : null
        if (!rank || state.busy) return

        const label = m.rankLabel.value.trim()
        if (!label) return showLabelError("O nome do cargo não pode ficar em branco.")
        showLabelError(null)

        setBusy(true)
        post("updateRank", {
            level: rank.level,
            label: label,
            permissions: collectPermissions(),
            bankAuth: m.rankBank.checked,
        }).then((res) => {
            setBusy(false)
            if (!state.open) return
            if (res && res.ok) {
                if (res.data) applySnapshot(res.data)
                message(m.ranksMessage, "Cargo salvo: " + label + ".", "success")
                return
            }
            message(m.ranksMessage, errorText(res && res.code, "ranks"), "error")
            refresh()
        })
    }

    function askCreateRank() {
        if (state.busy || m.rankCreate.disabled) return
        pendingAction = { kind: "rankCreate" }
        openModal(
            "CRIAR CARGO",
            "O cargo nasce logo abaixo do chefe, sem nenhuma permissão. Você escolhe o que ele pode depois de criar.",
            null,
            null,
            "CRIAR CARGO",
            false,
            true
        )
    }

    function askDeleteRank() {
        const rank = state.selectedRank != null ? rankByLevel(state.selectedRank) : null
        if (!rank || state.busy || m.rankDelete.disabled) return
        pendingAction = { kind: "rankDelete", rank: rank }
        openModal(
            "EXCLUIR CARGO",
            "Excluir ",
            rank.label,
            ". O cargo some da escada da gang e não volta.",
            "EXCLUIR CARGO",
            true
        )
    }

    // ═══════════════════════════════ Território ═══════════════════════════════

    const NEUTRAL = "#7a7a7a"
    const FALLBACK_MAP = {
        tiles: "nui://noir_territories/web/tiles/{z}/{x}/{y}.png",
        maxZoom: 7, maxNativeZoom: 4, maxResolution: 0.25,
        centerLat: -5525, centerLng: 3755, offset: 0.66,
    }

    let map = null
    let mapLayer = null
    let mapConfig = FALLBACK_MAP
    let gtaToLatLng = null
    // O mapa só é desenhado quando a aba aparece: o Leaflet mede o contêiner na criação e,
    // nascido escondido, ele nasce com tamanho zero e enquadra tudo errado. A maioria das
    // aberturas também nunca chega nesta aba.
    let mapDirty = true

    const territoryZones = () => {
        const territory = state.data && state.data.territory
        return (territory && territory.zones) || []
    }

    /// Os bairros que a gang de quem está olhando domina de fato. Disputa não conta: bairro
    /// em disputa não é de ninguém.
    function ownedZones() {
        const mine = state.data && state.data.gang ? state.data.gang.name : null
        return territoryZones().filter((z) => z.state === "controlled" && z.gang === mine)
    }

    const hasLeaflet = () => typeof L !== "undefined"

    /// A projeção chega pronta do noir_territories, que é dono dos tiles. Se ela mudar lá, a
    /// tela muda junto — não há constante de mapa escrita aqui.
    function initMap() {
        if (map || !hasLeaflet()) return
        if (!m.territoryMap.clientHeight) return

        const minResolution = Math.pow(2, mapConfig.maxZoom) * mapConfig.maxResolution
        const crs = L.CRS.Simple
        crs.scale = (zoom) => Math.pow(2, zoom) / minResolution

        const world = Math.pow(2, mapConfig.maxZoom) * 256 / (Math.pow(2, mapConfig.maxZoom) / minResolution)
        const bounds = L.latLngBounds([[-world, 0], [0, world]])

        gtaToLatLng = (x, y) => L.latLng(y * mapConfig.offset + mapConfig.centerLat, x * mapConfig.offset + mapConfig.centerLng)

        map = L.map(m.territoryMap, {
            crs,
            center: [mapConfig.centerLat, mapConfig.centerLng],
            zoom: 3,
            minZoom: 2,
            maxZoom: mapConfig.maxZoom,
            zoomControl: false,
            attributionControl: false,
            keyboard: false,
            maxBounds: bounds,
            maxBoundsViscosity: 1.0,
            layers: [L.tileLayer(mapConfig.tiles, {
                minZoom: 0, maxZoom: mapConfig.maxZoom, maxNativeZoom: mapConfig.maxNativeZoom,
                noWrap: true, tms: true, bounds: bounds,
            })],
        })
        mapLayer = L.featureGroup().addTo(map)
    }

    /// O mapa diz de quem é o bairro, e só isso. Quantas tags faltam para virar é contagem
    /// de graffiti, e ela saiu daqui: quem picha descobre pichando.
    function zoneLabel(zone) {
        const lines = [pretty(zone.name)]
        if (zone.state === "controlled") {
            lines.push(pretty(zone.gang))
        } else if (zone.state === "contested") {
            lines.push("EM DISPUTA · " + (zone.gangs || []).map(pretty).join(" / "))
        } else {
            lines.push("SEM DONO")
        }
        return lines.join("<br>")
    }

    function drawMap(zones) {
        initMap()
        if (!map) return
        mapDirty = false
        // O contêiner pode ter mudado de tamanho desde a última vez (troca de aba, outra
        // resolução); sem isto o enquadramento sai do tamanho de antes.
        map.invalidateSize()
        mapLayer.clearLayers()

        const seen = new Map()
        zones.forEach((zone) => {
            if (!zone.points || zone.points.length < 3) return

            const owned = zone.state === "controlled"
            const disputed = zone.state === "contested"
            const color = owned || disputed ? (zone.color || NEUTRAL) : NEUTRAL
            const ring = zone.points.map((p) => gtaToLatLng(p.x, p.y))

            L.polygon(ring, {
                color,
                weight: disputed ? 3 : 2,
                opacity: 0.9,
                // Tracejado em disputa: dois donos possíveis não podem parecer um dono só.
                dashArray: disputed ? "8 6" : null,
                fillColor: color,
                fillOpacity: owned ? 0.45 : disputed ? 0.3 : 0.12,
            })
                .bindTooltip(zoneLabel(zone), { permanent: true, direction: "center", className: "zone-label" })
                .addTo(mapLayer)

            if (owned) seen.set(zone.gang, color)
            else if (disputed) (zone.gangs || []).forEach((g) => seen.set(g, color))
        })

        m.legend.replaceChildren(...Array.from(seen).map(([name, color]) => {
            const row = document.createElement("div")
            const dot = document.createElement("i")
            dot.style.background = color
            const text = document.createElement("span")
            text.textContent = pretty(name)
            row.append(dot, text)
            return row
        }))

        const bounds = mapLayer.getBounds()
        if (bounds.isValid()) map.fitBounds(bounds, { padding: [30, 30] })
    }

    /// Os bairros da gang primeiro, depois os disputados, depois o resto: a lista responde
    /// "o que é meu e o que está em jogo" antes de responder "o que existe".
    function zoneOrder(mine) {
        return (a, b) => {
            const rank = (z) => (z.state === "controlled" && z.gang === mine ? 0 : z.state === "contested" ? 1 : z.state === "controlled" ? 2 : 3)
            const diff = rank(a) - rank(b)
            return diff !== 0 ? diff : String(a.name).localeCompare(String(b.name))
        }
    }

    function renderTerritory() {
        const data = state.data
        const territory = data.territory
        const mine = data.gang ? data.gang.name : null
        const zones = (territory && territory.zones) || []

        if (territory && territory.map) mapConfig = Object.assign({}, FALLBACK_MAP, territory.map)

        if (!hasLeaflet()) {
            show(m.territoryEmpty, true)
            m.territoryEmpty.textContent = "O mapa não pôde ser carregado nesta sessão."
        } else if (!territory) {
            show(m.territoryEmpty, true)
            m.territoryEmpty.textContent = "O controle de territórios está fora do ar. Os bairros voltam quando ele subir."
        } else if (zones.length === 0) {
            show(m.territoryEmpty, true)
            m.territoryEmpty.textContent = "Nenhum bairro mapeado ainda."
        } else {
            show(m.territoryEmpty, false)
        }

        const owned = ownedZones()
        const contested = zones.filter((z) => z.state === "contested" && (z.gangs || []).indexOf(mine) !== -1)

        m.territoryCount.textContent = int(owned.length)
        m.statTerritory.textContent = territory ? int(owned.length) : "—"
        m.territoryHint.textContent = contested.length > 0
            ? (contested.length === 1 ? "1 bairro em disputa." : int(contested.length) + " bairros em disputa.")
            : owned.length > 0
                ? "Nenhum bairro seu está em disputa."
                : "Marque as ruas para dominar um bairro."

        m.zoneList.replaceChildren()
        if (zones.length === 0) {
            m.zoneList.appendChild(emptyState("Sem bairros", "Nada mapeado até agora."))
        } else {
            zones.slice().sort(zoneOrder(mine)).forEach((zone) => {
                m.zoneList.appendChild(zoneRow(zone, mine))
            })
        }

        mapDirty = true
        if (state.tab === "territory") drawMap(zones)
    }

    function zoneRow(zone, mine) {
        const isMine = zone.state === "controlled" && zone.gang === mine
        const row = document.createElement("li")
        row.className = "zone-row"
        row.dataset.state = zone.state
        row.dataset.mine = String(isMine)

        const flag = document.createElement("span")
        flag.className = "zone-row__flag"
        if (zone.state !== "neutral" && zone.color) flag.style.background = zone.color

        const body = document.createElement("span")
        body.className = "zone-row__body"
        const name = document.createElement("span")
        name.className = "zone-row__name"
        name.textContent = pretty(zone.name)
        const owner = document.createElement("span")
        owner.className = "zone-row__owner"
        owner.textContent = zone.state === "controlled"
            ? (isMine ? "SEU BAIRRO" : pretty(zone.gang))
            : zone.state === "contested"
                ? "EM DISPUTA"
                : "SEM DONO"
        body.append(name, owner)

        row.append(flag, body)
        return row
    }

    // ═══════════════════════════════ Atividade ═══════════════════════════════

    function renderActivity() {
        const entries = state.data.activity || []
        m.history.replaceChildren()

        if (entries.length === 0) {
            m.history.appendChild(emptyState("Nenhuma atividade registrada", "Convites, cargos e desligamentos aparecem aqui."))
            return
        }

        entries.forEach((entry) => {
            const row = document.createElement("li")
            row.className = "history-row"

            const body = document.createElement("span")
            body.className = "history-row__body"
            const title = document.createElement("span")
            title.className = "history-row__title"
            title.textContent = ACTIVITY_TITLE[entry.action] || pretty(entry.action)
            const detail = document.createElement("span")
            detail.className = "history-row__detail"
            detail.textContent = activityDetail(entry)
            body.append(title, detail)

            const time = document.createElement("span")
            time.className = "history-row__time"
            time.textContent = stamp(entry.createdAt)

            row.append(body, time)
            m.history.appendChild(row)
        })
    }

    // ═══════════════════════════════ Navegação ═══════════════════════════════

    const TABS = ["overview", "members", "ranks", "territory", "activity"]
    const PANEL = {
        overview: "tab-overview",
        members: "tab-members",
        ranks: "tab-ranks",
        territory: "tab-territory",
        activity: "tab-activity",
    }

    /// Cargos só existe para quem gere cargos: sem a permissão o item do rail não fica
    /// desabilitado, ele não existe — uma aba que nunca abre é ruído de navegação.
    const visibleTabs = () => TABS.filter((tab) => {
        const nav = m.nav.find((btn) => btn.dataset.tab === tab)
        return nav != null && !nav.hidden
    })

    function renderRail() {
        m.shell.dataset.rail = state.railOpen ? "open" : "closed"
        m.railToggle.setAttribute("aria-expanded", String(state.railOpen))
        m.railToggle.setAttribute("aria-label", state.railOpen ? "Fechar menu lateral" : "Abrir menu lateral")
    }

    function setTab(tab, focusNav) {
        if (!PANEL[tab]) return
        if (visibleTabs().indexOf(tab) === -1) tab = "overview"
        state.tab = tab
        m.main.dataset.tab = tab

        m.nav.forEach((btn) => {
            const selected = btn.dataset.tab === tab
            btn.setAttribute("aria-selected", String(selected))
            btn.tabIndex = selected ? 0 : -1
            if (selected && focusNav) btn.focus()
        })

        TABS.forEach((name) => {
            const panel = $(PANEL[name])
            const visible = name === tab
            if (visible && panel.hidden) {
                panel.hidden = false
                panel.style.animation = "none"
                void panel.offsetWidth
                panel.style.animation = ""
            } else if (!visible) {
                panel.hidden = true
            }
        })

        // Agora o contêiner existe e tem tamanho: é aqui que o mapa nasce, ou se reenquadra.
        if (tab === "territory") {
            requestAnimationFrame(() => {
                if (state.tab !== "territory") return
                if (mapDirty || !map) return drawMap(territoryZones())
                map.invalidateSize()
                const bounds = mapLayer.getBounds()
                if (bounds.isValid()) map.fitBounds(bounds, { padding: [30, 30] })
            })
        }
    }

    function moveTab(delta) {
        const order = visibleTabs()
        const index = order.indexOf(state.tab)
        setTab(order[(index + delta + order.length) % order.length], true)
    }

    // ═══════════════════════════════ Ações ═══════════════════════════════

    // O botão nomeia a consequência, e a frase diz o que acontece depois — nada de "OK".
    const CONFIRM = {
        setGrade: { title: "ALTERAR CARGO", before: "Escolha o novo cargo de ", after: " na gang.", button: "ALTERAR CARGO", danger: false },
        remove: { title: "DESLIGAR MEMBRO", before: "Desligar ", after: " da gang. A pessoa perde o cargo e o acesso na hora.", button: "DESLIGAR MEMBRO", danger: true },
    }

    function askAction(member, action) {
        const copy = CONFIRM[action]
        if (!copy || state.busy) return

        if (action === "setGrade") {
            // Sem destino possível não se abre um modal vazio: a gang tem um cargo só, ou
            // todos os outros são o de chefe.
            const options = rankList().filter((rank) => !rank.isBoss && rank.level !== member.grade)
            if (options.length === 0) {
                return message(m.membersMessage, "Não há outro cargo para onde mover.", "error")
            }
            m.modalRank.replaceChildren()
            options.forEach((rank) => {
                const option = document.createElement("option")
                option.value = String(rank.level)
                option.textContent = rank.label
                m.modalRank.appendChild(option)
            })
        }

        pendingAction = { kind: "member", member: member, action: action }
        openModal(copy.title, copy.before, member.name, copy.after, copy.button, copy.danger,
            false, action === "setGrade")
    }

    function askLeave() {
        if (state.busy) return
        pendingAction = { kind: "leave" }
        openModal(
            "SAIR DA GANG",
            "Você perde o cargo e o acesso à gestão. Para voltar, precisa de um convite novo.",
            null,
            null,
            "SAIR DA GANG",
            true
        )
    }

    function openModal(title, before, strongPart, after, confirmLabel, danger, withField, withRank) {
        modalReturnFocus = document.activeElement
        m.modalTitle.textContent = title
        m.modalText.replaceChildren(document.createTextNode(before))
        if (strongPart) {
            const strong = document.createElement("strong")
            strong.textContent = strongPart
            m.modalText.append(strong, document.createTextNode(after || ""))
        }
        m.modalConfirm.textContent = confirmLabel
        m.modalConfirm.className = danger ? "btn btn--danger" : "btn btn--fill"
        show(m.modalField, withField === true)
        show(m.modalRankField, withRank === true)
        if (withField) {
            m.modalInput.value = ""
            m.modalInput.maxLength = (state.data && state.data.rankLimits && state.data.rankLimits.labelMaxLength) || 32
        }
        syncModalConfirm()
        show(m.modal, true)
        // Foco inicial no primeiro campo, ou na ação segura: a irreversível nunca começa
        // focada.
        if (withField) m.modalInput.focus()
        else if (withRank) m.modalRank.focus()
        else m.modalCancel.focus()
    }

    function closeModal() {
        show(m.modal, false)
        pendingAction = null
        if (modalReturnFocus && modalReturnFocus.isConnected) {
            modalReturnFocus.focus()
        } else {
            const nav = m.nav.find((btn) => btn.getAttribute("aria-selected") === "true")
            if (nav) nav.focus()
        }
        modalReturnFocus = null
    }

    /// O confirmar do modal fica indisponível enquanto o campo obrigatório está vazio, e
    /// enquanto uma ação está em voo.
    function syncModalConfirm() {
        m.modalConfirm.disabled = state.busy || (!m.modalField.hidden && !m.modalInput.value.trim())
    }

    function setBusy(busy) {
        state.busy = busy
        syncModalConfirm()
        m.membersInvite.disabled = busy
        m.membersInvite.dataset.pending = String(busy)
        m.rankSave.disabled = busy
        m.rankSave.dataset.pending = String(busy)
    }

    function applySnapshot(data) {
        state.data = data

        // O item do rail some antes de qualquer desenho: quem perdeu a permissão com a tela
        // aberta não pode continuar vendo a aba.
        show(m.navRanks, canManageRanks())
        if (!canManageRanks() && state.tab === "ranks") setTab("overview", false)

        // O cargo escolhido pode ter sumido (excluído, ou foi o seu que mudou de nível).
        if (state.selectedRank != null && !rankByLevel(state.selectedRank)) state.selectedRank = null

        renderHeader()
        renderOverview()
        renderMembers()
        renderRankList()
        renderRankForm()
        renderTerritory()
        renderActivity()
    }

    function confirmPending() {
        const pending = pendingAction
        if (!pending || state.busy || setup.busy) return

        // Campo obrigatório vazio não vira mensagem de erro: a ação simplesmente ainda não
        // está disponível, e o cursor volta para o campo que falta.
        if (!m.modalField.hidden && !m.modalInput.value.trim()) return m.modalInput.focus()

        show(m.modal, false)
        if (setup.open) setSetupBusy(true)
        else setBusy(true)

        const done = (res) => {
            if (setup.open) setSetupBusy(false)
            else setBusy(false)
            pendingAction = null
            if (modalReturnFocus && modalReturnFocus.isConnected) modalReturnFocus.focus()
            modalReturnFocus = null
            return res
        }

        if (pending.kind === "pointDelete") {
            post("deleteLocation", { id: pending.row.location.id }).then((res) => {
                done(res)
                if (!setup.open) return
                if (res && res.ok) {
                    if (res.data) applySetup(res.data)
                    message(su.pointsMessage, "Ponto excluído.", "success")
                    return
                }
                message(su.pointsMessage, setupError(res && res.code), "error")
            })
            return
        }

        if (pending.kind === "rankCreate") {
            const label = m.modalInput.value.trim()
            post("createRank", { label: label }).then((res) => {
                done(res)
                if (!state.open) return
                if (res && res.ok) {
                    if (res.data) applySnapshot(res.data)
                    // O cargo novo nasce logo abaixo do chefe; abri-lo já selecionado poupa
                    // a pessoa de procurar o que ela acabou de criar.
                    if (typeof res.extra === "number") selectRank(res.extra)
                    message(m.ranksMessage, "Cargo criado: " + label + ". Agora escolha o que ele pode.", "success")
                    return
                }
                message(m.ranksMessage, errorText(res && res.code, "ranks"), "error")
            })
            return
        }

        if (pending.kind === "rankDelete") {
            post("deleteRank", { level: pending.rank.level }).then((res) => {
                done(res)
                if (!state.open) return
                if (res && res.ok) {
                    state.selectedRank = null
                    if (res.data) applySnapshot(res.data)
                    message(m.ranksMessage, "Cargo excluído: " + pending.rank.label + ".", "success")
                    return
                }
                const code = res && res.code
                message(
                    m.ranksMessage,
                    code === "rank_occupied"
                        ? "Ainda há " + int(res.extra) + " no cargo. Mova essas pessoas antes de excluir."
                        : errorText(code, "ranks"),
                    "error"
                )
                refresh()
            })
            return
        }

        if (pending.kind === "leave") {
            post("leaveGang").then((res) => {
                done(res)
                if (!state.open) return
                // Saída aceita: não há mais gang para mostrar, então a tela sai de cena.
                if (res && res.ok) return playExitAndComplete()
                setTab("members", false)
                message(m.membersMessage, errorText(res && res.code), "error")
            })
            return
        }

        const member = pending.member
        const payload = { citizenid: member.citizenid, action: pending.action }
        if (pending.action === "setGrade") payload.level = Number(m.modalRank.value)
        post("memberAction", payload).then((res) => {
            done(res)
            if (!state.open) return
            if (res && res.ok) {
                if (res.data) applySnapshot(res.data)
                message(m.membersMessage, successText(pending.action, member, res.rankLabel), "success")
                return
            }
            message(m.membersMessage, errorText(res && res.code), "error")
            refresh()
        })
    }

    function successText(action, member, rankLabel) {
        if (action === "remove") return member.name + " não faz mais parte da gang."
        if (rankLabel) return member.name + " agora é " + rankLabel + "."
        return member.name + " mudou de cargo."
    }

    /// Convite enviado, a tela sai de cena — quem convida quer ver a pessoa do lado. O aviso
    /// de sucesso vem pelo jogo, que o client dispara: uma mensagem aqui dentro apareceria
    /// e sumiria junto com a janela.
    function invite() {
        if (state.busy) return
        setBusy(true)
        post("invite").then((res) => {
            setBusy(false)
            if (!state.open) return
            if (res && res.ok) return playExitAndComplete()
            message(m.membersMessage, errorText(res && res.code), "error")
        })
    }

    /// Releitura silenciosa: usada quando uma ação falha e o que está na tela pode estar
    /// velho. Falhar aqui não vira mensagem — a mensagem da ação já está na tela.
    function refresh() {
        post("refresh").then((res) => {
            if (!state.open || !res || !res.ok || !res.data) return
            applySnapshot(res.data)
        })
    }

    // ═══════════════════════════════ Ciclo de vida ═══════════════════════════════

    function openMenu(data) {
        if (!data) return
        clearTimers()
        state.open = true
        state.busy = false
        state.tab = "overview"
        state.search = ""
        state.selectedRank = null
        m.membersSearch.value = ""
        show(m.membersMessage, false)
        show(m.ranksMessage, false)
        show(m.modal, false)
        pendingAction = null

        document.getElementById("root").dataset.mode = "menu"
        show(su.window, false)
        show(m.gangWindow, true)
        applySnapshot(data)
        m.root.hidden = false
        m.root.dataset.anim = "enter"
        renderRail()
        setTab("overview", false)
        later(() => m.nav[0].focus(), 50)
    }

    function hideMenu() {
        clearTimers()
        state.open = false
        state.busy = false
        state.data = null
        pendingAction = null
        show(m.modal, false)
        m.root.dataset.anim = "idle"
        m.root.hidden = true
        document.getElementById("root").dataset.mode = "closed"
    }

    /// Saída animada com aviso ao client no fim. O client ainda tem um timeout próprio: se
    /// esta página travar, o jogador não fica sem teclado.
    function playExitAndComplete() {
        m.root.dataset.anim = "exit"
        later(() => {
            post("closeComplete")
            hideMenu()
        }, 300)
    }

    function requestClose() {
        if (!state.open || state.busy) return
        if (!m.modal.hidden) return closeModal()
        post("closeMenu").then((res) => {
            if (!state.open) return
            if (res && res.ok === false) return
            playExitAndComplete()
        })
    }

    // ═══════════════════════════════ Eventos ═══════════════════════════════

    m.nav.forEach((btn) => btn.addEventListener("click", () => setTab(btn.dataset.tab, true)))
    m.railToggle.addEventListener("click", () => { state.railOpen = !state.railOpen; renderRail() })
    m.close.addEventListener("click", requestClose)
    m.railLeave.addEventListener("click", askLeave)
    m.membersInvite.addEventListener("click", invite)
    m.rankCreate.addEventListener("click", askCreateRank)
    m.rankDelete.addEventListener("click", askDeleteRank)
    m.rankEditor.addEventListener("submit", (ev) => {
        ev.preventDefault()
        saveRank()
    })
    m.modalInput.addEventListener("input", syncModalConfirm)
    m.modalCancel.addEventListener("click", closeModal)
    m.modalConfirm.addEventListener("click", confirmPending)

    let searchTimer = null
    m.membersSearch.addEventListener("input", (ev) => {
        const value = ev.target.value
        clearTimeout(searchTimer)
        searchTimer = setTimeout(() => {
            state.search = value
            if (state.data) renderMembers()
        }, 180)
    })

    document.addEventListener("keydown", (ev) => {
        if (setup.open) return setupKeydown(ev)
        if (!state.open) return
        const modalOpen = !m.modal.hidden

        if (ev.key === "Escape") {
            ev.preventDefault()
            if (modalOpen) closeModal()
            else requestClose()
            return
        }

        if (modalOpen) {
            // Enter no campo confirma, que é o que a pessoa espera de um campo único.
            if (ev.key === "Enter" && ev.target === m.modalInput) {
                ev.preventDefault()
                confirmPending()
                return
            }
            if (ev.key === "Tab") {
                const controls = [m.modalField.hidden ? null : m.modalInput, m.modalCancel, m.modalConfirm]
                    .filter((node) => node && !node.disabled)
                const current = controls.indexOf(document.activeElement)
                const next = ev.shiftKey
                    ? (current <= 0 ? controls.length - 1 : current - 1)
                    : (current >= controls.length - 1 ? 0 : current + 1)
                ev.preventDefault()
                controls[next].focus()
            }
            return
        }

        const target = ev.target
        const inNav = target && target.classList && target.classList.contains("nav-item")
        if (!inNav) return

        if (ev.key === "Home" || ev.key === "End") {
            ev.preventDefault()
            const order = visibleTabs()
            setTab(ev.key === "Home" ? order[0] : order[order.length - 1], true)
        } else if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
            ev.preventDefault()
            moveTab(ev.key === "ArrowDown" ? 1 : -1)
        }
    })

    // ═══════════════════════════════ Administração (/gangsetup) ═══════════════════════════════
    //
    // Mesma página, outro modo. A tela esconde o que não se pode fazer, mas nada aqui é
    // prova de permissão: cada ação atravessa o portão de ace no servidor de novo.

    const SETUP_ERROR = {
        no_permission: "Você não tem acesso a esta ferramenta.",
        invalid_name: "O identificador precisa começar por letra e usar só letras, números e _.",
        name_taken: "Já existe uma gang com esse identificador.",
        invalid_label: "O nome exibido não pode ficar em branco.",
        invalid_archetype: "Arquétipo desconhecido.",
        invalid_color: "Cor desconhecida.",
        color_too_dark: "Cor escura demais: ela sumiria no mapa e na tela. Clareie.",
        gang_limit: "O servidor chegou ao limite de gangs.",
        gang_not_found: "Essa gang não existe mais.",
        location_not_found: "Esse ponto não existe mais.",
        invalid_product: "Produto desconhecido.",
        invalid_member: "Essa pessoa não está mais online.",
        already_in_gang: "Essa pessoa já pertence a uma gang.",
        boss_exists: "Essa gang já tem chefe. Trocar quem lidera é com /setgang.",
        no_boss: "Essa gang não tem cargo de chefe na escada.",
        not_ready: "O sistema de gangs não subiu: o registro está vazio e nada pode ser gravado.",
        busy: "Aguarde a ação anterior terminar.",
        not_open: "A ferramenta foi fechada.",
        failed: "Não foi possível concluir. Tente de novo.",
    }

    const setupError = (code) => SETUP_ERROR[code] || SETUP_ERROR.failed

    const su = {
        window: $("setup-window"),
        railToggle: $("setup-rail-toggle"),
        nav: Array.prototype.slice.call(document.querySelectorAll("[data-setup-tab]")),
        main: $("setup-main"),
        context: $("setup-context"),
        close: $("setup-close"),
        gangsSub: $("setup-gangs-sub"),
        message: $("setup-message"),
        create: $("setup-create"),
        list: $("setup-gang-list"),
        empty: $("setup-empty"),
        form: $("setup-form"),
        name: $("setup-name"),
        nameHint: $("setup-name-hint"),
        nameError: $("setup-name-error"),
        nameErrorText: $("setup-name-error-text"),
        label: $("setup-label"),
        archetype: $("setup-archetype"),
        archetypeHint: $("setup-archetype-hint"),
        products: $("setup-products"),
        bossRow: $("setup-boss-row"),
        boss: $("setup-boss"),
        bossHint: $("setup-boss-hint"),
        bossAssign: $("setup-boss-assign"),
        color: $("setup-color"),
        colorError: $("setup-color-error"),
        colorErrorText: $("setup-color-error-text"),
        picker: $("setup-picker"),
        pickerPreview: $("setup-picker-preview"),
        hue: $("setup-hue"),
        sat: $("setup-sat"),
        lig: $("setup-lig"),
        hex: $("setup-hex"),
        addPoint: $("setup-add-point"),
        cancel: $("setup-cancel"),
        save: $("setup-save"),
        pointsSub: $("setup-points-sub"),
        pointsMessage: $("setup-points-message"),
        pointList: $("setup-point-list"),
    }

    const setup = {
        open: false,
        busy: false,
        data: null,
        tab: "gangs",
        railOpen: false,
        selected: null,
        creating: false,
        custom: null, // '#RRGGBB' enquanto a cor livre está escolhida
        timers: [],
    }

    const setupGangs = () => (setup.data && setup.data.gangs) || []
    const setupGang = (name) => setupGangs().find((g) => g.name === name) || null

    const CHECK_SVG = '<svg class="swatch__check" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m5 13 4 4L19 7"/></svg>'

    function setupLater(fn, ms) {
        const id = setTimeout(fn, reducedMotion ? 0 : ms)
        setup.timers.push(id)
        return id
    }

    function showNameError(text) {
        su.nameErrorText.textContent = text || ""
        show(su.nameError, !!text)
        su.name.setAttribute("aria-invalid", String(!!text))
    }

    // ───────────── cor livre ─────────────
    //
    // A régua de contraste vem do servidor e é conferida aqui só para avisar na hora. Quem
    // recusa continua sendo ele: a tela não é prova de nada.

    const HEX_RE = /^#[0-9a-f]{6}$/i
    const DEFAULT_CUSTOM = "#E03232"

    function channelLuminance(value) {
        const c = value / 255
        return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
    }

    function luminance(r, g, b) {
        return 0.2126 * channelLuminance(r) + 0.7152 * channelLuminance(g) + 0.0722 * channelLuminance(b)
    }

    function colorContrast(hex) {
        const rule = (setup.data && setup.data.limits && setup.data.limits.color) || null
        if (!rule) return 21
        const against = rule.against
        const r = parseInt(hex.slice(1, 3), 16)
        const g = parseInt(hex.slice(3, 5), 16)
        const b = parseInt(hex.slice(5, 7), 16)
        let a = luminance(r, g, b) + 0.05
        let other = luminance(against.r, against.g, against.b) + 0.05
        if (a < other) { const swap = a; a = other; other = swap }
        return a / other
    }

    function colorTooDark(hex) {
        const rule = (setup.data && setup.data.limits && setup.data.limits.color) || null
        return !!rule && colorContrast(hex) < rule.minContrast
    }

    /// HSL para hexadecimal. Os sliders falam HSL porque é o espaço em que "mais claro" e
    /// "mais saturado" são um eixo só; o que se guarda é o hexadecimal.
    function hslToHex(h, sl, l) {
        const s = sl / 100
        const light = l / 100
        const k = (n) => (n + h / 30) % 12
        const a = s * Math.min(light, 1 - light)
        const f = (n) => {
            const value = light - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)))
            return Math.round(255 * value).toString(16).padStart(2, "0")
        }
        return ("#" + f(0) + f(8) + f(4)).toUpperCase()
    }

    function hexToHsl(hex) {
        const r = parseInt(hex.slice(1, 3), 16) / 255
        const g = parseInt(hex.slice(3, 5), 16) / 255
        const b = parseInt(hex.slice(5, 7), 16) / 255
        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        const l = (max + min) / 2
        const d = max - min
        if (d === 0) return { h: 0, s: 0, l: Math.round(l * 100) }
        const s = d / (1 - Math.abs(2 * l - 1))
        let h
        if (max === r) h = ((g - b) / d) % 6
        else if (max === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h = Math.round(h * 60)
        if (h < 0) h += 360
        return { h: h, s: Math.round(s * 100), l: Math.round(l * 100) }
    }

    function showColorError(text) {
        su.colorErrorText.textContent = text || ""
        show(su.colorError, !!text)
    }

    function renderPickerPreview(hex) {
        su.pickerPreview.style.background = hex
        su.hex.value = hex

        const swatch = su.color.querySelector(".swatch--custom")
        if (swatch) {
            swatch.dataset.custom = "true"
            swatch.style.setProperty("--swatch-custom", hex)
        }

        showColorError(colorTooDark(hex)
            ? "Cor escura demais: ela sumiria no mapa e na tela. Aumente o brilho."
            : null)
    }

    function setCustomColor(hex, syncSliders) {
        setup.custom = hex
        if (syncSliders) {
            const hsl = hexToHsl(hex)
            su.hue.value = String(hsl.h)
            su.sat.value = String(hsl.s)
            su.lig.value = String(hsl.l)
        }
        renderPickerPreview(hex)
    }

    function onSliderInput() {
        setCustomColor(hslToHex(Number(su.hue.value), Number(su.sat.value), Number(su.lig.value)), false)
    }

    function onHexInput() {
        let value = su.hex.value.trim()
        if (value && value[0] !== "#") value = "#" + value
        if (!HEX_RE.test(value)) return
        setCustomColor(value.toUpperCase(), true)
    }

    // ───────────── lista ─────────────

    function renderSetupList() {
        const gangs = setupGangs()
        const limits = (setup.data && setup.data.limits) || { max: 0 }

        su.gangsSub.textContent = gangs.length === 1
            ? "1 gang registrada."
            : int(gangs.length) + " gangs registradas, de " + int(limits.max) + " possíveis."
        su.context.textContent = int(gangs.length) + " GANGS"

        su.create.disabled = gangs.length >= limits.max
        su.create.title = gangs.length >= limits.max ? "O servidor chegou ao limite de gangs" : ""

        su.list.replaceChildren()
        gangs.forEach((gang) => {
            const option = document.createElement("button")
            option.type = "button"
            option.className = "rank-option"
            option.setAttribute("role", "option")
            option.setAttribute("aria-selected", String(!setup.creating && setup.selected === gang.name))

            const name = document.createElement("span")
            name.className = "rank-option__name"
            const dot = document.createElement("span")
            dot.className = "gang-option__dot"
            dot.style.background = gang.colorHex
            const text = document.createElement("span")
            text.textContent = gang.label
            name.append(dot, text)

            const count = document.createElement("span")
            count.className = "rank-option__count"
            count.textContent = gang.members === 1 ? "1 membro" : int(gang.members) + " membros"

            const meta = document.createElement("span")
            meta.className = "rank-option__meta"
            meta.textContent = gang.name + " · " + String(gang.archetypeLabel).toUpperCase() +
                " · " + int(gang.ranks) + " CARGOS · " +
                (gang.locations.length === 1 ? "1 PONTO" : int(gang.locations.length) + " PONTOS")

            option.append(name, count, meta)
            option.addEventListener("click", () => selectSetupGang(gang.name))
            su.list.appendChild(option)
        })
    }

    // ───────────── formulário ─────────────

    function renderChoices(gang) {
        const archetypes = (setup.data && setup.data.archetypes) || []
        const colors = (setup.data && setup.data.colors) || []
        // Trocar o arquétipo reescreve a escada de cargos: com gente dentro, cada pessoa
        // cairia num nível que talvez não exista do outro lado. O servidor recusa; a tela
        // desabilita e diz por quê, em vez de deixar tentar.
        const locked = !setup.creating && gang && gang.members > 0

        su.archetypeHint.textContent = locked
            ? "Com " + int(gang.members) + " dentro, o arquétipo não muda: isso reescreveria a escada de cargos."
            : "Define a escada de cargos da gang."

        su.archetype.replaceChildren()
        archetypes.forEach((archetype) => {
            const label = document.createElement("label")
            const input = document.createElement("input")
            input.type = "radio"
            input.name = "setup-archetype"
            input.value = archetype.id
            input.checked = gang ? gang.archetype === archetype.id : archetype.id === archetypes[0].id
            input.disabled = locked && (!gang || gang.archetype !== archetype.id)

            const text = document.createElement("span")
            text.textContent = archetype.label
            const count = document.createElement("span")
            count.className = "choice__count"
            count.textContent = int(archetype.ranks) + " cargos"

            label.append(input, text, count)
            su.archetype.appendChild(label)
        })

        // Produtos são caixas, e não rádios: uma gang pode operar mais de um. O
        // armazenamento é por (gang, produto) desde sempre, então isso não é novidade para
        // o servidor — a tela é que não tinha como dizer.
        const products = (setup.data && setup.data.products) || []
        const current = (gang && gang.products) || []
        su.products.replaceChildren()
        products.forEach((product) => {
            const label = document.createElement("label")
            const input = document.createElement("input")
            input.type = "checkbox"
            input.name = "setup-product"
            input.value = product.id
            input.checked = current.indexOf(product.id) !== -1

            const text = document.createElement("span")
            text.textContent = product.label

            label.append(input, text)
            su.products.appendChild(label)
        })

        // Cor livre é a que não está na paleta: ela chega como `#RRGGBB`.
        const currentColor = gang ? gang.color : null
        const isCustom = typeof currentColor === "string" && HEX_RE.test(currentColor)
        setup.custom = isCustom ? currentColor.toUpperCase() : null

        su.color.replaceChildren()
        colors.forEach((color) => {
            const label = document.createElement("label")
            label.title = color.label
            const input = document.createElement("input")
            input.type = "radio"
            input.name = "setup-color"
            input.value = color.id
            input.checked = !isCustom && (gang ? currentColor === color.id : color.id === colors[0].id)
            input.setAttribute("aria-label", color.label)

            const dot = document.createElement("span")
            dot.className = "swatch__dot"
            dot.style.background = color.hex

            label.append(input, dot)
            label.insertAdjacentHTML("beforeend", CHECK_SVG)
            su.color.appendChild(label)
        })

        // A última amostra abre o seletor livre. Ela é um rádio como as outras, então a
        // escolha continua sendo uma só e o teclado anda por todas com as setas.
        const custom = document.createElement("label")
        custom.className = "swatch--custom"
        custom.title = "Cor personalizada"
        const customInput = document.createElement("input")
        customInput.type = "radio"
        customInput.name = "setup-color"
        customInput.value = "__custom__"
        customInput.checked = isCustom
        customInput.setAttribute("aria-label", "Cor personalizada")

        const customDot = document.createElement("span")
        customDot.className = "swatch__dot"
        custom.append(customInput, customDot)
        custom.insertAdjacentHTML("beforeend", CHECK_SVG)
        su.color.appendChild(custom)

        show(su.picker, isCustom)
        setCustomColor(isCustom ? currentColor.toUpperCase() : DEFAULT_CUSTOM, true)
        if (!isCustom) {
            custom.dataset.custom = "false"
            custom.style.removeProperty("--swatch-custom")
        }
        showColorError(isCustom && colorTooDark(setup.custom)
            ? "Cor escura demais: ela sumiria no mapa e na tela. Aumente o brilho."
            : null)
    }

    function renderSetupForm() {
        const gang = setup.creating ? null : (setup.selected ? setupGang(setup.selected) : null)

        if (!setup.creating && !gang) {
            show(su.empty, true)
            show(su.form, false)
            return
        }

        show(su.empty, false)
        show(su.form, true)
        showNameError(null)

        const limits = (setup.data && setup.data.limits) || {}
        su.name.value = gang ? gang.name : ""
        su.name.readOnly = !setup.creating
        su.name.maxLength = limits.nameMaxLength || 24
        su.nameHint.textContent = setup.creating
            ? "Minúsculo, sem espaço. É por ele que cada personagem aponta para a gang, então ele não muda depois."
            : "Definido na criação. Mudar deixaria órfã cada pessoa que já está dentro."

        su.label.value = gang ? gang.label : ""
        su.label.maxLength = limits.labelMaxLength || 40

        renderChoices(gang)

        renderBossRow(gang)

        show(su.cancel, setup.creating)
        // Ponto de gestão é de gang que já existe: não dá para marcar no mundo o lugar de
        // algo que ainda não foi criado.
        show(su.addPoint, !setup.creating)
        su.save.textContent = setup.creating ? "CRIAR GANG" : "SALVAR ALTERAÇÕES"
    }

    // O primeiro chefe só aparece onde falta um: com chefe em pé, trocar quem lidera é
    // `/setgang`, e a tela não finge o contrário. Na criação também não aparece — não dá
    // para pôr alguém numa gang que ainda não existe.
    function renderBossRow(gang) {
        const candidates = (setup.data && setup.data.candidates) || []
        const missing = !setup.creating && gang && gang.hasBossRank && !gang.bossName
        show(su.bossRow, !!missing)
        if (!missing) return

        su.boss.replaceChildren()
        candidates.forEach((candidate) => {
            const option = document.createElement("option")
            option.value = String(candidate.source)
            option.textContent = candidate.name
            su.boss.appendChild(option)
        })

        const empty = candidates.length === 0
        su.boss.disabled = empty
        su.bossAssign.disabled = empty || setup.busy
        su.bossHint.textContent = empty
            ? "Ninguém online e fora de gang para assumir. A lista é de quem está sem gang agora."
            : "A gang está sem chefe. Depois de definido, trocar quem lidera é com /setgang."
    }

    function assignBoss() {
        if (setup.busy || !setup.selected || su.bossAssign.disabled) return
        const target = su.boss.value
        if (!target) return

        setSetupBusy(true)
        post("assignBoss", { gang: setup.selected, target: Number(target) }).then((res) => {
            setSetupBusy(false)
            if (!setup.open) return
            if (res && res.ok) {
                if (res.data) applySetup(res.data)
                message(su.message, "Chefe definido: " + (res.extra || "—") + ".", "success")
                return
            }
            message(su.message, setupError(res && res.code), "error")
        })
    }

    function selectSetupGang(name) {
        setup.creating = false
        setup.selected = name
        hideMessage(su.message)
        renderSetupList()
        renderSetupForm()
    }

    function startCreate() {
        if (setup.busy || su.create.disabled) return
        setup.creating = true
        setup.selected = null
        hideMessage(su.message)
        renderSetupList()
        renderSetupForm()
        su.name.focus()
    }

    function cancelCreate() {
        setup.creating = false
        renderSetupList()
        renderSetupForm()
    }

    const pickedValue = (group) => {
        const input = group.querySelector("input:checked")
        return input ? input.value : null
    }

    function submitSetupForm() {
        if (setup.busy) return

        const label = su.label.value.trim()
        if (!label) return showNameError("O nome exibido não pode ficar em branco.")

        const pickedColor = pickedValue(su.color)
        const color = pickedColor === "__custom__" ? (setup.custom || "") : pickedColor
        if (pickedColor === "__custom__" && colorTooDark(color)) {
            return showColorError("Cor escura demais: ela sumiria no mapa e na tela. Aumente o brilho.")
        }

        const checked = Array.prototype.slice.call(su.products.querySelectorAll("input:checked"))
        const payload = {
            label: label,
            archetype: pickedValue(su.archetype),
            color: color,
            products: checked.map((input) => input.value),
        }

        if (setup.creating) {
            const name = su.name.value.trim().toLowerCase()
            if (!name) return showNameError("O identificador não pode ficar em branco.")
            payload.name = name
        } else {
            if (!setup.selected) return
            payload.name = setup.selected
        }

        showNameError(null)
        setSetupBusy(true)
        post(setup.creating ? "createGang" : "updateGang", payload).then((res) => {
            setSetupBusy(false)
            if (!setup.open) return
            if (res && res.ok) {
                const created = setup.creating
                setup.creating = false
                if (created && typeof res.extra === "string") setup.selected = res.extra
                if (res.data) applySetup(res.data)
                message(su.message, created ? "Gang criada: " + label + "." : "Gang salva: " + label + ".", "success")
                return
            }
            const code = res && res.code
            message(
                su.message,
                code === "gang_occupied"
                    ? "A gang tem " + int(res.extra) + " dentro; o arquétipo não pode mudar agora."
                    : setupError(code),
                "error"
            )
        })
    }

    // ───────────── pontos ─────────────

    function renderSetupPoints() {
        const gangs = setupGangs()
        const rows = []
        gangs.forEach((gang) => {
            gang.locations.forEach((location) => rows.push({ gang: gang, location: location }))
        })

        su.pointsSub.textContent = rows.length === 0
            ? "Nenhum ponto criado. É neles que o menu da gang abre no mundo."
            : (rows.length === 1 ? "1 ponto" : int(rows.length) + " pontos") + " no mundo. É neles que o menu da gang abre."

        su.pointList.replaceChildren()
        if (rows.length === 0) {
            su.pointList.appendChild(
                emptyState("Nenhum ponto de gestão", "Escolha uma gang em Gangs e use ADICIONAR PONTO.")
            )
            return
        }

        rows.forEach((row) => {
            const line = document.createElement("div")
            line.className = "point-row"
            line.setAttribute("role", "row")

            const gangCell = document.createElement("span")
            gangCell.className = "point-row__gang"
            const dot = document.createElement("span")
            dot.className = "gang-option__dot"
            dot.style.background = row.gang.colorHex
            const gangName = document.createElement("span")
            gangName.textContent = row.gang.label
            gangCell.append(dot, gangName)

            const coords = document.createElement("span")
            coords.className = "point-row__coords"
            coords.textContent = row.location.coords.x.toFixed(1) + ", " +
                row.location.coords.y.toFixed(1) + ", " + row.location.coords.z.toFixed(1)

            const actions = document.createElement("span")
            actions.className = "point-row__actions"
            actions.append(
                actionButton("TELEPORTAR", ICON.pin, false, () => teleportToPoint(row.location)),
                actionButton("MOVER", ICON.move, false, () => placePoint(row.gang.name, row.location.id)),
                actionButton("EXCLUIR", ICON.trash, true, () => askDeletePoint(row))
            )

            line.append(gangCell, coords, actions)
            su.pointList.appendChild(line)
        })
    }

    function placePoint(gangName, locationId) {
        if (setup.busy) return
        post("placeLocation", { gang: gangName, id: locationId }).then((res) => {
            if (res && res.ok) return
            message(su.pointsMessage, setupError(res && res.code), "error")
        })
    }

    function teleportToPoint(location) {
        if (setup.busy) return
        post("teleportToLocation", { coords: location.coords })
    }

    function askDeletePoint(row) {
        if (setup.busy) return
        pendingAction = { kind: "pointDelete", row: row }
        openModal(
            "EXCLUIR PONTO",
            "Excluir o ponto de gestão de ",
            row.gang.label,
            ". O menu da gang deixa de abrir ali, e isso não volta.",
            "EXCLUIR PONTO",
            true
        )
    }

    // ───────────── navegação e ciclo de vida ─────────────

    const SETUP_TABS = ["gangs", "points"]
    const SETUP_PANEL = { gangs: "setup-tab-gangs", points: "setup-tab-points" }

    function renderSetupRail() {
        su.window.dataset.rail = setup.railOpen ? "open" : "closed"
        su.railToggle.setAttribute("aria-expanded", String(setup.railOpen))
        su.railToggle.setAttribute("aria-label", setup.railOpen ? "Fechar menu lateral" : "Abrir menu lateral")
    }

    function setSetupTab(tab, focusNav) {
        if (!SETUP_PANEL[tab]) return
        setup.tab = tab
        su.main.dataset.tab = tab

        su.nav.forEach((btn) => {
            const selected = btn.dataset.setupTab === tab
            btn.setAttribute("aria-selected", String(selected))
            btn.tabIndex = selected ? 0 : -1
            if (selected && focusNav) btn.focus()
        })

        SETUP_TABS.forEach((name) => {
            const panel = $(SETUP_PANEL[name])
            const visible = name === tab
            if (visible && panel.hidden) {
                panel.hidden = false
                panel.style.animation = "none"
                void panel.offsetWidth
                panel.style.animation = ""
            } else if (!visible) {
                panel.hidden = true
            }
        })
    }

    function setSetupBusy(busy) {
        setup.busy = busy
        su.save.disabled = busy
        su.save.dataset.pending = String(busy)
        const max = (setup.data && setup.data.limits && setup.data.limits.max) || 0
        su.create.disabled = busy || setupGangs().length >= max
        su.bossAssign.disabled = busy || su.boss.disabled
        syncModalConfirm()
    }

    function applySetup(data) {
        setup.data = data
        if (setup.selected && !setupGang(setup.selected)) setup.selected = null
        renderSetupList()
        renderSetupForm()
        renderSetupPoints()
    }

    function openSetup(data) {
        if (!data) return
        clearTimers()
        setup.open = true
        setup.busy = false
        setup.tab = "gangs"
        setup.creating = false
        setup.selected = null
        hideMessage(su.message)
        hideMessage(su.pointsMessage)
        show(m.modal, false)
        pendingAction = null

        document.getElementById("root").dataset.mode = "setup"
        applySetup(data)
        show(m.gangWindow, false)
        show(su.window, true)
        m.root.hidden = false
        m.root.dataset.anim = "enter"
        renderSetupRail()
        setSetupTab("gangs", false)
        setupLater(() => su.nav[0].focus(), 50)
    }

    function hideSetup() {
        setup.timers.forEach(clearTimeout)
        setup.timers = []
        show(m.gangWindow, true)
        setup.open = false
        setup.busy = false
        setup.data = null
        pendingAction = null
        show(m.modal, false)
        show(su.window, false)
        m.root.dataset.anim = "idle"
        m.root.hidden = true
        document.getElementById("root").dataset.mode = "closed"
    }

    function playSetupExit() {
        m.root.dataset.anim = "exit"
        setupLater(() => {
            post("setupCloseComplete")
            hideSetup()
        }, 300)
    }

    function requestSetupClose() {
        if (!setup.open || setup.busy) return
        if (!m.modal.hidden) return closeModal()
        post("closeSetup").then((res) => {
            if (!setup.open) return
            if (res && res.ok === false) return
            playSetupExit()
        })
    }

    su.nav.forEach((btn) => btn.addEventListener("click", () => setSetupTab(btn.dataset.setupTab, true)))
    su.railToggle.addEventListener("click", () => { setup.railOpen = !setup.railOpen; renderSetupRail() })
    su.close.addEventListener("click", requestSetupClose)
    su.create.addEventListener("click", startCreate)
    su.cancel.addEventListener("click", cancelCreate)
    su.form.addEventListener("submit", (ev) => {
        ev.preventDefault()
        submitSetupForm()
    })
    su.bossAssign.addEventListener("click", assignBoss)
    su.addPoint.addEventListener("click", () => {
        if (setup.selected) placePoint(setup.selected, null)
    })
    // No container, e uma vez só: `renderChoices` redesenha as amostras a cada troca de
    // gang, e prender o listener lá dentro empilharia um por redesenho.
    su.color.addEventListener("change", () => {
        const picked = pickedValue(su.color)
        const custom = picked === "__custom__"
        show(su.picker, custom)
        if (!custom) return showColorError(null)

        renderPickerPreview(setup.custom || DEFAULT_CUSTOM)
        // O formulário rola: o seletor nasce abaixo da dobra e ninguém o veria abrir.
        su.picker.scrollIntoView({ block: "nearest", behavior: reducedMotion ? "auto" : "smooth" })
    })
    su.hue.addEventListener("input", onSliderInput)
    su.sat.addEventListener("input", onSliderInput)
    su.lig.addEventListener("input", onSliderInput)
    su.hex.addEventListener("input", onHexInput)

    function setupKeydown(ev) {
        const modalOpen = !m.modal.hidden

        if (ev.key === "Escape") {
            ev.preventDefault()
            if (modalOpen) closeModal()
            else requestSetupClose()
            return
        }
        if (modalOpen) return

        const target = ev.target
        if (!target || !target.classList || !target.classList.contains("nav-item")) return

        if (ev.key === "Home" || ev.key === "End") {
            ev.preventDefault()
            setSetupTab(ev.key === "Home" ? SETUP_TABS[0] : SETUP_TABS[SETUP_TABS.length - 1], true)
        } else if (ev.key === "ArrowDown" || ev.key === "ArrowUp") {
            ev.preventDefault()
            const index = SETUP_TABS.indexOf(setup.tab)
            const next = (index + (ev.key === "ArrowDown" ? 1 : -1) + SETUP_TABS.length) % SETUP_TABS.length
            setSetupTab(SETUP_TABS[next], true)
        }
    }

    // ═══════════════════════════════ Mensagens do client ═══════════════════════════════

    const handlers = {
        "gang:open": (payload) => openMenu(payload),
        "gangSetup:open": (payload) => openSetup(payload),
        "gangSetup:close": (payload) => {
            if (!setup.open) return
            if (payload && payload.immediate) return hideSetup()
            playSetupExit()
        },
        // O posicionamento no mundo solta o foco sem desmontar a tela: ela volta com
        // `gangSetup:open` e o estado de antes.
        "gangSetup:suspend": () => {
            if (!setup.open) return
            m.root.hidden = true
        },
        "gang:close": (payload) => {
            if (!state.open) return
            if (payload && payload.immediate) return hideMenu()
            playExitAndComplete()
        },
    }

    window.addEventListener("message", (event) => {
        const msg = event.data || {}
        const handler = handlers[msg.action]
        if (handler) handler(msg.data)
    })

    // Avisa os dois lados que a página carregou: um reload do CEF redesenha a tela que
    // estiver aberta, seja a gestão ou a administração.
    post("uiReady")
    post("setupReady")
})()
