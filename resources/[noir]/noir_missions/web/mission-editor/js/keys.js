// Teclas visíveis (DESIGN_v4 §7): pílulas no canto inferior direito, só do contexto atual.
// Somem com janela central aberta (§6) e durante o posicionamento no mundo.
import { el } from './dom.js';
import { isWindowOpen, onWindowsChange } from './modal.js';

let provider = () => [];
let suppressed = false;

/** @param {() => [string, string][]} fn devolve [tecla, rótulo] do contexto atual */
export function setKeyProvider(fn) {
    provider = fn;
    refreshKeys();
}

export function suppressKeys(value) {
    suppressed = value;
    refreshKeys();
}

export function refreshKeys() {
    const root = document.getElementById('keys');
    if (!root) return;
    const keys = suppressed || isWindowOpen() ? [] : provider();
    root.replaceChildren(...keys.map(([key, label]) => el('span', 'key', el('kbd', { text: key }), label)));
}

onWindowsChange(refreshKeys);
