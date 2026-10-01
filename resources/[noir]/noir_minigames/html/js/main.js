// noir_minigames: ponte com o cliente Lua. Mensagens fora da allowlist são ignoradas.
// Fora do jogo (navegador) liga o preview com um botão por jogo (DESIGN_v4 §10).

'use strict';

const IN_GAME = typeof window.invokeNative === 'function' || typeof GetParentResourceName === 'function';
const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'noir_minigames';

async function post(endpoint, payload) {
    if (!IN_GAME) return;
    try {
        await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(payload || {}),
        });
    } catch (_) {
        // O cliente tem limite de tempo próprio; nada a fazer aqui.
    }
}

const HANDLERS = {
    'noir_minigames:play': async (msg) => {
        if (NoirMG.busy()) return;
        const passed = await NoirMG.play(String(msg.kind || ''), Number(msg.difficulty) || 2);
        post('result', { passed: passed === true });
    },
    'noir_minigames:abort': () => NoirMG.abort(),
};

window.addEventListener('message', (event) => {
    const msg = event.data || {};
    const handler = HANDLERS[msg.action];
    if (handler) handler(msg);
});

function preview() {
    document.documentElement.style.setProperty('background', '#2a2f36 !important');
    document.body.style.setProperty('background', 'linear-gradient(135deg, #1d2127, #3a3f47) !important');

    const bar = document.createElement('div');
    bar.className = 'mg-preview';

    const select = document.createElement('select');
    for (const [value, label] of [[1, 'Fácil'], [2, 'Normal'], [3, 'Difícil']]) {
        const option = document.createElement('option');
        option.value = String(value);
        option.textContent = label;
        if (value === 2) option.selected = true;
        select.append(option);
    }
    bar.append(select);

    for (const { kind, title } of NoirMG.list()) {
        const button = document.createElement('button');
        button.className = 'mg-btn';
        button.textContent = title;
        button.addEventListener('click', async () => {
            if (NoirMG.busy()) return;
            bar.classList.add('hidden');
            const passed = await NoirMG.play(kind, Number(select.value));
            console.log(`[preview] ${kind}: ${passed ? 'passou' : 'falhou'}`);
            bar.classList.remove('hidden');
        });
        bar.append(button);
    }
    document.body.append(bar);
}

window.addEventListener('load', () => {
    if (IN_GAME) post('uiReady', {});
    else preview();
});
