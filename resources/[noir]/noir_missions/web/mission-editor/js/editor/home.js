// Tela inicial: lista de missões, ações sobre a selecionada e instâncias em andamento.
import { el, button, icon } from '../dom.js';
import { fetchNui } from '../nui.js';
import { codeText } from '../codes.js';
import { notify } from '../feedback.js';
import { openWindow, confirmWindow } from '../modal.js';
import { state, on, setMissions, setInstances } from './store.js';
import { loadMission, createMission, setStatus, startTest } from './api.js';
import { isValidMissionId } from './refs.js';
import { panelHead, noticeArea, statusTag, playersText, relativeTime } from './ui.js';

let refs = null;

function selectedMission() {
    return state.missions.find((mission) => mission.id === state.homeSel) || null;
}

/** @param {HTMLElement} root @param {{close: () => void}} shell */
export function renderHome(root, shell) {
    const list = el('div', { class: 'home-list', role: 'listbox', tabindex: '0', 'aria-label': 'Missões' });
    const instances = el('div', 'home-instances');
    const toolbar = el('div', 'ed-toolbar');
    const subtitle = el('div', 'ed-subtitle');
    const head = panelHead({ title: 'Noir Missions', onClose: shell.close });
    head.querySelector('.ed-head-text').append(subtitle);

    root.replaceChildren(head, el('div', 'ed-barwrap', toolbar, noticeArea()),
        el('div', 'ed-scroll',
            el('div', 'home-cols',
                el('span', { text: 'Missão' }), el('span', { text: 'Categoria' }), el('span', { text: 'Estado' }),
                el('span', { class: 'right', text: 'Jogadores' }), el('span', { class: 'right', text: 'Passos' }), el('span', { class: 'right', text: 'Erros' })),
            list,
            instances));

    refs = { list, instances, toolbar, subtitle };
    list.addEventListener('keydown', onListKey);
    drawList();
    drawToolbar();
    drawInstances();
    requestAnimationFrame(() => list.focus({ preventScroll: true }));
}

function drawList() {
    if (!refs) return;
    const { list, subtitle } = refs;
    subtitle.textContent = `Editor de missões · ${state.missions.length} ${state.missions.length === 1 ? 'missão' : 'missões'}`;
    list.replaceChildren();
    if (!state.missions.length) {
        list.append(el('div', { class: 'row-info', text: 'Nenhuma missão ainda. Use CRIAR MISSÃO para começar.' }));
        return;
    }
    if (state.homeSel && !selectedMission()) state.homeSel = null;
    for (const mission of state.missions) {
        const selected = mission.id === state.homeSel;
        const errors = Number(mission.errors) || 0;
        const row = el('div', {
            class: selected ? 'row home-row selected' : 'row home-row', role: 'option', 'aria-selected': String(selected),
            dataset: { id: mission.id },
            on: {
                click: () => select(mission.id),
                dblclick: () => edit(),
            },
        },
        el('div', 'home-name',
            el('span', { class: 'row-label', text: mission.name || mission.id }),
            el('span', 'row-desc',
                el('span', { class: 'mono', text: mission.id }),
                mission.hasUnpublished && mission.status !== 'draft' ? el('span', { class: 'tag warn', text: 'Alterações não publicadas' }) : null,
                el('span', { text: `Atualizada ${relativeTime(mission.updatedAt)}` }))),
        el('span', { class: 'row-meta', text: mission.category || '—' }),
        el('span', null, statusTag(mission.status)),
        el('span', { class: 'row-value num', text: playersText(mission.minPlayers, mission.maxPlayers) }),
        el('span', { class: 'row-value num', text: String(mission.steps ?? 0) }),
        el('span', { class: errors ? 'row-value num err' : 'row-value num', text: errors ? String(errors) : '—' }));
        list.append(row);
    }
}

function select(id) {
    state.homeSel = id;
    drawList();
    drawToolbar();
    refs?.list.querySelector('.selected')?.scrollIntoView({ block: 'nearest' });
}

function drawToolbar() {
    if (!refs) return;
    const mission = selectedMission();
    const none = !mission;
    const published = mission?.status === 'published';
    refs.toolbar.replaceChildren(...[
        button('CRIAR MISSÃO', openCreate, 'confirm', { icon: 'plus' }),
        el('div', 'spacer'),
        button('EDITAR', edit, '', { disabled: none }),
        button('DUPLICAR', openDuplicate, '', { disabled: none }),
        button('TESTAR', test, '', { disabled: none }),
        !published || mission?.hasUnpublished ? button('PUBLICAR', () => changeStatus('published'), '', { disabled: none }) : null,
        published ? button('DESATIVAR', () => changeStatus('disabled'), '', { disabled: none }) : null,
        el('button', { type: 'button', class: 'btn danger-text', disabled: none, text: 'APAGAR', on: { click: openDelete } }),
    ].filter(Boolean));
}

function drawInstances() {
    if (!refs) return;
    const box = refs.instances;
    box.replaceChildren(el('div', 'list-section', el('span', { text: 'Em andamento' }), el('span', { class: 'num', text: String(state.instances.length) })));
    if (!state.instances.length) {
        box.append(el('div', { class: 'row-info', text: 'Nenhuma missão em andamento.' }));
        return;
    }
    for (const instance of state.instances) {
        const stop = button('ENCERRAR', async () => {
            stop.setAttribute('aria-busy', 'true');
            const response = await fetchNui('editorStopInstance', { instanceId: instance.instanceId });
            stop.removeAttribute('aria-busy');
            if (!response.ok) { notify('danger', codeText(response.code)); return; }
            setInstances(response.instances);
            notify('success', 'Instância encerrada.');
        }, '', { small: true });
        const participants = Array.isArray(instance.participants) ? instance.participants.length : Number(instance.participants) || 0;
        box.append(el('div', 'row inst-row',
            el('div', 'home-name',
                el('span', 'row-label', instance.name || instance.missionId, instance.test ? el('span', { class: 'tag test', text: 'Teste' }) : null),
                el('span', 'row-desc',
                    el('span', { class: 'mono', text: instance.missionId }),
                    el('span', { text: `Passo: ${instance.step || '—'}` }),
                    el('span', { text: `${participants} ${participants === 1 ? 'participante' : 'participantes'}` }),
                    el('span', { text: `Começou ${relativeTime(instance.startedAt)}` }))),
            stop));
    }
}

function onListKey(event) {
    if (!state.missions.length) return;
    const index = state.missions.findIndex((mission) => mission.id === state.homeSel);
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        const step = event.key === 'ArrowDown' ? 1 : -1;
        const next = index < 0 ? 0 : (index + step + state.missions.length) % state.missions.length;
        select(state.missions[next].id);
    } else if (event.key === 'Home' || event.key === 'End') {
        event.preventDefault();
        select(state.missions[event.key === 'Home' ? 0 : state.missions.length - 1].id);
    } else if (event.key === 'Enter' && index >= 0) {
        event.preventDefault();
        edit();
    }
}

async function edit() {
    const mission = selectedMission();
    if (mission) await loadMission(mission.id);
}

async function test() {
    const mission = selectedMission();
    if (!mission) return;
    if (Number(mission.errors) > 0) {
        notify('warning', 'A missão tem erros. Abra e corrija antes de testar.');
        return;
    }
    await startTest(mission.id, 'full');
}

async function changeStatus(status) {
    const mission = selectedMission();
    if (mission) await setStatus(mission.id, status);
}

/** Campos de ID + Nome para criar e duplicar. */
function idNameForm(initialId, initialName) {
    const idInput = el('input', { class: 'input mono', type: 'text', value: initialId, maxLength: 48, placeholder: 'ex.: meth_docks_run', spellcheck: 'false', 'aria-label': 'ID' });
    const nameInput = el('input', { class: 'input', type: 'text', value: initialName, maxLength: 64, placeholder: 'Nome que aparece para o admin', 'aria-label': 'Nome' });
    const idError = el('div', { class: 'field-error', hidden: true });
    const nameError = el('div', { class: 'field-error', hidden: true });
    const setError = (node, input, message) => {
        node.hidden = !message;
        node.replaceChildren(...(message ? [icon('alert', 13), el('span', { text: message })] : []));
        input.classList.toggle('invalid', !!message);
    };
    idInput.addEventListener('input', () => {
        const lower = idInput.value.toLowerCase().replace(/\s+/g, '_');
        if (lower !== idInput.value) idInput.value = lower;
        setError(idError, idInput, null);
    });
    nameInput.addEventListener('input', () => setError(nameError, nameInput, null));
    const nodes = [
        el('div', 'field', el('div', 'field-head', el('label', { class: 'field-label', text: 'ID' })), idInput,
            el('div', { class: 'field-help', text: 'Minúsculas, números, _ e -. De 2 a 48 caracteres. Não muda depois.' }), idError),
        el('div', 'field', el('div', 'field-head', el('label', { class: 'field-label', text: 'Nome' })), nameInput, nameError),
    ];
    const validate = () => {
        const id = idInput.value.trim();
        const name = nameInput.value.trim();
        let ok = true;
        if (!isValidMissionId(id)) { setError(idError, idInput, 'ID inválido. Use minúsculas, números, _ e -, de 2 a 48 caracteres.'); ok = false; }
        else if (state.missions.some((mission) => mission.id === id)) { setError(idError, idInput, 'Já existe uma missão com esse ID.'); ok = false; }
        if (!name) { setError(nameError, nameInput, 'Obrigatório'); ok = false; }
        return ok ? { id, name } : null;
    };
    const serverError = (code) => {
        if (code === 'invalid_id' || code === 'id_exists') setError(idError, idInput, codeText(code));
        else setError(nameError, nameInput, codeText(code));
    };
    return { nodes, validate, serverError };
}

function openCreate() {
    const form = idNameForm('', '');
    openWindow({
        title: 'CRIAR MISSÃO',
        focus: 'input',
        content: () => [el('p', { class: 'win-text', text: 'A missão começa como rascunho, sem passos.' }), ...form.nodes],
        action: {
            label: 'CRIAR MISSÃO',
            run: async () => {
                const values = form.validate();
                if (!values) return false;
                const response = await createMission(values.id, values.name);
                if (!response.ok) { form.serverError(response.code); return false; }
                state.homeSel = values.id;
                return true;
            },
        },
    });
}

function openDuplicate() {
    const mission = selectedMission();
    if (!mission) return;
    const form = idNameForm(`${mission.id}_copia`.slice(0, 48), `${mission.name || mission.id} (cópia)`.slice(0, 64));
    openWindow({
        title: 'DUPLICAR MISSÃO',
        focus: 'input',
        content: () => [
            el('div', 'win-object', mission.name || mission.id, el('small', { text: mission.id })),
            el('p', { class: 'win-text', text: 'A cópia nasce como rascunho, com o rascunho atual da original.' }),
            ...form.nodes,
        ],
        action: {
            label: 'DUPLICAR',
            run: async () => {
                const values = form.validate();
                if (!values) return false;
                const response = await fetchNui('editorDuplicate', { id: mission.id, newId: values.id, newName: values.name });
                if (!response.ok) { form.serverError(response.code); return false; }
                state.homeSel = values.id;
                setMissions(response.missions);
                notify('success', 'Missão duplicada.');
                return true;
            },
        },
    });
}

async function openDelete() {
    const mission = selectedMission();
    if (!mission) return;
    const yes = await confirmWindow({
        title: 'APAGAR MISSÃO',
        object: mission.name || mission.id,
        detail: mission.id,
        text: 'O rascunho e a versão publicada serão apagados. Não dá para desfazer.',
        actionLabel: 'APAGAR',
    });
    if (!yes) return;
    const response = await fetchNui('editorDelete', { id: mission.id });
    if (!response.ok) { notify('danger', codeText(response.code)); return; }
    state.homeSel = null;
    setMissions(response.missions);
    notify('success', 'Missão apagada.');
}

on('missions', () => { if (state.screen === 'home') { drawList(); drawToolbar(); } });
on('instances', () => { if (state.screen === 'home') drawInstances(); });

export function homeKeys() {
    return [['↑↓', 'Navegar'], ['↵', 'Editar'], ['Esc', 'Fechar']];
}
