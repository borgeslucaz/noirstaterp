(() => {
    'use strict';

    const resourceName = typeof GetParentResourceName === 'function'
        ? GetParentResourceName()
        : 'noir_outposts';

    const el = (id) => document.getElementById(id);
    const shell = el('shell');
    const message = el('message');
    const confirmBackdrop = el('confirm-backdrop');

    let snapshot = null;
    let activeTab = 'market';
    let busy = false;
    let messageTimer = null;
    let confirmResolve = null;

    const ERRORS = {
        rate_limited: 'Aguarde um instante antes de tentar de novo.',
        invalid_payload: 'Requisição inválida.',
        invalid_player: 'Personagem indisponível.',
        player_unavailable: 'Você não pode fazer isso agora.',
        invalid_state: 'Esta ação não está disponível agora.',
        invalid_session: 'A sessão expirou. Abra o terminal novamente.',
        session_expired: 'A sessão expirou.',
        request_in_progress: 'Já existe uma ação em andamento.',
        already_processed: 'Esta ação já foi processada.',
        unknown_outpost: 'Local desconhecido.',
        unknown_dealer: 'Corredor desconhecido.',
        unknown_profile: 'Perfil desconhecido.',
        unknown_product: 'Produto desconhecido.',
        outpost_inactive: 'Este local não está ativo.',
        no_organization: 'Você precisa pertencer a uma organização.',
        insufficient_grade: 'Seu cargo não permite esta ação.',
        not_owner: 'Sua organização não controla este local.',
        too_far: 'Aproxime-se do terminal.',
        not_enough_players: 'Não há movimento suficiente na cidade.',
        not_enough_police: 'Não há policiamento suficiente na cidade.',
        organization_cooldown: 'Sua organização precisa esperar antes de tomar outro local.',
        claim_in_progress: 'Outra tomada já está em andamento.',
        dealer_limit: 'O limite de corredores foi atingido.',
        already_hired: 'Este corredor já está em campo.',
        no_corner: 'Não há posição livre para este corredor.',
        insufficient_funds: 'Dinheiro insuficiente.',
        dealer_busy: 'Este corredor está ocupado.',
        amount_too_large: 'Quantidade acima do permitido.',
        stock_full: 'O estoque do local está cheio.',
        not_enough_items: 'Você não tem essa quantidade.',
        empty_purse: 'A carteira está vazia.',
        cannot_carry: 'Você não tem espaço para carregar isso.',
        purse_changed: 'A carteira mudou. Tente novamente.',
        cancelled: 'Ação cancelada.',
        provider_unavailable: 'Serviço indisponível no momento.',
        internal_error: 'Não foi possível concluir. Tente novamente.',
        transport_error: 'Falha de comunicação com o servidor.',
    };

    const STATUS = {
        inactive: 'INATIVO',
        available: 'DISPONÍVEL',
        claiming: 'EM DISPUTA',
        controlled: 'CONTROLADO',
        contested: 'CONTESTADO',
        cooldown: 'EM ESPERA',
    };

    const DEALER_STATUS = {
        deployed: 'EM CAMPO',
        recovering: 'RECUPERANDO',
    };

    const OPERATION = {
        sale: 'Venda',
        deposit: 'Depósito',
        collect: 'Coleta',
        robbery: 'Roubo',
        dealer_down: 'Corredor derrubado',
        hire: 'Contratação',
        fire: 'Demissão',
        claim: 'Tomada',
    };

    async function post(name, data = {}) {
        try {
            const response = await fetch(`https://${resourceName}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            return await response.json();
        } catch {
            return { ok: false, code: 'transport_error' };
        }
    }

    function describe(code) {
        return ERRORS[code] || ERRORS.internal_error;
    }

    function notify(text, tone) {
        if (messageTimer) window.clearTimeout(messageTimer);
        message.textContent = text;
        message.dataset.tone = tone || 'info';
        message.hidden = false;
        messageTimer = window.setTimeout(() => {
            message.hidden = true;
            messageTimer = null;
        }, 6000);
    }

    function money(value) {
        return `$${Number(value || 0).toLocaleString('pt-BR')}`;
    }

    function countdown(target, serverTime) {
        const seconds = Math.max(0, Math.floor(Number(target || 0) - Number(serverTime || 0)));
        if (seconds <= 0) return 'agora';
        if (seconds < 60) return `${seconds}s`;
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes}min`;
        return `${Math.floor(minutes / 60)}h ${minutes % 60}min`;
    }

    function clear(node) {
        node.replaceChildren();
    }

    function labelled(labelText, valueText, tone) {
        const wrap = document.createElement('div');
        wrap.className = 'stat';
        const label = document.createElement('span');
        label.className = 'data-label';
        label.textContent = labelText;
        const value = document.createElement('strong');
        value.className = 'tabular';
        value.textContent = valueText;
        if (tone) value.dataset.tone = tone;
        wrap.append(label, value);
        return wrap;
    }

    function metric(labelText, valueText) {
        const wrap = document.createElement('div');
        wrap.className = 'row__metric';
        const label = document.createElement('span');
        label.className = 'data-label';
        label.textContent = labelText;
        const value = document.createElement('span');
        value.className = 'tabular';
        value.textContent = valueText;
        wrap.append(label, value);
        return wrap;
    }

    // O handler recebe o próprio nó: `event.currentTarget` vira null assim que a função
    // aguarda algo, porque o evento já terminou de ser despachado.
    function button(text, variant, handler) {
        const node = document.createElement('button');
        node.type = 'button';
        node.className = `btn ${variant}`.trim();
        node.textContent = text;
        node.addEventListener('click', () => handler(node));
        return node;
    }

    function askConfirm(title, text) {
        el('confirm-title').textContent = title;
        el('confirm-text').textContent = text;
        confirmBackdrop.hidden = false;
        el('confirm-cancel').focus();
        return new Promise((resolve) => {
            confirmResolve = resolve;
        });
    }

    function resolveConfirm(value) {
        confirmBackdrop.hidden = true;
        if (confirmResolve) {
            const resolve = confirmResolve;
            confirmResolve = null;
            resolve(value);
        }
    }

    el('confirm-cancel').addEventListener('click', () => resolveConfirm(false));
    el('confirm-accept').addEventListener('click', () => resolveConfirm(true));

    async function act(node, name, payload, successText) {
        if (busy) return;
        busy = true;

        const previous = node ? node.textContent : null;
        if (node) {
            node.dataset.loading = 'true';
            node.textContent = 'PROCESSANDO';
        }

        const response = await post(name, payload);

        // Um re-render entre o clique e a resposta pode ter trocado o botão.
        if (node && node.isConnected) {
            node.dataset.loading = 'false';
            node.textContent = previous;
        }
        busy = false;

        if (!response || !response.ok) {
            if (response && response.code !== 'cancelled') notify(describe(response.code), 'error');
            return;
        }
        if (successText) notify(successText, 'success');
        if (response.data && response.data.closing) return;
        if (response.data && response.data.outpost) render(response.data);
    }

    /* Render ------------------------------------------------------------- */

    function renderHeader() {
        const outpost = snapshot.outpost;
        el('outpost-name').textContent = outpost.label.toUpperCase();
        el('outpost-status').textContent = STATUS[outpost.status] || outpost.status.toUpperCase();

        const viewer = snapshot.viewer;
        el('owner-label').textContent = viewer.isOwner ? 'SUA ORGANIZAÇÃO' : 'ORGANIZAÇÃO';
        el('owner-value').textContent = viewer.organizationLabel || 'Sem organização';
    }

    function renderMarket() {
        const stats = el('market-stats');
        clear(stats);
        stats.append(
            labelled('CORREDORES', `${snapshot.market.hiredCount} / ${snapshot.limits.maxDealers}`),
            labelled('CONTROLE', snapshot.viewer.isOwner ? 'SUA ORGANIZAÇÃO' : (STATUS[snapshot.outpost.status] || '—')),
        );

        const rows = el('market-rows');
        clear(rows);
        const profiles = snapshot.market.profiles || [];
        el('market-empty').hidden = profiles.length > 0;

        for (const profile of profiles) {
            const row = document.createElement('div');
            row.className = 'row';

            const info = document.createElement('div');
            const title = document.createElement('span');
            title.className = 'row__title';
            title.textContent = profile.name;
            const sub = document.createElement('p');
            sub.className = 'row__sub';
            sub.textContent = profile.description;
            info.append(title, sub);

            const meta = document.createElement('div');
            meta.className = 'row__meta';
            meta.append(
                metric('VELOCIDADE', `${profile.stats.speed}`),
                metric('CAPACIDADE', `${profile.stats.capacity}`),
                metric('NEGOCIAÇÃO', `${profile.stats.negotiation}`),
                metric('COMISSÃO', `${profile.stats.split}%`),
                metric('CICLO', `${profile.intervalSeconds}s`),
                metric('CUSTO', money(profile.hirePrice)),
            );

            const actions = document.createElement('div');
            actions.className = 'row__actions';

            if (profile.hired) {
                actions.append(button('DEMITIR', 'btn--danger', async (node) => {
                    const accepted = await askConfirm(
                        'DEMITIR CORREDOR',
                        `${profile.name} sai de campo imediatamente e o valor da contratação não é devolvido.`,
                    );
                    if (!accepted) return;
                    await act(node, 'fire', { dealerId: profile.dealerId }, `${profile.name} foi dispensado.`);
                }));
            } else {
                const canHire = snapshot.viewer.isOwner
                    && snapshot.viewer.permissions.hire === true
                    && snapshot.market.hiredCount < snapshot.limits.maxDealers;
                const hire = button('CONTRATAR', 'btn', async (node) => {
                    await act(node, 'hire', { profileKey: profile.key }, `${profile.name} entrou em campo.`);
                });
                hire.disabled = !canHire;
                if (!canHire) {
                    hire.title = snapshot.viewer.isOwner
                        ? 'Sem permissão ou limite atingido'
                        : 'Sua organização não controla este local';
                }
                actions.append(hire);
            }

            row.append(info, meta, actions);
            rows.append(row);
        }
    }

    function renderDealers(runners) {
        const rows = el('dealer-rows');
        clear(rows);
        const dealers = runners.dealers || [];
        el('dealers-empty').hidden = dealers.length > 0;

        for (const dealer of dealers) {
            const row = document.createElement('div');
            row.className = 'row';

            const info = document.createElement('div');
            const title = document.createElement('span');
            title.className = 'row__title';
            title.textContent = dealer.name;
            const sub = document.createElement('p');
            sub.className = 'row__sub';
            sub.textContent = `${DEALER_STATUS[dealer.status] || dealer.status} · posição ${dealer.cornerIndex || '—'}`;
            info.append(title, sub);

            const meta = document.createElement('div');
            meta.className = 'row__meta';
            meta.append(
                metric('PRÓXIMA VENDA', dealer.status === 'recovering'
                    ? countdown(dealer.robbedUntil, snapshot.serverTime)
                    : countdown(dealer.nextSaleAt, snapshot.serverTime)),
                metric('VENDAS', `${dealer.lifetimeSales}`),
                metric('BRUTO', money(dealer.lifetimeGross)),
                metric('COMISSÃO', `${dealer.split}%`),
            );

            const actions = document.createElement('div');
            actions.className = 'row__actions';
            const fire = button('DEMITIR', 'btn--danger', async (node) => {
                const accepted = await askConfirm(
                    'DEMITIR CORREDOR',
                    `${dealer.name} sai de campo imediatamente e o valor da contratação não é devolvido.`,
                );
                if (!accepted) return;
                await act(node, 'fire', { dealerId: dealer.id }, `${dealer.name} foi dispensado.`);
            });
            fire.disabled = snapshot.viewer.permissions.fire !== true;
            actions.append(fire);

            row.append(info, meta, actions);
            rows.append(row);
        }
    }

    function renderStock(runners) {
        const rows = el('stock-rows');
        clear(rows);
        el('stock-total').textContent = `${runners.stockTotal} / ${snapshot.limits.maxStockTotal}`;

        for (const product of runners.stock || []) {
            const row = document.createElement('div');
            row.className = 'row';

            const info = document.createElement('div');
            const title = document.createElement('span');
            title.className = 'row__title';
            title.textContent = product.label;
            const bar = document.createElement('div');
            bar.className = 'bar';
            const fill = document.createElement('i');
            const ratio = snapshot.limits.maxStockTotal > 0
                ? Math.min(100, (product.quantity / snapshot.limits.maxStockTotal) * 100)
                : 0;
            fill.style.width = `${ratio}%`;
            bar.append(fill);
            info.append(title, bar);

            const meta = document.createElement('div');
            meta.className = 'row__meta';
            meta.append(
                metric('NO LOCAL', `${product.quantity}`),
                metric('COM VOCÊ', `${product.carried}`),
            );

            const amountWrap = document.createElement('div');
            amountWrap.className = 'amount';

            const actions = document.createElement('div');
            actions.className = 'row__actions';

            const input = document.createElement('input');
            input.type = 'number';
            input.min = '1';
            input.max = String(snapshot.limits.maxStockPerDeposit);
            input.value = String(Math.min(product.carried || 1, snapshot.limits.maxStockPerDeposit) || 1);
            input.setAttribute('aria-label', `Quantidade de ${product.label}`);
            amountWrap.append(input);

            const deposit = button('ABASTECER', 'btn', async (node) => {
                const amount = Math.floor(Number(input.value));
                if (!Number.isFinite(amount) || amount < 1) {
                    notify('Informe uma quantidade válida.', 'error');
                    return;
                }
                await act(
                    node,
                    'deposit',
                    { productId: product.id, amount },
                    `${amount} × ${product.label} adicionados ao estoque.`,
                );
            });
            deposit.disabled = snapshot.viewer.permissions.stock !== true || product.carried < 1;
            actions.append(deposit);

            row.append(info, meta, amountWrap, actions);
            rows.append(row);
        }
    }

    function renderHistory(runners) {
        const rows = el('history-rows');
        clear(rows);
        const history = runners.history || [];
        el('history-empty').hidden = history.length > 0;

        for (const entry of history) {
            const row = document.createElement('div');
            row.className = 'row';

            const when = document.createElement('span');
            when.className = 'data-label';
            when.textContent = new Date(Number(entry.at || 0) * 1000)
                .toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });

            const info = document.createElement('div');
            const title = document.createElement('span');
            title.className = 'row__title';
            title.textContent = OPERATION[entry.type] || entry.type;
            const sub = document.createElement('p');
            sub.className = 'row__sub';
            sub.textContent = entry.item
                ? `${entry.quantity || 0} × ${entry.item}`
                : 'Movimentação registrada';
            info.append(title, sub);

            const value = document.createElement('span');
            value.className = 'tabular';
            value.textContent = entry.net ? money(entry.net) : '—';

            row.append(when, info, value);
            rows.append(row);
        }
    }

    function renderRunners() {
        const runners = snapshot.runners;
        const tab = el('tab-runners');

        if (!runners) {
            clear(el('runners-stats'));
            clear(el('dealer-rows'));
            clear(el('stock-rows'));
            clear(el('history-rows'));
            el('dealers-empty').hidden = false;
            el('dealers-empty').textContent = 'Sua organização não controla este local.';
            el('history-empty').hidden = false;
            el('purse-section').hidden = true;
            return;
        }

        el('dealers-empty').textContent = 'Nenhum corredor contratado.';

        const stats = el('runners-stats');
        clear(stats);
        const total = runners.stockTotal;
        const tone = total <= 0 ? 'bad' : total < snapshot.limits.maxStockTotal * 0.1 ? 'warn' : 'good';
        stats.append(
            labelled('CORREDORES', `${(runners.dealers || []).length} / ${snapshot.limits.maxDealers}`),
            labelled('ESTOQUE', `${total} / ${snapshot.limits.maxStockTotal}`, tone),
            labelled('CONTROLE ATÉ', countdown(snapshot.outpost.expiresAt, snapshot.serverTime)),
        );

        renderDealers(runners);
        renderStock(runners);
        renderHistory(runners);

        const purse = runners.purse;
        el('purse-section').hidden = !purse;
        if (purse) {
            el('purse-value').textContent = money(purse.available);
            el('purse-note').textContent = purse.pending > 0
                ? `${money(purse.pending)} em entrega pendente.`
                : 'Dinheiro sujo acumulado pelas vendas.';
            const collect = el('collect');
            collect.disabled = snapshot.viewer.permissions.collect !== true || purse.available <= 0;
        }
    }

    function renderControl() {
        const claim = snapshot.claim;
        const requirements = el('claim-requirements');
        clear(requirements);

        const rows = [
            ['JOGADORES ONLINE', `${claim.requirements.online} / ${claim.requirements.minOnlinePlayers}`,
                claim.requirements.online >= claim.requirements.minOnlinePlayers],
            ['POLICIAMENTO', `${claim.requirements.police} / ${claim.requirements.minPolice}`,
                claim.requirements.police >= claim.requirements.minPolice],
            ['CARGO', snapshot.viewer.permissions.claim ? 'AUTORIZADO' : 'INSUFICIENTE',
                snapshot.viewer.permissions.claim === true],
            ['DURAÇÃO', `${Math.round(claim.requirements.durationMs / 1000)}s`, true],
            ['CONTROLE', `${claim.requirements.controlHours}h`, true],
        ];

        if (claim.requirements.cooldownUntil && claim.requirements.cooldownUntil > snapshot.serverTime) {
            rows.push(['ESPERA DA ORGANIZAÇÃO',
                countdown(claim.requirements.cooldownUntil, snapshot.serverTime), false]);
        }

        for (const [label, value, ok] of rows) {
            const wrap = document.createElement('div');
            wrap.className = 'requirement';
            const name = document.createElement('span');
            name.className = 'data-label';
            name.textContent = label;
            const strong = document.createElement('strong');
            strong.className = 'tabular';
            strong.textContent = value;
            strong.dataset.ok = String(ok === true);
            wrap.append(name, strong);
            requirements.append(wrap);
        }

        const state = el('control-state');
        const detail = el('control-detail');
        state.textContent = STATUS[snapshot.outpost.status] || snapshot.outpost.status.toUpperCase();

        if (snapshot.viewer.isOwner) {
            detail.textContent = `Sua organização controla este local por mais ${countdown(snapshot.outpost.expiresAt, snapshot.serverTime)}.`;
        } else if (snapshot.outpost.owner) {
            detail.textContent = 'Outra organização controla este local.';
        } else if (snapshot.outpost.status === 'claiming') {
            detail.textContent = 'Uma tomada já está em andamento.';
        } else {
            detail.textContent = 'Nenhuma organização controla este local.';
        }

        const claimButton = el('claim');
        claimButton.disabled = claim.canClaim !== true;
    }

    function render(data) {
        snapshot = data;
        renderHeader();
        renderMarket();
        renderRunners();
        renderControl();
    }

    /* Navegação ---------------------------------------------------------- */

    function selectTab(name) {
        activeTab = name;
        for (const item of document.querySelectorAll('.nav__item')) {
            const selected = item.dataset.tab === name;
            item.setAttribute('aria-selected', String(selected));
            item.tabIndex = selected ? 0 : -1;
        }
        for (const tab of document.querySelectorAll('.tab')) {
            tab.hidden = tab.id !== `tab-${name}`;
        }
    }

    for (const item of document.querySelectorAll('.nav__item')) {
        item.addEventListener('click', () => selectTab(item.dataset.tab));
        item.addEventListener('keydown', (event) => {
            if (event.key !== 'ArrowRight' && event.key !== 'ArrowLeft') return;
            const items = Array.from(document.querySelectorAll('.nav__item'));
            const index = items.indexOf(item);
            const next = event.key === 'ArrowRight'
                ? items[(index + 1) % items.length]
                : items[(index - 1 + items.length) % items.length];
            next.focus();
            selectTab(next.dataset.tab);
        });
    }

    el('collect').addEventListener('click', async () => {
        await act(el('collect'), 'collect', {}, 'Carteira coletada.');
    });

    el('claim').addEventListener('click', async () => {
        const accepted = await askConfirm(
            'INICIAR TOMADA',
            'A janela vai fechar e você precisa permanecer no terminal até o fim. Sair cancela a tomada.',
        );
        if (!accepted) return;
        await act(el('claim'), 'claim', {});
    });

    el('close').addEventListener('click', () => { void requestClose(); });

    async function requestClose() {
        if (busy) return;
        if (!confirmBackdrop.hidden) {
            resolveConfirm(false);
            return;
        }
        const response = await post('close', {});
        if (response && response.ok) animateOut();
    }

    document.addEventListener('keydown', (event) => {
        if (event.key !== 'Escape') return;
        event.preventDefault();
        void requestClose();
    });

    /* Ciclo de vida ------------------------------------------------------ */

    let refreshTimer = null;

    function startRefreshLoop() {
        stopRefreshLoop();
        refreshTimer = window.setInterval(async () => {
            if (shell.hidden || busy || !confirmBackdrop.hidden) return;
            const response = await post('refresh', {});
            if (response && response.ok && response.data) render(response.data);
        }, 15000);
    }

    function stopRefreshLoop() {
        if (refreshTimer) window.clearInterval(refreshTimer);
        refreshTimer = null;
    }

    let exitTimer = null;

    function animateOut() {
        if (shell.hidden) return;
        shell.dataset.anim = 'exit';
        if (exitTimer) window.clearTimeout(exitTimer);
        exitTimer = window.setTimeout(() => {
            hideImmediate();
            void post('closeComplete', {});
        }, 260);
    }

    function hideImmediate() {
        if (exitTimer) window.clearTimeout(exitTimer);
        exitTimer = null;
        stopRefreshLoop();
        shell.hidden = true;
        shell.dataset.anim = 'idle';
        confirmBackdrop.hidden = true;
        confirmResolve = null;
        message.hidden = true;
        busy = false;
    }

    function show(data) {
        hideImmediate();
        render(data);
        selectTab(data.viewer.isOwner ? 'runners' : activeTab === 'runners' ? 'market' : activeTab);
        shell.hidden = false;
        shell.dataset.anim = 'enter';
        el('close').focus();
        startRefreshLoop();
    }

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data.action !== 'string') return;

        if (data.action === 'outposts:open') {
            show(data.data);
        } else if (data.action === 'outposts:update') {
            if (!shell.hidden) render(data.data);
        } else if (data.action === 'outposts:close') {
            if (data.data && data.data.immediate) hideImmediate();
            else animateOut();
        }
    });

    hideImmediate();
    void post('uiReady', {});
})();
