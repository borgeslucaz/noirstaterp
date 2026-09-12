(() => {
    'use strict';

    // A página roda num iframe dinâmico criado pelo telefone, e cada fonte de nome de
    // resource mente de um jeito diferente ali dentro:
    //   - `window.resourceName` é quem REGISTROU o app, ou seja o bridge, não nós;
    //   - `GetParentResourceName()` devolve o nome interno do frame, algo como
    //     "<!--dynamicFrame...", porque o frame não foi criado pelo runtime de NUI;
    //   - `location.hostname` só vale quando o iframe carregou pela nossa própria URL.
    // Por isso cada candidato é validado, e o literal existe como último recurso.
    const FALLBACK_RESOURCE = 'noir_outposts';

    function validResourceName(value) {
        return typeof value === 'string'
            && value.length > 0
            && value.length <= 64
            && /^[A-Za-z0-9_-]+$/.test(value);
    }

    function ownResource() {
        if (typeof GetParentResourceName === 'function') {
            try {
                const name = GetParentResourceName();
                if (validResourceName(name)) return name;
            } catch { /* frame sem runtime de NUI */ }
        }

        const host = String(location.hostname || '');
        if (host.startsWith('cfx-nui-')) {
            const name = host.slice('cfx-nui-'.length);
            if (validResourceName(name)) return name;
        }

        return FALLBACK_RESOURCE;
    }

    const resourceName = ownResource();
    const el = (id) => document.getElementById(id);

    let snapshot = null;
    let activeTab = 'network';

    const STATUS = {
        inactive: { label: 'Inativo', tone: 'grey' },
        available: { label: 'Livre', tone: 'green' },
        claiming: { label: 'Em disputa', tone: 'orange' },
        controlled: { label: 'Ocupado', tone: 'red' },
        contested: { label: 'Contestado', tone: 'orange' },
        cooldown: { label: 'Em espera', tone: 'grey' },
    };

    const TYPE = { drug: 'Entorpecentes', money: 'Lavagem' };

    // Traços no estilo lucide, a família usada pelos apps nativos.
    const ICONS = {
        signal: ['M4 20v-5', 'M10 20V10', 'M16 20V6', 'M22 20V13'],
        inbox: ['M21 12h-6l-2 3h-2l-2-3H3', 'M5 5h14l2 7v5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-5z'],
        box: ['M21 8l-9-5-9 5v8l9 5 9-5z', 'M3 8l9 5 9-5', 'M12 13v8'],
        refresh: ['M21 12a9 9 0 1 1-3-6.7', 'M21 4v5h-5'],
        bell: ['M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9', 'M13.7 21a2 2 0 0 1-3.4 0'],
        cash: ['M3 6h18v12H3z', 'M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z'],
        inbox2: ['M21 12h-6l-2 3h-2l-2-3H3', 'M5 5h14l2 7v5a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-5z'],
        mask: ['M4 8s3-2 8-2 8 2 8 2v4c0 4-4 6-8 6s-8-2-8-6z', 'M9 11h.01', 'M15 11h.01'],
        person: ['M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2', 'M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z'],
        flag: ['M4 21V4', 'M4 5h12l-2 4 2 4H4'],
        alert: ['M12 9v4', 'M12 17h.01', 'M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z'],
        trash: ['M3 6h18', 'M8 6V4h8v2', 'M19 6l-1 14H6L5 6', 'M10 11v6', 'M14 11v6'],
        gear: ['M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z', 'M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-2.9-1.2l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0-1.2-2.9H3a2 2 0 0 1 0-4h.1A1.7 1.7 0 0 0 4.3 6l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 2.9-1.2V2a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 2.9 1.2l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0 1.2 2.9H22a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z'],
    };

    // Categorias de alerta. O texto explica que o filtro não afeta o histórico.
    const ALERT_CATEGORIES = {
        sales: { title: 'Vendas', text: 'Resumo das vendas dos seus corredores.' },
        stock: { title: 'Estoque', text: 'Aviso quando o estoque fica baixo ou zera.' },
        security: { title: 'Segurança', text: 'Abordagem, assalto e corredor derrubado.' },
        control: { title: 'Controle', text: 'Tomada de ponto e fim do controle.' },
    };

    // Cada tipo de operação vira uma notificação legível.
    const EVENTS = {
        sale: { glyph: 'cash', tone: 'green', title: 'Venda concluída' },
        deposit: { glyph: 'inbox2', tone: 'blue', title: 'Estoque abastecido' },
        collect: { glyph: 'cash', tone: 'blue', title: 'Carteira coletada' },
        robbery: { glyph: 'mask', tone: 'red', title: 'Corredor assaltado' },
        holdup: { glyph: 'alert', tone: 'orange', title: 'Corredor abordado' },
        dealer_down: { glyph: 'alert', tone: 'red', title: 'Corredor derrubado' },
        hire: { glyph: 'person', tone: 'blue', title: 'Corredor contratado' },
        fire: { glyph: 'person', tone: 'grey', title: 'Corredor dispensado' },
        claim: { glyph: 'flag', tone: 'green', title: 'Outpost assumido' },
        release: { glyph: 'flag', tone: 'grey', title: 'Controle encerrado' },
        forfeit: { glyph: 'cash', tone: 'red', title: 'Carteira perdida' },
    };

    function svgIcon(paths, className) {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', '0 0 24 24');
        svg.setAttribute('fill', 'none');
        svg.setAttribute('stroke', 'currentColor');
        svg.setAttribute('stroke-width', '2');
        svg.setAttribute('stroke-linecap', 'round');
        svg.setAttribute('stroke-linejoin', 'round');
        svg.setAttribute('aria-hidden', 'true');
        if (className) svg.setAttribute('class', className);
        for (const d of paths) {
            const node = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            node.setAttribute('d', d);
            svg.append(node);
        }
        return svg;
    }

    let noticeTimer = null;

    // Aviso curto acima da barra de abas, no lugar do rodapé permanente.
    function notice(text) {
        const node = el('notice');
        node.textContent = text;
        node.hidden = false;
        if (noticeTimer) window.clearTimeout(noticeTimer);
        noticeTimer = window.setTimeout(() => {
            node.hidden = true;
            noticeTimer = null;
        }, 5000);
    }

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

    function money(value) {
        return `$${Number(value || 0).toLocaleString('pt-BR')}`;
    }

    function countdown(target, serverTime) {
        const seconds = Math.max(0, Math.floor(Number(target || 0) - Number(serverTime || 0)));
        if (seconds <= 0) return 'expirado';
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes} min`;
        return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
    }

    function timeAgo(at, serverTime) {
        const seconds = Math.max(0, Math.floor(Number(serverTime || 0) - Number(at || 0)));
        if (seconds < 60) return 'agora';
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes} min`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24) return `${hours} h`;
        return `${Math.floor(hours / 24)} d`;
    }

    /* Cartões --------------------------------------------------------------- */

    function pill(text, tone) {
        const node = document.createElement('span');
        node.className = 'pill';
        node.dataset.tone = tone || 'grey';
        node.textContent = text;
        return node;
    }

    function metric(label, value) {
        const wrap = document.createElement('div');
        wrap.className = 'metric';
        const name = document.createElement('span');
        name.className = 'metric__label';
        name.textContent = label;
        const amount = document.createElement('span');
        amount.className = 'metric__value';
        amount.textContent = value;
        wrap.append(name, amount);
        return wrap;
    }

    function card({ title, badge, body, meta, metrics, onSelect }) {
        const node = document.createElement(onSelect ? 'button' : 'div');
        node.className = 'card';
        if (onSelect) {
            node.type = 'button';
            node.addEventListener('click', () => onSelect());
        }

        const head = document.createElement('div');
        head.className = 'card__head';
        const heading = document.createElement('h3');
        heading.className = 'card__title';
        heading.textContent = title;
        head.append(heading);
        if (badge) head.append(badge);
        node.append(head);

        if (body) {
            const paragraph = document.createElement('p');
            paragraph.className = 'card__body';
            paragraph.textContent = body;
            node.append(paragraph);
        }
        if (meta) {
            const line = document.createElement('p');
            line.className = 'card__meta';
            line.textContent = meta;
            node.append(line);
        }
        if (metrics && metrics.length) {
            const row = document.createElement('div');
            row.className = 'metrics';
            for (const [label, value] of metrics) row.append(metric(label, value));
            node.append(row);
        }
        return node;
    }

    function emptyState(container, title, text, glyph) {
        const wrap = document.createElement('div');
        wrap.className = 'empty';

        const circle = document.createElement('div');
        circle.className = 'empty__circle';
        circle.append(svgIcon(glyph));
        wrap.append(circle);

        const heading = document.createElement('div');
        heading.className = 'empty__title';
        heading.textContent = title;
        wrap.append(heading);

        const paragraph = document.createElement('p');
        paragraph.className = 'empty__text';
        paragraph.textContent = text;
        wrap.append(paragraph);

        container.append(wrap);
    }

    async function routeTo(outpost) {
        const response = await post('phone:setWaypoint', { x: outpost.coords.x, y: outpost.coords.y });
        if (!response || !response.ok) notice('Não foi possível marcar a rota.');
    }

    /* Abas ------------------------------------------------------------------ */

    function renderNetwork() {
        const stack = el('network-stack');
        stack.replaceChildren();

        const outposts = (snapshot.outposts || []).filter((o) => o.status !== 'inactive');
        if (outposts.length === 0) {
            emptyState(stack, 'Nenhum ponto ativo',
                'Quando a rede abrir um ponto, ele aparece aqui.', ICONS.signal);
            return;
        }

        for (const outpost of outposts) {
            const meta = STATUS[outpost.status] || { label: outpost.status, tone: 'grey' };
            stack.append(card({
                title: outpost.label,
                badge: outpost.isMine ? pill('Sua', 'blue') : pill(meta.label, meta.tone),
                body: TYPE[outpost.operationType] || 'Operação',
                meta: 'Toque para traçar a rota',
                onSelect: () => routeTo(outpost),
            }));
        }
    }

    function renderOperation() {
        const stack = el('operation-stack');
        stack.replaceChildren();

        const mine = (snapshot.outposts || []).filter((o) => o.isMine);
        if (mine.length === 0) {
            emptyState(stack, 'Sem operação',
                'Sua organização não controla nenhum ponto no momento.', ICONS.box);
            return;
        }

        for (const outpost of mine) {
            const metrics = [['Runners', String(outpost.dealers || 0)]];
            if (typeof outpost.stockTotal === 'number') metrics.push(['Estoque', String(outpost.stockTotal)]);
            if (typeof outpost.purse === 'number') metrics.push(['Carteira', money(outpost.purse)]);

            stack.append(card({
                title: outpost.label,
                badge: pill('Sua', 'blue'),
                body: snapshot.organization ? snapshot.organization.label : 'Sua organização',
                meta: `Controle por mais ${countdown(outpost.expiresAt, snapshot.serverTime)}`,
                metrics,
                onSelect: () => routeTo(outpost),
            }));
        }
    }

    /* Feed ------------------------------------------------------------------- */

    const feed = { items: [], cursor: null, done: false, loading: false, started: false, serverTime: 0 };

    function feedBody(item) {
        const parts = [item.outpostLabel];
        if (item.dealer) parts.push(item.dealer);

        if (item.type === 'sale' || item.type === 'deposit') {
            if (item.quantity) parts.push(`${item.quantity} × ${item.itemLabel || item.item}`);
        }
        if (item.type === 'holdup') parts.push(item.reacted ? 'reagiu' : 'rendeu-se');
        if (item.type === 'robbery' && item.quantity) {
            parts.push(`${item.quantity} × ${item.itemLabel || item.item}`);
        }

        const amount = item.type === 'sale' || item.type === 'collect'
            || item.type === 'robbery' || item.type === 'forfeit'
            ? item.net
            : item.type === 'hire' ? item.gross : null;
        if (amount) parts.push(money(amount));

        return parts.join(' · ');
    }

    function feedCard(item) {
        const event = EVENTS[item.type] || { glyph: 'bell', tone: 'grey', title: item.type };

        const node = document.createElement('div');
        node.className = 'card feed-item';

        const glyph = document.createElement('span');
        glyph.className = 'feed-item__glyph';
        glyph.dataset.tone = event.tone;
        glyph.append(svgIcon(ICONS[event.glyph] || ICONS.bell));
        node.append(glyph);

        const main = document.createElement('div');
        main.className = 'feed-item__main';

        const head = document.createElement('div');
        head.className = 'feed-item__head';
        const title = document.createElement('h3');
        title.className = 'feed-item__title';
        title.textContent = event.title;
        const time = document.createElement('span');
        time.className = 'feed-item__time';
        time.textContent = timeAgo(item.at, feed.serverTime);
        head.append(title, time);
        main.append(head);

        const body = document.createElement('p');
        body.className = 'feed-item__body';
        body.textContent = feedBody(item);
        main.append(body);

        node.append(main);
        return node;
    }

    function renderFeed() {
        const stack = el('feed-stack');
        stack.replaceChildren();

        if (feed.items.length === 0) {
            if (!feed.loading) {
                emptyState(stack, 'Sem notificações',
                    'O que acontecer nos seus pontos aparece aqui.', ICONS.bell);
            }
            el('feed-end').hidden = true;
            return;
        }

        for (const item of feed.items) stack.append(feedCard(item));
        el('feed-end').hidden = !feed.done;
    }

    async function loadFeed(reset) {
        if (feed.loading) return;
        if (reset) {
            feed.items = [];
            feed.cursor = null;
            feed.done = false;
        } else if (feed.done) {
            return;
        }

        feed.loading = true;
        feed.started = true;
        const response = await post('phone:feed', feed.cursor ? { cursor: feed.cursor } : {});
        feed.loading = false;

        if (!response || !response.ok) {
            notice(response && response.code === 'insufficient_grade'
                ? 'Seu cargo não permite ver o histórico.'
                : 'Não foi possível carregar as notificações.');
            feed.done = true;
            renderFeed();
            return;
        }

        feed.serverTime = response.data.serverTime;
        for (const item of response.data.items || []) feed.items.push(item);
        feed.cursor = response.data.nextCursor || null;
        feed.done = !feed.cursor;
        renderFeed();

        // Se a primeira página não encheu a tela, o observador não dispara sozinho.
        if (!feed.done && el('panel-feed').hidden === false) {
            const sentinel = el('feed-sentinel');
            const box = sentinel.getBoundingClientRect();
            if (box.top <= window.innerHeight) void loadFeed(false);
        }
    }

    // Scroll infinito: carrega a próxima página quando o fim da lista entra na tela.
    const observer = typeof IntersectionObserver === 'function'
        ? new IntersectionObserver((entries) => {
            for (const entry of entries) {
                if (entry.isIntersecting && feed.started && !feed.done) void loadFeed(false);
            }
        }, { root: document.querySelector('.content'), rootMargin: '160px' })
        : null;

    function render(data) {
        snapshot = data;
        renderNetwork();
        renderOperation();
    }

    /* Configurações ---------------------------------------------------------- */

    const settings = { categories: [], loading: false, saving: false };

    function toggleRow(category) {
        const meta = ALERT_CATEGORIES[category.id] || { title: category.id, text: '' };

        const node = document.createElement('div');
        node.className = 'card toggle-row';

        const main = document.createElement('div');
        main.className = 'toggle-row__main';
        const title = document.createElement('p');
        title.className = 'toggle-row__title';
        title.textContent = meta.title;
        const text = document.createElement('p');
        text.className = 'toggle-row__text';
        text.textContent = meta.text;
        main.append(title, text);

        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'switch';
        button.setAttribute('role', 'switch');
        button.setAttribute('aria-checked', String(category.enabled));
        button.setAttribute('aria-label', meta.title);
        button.addEventListener('click', () => {
            if (settings.saving) return;
            category.enabled = !category.enabled;
            button.setAttribute('aria-checked', String(category.enabled));
            void saveAlerts();
        });

        node.append(main, button);
        return node;
    }

    function renderSettings() {
        const list = el('settings-list');
        list.replaceChildren();
        for (const category of settings.categories) list.append(toggleRow(category));
    }

    async function saveAlerts() {
        if (settings.saving) return;
        settings.saving = true;
        const alerts = {};
        for (const category of settings.categories) alerts[category.id] = category.enabled;
        const response = await post('phone:setAlerts', { alerts });
        settings.saving = false;
        if (!response || !response.ok) {
            notice('Não foi possível salvar a preferência.');
            void openSettings(true);
        }
    }

    async function openSettings(silent) {
        if (!silent) el('settings-sheet').hidden = false;
        if (settings.loading) return;
        settings.loading = true;
        const response = await post('phone:settings', {});
        settings.loading = false;
        if (!response || !response.ok) {
            notice('Não foi possível carregar as preferências.');
            return;
        }
        settings.categories = response.data.categories || [];
        renderSettings();
    }

    async function clearFeed() {
        const response = await post('phone:clearFeed', {});
        if (!response || !response.ok) {
            notice('Não foi possível limpar as notificações.');
            return;
        }
        notice('Notificações limpas.');
        await loadFeed(true);
    }

    function selectTab(name) {
        activeTab = name;
        for (const tab of document.querySelectorAll('.tabbar__item')) {
            const selected = tab.dataset.tab === name;
            tab.setAttribute('aria-selected', String(selected));
            tab.tabIndex = selected ? 0 : -1;
        }
        el('panel-network').hidden = name !== 'network';
        el('panel-operation').hidden = name !== 'operation';
        el('panel-feed').hidden = name !== 'feed';
        el('title').textContent = name === 'network' ? 'Rede'
            : name === 'operation' ? 'Operação' : 'Notificações';

        const onFeed = name === 'feed';
        el('clear').hidden = !onFeed;
        el('settings').hidden = !onFeed;

        if (onFeed && !feed.started) void loadFeed(true);
    }

    // Ícones da barra de abas e da ação de atualizar são montados uma vez.
    el('tab-network').prepend(svgIcon(ICONS.signal));
    el('tab-operation').prepend(svgIcon(ICONS.inbox));
    el('tab-feed').prepend(svgIcon(ICONS.bell));
    el('refresh').append(svgIcon(ICONS.refresh));
    el('clear').append(svgIcon(ICONS.trash));
    el('settings').append(svgIcon(ICONS.gear));
    if (observer) observer.observe(el('feed-sentinel'));

    for (const tab of document.querySelectorAll('.tabbar__item')) {
        tab.addEventListener('click', () => selectTab(tab.dataset.tab));
    }

    el('clear').addEventListener('click', () => { void clearFeed(); });
    el('settings').addEventListener('click', () => { void openSettings(false); });
    el('settings-back').addEventListener('click', () => { el('settings-sheet').hidden = true; });

    el('refresh').addEventListener('click', () => {
        if (activeTab === 'feed') { void loadFeed(true); return; }
        void requestState();
    });

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data !== 'object') return;
        if (data.action !== 'exchange:state' || !data.data) return;
        render(data.data);
    });

    selectTab(activeTab);

    async function requestState() {
        const response = await post('phone:requestState', {});
        if (!response || !response.ok) {
            notice(`Não foi possível falar com a rede (${resourceName}).`);
        }
    }

    void requestState();
    window.setInterval(() => { void requestState(); }, 30000);
})();
