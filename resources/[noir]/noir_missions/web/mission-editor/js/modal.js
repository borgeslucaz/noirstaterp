// Janela central (DESIGN_v4 §6): pilha de janelas com overlay, foco preso, Esc cancela e a
// tecla não vaza para trás (stopPropagation no keydown da janela; o roteador global também
// consulta isWindowOpen()). Rodapé em duas metades: cancelar à esquerda, ação à direita.
import { el, icon, setBusy } from './dom.js';

/** @type {{ api: any, overlay: HTMLElement, opener: Element|null, owner: string }[]} */
const stack = [];
const listeners = new Set();

export function isWindowOpen() {
    return stack.length > 0;
}

/** Avisa quem mostra teclas visíveis: com janela aberta elas somem (§6). */
export function onWindowsChange(fn) {
    listeners.add(fn);
}

function changed() {
    for (const fn of listeners) fn(stack.length);
}

/** Esc vindo do roteador global quando o foco escapou da janela. */
export function cancelTop() {
    const top = stack[stack.length - 1];
    if (top) top.api.cancel();
}

/** Fecha as janelas de um dono ('editor' ou 'offer'); a oferta não cai junto com o editor. */
export function closeAll(owner = 'editor') {
    for (const entry of [...stack].reverse()) if (entry.owner === owner) entry.api.close();
}

const FOCUSABLE = 'button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])';

/**
 * @param {object} options
 * @param {string} options.title
 * @param {boolean} [options.wide]
 * @param {(api: any) => (Node|null)[]} options.content
 * @param {{label?: string}|null} [options.cancel] metade esquerda; null = sem botão de cancelar
 * @param {{label: string, kind?: string, run: (api: any) => any}|null} [options.action]
 *        run devolve false (ou Promise<false>) para manter a janela aberta
 * @param {'cancel'|'action'|'input'} [options.focus]
 * @param {() => void} [options.onCancel]
 * @param {HTMLElement} [options.layer]
 * @param {string} [options.owner] 'editor' (padrão) ou 'offer'
 */
export function openWindow(options) {
    const layer = options.layer || document.getElementById('windows');
    const opener = document.activeElement;
    const overlay = el('div', 'win-overlay');
    const win = el('section', { class: options.wide ? 'win wide' : 'win', role: 'dialog', 'aria-modal': 'true', 'aria-label': options.title });
    const titleNode = el('h2', { class: 'win-title', text: options.title });
    const body = el('div', 'win-body');
    let closed = false;

    const api = {
        root: win,
        body,
        closed: () => closed,
        setTitle(text) { titleNode.textContent = text; },
        close() {
            if (closed) return;
            closed = true;
            const index = stack.findIndex((entry) => entry.api === api);
            if (index >= 0) stack.splice(index, 1);
            overlay.remove();
            if (opener && opener instanceof HTMLElement && opener.isConnected) opener.focus({ preventScroll: true });
            changed();
        },
        cancel() {
            if (closed) return;
            if (options.onCancel) options.onCancel();
            api.close();
        },
        async submit() {
            if (closed || !options.action || actionBtn.disabled || actionBtn.getAttribute('aria-busy')) return;
            setBusy(actionBtn, true);
            let keep = false;
            try {
                keep = (await options.action.run(api)) === false;
            } finally {
                setBusy(actionBtn, false);
            }
            if (!keep) api.close();
        },
    };

    const closeBtn = el('button', { type: 'button', class: 'icon-btn lg', 'aria-label': 'Fechar', title: 'Fechar', on: { click: () => api.cancel() } }, icon('close', 18));
    win.append(el('header', 'win-head', titleNode, closeBtn), body);

    for (const node of options.content(api) || []) if (node) body.append(node);

    const foot = el('footer', 'win-foot');
    let cancelBtn = null;
    let actionBtn = null;
    if (options.cancel !== null) {
        cancelBtn = el('button', { type: 'button', class: 'btn', text: options.cancel?.label || 'CANCELAR', on: { click: () => api.cancel() } });
        foot.append(cancelBtn);
    }
    if (options.action) {
        actionBtn = el('button', { type: 'button', class: `btn ${options.action.kind || 'confirm'}`, text: options.action.label, on: { click: () => api.submit() } });
        foot.append(actionBtn);
    }
    if (foot.children.length === 1) foot.style.gridTemplateColumns = '1fr';
    if (foot.children.length) win.append(foot);
    api.actionButton = actionBtn;
    api.cancelButton = cancelBtn;

    win.addEventListener('keydown', (event) => {
        // A janela é dona do teclado enquanto aberta: nada sobe para o roteador global.
        event.stopPropagation();
        if (stack[stack.length - 1]?.api !== api) return;
        if (event.key === 'Escape') {
            event.preventDefault();
            api.cancel();
        } else if (event.key === 'Tab') {
            const nodes = [...win.querySelectorAll(FOCUSABLE)].filter((node) => node.offsetParent !== null);
            if (!nodes.length) return;
            const first = nodes[0];
            const last = nodes[nodes.length - 1];
            if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
            else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
        } else if (event.key === 'Enter' && event.target instanceof HTMLInputElement && options.action) {
            event.preventDefault();
            api.submit();
        }
    });
    // Clique fora não fecha: evita perder digitação por acidente.
    overlay.addEventListener('mousedown', (event) => { if (event.target === overlay) event.preventDefault(); });

    overlay.append(win);
    layer.append(overlay);
    stack.push({ api, overlay, opener, owner: options.owner || 'editor' });
    changed();

    requestAnimationFrame(() => {
        let target = null;
        if (options.focus === 'action') target = actionBtn;
        else if (options.focus === 'input') target = body.querySelector('input, textarea, select');
        else if (options.focus === 'cancel') target = cancelBtn;
        target = target || cancelBtn || body.querySelector(FOCUSABLE) || closeBtn;
        target.focus({ preventScroll: true });
    });
    return api;
}

/**
 * Confirmação simples. Foco inicial em Cancelar (§6: Enter sem querer não executa).
 * @returns {Promise<boolean>}
 */
export function confirmWindow({ title, object, detail, text, actionLabel, kind = 'danger', cancelLabel }) {
    return new Promise((resolve) => {
        openWindow({
            title,
            content: () => [
                object ? el('div', 'win-object', object, detail ? el('small', { text: detail }) : null) : null,
                text ? el('p', { text }) : null,
            ],
            cancel: { label: cancelLabel || 'CANCELAR' },
            action: { label: actionLabel, kind, run: () => resolve(true) },
            onCancel: () => resolve(false),
            focus: 'cancel',
        });
    });
}
