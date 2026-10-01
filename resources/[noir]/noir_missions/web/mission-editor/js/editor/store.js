// Estado único do editor. Os formulários mutam `state.mission.def` no lugar (rascunho) e
// avisam por markDirty(); quem desenha cabeçalho/listas escuta os eventos daqui e
// redesenha só o pedaço afetado, para o campo em edição não perder foco nem cursor.

export const state = {
    /** esquema preparado (forms/schema-util.prepareSchema) */
    S: null,
    lists: { items: [], minigames: [], weapons: [] },
    missions: [],
    instances: [],
    open: false,
    placement: false,
    screen: 'home',
    /** id da missão selecionada na lista */
    homeSel: null,
    /** @type {null | { record: any, def: any, errors: {path: string, message: string}[], dirty: boolean }} */
    mission: null,
    section: 'general',
    /** índice selecionado por seção (passos, coleções, gatilhos) */
    sel: {},
    /** caminho a destacar no próximo desenho (vindo do painel de erros) */
    focusPath: null,
    debug: false,
};

const subscribers = new Map();

export function on(event, fn) {
    if (!subscribers.has(event)) subscribers.set(event, new Set());
    subscribers.get(event).add(fn);
}

export function emit(event, payload) {
    for (const fn of subscribers.get(event) || []) fn(payload);
}

export function markDirty() {
    if (!state.mission) return;
    state.mission.rev = (state.mission.rev || 0) + 1;
    if (!state.mission.dirty) {
        state.mission.dirty = true;
        emit('dirty', true);
    }
    emit('edit');
}

export function setMissions(missions) {
    if (!Array.isArray(missions)) return;
    state.missions = missions;
    emit('missions');
}

export function setInstances(instances) {
    if (!Array.isArray(instances)) return;
    state.instances = instances;
    emit('instances');
}
