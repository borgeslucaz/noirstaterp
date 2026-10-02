// Preview no navegador (DESIGN_v4 §10). Simula o Lua mandando mensagens para a NUI real no
// iframe; os callbacks da NUI caem no mock (web/mission-editor/js/mock.js).
//   ?preset=editor|list|hud|offer|info abre um cenário direto.
const frame = document.getElementById('nui');
const nui = () => frame.contentWindow;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function send(action, data = {}) {
    nui().postMessage({ action, data }, '*');
}

async function waitFor(read, timeout = 8000) {
    const start = Date.now();
    for (;;) {
        const value = read();
        if (value) return value;
        if (Date.now() - start > timeout) throw new Error('preview: tempo esgotado esperando a NUI');
        await sleep(40);
    }
}

async function mock() {
    if (frame.contentDocument?.readyState !== 'complete') await new Promise((resolve) => frame.addEventListener('load', resolve, { once: true }));
    const api = await waitFor(() => nui().__noirMock);
    await api.ready;
    return api;
}

const scenarios = {
    async editor() {
        const api = await mock();
        send('editor:open', await api.openPayload());
    },
    async mission() {
        await scenarios.editor();
        const dev = await waitFor(() => nui().__noirDev);
        await sleep(50);
        await dev.openMission('meth_elysian_precursors');
    },
    async objective(expanded = true) {
        await mock();
        send('hud:objective', {
            visible: true,
            title: 'Elysian Chemical Shipment',
            text: 'Carregue os tambores químicos na van.',
            progress: { current: 3, max: 4 },
            timer: null,
            expanded,
            toggleKey: 'J',
            completed: [
                { text: 'Vá até o galpão em Elysian Island.' },
                { text: 'Encontre informações sobre o carregamento.' },
            ],
            infos: [{
                title: 'Manifesto de carga',
                lines: [
                    { label: 'Carga', value: 'Solvente Industrial X-9' },
                    { label: 'Lote', value: 'C-17' },
                    { label: 'Armazenado', value: 'Galpão C' },
                ],
            }],
        });
    },
    async compact() {
        await scenarios.objective(false);
    },
    async info() {
        await mock();
        send('hud:info', {
            title: 'Manifesto de carga',
            lines: [
                { label: 'Carga', value: 'Solvente Industrial X-9' },
                { label: 'Lote', value: 'C-17' },
                { label: 'Armazenado', value: 'Galpão C' },
            ],
            seconds: 12,
        });
    },
    async offer() {
        await mock();
        send('hud:offer', {
            offerId: `offer_${Date.now()}`,
            caller: 'Contato',
            title: 'Chamada',
            text: 'Tem um carregamento de químico parado num galpão em Elysian. Quatro tambores. Topa?',
            seconds: 25,
        });
    },
    async reset() {
        await mock();
        send('editor:close');
        send('hud:reset');
    },
};

for (const button of document.querySelectorAll('[data-run]')) {
    button.addEventListener('click', () => scenarios[button.dataset.run]().catch((error) => console.error(error)));
}

const presets = {
    editor: ['mission'],
    list: ['editor'],
    hud: ['objective'],
    compact: ['compact', 'info'],
    offer: ['offer'],
    info: ['objective', 'info'],
};
const preset = new URLSearchParams(location.search).get('preset');
if (preset && presets[preset]) {
    (async () => {
        for (const name of presets[preset]) await scenarios[name]();
        document.documentElement.dataset.ready = 'true';
    })().catch((error) => console.error(error));
} else {
    document.documentElement.dataset.ready = 'true';
}
