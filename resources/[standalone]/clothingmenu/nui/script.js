const app = document.getElementById('app');
const layer = document.getElementById('anchor-layer');
const label = document.getElementById('item-label');
const labelName = document.getElementById('item-name');
const labelStatus = document.getElementById('item-status');
const targetInfo = document.getElementById('target-info');
const targetName = document.getElementById('target-name');
const toastStack = document.getElementById('toast-stack');
const closeButton = document.getElementById('close-button');

let items = [];
let activeLabelId = null;
const anchors = new Map();

const iconPaths = {
    mask: '<path d="M7 8c0-2 2-4 5-4s5 2 5 4v3c0 4-2 7-5 7s-5-3-5-7V8z"/><path d="M9 10h2M13 10h2M10 14c1 .8 3 .8 4 0"/>',
    hat: '<path d="M5 13h14"/><path d="M8 13l1-6c2-1 4-1 6 0l1 6"/><path d="M3 15c4 2 14 2 18 0"/>',
    glasses: '<circle cx="8" cy="12" r="3"/><circle cx="16" cy="12" r="3"/><path d="M11 12h2M5 11l-2-1M19 11l2-1"/>',
    jacket: '<path d="M8 5l4 3 4-3 3 4-2 2v8H7v-8L5 9l3-4z"/><path d="M12 8v11"/>',
    pants: '<path d="M8 5h8l1 15h-4l-1-8-1 8H7L8 5z"/>',
    shoes: '<path d="M4 15c3 1 6 1 9 0l2 2h5v2H4v-4z"/><path d="M7 14l1-4"/>',
    bag: '<rect x="6" y="8" width="12" height="11" rx="2"/><path d="M9 8V7a3 3 0 0 1 6 0v1"/><path d="M9 12h6"/>',
    vest: '<path d="M8 5l4 3 4-3 2 4-2 2v8H8v-8L6 9l2-4z"/><path d="M10 9v10M14 9v10"/>',
    watch: '<rect x="8" y="8" width="8" height="8" rx="2"/><path d="M10 3h4l1 5H9l1-5zM9 16h6l-1 5h-4l-1-5z"/>',
    necklace: '<path d="M7 5c1 7 3 11 5 11s4-4 5-11"/><path d="M12 16l-2 4h4l-2-4z"/>',
    default: '<circle cx="12" cy="12" r="7"/><path d="M12 8v8M8 12h8"/>'
};

const labelToIcon = {
    'máscara': 'mask',
    'chapeu': 'hat',
    'chapéu': 'hat',
    'óculos': 'glasses',
    jaqueta: 'jacket',
    calça: 'pants',
    sapatos: 'shoes',
    mochila: 'bag',
    colete: 'vest',
    relógio: 'watch',
    colar: 'necklace'
};

function nuiPost(name, payload = {}) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload)
    }).catch(() => {});
}

function iconFor(item) {
    const key = labelToIcon[String(item.label || '').toLowerCase()] || 'default';
    return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${iconPaths[key]}</svg>`;
}

function applyColors(colors) {
    if (!colors) return;
    const root = document.documentElement.style;
    if (colors.primary) root.setProperty('--primary', colors.primary);
    if (colors.secondary) root.setProperty('--secondary', colors.secondary);
    if (colors.accent) root.setProperty('--accent', colors.accent);
    if (colors.text) root.setProperty('--text', colors.text);
}

function setupMenu(nextItems = [], colors) {
    items = nextItems;
    anchors.clear();
    layer.replaceChildren();
    applyColors(colors);

    items.forEach((item, index) => {
        const size = Number(item.size) || 58;
        const button = document.createElement('button');
        button.className = 'clothing-anchor';
        button.type = 'button';
        button.dataset.id = String(index);
        button.style.width = `${size}px`;
        button.style.height = `${size}px`;
        button.style.left = `${item.x || 50}%`;
        button.style.top = `${item.y || 50}%`;
        button.setAttribute('aria-label', item.label || 'Item de roupa');
        button.innerHTML = `${iconFor(item)}<span class="anchor-index">${index + 1}</span>`;

        button.addEventListener('mouseenter', () => showLabel(index));
        button.addEventListener('focus', () => showLabel(index));
        button.addEventListener('mouseleave', hideLabel);
        button.addEventListener('blur', hideLabel);
        button.addEventListener('click', () => nuiPost('toggleItem', { index }));

        anchors.set(index, button);
        layer.appendChild(button);
    });
}

function setOpen(open) {
    app.classList.toggle('is-open', open);
    app.setAttribute('aria-hidden', open ? 'false' : 'true');
    if (!open) {
        hideLabel();
        hideTargetInfo();
    }
}

function showTargetInfo(name) {
    targetName.textContent = name || 'JOGADOR';
    targetInfo.hidden = false;
}

function hideTargetInfo() {
    targetInfo.hidden = true;
}

function showLabel(index) {
    const item = items[index];
    const anchor = anchors.get(index);
    if (!item || !anchor) return;

    activeLabelId = index;
    const rect = anchor.getBoundingClientRect();
    const isOff = anchor.classList.contains('is-off');

    labelName.textContent = item.label || 'SELECIONE';
    labelStatus.textContent = isOff ? 'REMOVIDO' : 'PRONTO';
    label.style.left = `${rect.left + rect.width / 2}px`;
    label.style.top = `${Math.max(72, rect.top - 12)}px`;
    label.hidden = false;
    requestAnimationFrame(() => label.classList.add('is-visible'));
    anchor.classList.add('is-selected');
}

function hideLabel() {
    if (activeLabelId !== null) {
        const anchor = anchors.get(activeLabelId);
        if (anchor) anchor.classList.remove('is-selected');
    }
    activeLabelId = null;
    label.classList.remove('is-visible');
    window.setTimeout(() => {
        if (activeLabelId === null) label.hidden = true;
    }, 120);
}

function updateState(states = {}) {
    anchors.forEach((anchor, index) => {
        const active = !!states[index + 1] || !!states[index];
        anchor.classList.toggle('is-off', !active);
        anchor.classList.toggle('is-active', active);
        anchor.setAttribute('aria-pressed', active ? 'true' : 'false');
    });

    if (activeLabelId !== null) showLabel(activeLabelId);
}

function updatePositions(nextPositions = []) {
    nextPositions.forEach((position, index) => {
        const anchor = anchors.get(index);
        if (!anchor || !position) return;

        if (position.visible === false) {
            anchor.classList.add('is-hidden');
            return;
        }

        anchor.classList.remove('is-hidden');
        anchor.style.left = `${position.x}%`;
        anchor.style.top = `${position.y}%`;
    });

    if (activeLabelId !== null) showLabel(activeLabelId);
}

function showNotification(message) {
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message || 'Ação indisponível';
    toastStack.appendChild(toast);
    window.setTimeout(() => toast.remove(), 2800);
}

window.addEventListener('message', (event) => {
    const data = event.data || {};

    if (data.type === 'open') {
        setupMenu(data.items, data.colors);
        setOpen(true);
        updateState(data.states);
        if (data.isTarget && data.targetName) showTargetInfo(data.targetName);
        else hideTargetInfo();
        return;
    }

    if (data.type === 'close') {
        setOpen(false);
        return;
    }

    if (data.type === 'updateState') updateState(data.states);
    if (data.type === 'notification') showNotification(data.message);
    if (data.type === 'updatePositions') updatePositions(data.items);
});

window.addEventListener('keyup', (event) => {
    if (event.key === 'Escape' || event.key === 'Backspace') nuiPost('close');
});

closeButton.addEventListener('click', () => nuiPost('close'));
