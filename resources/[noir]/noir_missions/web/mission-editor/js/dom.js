// Construção de DOM sem innerHTML: todo texto vindo de dado entra por textContent.

/**
 * @param {string} tag
 * @param {string|object|null} [props] classe (string) ou { class, text, attrs, on, ... }
 * @param {...(Node|string|null|false|undefined)} children
 */
export function el(tag, props, ...children) {
    const node = document.createElement(tag);
    if (typeof props === 'string') {
        node.className = props;
    } else if (props) {
        for (const [key, value] of Object.entries(props)) {
            if (value === undefined || value === null || value === false) continue;
            if (key === 'class') node.className = value;
            else if (key === 'text') node.textContent = String(value);
            else if (key === 'on') for (const [evt, fn] of Object.entries(value)) node.addEventListener(evt, fn);
            else if (key === 'dataset') Object.assign(node.dataset, value);
            else if (key in node && typeof value !== 'string') node[key] = value;
            else if (key === 'value' || key === 'checked' || key === 'disabled' || key === 'hidden') node[key] = value;
            else node.setAttribute(key, value === true ? '' : String(value));
        }
    }
    append(node, children);
    return node;
}

function append(node, children) {
    for (const child of children) {
        if (child === null || child === undefined || child === false) continue;
        if (Array.isArray(child)) append(node, child);
        else node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
}

export function clear(node) {
    node.replaceChildren();
    return node;
}

const SVG_NS = 'http://www.w3.org/2000/svg';

// Ícones de traço simples, 24x24. Desenhados aqui para não depender de CDN nem de fonte.
const ICONS = {
    close: ['M6 6l12 12', 'M18 6L6 18'],
    plus: ['M12 5v14', 'M5 12h14'],
    minus: ['M5 12h14'],
    up: ['M6 15l6-6 6 6'],
    down: ['M6 9l6 6 6-6'],
    copy: ['M9 9h10v10H9z', 'M5 15V5h10'],
    trash: ['M4 7h16', 'M9 7V4h6v3', 'M6 7l1 13h10l1-13'],
    alert: ['M12 3l10 18H2z', 'M12 10v5', 'M12 18v.01'],
    check: ['M5 12l5 5 9-10'],
    info: ['M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18', 'M12 11v6', 'M12 7.5v.01'],
    target: ['M12 3a9 9 0 1 0 0 18a9 9 0 1 0 0-18', 'M12 1v5', 'M12 18v5', 'M1 12h5', 'M18 12h5'],
    teleport: ['M5 12h12', 'M13 6l6 6-6 6'],
    eye: ['M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z', 'M12 9a3 3 0 1 0 0 6a3 3 0 1 0 0-6'],
    grip: ['M9 6v.01', 'M15 6v.01', 'M9 12v.01', 'M15 12v.01', 'M9 18v.01', 'M15 18v.01'],
    branch: ['M6 4v16', 'M6 12h6a6 6 0 0 0 6-6V4'],
    phone: ['M5 4h4l2 5-3 2a11 11 0 0 0 5 5l2-3 5 2v4a2 2 0 0 1-2 2A17 17 0 0 1 3 6a2 2 0 0 1 2-2'],
};

/**
 * @param {keyof typeof ICONS} name
 * @param {number} [size]
 */
export function icon(name, size = 16) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('width', String(size));
    svg.setAttribute('height', String(size));
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', name === 'grip' ? '3' : '2');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');
    for (const d of ICONS[name] || []) {
        const path = document.createElementNS(SVG_NS, 'path');
        path.setAttribute('d', d);
        svg.append(path);
    }
    return svg;
}

/** Botão de ícone com rótulo acessível. */
export function iconButton(name, label, onClick, extraClass = '') {
    return el('button', {
        type: 'button',
        class: `icon-btn ${extraClass}`.trim(),
        title: label,
        'aria-label': label,
        on: { click: onClick },
    }, icon(name));
}

/** Botão de texto v4. kind: '' | 'confirm' | 'danger' | 'ghost'; small opcional. */
export function button(label, onClick, kind = '', extra = {}) {
    return el('button', {
        type: 'button',
        class: ['btn', kind, extra.small ? 'small' : ''].filter(Boolean).join(' '),
        on: { click: onClick },
        disabled: extra.disabled,
        title: extra.title,
    }, extra.icon ? icon(extra.icon, 14) : null, label);
}

/** Liga/desliga o estado de carregando de um botão (§5: spinner + aria-busy). */
export function setBusy(btn, busy) {
    if (!btn) return;
    if (busy) btn.setAttribute('aria-busy', 'true');
    else btn.removeAttribute('aria-busy');
}

/** Aviso v4: filete semântico + ícone + texto. tone: warning | danger | success | info */
export function notice(tone, text) {
    const iconName = tone === 'success' ? 'check' : tone === 'info' ? 'info' : 'alert';
    return el('div', { class: 'notice', dataset: { tone }, role: tone === 'danger' ? 'alert' : 'status' },
        icon(iconName, 16), el('div', { class: 'notice-text', text }));
}

export function pad2(value) {
    return String(value).padStart(2, '0');
}
