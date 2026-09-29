const resource = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'noir_burnerphone';
const pageNames = ['home', 'contracts', 'illegal', 'street'];
const phone = document.querySelector('.phone');

let closing = false;
let closeTimer;

async function post(callback, data = {}) {
    try {
        const response = await fetch(`https://${resource}/${callback}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return response.ok ? response.json().catch(() => ({ ok: true })) : { ok: false };
    } catch {
        return { ok: false };
    }
}

function setPage(name) {
    if (!pageNames.includes(name)) return;
    pageNames.forEach((pageName) => {
        const page = document.getElementById(`${pageName}-page`);
        const active = pageName === name;
        page.hidden = !active;
        page.classList.toggle('active', active);
    });
}

function closePhone() {
    if (!closing) void post('close');
}

function hidePhone() {
    if (!document.body.classList.contains('open')) {
        clearTimeout(closeTimer);
        document.body.classList.remove('open', 'closing');
        phone.hidden = true;
        phone.setAttribute('aria-hidden', 'true');
        closing = false;
        return;
    }
    if (closing) return;

    closing = true;
    document.body.classList.add('closing');
    clearTimeout(closeTimer);
    closeTimer = setTimeout(() => {
        document.body.classList.remove('open', 'closing');
        phone.hidden = true;
        phone.setAttribute('aria-hidden', 'true');
        closing = false;
        setPage('home');
    }, 180);
}

function applyActivities(value) {
    const activities = value && typeof value === 'object' ? value : {};
    const streetEnabled = activities.drugSales === true;
    document.getElementById('street-activity').hidden = !streetEnabled;
    document.getElementById('no-activities').hidden = streetEnabled;
}

// Contracts ---------------------------------------------------------------
// The NUI is never the source of truth: it renders the snapshot it was given
// and replaces it wholesale with whatever the server returns after an action.
const contractsUI = (() => {
    const lists = {
        active: document.getElementById('active-contracts'),
        available: document.getElementById('available-contracts'),
    };
    const toggles = Array.from(document.querySelectorAll('[data-toggle]'));
    const errorBox = document.getElementById('contract-error');
    if (!lists.active || !lists.available || !errorBox) {
        return { apply() {}, reset() {}, load() {} };
    }

    const ICONS = {
        route: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a7 7 0 0 0-7 7c0 5.2 7 13 7 13s7-7.8 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5Z"/></svg>',
        abandon: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M18.3 5.7 12 12l6.3 6.3-1.4 1.4L10.6 13.4 4.3 19.7 2.9 18.3 9.2 12 2.9 5.7l1.4-1.4 6.3 6.3 6.3-6.3 1.4 1.4Z"/></svg>',
    };
    const EMPTY_TEXT = { active: 'Nenhum contrato ativo', available: 'Nenhum contrato disponível' };

    let snapshot = { active: [], available: [] };
    const expanded = { active: true, available: true };
    const pending = new Set();
    let confirmingId = null;
    let openOfferId = null;
    let messageTimer;

    function normalize(value) {
        const source = value && typeof value === 'object' ? value : {};
        const clean = (list, keys) => (Array.isArray(list) ? list : [])
            .filter((entry) => entry && typeof entry === 'object' && typeof entry.id === 'string')
            .map((entry) => {
                const out = {};
                keys.forEach((key) => { out[key] = entry[key]; });
                return out;
            });
        return {
            active: clean(source.active, ['id', 'label', 'status', 'canResume', 'canAbandon']),
            available: clean(source.available, ['id', 'label', 'tier', 'difficulty']),
        };
    }

    function showMessage(text, kind) {
        clearTimeout(messageTimer);
        errorBox.textContent = text || '';
        errorBox.classList.toggle('success', kind === 'success');
        errorBox.hidden = !text;
        if (text) messageTimer = setTimeout(() => { errorBox.hidden = true; }, 4000);
    }

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined) node.textContent = text;
        return node;
    }

    function iconButton(kind, label, onClick, disabled) {
        const button = el('button', `icon-action ${kind}`);
        button.type = 'button';
        button.setAttribute('aria-label', label);
        button.title = label;
        button.innerHTML = ICONS[kind];
        button.disabled = disabled;
        button.addEventListener('click', onClick);
        return button;
    }

    function renderActive(entry) {
        const row = el('div', 'contract-row');
        row.setAttribute('role', 'listitem');
        const main = el('div', 'contract-row-main');
        main.appendChild(el('span', 'contract-label', entry.label || 'Contrato'));

        const busy = pending.has(entry.id);
        const actions = el('div', 'contract-actions');
        if (entry.canResume !== false) {
            actions.appendChild(iconButton('route', 'Marcar localização no mapa',
                () => void act('resumeContract', entry.id), busy));
        }
        if (entry.canAbandon !== false) {
            actions.appendChild(iconButton('abandon', 'Abandonar contrato', () => {
                confirmingId = confirmingId === entry.id ? null : entry.id;
                render();
            }, busy));
        }
        main.appendChild(actions);
        row.appendChild(main);

        if (confirmingId === entry.id) {
            const confirm = el('div', 'contract-confirm');
            confirm.appendChild(el('span', null, 'Abandonar este contrato?'));
            const yes = el('button', 'mini-action danger', 'Abandonar');
            yes.type = 'button';
            yes.disabled = busy;
            yes.addEventListener('click', () => void act('abandonContract', entry.id));
            const no = el('button', 'mini-action', 'Cancelar');
            no.type = 'button';
            no.disabled = busy;
            no.addEventListener('click', () => { confirmingId = null; render(); });
            confirm.append(yes, no);
            row.appendChild(confirm);
        }
        return row;
    }

    function renderAvailable(entry) {
        const row = el('div', 'contract-row');
        row.setAttribute('role', 'listitem');
        const isOpen = openOfferId === entry.id;
        const offer = el('button', 'contract-offer', entry.label || 'Contrato');
        offer.type = 'button';
        offer.setAttribute('aria-expanded', String(isOpen));
        offer.addEventListener('click', () => {
            openOfferId = isOpen ? null : entry.id;
            render();
        });
        row.appendChild(offer);

        if (isOpen) {
            const detail = el('div', 'contract-detail');
            detail.appendChild(el('p', 'contract-detail-name', entry.label || 'Contrato'));
            if (entry.difficulty) detail.appendChild(el('p', 'contract-detail-meta', `Risco: ${entry.difficulty}`));
            const accept = el('button', 'primary-action', 'Aceitar contrato');
            accept.type = 'button';
            accept.disabled = pending.has(entry.id);
            accept.addEventListener('click', () => void act('acceptContract', entry.id));
            detail.appendChild(accept);
            row.appendChild(detail);
        }
        return row;
    }

    function render() {
        toggles.forEach((toggle) => {
            const key = toggle.dataset.toggle;
            if (key in expanded) toggle.setAttribute('aria-expanded', String(expanded[key]));
        });
        ['active', 'available'].forEach((key) => {
            const list = lists[key];
            list.replaceChildren();
            list.hidden = !expanded[key];
            const entries = snapshot[key];
            if (!entries.length) {
                list.appendChild(el('p', 'contract-empty', EMPTY_TEXT[key]));
                return;
            }
            entries.forEach((entry) => {
                list.appendChild(key === 'active' ? renderActive(entry) : renderAvailable(entry));
            });
        });
    }

    function apply(value) {
        snapshot = normalize(value);
        const ids = new Set([...snapshot.active, ...snapshot.available].map((entry) => entry.id));
        if (confirmingId && !ids.has(confirmingId)) confirmingId = null;
        if (openOfferId && !ids.has(openOfferId)) openOfferId = null;
        render();
    }

    async function act(callback, id) {
        if (pending.has(id)) return;
        pending.add(id);
        render();
        const response = await post(callback, { id });
        pending.delete(id);
        if (response && response.ok) {
            confirmingId = null;
            openOfferId = null;
            if (callback === 'resumeContract') showMessage('Endereço marcado no GPS.', 'success');
            else showMessage('');
            apply(response.contracts);
        } else {
            showMessage((response && response.error) || 'Não foi possível concluir a ação.');
            render();
        }
    }

    async function load() {
        const response = await post('loadContracts');
        if (response && response.ok && response.contracts) apply(response.contracts);
    }

    function reset() {
        expanded.active = true;
        expanded.available = true;
        pending.clear();
        confirmingId = null;
        openOfferId = null;
        showMessage('');
        render();
    }

    toggles.forEach((toggle) => {
        toggle.addEventListener('click', () => {
            const key = toggle.dataset.toggle;
            if (!(key in expanded)) return;
            expanded[key] = !expanded[key];
            render();
        });
    });

    render();
    return { apply, reset, load };
})();

document.getElementById('close-phone').addEventListener('click', closePhone);
document.querySelectorAll('[data-page]').forEach((element) => {
    element.addEventListener('click', () => setPage(element.dataset.page));
});
document.querySelectorAll('[data-page="contracts"]').forEach((element) => {
    element.addEventListener('click', () => void contractsUI.load());
});

document.getElementById('start-street-sale').addEventListener('click', async () => {
    await post('startActivity', { id: 'drugSales' });
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') return;

    if (data.action === 'burner:open') {
        clearTimeout(closeTimer);
        closing = false;
        document.body.classList.remove('closing');
        phone.hidden = false;
        document.body.classList.add('open');
        phone.setAttribute('aria-hidden', 'false');
        applyActivities(data.activities);
        contractsUI.reset();
        contractsUI.apply(data.contracts);
        setPage('home');
    } else if (data.action === 'burner:state') {
        applyActivities(data.activities);
    } else if (data.action === 'burner:contracts') {
        contractsUI.apply(data.contracts);
    } else if (data.action === 'burner:close') {
        hidePhone();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape' || !document.body.classList.contains('open')) return;
    event.preventDefault();
    closePhone();
});

window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.remove('open', 'closing');
    phone.hidden = true;
    phone.setAttribute('aria-hidden', 'true');
    setPage('home');
    void post('ready');
});
