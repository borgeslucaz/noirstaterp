(() => {
    'use strict';

    // A página roda dentro do iframe do telefone, servida do nosso próprio resource.
    // Não usar o `resourceName` que o provider injeta: ele aponta para quem registrou o app,
    // que é o bridge, e não para quem responde aos callbacks.
    function ownResource() {
        if (typeof GetParentResourceName === 'function') {
            const name = GetParentResourceName();
            if (typeof name === 'string' && name) return name;
        }
        // O host do iframe é cfx-nui-<resource>, então serve de fonte determinística.
        const host = String(location.hostname || '');
        if (host.startsWith('cfx-nui-')) return host.slice('cfx-nui-'.length);
        return 'noir_outposts';
    }

    const resourceName = ownResource();

    const el = (id) => document.getElementById(id);
    const status = el('status');

    let snapshot = null;
    let activeTab = 'network';

    const STATUS = {
        inactive: 'INATIVO',
        available: 'LIVRE',
        claiming: 'EM DISPUTA',
        controlled: 'OCUPADO',
        contested: 'CONTESTADO',
        cooldown: 'EM ESPERA',
    };

    const TYPE = {
        drug: 'Entorpecentes',
        money: 'Lavagem',
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

    function money(value) {
        return `$${Number(value || 0).toLocaleString('pt-BR')}`;
    }

    function countdown(target, serverTime) {
        const seconds = Math.max(0, Math.floor(Number(target || 0) - Number(serverTime || 0)));
        if (seconds <= 0) return 'expirado';
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60) return `${minutes}min`;
        return `${Math.floor(minutes / 60)}h ${minutes % 60}min`;
    }

    function makeItem(title, subtitle, badgeText, badgeTone, onSelect) {
        const item = document.createElement('li');
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'item';

        const main = document.createElement('div');
        main.className = 'item__main';
        const name = document.createElement('span');
        name.className = 'item__title';
        name.textContent = title;
        const sub = document.createElement('span');
        sub.className = 'item__sub';
        sub.textContent = subtitle;
        main.append(name, sub);

        const badge = document.createElement('span');
        badge.className = 'badge';
        badge.textContent = badgeText;
        if (badgeTone) badge.dataset.tone = badgeTone;

        button.append(main, badge);
        if (onSelect) button.addEventListener('click', onSelect);
        item.append(button);
        return item;
    }

    function renderNetwork() {
        const list = el('network-list');
        list.replaceChildren();

        const outposts = (snapshot.outposts || []).filter((outpost) => outpost.status !== 'inactive');
        el('network-empty').hidden = outposts.length > 0;

        for (const outpost of outposts) {
            const tone = outpost.isMine ? 'mine' : outpost.controlled ? 'taken' : 'free';
            const badge = outpost.isMine ? 'SUA' : (STATUS[outpost.status] || outpost.status);
            const subtitle = `${TYPE[outpost.operationType] || 'Operação'} · toque para traçar rota`;

            list.append(makeItem(outpost.label, subtitle, badge, tone, async () => {
                const response = await post('phone:setWaypoint', { x: outpost.coords.x, y: outpost.coords.y });
                status.textContent = response && response.ok
                    ? `Rota marcada para ${outpost.label}.`
                    : 'Não foi possível marcar a rota.';
            }));
        }
    }

    function renderOperation() {
        const list = el('operation-list');
        const summary = el('operation-summary');
        list.replaceChildren();
        summary.replaceChildren();

        const mine = (snapshot.outposts || []).filter((outpost) => outpost.isMine);
        el('operation-empty').hidden = mine.length > 0;

        if (mine.length === 0) return;

        let dealers = 0;
        let stock = 0;
        let purse = 0;
        let hasStock = false;
        let hasPurse = false;

        for (const outpost of mine) {
            dealers += Number(outpost.dealers || 0);
            if (typeof outpost.stockTotal === 'number') {
                stock += outpost.stockTotal;
                hasStock = true;
            }
            if (typeof outpost.purse === 'number') {
                purse += outpost.purse;
                hasPurse = true;
            }
        }

        const stats = [['PONTOS', String(mine.length)], ['RUNNERS', String(dealers)]];
        if (hasStock) stats.push(['ESTOQUE', String(stock)]);
        if (hasPurse) stats.push(['CARTEIRA', money(purse)]);

        for (const [label, value] of stats) {
            const stat = document.createElement('div');
            stat.className = 'stat';
            const name = document.createElement('span');
            name.textContent = label;
            const strong = document.createElement('strong');
            strong.textContent = value;
            stat.append(name, strong);
            summary.append(stat);
        }

        for (const outpost of mine) {
            const parts = [`${outpost.dealers || 0} runners`];
            if (typeof outpost.stockTotal === 'number') parts.push(`${outpost.stockTotal} em estoque`);
            if (typeof outpost.purse === 'number') parts.push(money(outpost.purse));
            parts.push(`controle por ${countdown(outpost.expiresAt, snapshot.serverTime)}`);

            list.append(makeItem(outpost.label, parts.join(' · '), 'SUA', 'mine', async () => {
                const response = await post('phone:setWaypoint', { x: outpost.coords.x, y: outpost.coords.y });
                status.textContent = response && response.ok
                    ? `Rota marcada para ${outpost.label}.`
                    : 'Não foi possível marcar a rota.';
            }));
        }
    }

    function render(data) {
        snapshot = data;
        el('org').textContent = data.organization ? data.organization.label : 'Sem organização';
        renderNetwork();
        renderOperation();
        status.textContent = `Atualizado às ${new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })}.`;
    }

    function selectTab(name) {
        activeTab = name;
        for (const tab of document.querySelectorAll('.tab')) {
            const selected = tab.dataset.tab === name;
            tab.setAttribute('aria-selected', String(selected));
            tab.tabIndex = selected ? 0 : -1;
        }
        el('panel-network').hidden = name !== 'network';
        el('panel-operation').hidden = name !== 'operation';
    }

    for (const tab of document.querySelectorAll('.tab')) {
        tab.addEventListener('click', () => selectTab(tab.dataset.tab));
    }

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data !== 'object') return;
        if (data.action !== 'exchange:state' || !data.data) return;
        render(data.data);
    });

    selectTab(activeTab);

    async function requestState() {
        const response = await post('phone:requestState', {});
        if (!response || !response.ok) {
            status.textContent = `Não foi possível falar com a rede (${resourceName}).`;
        }
    }

    void requestState();
    window.setInterval(() => { void requestState(); }, 30000);
})();
