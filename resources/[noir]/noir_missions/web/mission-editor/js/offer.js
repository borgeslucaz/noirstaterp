// Oferta de missão ("ligação"): janela central com RECUSAR / ACEITAR e contagem regressiva.
// Foco inicial em RECUSAR; Esc recusa; acabou o tempo = recusa automática.
import { el, icon } from './dom.js';
import { fetchNui } from './nui.js';
import { openWindow } from './modal.js';

let current = null;

function finish(accept) {
    if (!current) return;
    const { offerId, api, timer } = current;
    current = null;
    clearInterval(timer);
    if (!api.closed()) api.close();
    fetchNui('offerAnswer', { offerId, accept });
}

/** hud:offer */
export function showOffer(data) {
    if (!data) return;
    // Oferta nova substitui a anterior sem responder por ela (o Lua já a trocou).
    if (current) closeOffer({ offerId: current.offerId });
    const seconds = Math.max(1, Math.round(Number(data.seconds) || 30));
    const endAt = Date.now() + seconds * 1000;
    const countdown = el('span', 'num');
    const update = () => {
        const left = Math.max(0, Math.ceil((endAt - Date.now()) / 1000));
        countdown.textContent = `${left} s`;
        return left;
    };
    update();

    const api = openWindow({
        title: data.title || 'Chamada',
        content: () => [
            el('div', 'offer-caller', icon('phone', 18), el('span', { text: data.caller || 'Desconhecido' })),
            data.text ? el('p', { class: 'offer-text', text: data.text }) : null,
            el('div', 'offer-expire', 'Expira em ', countdown),
        ],
        cancel: { label: 'RECUSAR' },
        action: { label: 'ACEITAR', kind: 'confirm', run: () => { finish(true); } },
        onCancel: () => finish(false),
        focus: 'cancel',
        owner: 'offer',
    });
    api.root.classList.add('offer-win');

    const timer = setInterval(() => {
        if (update() <= 0) finish(false);
    }, 250);
    current = { offerId: data.offerId, api, timer };
}

/** hud:offerClose — fecha sem responder. */
export function closeOffer(data) {
    if (!current) return;
    if (data && data.offerId !== undefined && data.offerId !== current.offerId) return;
    const { api, timer } = current;
    current = null;
    clearInterval(timer);
    if (!api.closed()) api.close();
}

export function offerOpen() {
    return !!current;
}
