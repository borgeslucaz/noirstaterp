// Casca do editor: painel na borda direita, troca de tela (lista ↔ missão), fechamento,
// posicionamento no mundo (o painel some inteiro) e teclado do editor.
import { el } from '../dom.js';
import { fetchNui } from '../nui.js';
import { closeAll } from '../modal.js';
import { setKeyProvider, suppressKeys, refreshKeys } from '../keys.js';
import { setFeedbackSink } from '../feedback.js';
import { prepareSchema, toArray } from '../forms/schema-util.js';
import { cancelPlacements } from '../forms/placement.js';
import { state, on, setMissions, setInstances } from './store.js';
import { renderHome, homeKeys } from './home.js';
import { renderMission, missionKeys, confirmLeave, goBack, save, errorsOpen, closeErrors } from './mission.js';
import { loadMission } from './api.js';
import { pushNotice } from './ui.js';

let root = null;
let panel = null;

const shell = { close: () => requestClose() };

function ensureRoot() {
    if (!root) root = document.getElementById('editor');
    return root;
}

function render() {
    ensureRoot();
    if (!state.open) { root.replaceChildren(); panel = null; return; }
    panel = el('section', { class: 'ed-panel', 'aria-label': 'Editor de missões' });
    root.replaceChildren(panel);
    if (state.screen === 'mission' && state.mission) renderMission(panel, shell);
    else renderHome(panel, shell);
    refreshKeys();
}

function populateLists() {
    const items = document.getElementById('dl-items');
    const weapons = document.getElementById('dl-weapons');
    items?.replaceChildren(...toArray(state.lists.items).map((item) => el('option', { value: item.name, label: item.label || item.name })));
    weapons?.replaceChildren(...toArray(state.lists.weapons).map((weapon) => el('option', { value: String(weapon) })));
}

/** editor:open */
export function openEditor(data) {
    if (!data || typeof data !== 'object') return;
    if (data.schema) state.S = prepareSchema(data.schema);
    if (!state.S) { console.error('[noir_missions] editor:open sem schema'); return; }
    const lists = data.lists || {};
    state.lists = { items: toArray(lists.items), minigames: toArray(lists.minigames), weapons: toArray(lists.weapons) };
    state.missions = toArray(data.missions);
    state.instances = toArray(data.instances);
    state.open = true;
    state.placement = false;
    state.screen = 'home';
    state.mission = null;
    populateLists();
    ensureRoot().hidden = false;
    render();
}

/** editor:close (vindo do Lua) — fecha sem perguntar. */
export function closeEditor() {
    state.open = false;
    state.mission = null;
    state.screen = 'home';
    state.placement = false;
    cancelPlacements();
    closeAll();
    suppressKeys(false);
    render();
}

/** X ou Esc na lista: pergunta se houver alteração e avisa o Lua. */
export async function requestClose() {
    if (state.screen === 'mission' && !(await confirmLeave())) return;
    closeEditor();
    await fetchNui('editorClose', {});
}

export function setPlacement(active) {
    state.placement = !!active;
    ensureRoot().classList.toggle('placing', state.placement);
    suppressKeys(state.placement);
}

export function setMissionsFromLua(missions) {
    setMissions(toArray(missions));
}

export function setInstancesFromLua(instances) {
    setInstances(toArray(instances));
}

/** Preview no navegador: abre direto uma missão. */
export async function devOpenMission(id) {
    if (!state.open) return false;
    return loadMission(id);
}

function isTyping(target) {
    return target instanceof HTMLElement && (target.matches('input, textarea, select') || target.isContentEditable);
}

/** Teclado do editor, chamado pelo roteador global quando não há janela central aberta. */
export function editorKey(event) {
    if (!state.open || state.placement) return false;
    const key = event.key;
    if ((event.ctrlKey || event.metaKey) && key.toLowerCase() === 's') {
        event.preventDefault();
        if (state.screen === 'mission') save();
        return true;
    }
    if (key === 'Escape') {
        event.preventDefault();
        if (state.screen === 'mission') {
            if (errorsOpen()) closeErrors();
            else goBack();
        } else {
            requestClose();
        }
        return true;
    }
    if (state.screen === 'home' && !isTyping(event.target) && (key === 'ArrowDown' || key === 'ArrowUp')) {
        // Seta fora da lista leva o foco para ela.
        const list = panel?.querySelector('.home-list');
        if (list && event.target !== list) { list.focus(); list.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: false })); }
        return true;
    }
    return false;
}

setFeedbackSink((tone, text) => pushNotice(tone, text));
setKeyProvider(() => {
    if (!state.open) return [];
    return state.screen === 'mission' ? missionKeys() : homeKeys();
});
on('screen', () => render());
on('keys', () => refreshKeys());
