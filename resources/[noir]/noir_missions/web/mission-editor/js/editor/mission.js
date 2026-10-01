// Tela da missão: cabeçalho com estado/salvar/publicar, navegação lateral por seção e a área
// de conteúdo. Seção = Geral, Passos, Gatilhos, uma por coleção do esquema e Teste.
import { el, button, icon } from '../dom.js';
import { confirmWindow } from '../modal.js';
import { notify } from '../feedback.js';
import { state, on, emit, markDirty } from './store.js';
import { saveMission, setStatus } from './api.js';
import { panelHead, noticeArea, statusTag, clearNotices } from './ui.js';
import { toArray } from '../forms/schema-util.js';
import { readableNames } from './refs.js';
import { renderGeneral } from './sections/general.js';
import { renderSteps } from './sections/steps.js';
import { renderCollection } from './sections/collection.js';
import { renderTest } from './sections/test.js';

let refs = null;
let shellRef = null;

/** Seções na ordem da navegação. Coleções vêm do esquema, na ordem dele. */
function sections() {
    const S = state.S;
    const def = state.mission?.def || {};
    const out = [
        { key: 'general', label: 'Geral', group: 'Missão' },
        { key: 'steps', label: 'Passos', group: 'Missão', count: toArray(def.steps).length },
        { key: 'triggers', label: 'Gatilhos', group: 'Missão', count: toArray(def.triggers).length },
    ];
    for (const collection of S.collections) {
        out.push({ key: collection.key, label: collection.label, group: 'Componentes', count: toArray(def[collection.key]).length, collection });
    }
    out.push({ key: 'test', label: 'Teste', group: 'Ferramentas' });
    return out;
}

/** Seção dona de um caminho de erro (`pedGroups[2].peds[1].model` → pedGroups). */
function sectionOfPath(path) {
    const match = /^([A-Za-z_]+)(?:\[(\d+)\])?/.exec(path || '');
    if (!match) return { key: 'general', index: null };
    const root = match[1];
    const index = match[2] ? Number(match[2]) - 1 : null;
    if (root === 'steps' || root === 'triggers' || state.S.collectionByKey.has(root)) return { key: root, index };
    return { key: 'general', index: null };
}

function errorMap() {
    return new Map((state.mission?.errors || []).map((entry) => [entry.path, entry.message]));
}

export function renderMission(root, shell) {
    shellRef = shell;
    const title = el('h1', 'ed-title');
    const subtitle = el('div', 'ed-subtitle');
    const head = panelHead({ title: '', onClose: shell.close });
    head.querySelector('.ed-head-text').replaceChildren(title, subtitle);

    const status = el('div', 'bar-status');
    const saveBtn = button('SALVAR', () => save(), 'confirm');
    const publishBtn = button('PUBLICAR', publish);
    const toolbar = el('div', 'ed-toolbar', status, el('div', 'spacer'),
        button('VOLTAR', () => goBack()), publishBtn, saveBtn);

    const nav = el('nav', { class: 'ed-nav', 'aria-label': 'Seções' });
    const content = el('div', 'ed-content');
    const errorsPanel = el('div', { class: 'errors-panel', hidden: true, role: 'dialog', 'aria-label': 'Erros da missão' });
    const body = el('div', 'ed-body', nav, content, errorsPanel);

    root.replaceChildren(head, el('div', 'ed-barwrap', toolbar, noticeArea()), body);
    refs = { title, subtitle, status, saveBtn, publishBtn, nav, content, errorsPanel };
    updateHeader();
    updateNav();
    renderSection();
}

function updateHeader() {
    if (!refs || !state.mission) return;
    const { def, record, errors, dirty } = state.mission;
    refs.title.textContent = def.name || def.id || 'Sem nome';
    refs.subtitle.textContent = [def.id, def.category].filter(Boolean).join(' · ');
    const count = errors.length;
    const errorsBtn = el('button', {
        type: 'button', class: count ? 'tag error tag-btn' : 'tag published tag-btn',
        title: count ? 'Ver erros' : 'Sem erros', 'aria-expanded': String(!refs.errorsPanel.hidden),
        on: { click: () => toggleErrors() },
    }, count ? `${count} ${count === 1 ? 'erro' : 'erros'}` : 'Sem erros');
    errorsBtn.disabled = !count;
    refs.status.replaceChildren(...[
        statusTag(record?.status),
        record?.hasUnpublished && record?.status !== 'draft' ? el('span', { class: 'tag warn', text: 'Alterações não publicadas' }) : null,
        dirty ? el('span', { class: 'tag warn', text: 'Não salvo' }) : null,
        errorsBtn,
    ].filter(Boolean));
}

function updateNav() {
    if (!refs || !state.mission) return;
    const errorCounts = new Map();
    for (const entry of state.mission.errors) {
        const { key } = sectionOfPath(entry.path);
        errorCounts.set(key, (errorCounts.get(key) || 0) + 1);
    }
    const nodes = [];
    let group = null;
    for (const section of sections()) {
        if (section.group !== group) {
            group = section.group;
            nodes.push(el('div', { class: 'nav-group', text: group }));
        }
        const active = section.key === state.section;
        const errors = errorCounts.get(section.key) || 0;
        nodes.push(el('button', {
            type: 'button', class: active ? 'nav-item active' : 'nav-item', 'aria-current': active ? 'page' : null,
            on: { click: () => navigate(section.key) },
        },
        el('span', { class: 'nav-label', text: section.label }),
        errors ? el('span', { class: 'nav-err num', title: `${errors} ${errors === 1 ? 'erro' : 'erros'}`, text: String(errors) }) : null,
        section.count !== undefined ? el('span', { class: 'nav-count num', text: String(section.count) }) : null));
    }
    refs.nav.replaceChildren(...nodes);
}

function sectionContext() {
    return {
        S: state.S,
        lists: state.lists,
        get def() { return state.mission.def; },
        get mission() { return state.mission; },
        errors: errorMap(),
        focusPath: state.focusPath,
        getSel: (key) => state.sel[key] ?? 0,
        setSel: (key, index) => { state.sel[key] = index; },
        onEdit: () => markDirty(),
        onStructure: () => { markDirty(); updateNav(); refreshDatalists(); },
        rerender: () => renderSection(true),
        ensureSaved,
    };
}

/** Nomes legíveis de condições e campos `var` mudam com variáveis e coleções. */
export function refreshDatalists() {
    const list = document.getElementById('dl-vars');
    if (!list || !state.mission) return;
    list.replaceChildren(...readableNames(state.S, state.mission.def).map((entry) => el('option', { value: entry.name, label: entry.label })));
}

/** Rolagem e foco sobrevivem ao redesenho (ex.: Ctrl+S no meio da digitação). */
function snapshotView() {
    const scroll = new Map();
    for (const node of refs.content.querySelectorAll('[data-scroll]')) scroll.set(node.dataset.scroll, node.scrollTop);
    const active = document.activeElement;
    let focus = null;
    const holder = active && refs.content.contains(active) ? active.closest('[data-path]') : null;
    if (holder) {
        const inputs = [...holder.querySelectorAll('input, select, textarea')];
        focus = { path: holder.dataset.path, index: inputs.indexOf(active), caret: active.selectionStart ?? null };
    }
    return { scroll, focus, section: state.section };
}

function restoreView(view) {
    if (!view || view.section !== state.section) return;
    for (const node of refs.content.querySelectorAll('[data-scroll]')) {
        if (view.scroll.has(node.dataset.scroll)) node.scrollTop = view.scroll.get(node.dataset.scroll);
    }
    if (view.focus) {
        const holder = refs.content.querySelector(`[data-path="${CSS.escape(view.focus.path)}"]`);
        const input = holder ? holder.querySelectorAll('input, select, textarea')[view.focus.index] : null;
        if (input) {
            input.focus({ preventScroll: true });
            if (view.focus.caret !== null && typeof input.setSelectionRange === 'function') {
                try { input.setSelectionRange(view.focus.caret, view.focus.caret); } catch { /* number não aceita */ }
            }
        }
    }
}

function renderSection(keepView = false) {
    if (!refs || !state.mission) return;
    const view = keepView ? snapshotView() : null;
    refreshDatalists();
    const ctx = sectionContext();
    const section = sections().find((entry) => entry.key === state.section) || sections()[0];
    const host = el('div', { class: 'sec', dataset: { section: section.key } });
    refs.content.replaceChildren(host);
    if (section.key === 'general') renderGeneral(host, ctx);
    else if (section.key === 'steps') renderSteps(host, ctx);
    else if (section.key === 'triggers') {
        renderCollection(host, ctx, {
            key: 'triggers', label: 'Gatilhos', singular: 'gatilho', itemLabel: 'label', fields: state.S.trigger,
            help: 'Reações a eventos da missão: quando algo acontece (e a condição bate), as ações rodam.',
        });
    } else if (section.collection) renderCollection(host, ctx, section.collection);
    else if (section.key === 'test') renderTest(host, ctx);
    restoreView(view);

    if (state.focusPath) {
        const path = state.focusPath;
        state.focusPath = null;
        requestAnimationFrame(() => highlightPath(path));
    }
}

function highlightPath(path) {
    // Caminho exato ou o ancestral mais próximo que estiver desenhado.
    let current = path;
    let node = null;
    while (current && !node) {
        node = refs.content.querySelector(`[data-path="${CSS.escape(current)}"]`);
        if (!node) {
            const cut = Math.max(current.lastIndexOf('.'), current.lastIndexOf('['));
            current = cut > 0 ? current.slice(0, cut) : '';
        }
    }
    if (!node) return;
    node.scrollIntoView({ block: 'center' });
    node.classList.remove('flash');
    void node.offsetWidth;
    node.classList.add('flash');
    node.querySelector('input, select, textarea')?.focus({ preventScroll: true });
}

export function navigate(key, index = null, path = null) {
    if (index !== null) state.sel[key] = index;
    state.section = key;
    state.focusPath = path;
    closeErrors();
    updateNav();
    renderSection();
    emit('keys');
}

function toggleErrors() {
    if (!refs) return;
    if (!refs.errorsPanel.hidden) { closeErrors(); return; }
    openErrors();
}

export function openErrors() {
    if (!refs || !state.mission) return;
    const panel = refs.errorsPanel;
    const errors = state.mission.errors;
    const rows = errors.map((entry) => {
        const target = sectionOfPath(entry.path);
        const label = sections().find((section) => section.key === target.key)?.label || 'Geral';
        return el('button', {
            type: 'button', class: 'err-row',
            on: { click: () => navigate(target.key, target.index, entry.path) },
        },
        icon('alert', 14),
        el('span', 'err-text',
            el('span', { class: 'err-msg', text: entry.message }),
            el('span', { class: 'err-path mono', text: `${label} · ${entry.path}` })));
    });
    panel.replaceChildren(
        el('div', 'errors-head', el('span', { text: `${errors.length} ${errors.length === 1 ? 'erro' : 'erros'}` }),
            el('button', { type: 'button', class: 'icon-btn', 'aria-label': 'Fechar lista de erros', title: 'Fechar', on: { click: closeErrors } }, icon('close', 14))),
        el('div', 'errors-list', rows.length ? rows : el('div', { class: 'row-info', text: 'Sem erros.' })));
    panel.hidden = false;
    clearNotices();
    updateHeader();
    emit('keys');
    panel.querySelector('.err-row')?.focus();
}

export function closeErrors() {
    if (!refs || refs.errorsPanel.hidden) return false;
    refs.errorsPanel.hidden = true;
    updateHeader();
    emit('keys');
    return true;
}

export function errorsOpen() {
    return !!refs && !refs.errorsPanel.hidden;
}

export async function save() {
    if (!refs) return { ok: false, errors: [] };
    refs.saveBtn.setAttribute('aria-busy', 'true');
    try {
        return await saveMission();
    } finally {
        refs?.saveBtn.removeAttribute('aria-busy');
    }
}

/** Antes de testar/publicar: salva o que estiver pendente e exige zero erros. */
async function ensureSaved() {
    if (!state.mission) return false;
    if (state.mission.dirty) {
        const result = await save();
        if (!result.ok) return false;
    }
    if (state.mission.errors.length) {
        notify('warning', `Corrija ${state.mission.errors.length === 1 ? 'o erro' : `os ${state.mission.errors.length} erros`} antes de continuar.`);
        openErrors();
        return false;
    }
    return true;
}

async function publish() {
    if (!state.mission) return;
    refs.publishBtn.setAttribute('aria-busy', 'true');
    try {
        if (!(await ensureSaved())) return;
        await setStatus(state.mission.def.id, 'published');
    } finally {
        refs?.publishBtn.removeAttribute('aria-busy');
    }
}

/** Pergunta uma vez antes de perder alterações. */
export async function confirmLeave() {
    if (!state.mission?.dirty) return true;
    return confirmWindow({
        title: 'DESCARTAR ALTERAÇÕES?',
        object: state.mission.def.name || state.mission.def.id,
        text: 'As alterações feitas desde o último salvamento serão perdidas.',
        actionLabel: 'DESCARTAR ALTERAÇÕES',
    });
}

export async function goBack() {
    if (!(await confirmLeave())) return;
    state.mission = null;
    state.screen = 'home';
    refs = null;
    emit('screen');
}

export function missionKeys() {
    if (errorsOpen()) return [['Esc', 'Fechar erros']];
    const keys = [['Ctrl S', 'Salvar']];
    if (state.section === 'steps') keys.unshift(['Alt ↑↓', 'Mover passo']);
    keys.push(['Esc', 'Voltar']);
    return keys;
}

on('dirty', () => updateHeader());
on('record', () => updateHeader());
on('errors', () => { updateHeader(); updateNav(); if (refs && !refs.errorsPanel.hidden) openErrors(); });
on('replaced', () => renderSection(true));
on('edit', () => {
    if (!refs || !state.mission) return;
    const { def } = state.mission;
    refs.title.textContent = def.name || def.id || 'Sem nome';
    refs.subtitle.textContent = [def.id, def.category].filter(Boolean).join(' · ');
});
on('saving', (busy) => {
    if (!refs) return;
    if (busy) refs.saveBtn.setAttribute('aria-busy', 'true');
    else refs.saveBtn.removeAttribute('aria-busy');
});

export function shell() {
    return shellRef;
}
