// Entrada da NUI: roteia as mensagens do Lua para editor, HUD e oferta, e cuida do teclado
// global. Só depois do listener registrado avisa o Lua com uiReady.
import { fetchNui, isEnvBrowser } from './nui.js';
import { isWindowOpen, cancelTop } from './modal.js';
import { placementResult } from './forms/placement.js';
import {
    openEditor, closeEditor, setPlacement, setMissionsFromLua, setInstancesFromLua, editorKey, devOpenMission,
} from './editor/editor.js';
import { setObjective, showInfo, closeInfo, resetHud } from './hud.js';
import { showOffer, closeOffer } from './offer.js';

const handlers = {
    'editor:open': openEditor,
    'editor:close': closeEditor,
    'editor:missions': (data) => setMissionsFromLua(data?.missions),
    'editor:instances': (data) => setInstancesFromLua(data?.instances),
    'editor:placement': (data) => setPlacement(!!data?.active),
    'editor:placementResult': placementResult,
    'hud:objective': setObjective,
    'hud:info': showInfo,
    'hud:infoClose': closeInfo,
    'hud:offer': showOffer,
    'hud:offerClose': closeOffer,
    'hud:reset': () => { resetHud(); closeOffer(); },
};

window.addEventListener('message', (event) => {
    const message = event.data;
    if (!message || typeof message !== 'object' || typeof message.action !== 'string') return;
    const handler = handlers[message.action];
    if (!handler) return;
    try {
        handler(message.data ?? {});
    } catch (error) {
        console.error(`[noir_missions] ${message.action}`, error);
    }
});

// Janela central aberta é dona do teclado (DESIGN_v4 §6). O keydown de dentro dela já
// para nela; aqui só chega Esc com o foco fora (ex.: clicou no overlay).
document.addEventListener('keydown', (event) => {
    if (isWindowOpen()) {
        if (event.key === 'Escape') { event.preventDefault(); cancelTop(); }
        return;
    }
    editorKey(event);
});

if (isEnvBrowser()) {
    // Ganchos do preview (dev/index.html), só no navegador.
    window.__noirDev = { openMission: devOpenMission };
}

fetchNui('uiReady', {});
