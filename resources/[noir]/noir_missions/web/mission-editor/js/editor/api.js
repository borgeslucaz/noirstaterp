// Operações do editor que falam com o Lua. Atualizam o store e avisam por eventos; as telas
// só desenham.
import { fetchNui } from '../nui.js';
import { codeText } from '../codes.js';
import { notify } from '../feedback.js';
import { state, emit, setMissions } from './store.js';
import { toArray } from '../forms/schema-util.js';

function errorsOf(response) {
    return toArray(response?.errors).filter((entry) => entry && typeof entry.path === 'string');
}

/** Missão carregada vira o rascunho em edição. */
function adopt(response) {
    state.mission = {
        record: response.record || { id: response.definition?.id },
        def: response.definition && typeof response.definition === 'object' ? response.definition : {},
        errors: errorsOf(response),
        dirty: false,
        rev: 0,
    };
    if (!state.mission.def.start || typeof state.mission.def.start !== 'object') state.mission.def.start = {};
    state.section = 'general';
    state.sel = {};
    state.focusPath = null;
    state.screen = 'mission';
    emit('screen');
}

export async function loadMission(id) {
    const response = await fetchNui('editorLoad', { id });
    if (!response.ok) { notify('danger', codeText(response.code)); return false; }
    adopt(response);
    return true;
}

export async function createMission(id, name) {
    const response = await fetchNui('editorCreate', { id, name });
    if (!response.ok) return response;
    if (Array.isArray(response.missions)) setMissions(response.missions);
    adopt(response);
    state.mission.dirty = false;
    return response;
}

let saving = null;

/**
 * Salva o rascunho. Edição feita durante a ida e volta não se perde: nesse caso a definição
 * local continua valendo (e suja), só erros e registro são atualizados.
 * @returns {Promise<{ok: boolean, errors: any[]}>}
 */
export async function saveMission() {
    const mission = state.mission;
    if (!mission) return { ok: false, errors: [] };
    if (saving) return saving;
    const rev = mission.rev;
    emit('saving', true);
    saving = (async () => {
        const response = await fetchNui('editorSave', { definition: mission.def });
        if (state.mission !== mission) return { ok: false, errors: [] };
        if (!response.ok) {
            if (response.errors) { mission.errors = errorsOf(response); emit('errors'); }
            notify('danger', codeText(response.code));
            return { ok: false, errors: mission.errors };
        }
        mission.errors = errorsOf(response);
        if (response.record) mission.record = response.record;
        if (Array.isArray(response.missions)) setMissions(response.missions);
        if (mission.rev === rev) {
            if (response.definition && typeof response.definition === 'object') {
                mission.def = response.definition;
                if (!mission.def.start || typeof mission.def.start !== 'object') mission.def.start = {};
                emit('replaced');
            }
            mission.dirty = false;
            emit('dirty', false);
        }
        emit('errors');
        emit('record');
        const count = mission.errors.length;
        notify(count ? 'warning' : 'success', count
            ? `Rascunho salvo com ${count} ${count === 1 ? 'erro' : 'erros'}. Corrija antes de publicar ou testar.`
            : 'Rascunho salvo.');
        return { ok: true, errors: mission.errors };
    })();
    try {
        return await saving;
    } finally {
        saving = null;
        emit('saving', false);
    }
}

/**
 * @param {string} id
 * @param {'published'|'disabled'|'draft'} status
 */
export async function setStatus(id, status) {
    const response = await fetchNui('editorSetStatus', { id, status });
    if (Array.isArray(response.missions)) setMissions(response.missions);
    if (state.mission && state.mission.def.id === id) {
        if (response.record) { state.mission.record = response.record; emit('record'); }
        if (response.errors) { state.mission.errors = errorsOf(response); emit('errors'); }
    }
    if (!response.ok) {
        const count = errorsOf(response).length;
        notify('danger', count && response.code === 'invalid_definition'
            ? `Não publicada: ${count} ${count === 1 ? 'erro' : 'erros'} na missão.`
            : codeText(response.code));
        return false;
    }
    notify('success', status === 'published' ? 'Missão publicada.' : status === 'disabled' ? 'Missão desativada.' : 'Estado atualizado.');
    return true;
}

export async function startTest(id, mode, step) {
    const body = { id, mode };
    if (step) body.step = step;
    const response = await fetchNui('editorTest', body);
    if (!response.ok) { notify('danger', codeText(response.code)); return false; }
    notify('success', mode === 'sandbox' ? 'Sandbox iniciado.' : mode === 'step' ? `Teste iniciado a partir de ${step}.` : 'Teste iniciado.');
    return true;
}
