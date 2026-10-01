// Peças visuais repetidas nas telas do editor: cabeçalho do painel, etiqueta de estado,
// avisos temporários e formatação de números/tempo.
import { el, icon } from '../dom.js';

export const STATUS_LABEL = { draft: 'Rascunho', published: 'Publicada', disabled: 'Desativada' };

export function statusTag(status) {
    const key = STATUS_LABEL[status] ? status : 'draft';
    return el('span', { class: `tag ${key}`, text: STATUS_LABEL[key] });
}

export function playersText(min, max) {
    if (!min && !max) return '—';
    if (!max || min === max) return String(min || max);
    return `${min || 1}–${max}`;
}

/** updatedAt/startedAt chegam em segundos (os.time); aceita milissegundos também. */
export function relativeTime(timestamp) {
    if (!timestamp) return '—';
    const ms = timestamp > 1e12 ? timestamp : timestamp * 1000;
    const diff = Math.max(0, Math.round((Date.now() - ms) / 1000));
    if (diff < 60) return 'agora';
    if (diff < 3600) return `há ${Math.floor(diff / 60)} min`;
    if (diff < 86400) return `há ${Math.floor(diff / 3600)} h`;
    const days = Math.floor(diff / 86400);
    if (days < 30) return `há ${days} ${days === 1 ? 'dia' : 'dias'}`;
    return new Date(ms).toLocaleDateString('pt-BR');
}

/**
 * Cabeçalho de painel (34 px + subtítulo 15 px) com X à direita.
 * @param {{title: string, subtitle?: string, onClose: () => void, after?: Node}} options
 */
export function panelHead({ title, subtitle, onClose, after }) {
    return el('header', 'ed-head',
        el('div', 'ed-head-text',
            el('h1', { class: 'ed-title', text: title }),
            subtitle ? el('div', { class: 'ed-subtitle', text: subtitle }) : null),
        after || null,
        el('button', { type: 'button', class: 'icon-btn lg', title: 'Fechar editor', 'aria-label': 'Fechar editor', on: { click: onClose } }, icon('close', 20)));
}

// Avisos do painel (faixa abaixo do cabeçalho). Um container por tela; some sozinho.
let noticeHost = null;

export function noticeArea() {
    noticeHost = el('div', { class: 'ed-notices', 'aria-live': 'polite' });
    return noticeHost;
}

export function pushNotice(tone, text) {
    if (!noticeHost || !noticeHost.isConnected) return;
    const iconName = tone === 'success' ? 'check' : tone === 'info' ? 'info' : 'alert';
    const node = el('div', { class: 'notice ed-notice', dataset: { tone } },
        icon(iconName, 16), el('div', { class: 'notice-text', text }),
        el('button', { type: 'button', class: 'icon-btn notice-close', 'aria-label': 'Dispensar', title: 'Dispensar', on: { click: () => node.remove() } }, icon('close', 14)));
    // Um aviso por vez: o mais novo substitui, para não cobrir o formulário com uma pilha.
    noticeHost.replaceChildren(node);
    setTimeout(() => node.remove(), tone === 'danger' ? 9000 : 5000);
}

export function sectionHead(title, help, right) {
    return el('div', 'sec-head',
        el('div', 'sec-head-text',
            el('h2', { class: 'sec-title', text: title }),
            help ? el('p', { class: 'sec-help', text: help }) : null),
        right || null);
}

export function clearNotices() {
    noticeHost?.replaceChildren();
}
