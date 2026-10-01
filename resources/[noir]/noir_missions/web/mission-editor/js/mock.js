// Mocks do navegador (DESIGN_v4 §10). Só é importado quando não há invokeNative nem
// GetParentResourceName (nui.js); no jogo este arquivo nunca carrega. Responde os callbacks do
// contrato a partir de um banco em memória semeado com missions/*.json e dev/schema.json.
import { prepareSchema, walkDefinition, hiddenKeys, isEmptyValue, toArray, clone, pathIndex } from './forms/schema-util.js';
import { isValidId } from './editor/refs.js';

const ROOT = new URL('../../', document.baseURI);
const missions = new Map();
let schemaRaw = null;
let S = null;
let instances = [];
let testInstance = null;

const now = () => Math.floor(Date.now() / 1000);
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const post = (action, data) => window.postMessage({ action, data }, '*');

const LISTS = {
    items: [
        { name: 'chemical_precursor', label: 'Precursor químico' },
        { name: 'meth_bag', label: 'Saco de metanfetamina' },
        { name: 'coke_brick', label: 'Tijolo de cocaína' },
        { name: 'laptop', label: 'Notebook' },
        { name: 'usb_hack', label: 'Pendrive de invasão' },
        { name: 'lockpick', label: 'Gazua' },
        { name: 'thermite', label: 'Termita' },
        { name: 'keycard_humane', label: 'Cartão de acesso Humane Labs' },
        { name: 'phone', label: 'Celular' },
        { name: 'radio', label: 'Rádio' },
    ],
    minigames: [
        { id: 'noir:circuit', label: 'Circuito', available: true },
        { id: 'noir:signal_lock', label: 'Trava de sinal', available: true },
        { id: 'noir:tumbler', label: 'Tambor da fechadura', available: true },
        { id: 'noir:sequence', label: 'Sequência', available: true },
        { id: 'noir:frequency', label: 'Frequência', available: true },
        { id: 'noir:wire_trace', label: 'Rastrear fio', available: true },
        { id: 'noir:thermite', label: 'Termita', available: true },
        { id: 'noir:fingerprint', label: 'Digital', available: true },
        { id: 'noir:drill', label: 'Furadeira', available: false },
        { id: 'noir:pinpad', label: 'Teclado numérico', available: true },
    ],
    weapons: ['WEAPON_PISTOL', 'WEAPON_COMBATPISTOL', 'WEAPON_SMG', 'WEAPON_MICROSMG', 'WEAPON_PUMPSHOTGUN', 'WEAPON_CARBINERIFLE', 'WEAPON_ASSAULTRIFLE', 'WEAPON_KNIFE', 'WEAPON_BAT'],
};

/** Definição mínima para as missões de enchimento (lista longa, texto longo, erros). */
function baseDefinition(id, name, extra = {}) {
    const def = {
        schema: 1, id, name, category: extra.category || 'geral', description: extra.description || '',
        difficulty: 'medium', minPlayers: extra.min ?? 1, maxPlayers: extra.max ?? 4, cooldownMinutes: 60, timeLimitMinutes: 60,
        gangRequired: false, gangMinGrade: 0, participantRadius: 60,
        start: { type: 'phone', caller: 'Contato', text: 'Tenho um serviço. Topa?' },
        steps: [{
            id: 'step_1', type: 'goto', label: 'Ir até o local', enabled: true, objective: 'Vá até o local marcado.',
            coords: extra.noCoords ? undefined : { x: 120.5, y: -1300.25, z: 29.2 }, radius: 100, who: 'any',
            showGps: true, showBlip: true, blipLabel: 'Destino', blipSprite: 1, blipColor: 5, blipArea: false,
            onStart: [], onComplete: [],
        }],
        triggers: [], rewards: [],
    };
    for (const collection of S.collections) def[collection.key] = [];
    return def;
}

function addMission(def, status, options = {}) {
    const time = now();
    missions.set(def.id, {
        record: {
            id: def.id, status,
            updatedAt: time - (options.age ?? 3600),
            publishedAt: status === 'draft' ? null : time - (options.age ?? 3600) - 600,
            hasUnpublished: !!options.unpublished,
        },
        draft: def,
        published: status === 'draft' ? null : clone(def),
    });
}

/** Validação leve no formato do Lua: obrigatório, referência e id, com índice começando em 1. */
function validate(def) {
    const errors = [];
    const ids = new Map();
    const register = (key, list, base) => {
        const seen = new Set();
        toArray(list).forEach((item, index) => {
            const path = `${pathIndex(base, index)}.id`;
            if (!isValidId(item?.id)) errors.push({ path, message: 'id inválido (minúsculas, números, _ e -)' });
            else if (seen.has(item.id)) errors.push({ path, message: `id repetido: ${item.id}` });
            seen.add(item?.id);
        });
        ids.set(key, seen);
    };
    for (const collection of S.collections) register(collection.key, def[collection.key], collection.key);
    register('steps', def.steps, 'steps');
    register('triggers', def.triggers, 'triggers');
    toArray(def.steps).forEach((step, index) => {
        if (!S.stepByType.has(step?.type)) errors.push({ path: pathIndex('steps', index), message: 'tipo de passo desconhecido' });
    });

    const hiddenCache = new WeakMap();
    walkDefinition(S, def, (spec, obj, path, fields) => {
        if (!hiddenCache.has(obj)) hiddenCache.set(obj, hiddenKeys(fields, obj));
        if (hiddenCache.get(obj).has(spec.key)) return;
        const value = obj[spec.key];
        if (spec.required && isEmptyValue(value)) errors.push({ path, message: 'obrigatório' });
        if (spec.type === 'ref' && value && ids.has(spec.ref) && !ids.get(spec.ref).has(value)) {
            errors.push({ path, message: `não existe: ${value}` });
        }
        if (spec.type === 'refs' && Array.isArray(value)) {
            value.forEach((id, index) => {
                if (ids.has(spec.ref) && !ids.get(spec.ref).has(id)) errors.push({ path: pathIndex(path, index), message: `não existe: ${id}` });
            });
        }
        if (spec.type === 'list' && spec.min && toArray(value).length < spec.min) {
            errors.push({ path, message: `precisa de pelo menos ${spec.min}` });
        }
    });
    if (Number(def.maxPlayers) < Number(def.minPlayers)) errors.push({ path: 'maxPlayers', message: 'máximo menor que o mínimo' });
    return errors;
}

function summary(entry) {
    const def = entry.draft;
    return {
        id: entry.record.id, name: def.name, category: def.category, status: entry.record.status,
        minPlayers: def.minPlayers, maxPlayers: def.maxPlayers, steps: toArray(def.steps).length,
        errors: validate(def).length, updatedAt: entry.record.updatedAt, publishedAt: entry.record.publishedAt,
        hasUnpublished: entry.record.hasUnpublished,
    };
}

function summaries() {
    return [...missions.values()].map(summary).sort((a, b) => b.updatedAt - a.updatedAt);
}

async function init() {
    const [schemaResponse, missionResponse] = await Promise.all([
        fetch(new URL('dev/schema.json', ROOT)),
        fetch(new URL('missions/meth_elysian_precursors.json', ROOT)),
    ]);
    schemaRaw = await schemaResponse.json();
    S = prepareSchema(clone(schemaRaw));
    const elysian = await missionResponse.json();
    addMission(elysian.draft, elysian.status || 'draft', { age: 300 });

    addMission(baseDefinition('coke_docks_run', 'Corrida das Docas', { category: 'coke', min: 2, max: 4 }), 'published', { age: 86400 * 3 });
    addMission(baseDefinition('weed_farm_raid', 'Invasão da Plantação', { category: 'weed' }), 'disabled', { age: 86400 * 9, unpublished: true });
    addMission(baseDefinition('gun_convoy_ambush', 'Emboscada ao Comboio de Armas na Rodovia Senora com Escolta Pesada', {
        category: 'armas', min: 3, max: 8, noCoords: true,
        description: 'Texto longo para conferir quebra de linha e reticências nas listas do editor.',
    }), 'draft', { age: 7200 });
    const fillers = [
        ['bank_fleeca_scout', 'Reconhecimento do Fleeca', 'banco'],
        ['lab_supply_run', 'Suprimentos do Laboratório', 'meth'],
        ['boat_drop_paleto', 'Entrega de Barco em Paleto', 'coke'],
        ['courier_vinewood', 'Mensageiro de Vinewood', 'geral'],
        ['chop_shop_job', 'Desmanche Encomendado', 'carros'],
        ['heist_prep_humane', 'Preparação Humane Labs', 'assalto'],
        ['arms_deal_sandy', 'Negócio de Armas em Sandy', 'armas'],
        ['yacht_party_crash', 'Festa no Iate', 'geral'],
    ];
    fillers.forEach(([id, name, category], index) => {
        addMission(baseDefinition(id, name, { category }), index % 3 === 0 ? 'published' : 'draft', { age: 86400 * (index + 2) });
    });

    instances = [{
        instanceId: 'inst_7f3a', missionId: 'coke_docks_run', name: 'Corrida das Docas', step: 'step_1',
        participants: [12, 48, 51], test: false, startedAt: now() - 540,
    }];
}

const ready = init();

/** editor:open para o preview. */
export async function openPayload() {
    await ready;
    return { missions: summaries(), instances: clone(instances), schema: clone(schemaRaw), lists: clone(LISTS) };
}

function randomNear(base, heading) {
    const origin = base && Number.isFinite(Number(base.x)) ? base : { x: 60, y: -2560, z: 6 };
    const position = {
        x: Number(origin.x) + (Math.random() * 16 - 8),
        y: Number(origin.y) + (Math.random() * 16 - 8),
        z: Number(origin.z) + Math.random() * 0.6,
    };
    if (heading) position.w = Math.random() * 360;
    return position;
}

const handlers = {
    uiReady: () => ({ ok: true }),
    editorClose: () => ({ ok: true }),
    infoClose: () => ({ ok: true }),
    offerAnswer: ({ offerId, accept }) => {
        console.info(`[mock] offerAnswer ${offerId} → ${accept ? 'aceitou' : 'recusou'}`);
        return { ok: true };
    },

    editorLoad: ({ id }) => {
        const entry = missions.get(id);
        if (!entry) return { ok: false, code: 'not_found' };
        return { ok: true, record: clone(entry.record), definition: clone(entry.draft), errors: validate(entry.draft) };
    },

    editorCreate: ({ id, name }) => {
        if (!/^[a-z0-9][a-z0-9_-]*$/.test(id || '') || id.length < 2 || id.length > 48) return { ok: false, code: 'invalid_id' };
        if (missions.has(id)) return { ok: false, code: 'id_exists' };
        const def = baseDefinition(id, name);
        def.steps = [];
        addMission(def, 'draft', { age: 0 });
        const entry = missions.get(id);
        return { ok: true, record: clone(entry.record), definition: clone(def), errors: validate(def), missions: summaries() };
    },

    editorSave: ({ definition }) => {
        const entry = missions.get(definition?.id);
        if (!entry) return { ok: false, code: 'not_found' };
        entry.draft = clone(definition);
        entry.record.updatedAt = now();
        entry.record.hasUnpublished = entry.record.status !== 'draft';
        const errors = validate(entry.draft);
        return { ok: true, record: clone(entry.record), definition: clone(entry.draft), errors, missions: summaries() };
    },

    editorDuplicate: ({ id, newId, newName }) => {
        const entry = missions.get(id);
        if (!entry) return { ok: false, code: 'not_found' };
        if (!/^[a-z0-9][a-z0-9_-]*$/.test(newId || '') || newId.length < 2) return { ok: false, code: 'invalid_id' };
        if (missions.has(newId)) return { ok: false, code: 'id_exists' };
        const def = clone(entry.draft);
        def.id = newId;
        def.name = newName || def.name;
        addMission(def, 'draft', { age: 0 });
        return { ok: true, missions: summaries() };
    },

    editorDelete: ({ id }) => {
        if (!missions.delete(id)) return { ok: false, code: 'not_found' };
        return { ok: true, missions: summaries() };
    },

    editorSetStatus: ({ id, status }) => {
        const entry = missions.get(id);
        if (!entry) return { ok: false, code: 'not_found' };
        if (status === 'published') {
            const errors = validate(entry.draft);
            if (errors.length) return { ok: false, code: 'invalid_definition', errors, missions: summaries() };
            entry.published = clone(entry.draft);
            entry.record.publishedAt = now();
            entry.record.hasUnpublished = false;
        }
        entry.record.status = status;
        return { ok: true, record: clone(entry.record), missions: summaries() };
    },

    editorPlace: ({ requestId, heading, current }) => {
        post('editor:placement', { active: true });
        setTimeout(() => {
            post('editor:placementResult', { requestId, ok: true, position: randomNear(current, heading) });
            post('editor:placement', { active: false });
        }, 600);
        return { ok: true };
    },

    editorTeleport: () => ({ ok: true }),
    editorPreview: () => ({ ok: true }),
    editorValidateModel: () => ({ ok: true, valid: true }),

    editorTest: ({ id, mode, step }) => {
        const entry = missions.get(id);
        if (!entry) return { ok: false, code: 'not_found' };
        if (validate(entry.draft).length) return { ok: false, code: 'invalid_definition' };
        testInstance = {
            instanceId: `test_${Math.random().toString(36).slice(2, 6)}`, missionId: id, name: entry.draft.name,
            step: mode === 'step' ? step : toArray(entry.draft.steps)[0]?.id || '—', participants: [1], test: true, startedAt: now(),
        };
        instances = [...instances.filter((instance) => !instance.test), testInstance];
        post('editor:instances', { instances: clone(instances) });
        return { ok: true, instanceId: testInstance.instanceId };
    },

    editorTestTool: ({ tool }) => {
        if (tool === 'reset') {
            testInstance = null;
            instances = instances.filter((instance) => !instance.test);
            post('editor:instances', { instances: clone(instances) });
            return { ok: true };
        }
        if (!testInstance) return { ok: false, code: 'no_instance' };
        return { ok: true };
    },

    editorStopInstance: ({ instanceId }) => {
        instances = instances.filter((instance) => instance.instanceId !== instanceId);
        if (testInstance?.instanceId === instanceId) testInstance = null;
        return { ok: true, instances: clone(instances) };
    },

    editorDebug: () => ({ ok: true }),
};

export async function handle(name, data) {
    await ready;
    await wait(name === 'uiReady' ? 0 : 120);
    const handler = handlers[name];
    if (!handler) return { ok: false, code: 'internal_error' };
    // Ida e volta por JSON, como no jogo: nada de referência compartilhada com a UI.
    return clone(handler(clone(data) || {}));
}

window.__noirMock = { openPayload, ready, post };
