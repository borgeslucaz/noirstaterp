// Leitura do esquema (shared/types/schema.lua → Schema.export()) e caminhamento genérico da
// definição. Nada aqui sabe o que é um "reforço": tudo sai dos campos do esquema.

/** Tabela vazia do Lua pode chegar como {} em vez de []. */
export function toArray(value) {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') {
        const keys = Object.keys(value);
        if (keys.length && keys.every((key) => /^\d+$/.test(key))) {
            return keys.sort((a, b) => a - b).map((key) => value[key]);
        }
    }
    return [];
}

/** Garante array no próprio objeto (para mutar no lugar sem perder a referência). */
export function arrayAt(obj, key) {
    if (!Array.isArray(obj[key])) obj[key] = toArray(obj[key]);
    return obj[key];
}

function normalizeFields(fields) {
    const list = toArray(fields);
    for (const spec of list) {
        if (spec.options) spec.options = toArray(spec.options);
        if (spec.showIf) spec.showIf.is = toArray(spec.showIf.is);
        if (spec.fields) spec.fields = normalizeFields(spec.fields);
    }
    return list;
}

/** Normaliza arrays e monta índices. Chamado uma vez no editor:open. */
export function prepareSchema(raw) {
    const schema = raw || {};
    const S = {
        general: normalizeFields(schema.general),
        start: normalizeFields(schema.start),
        collections: toArray(schema.collections),
        stepCommon: normalizeFields(schema.stepCommon),
        steps: toArray(schema.steps),
        actions: toArray(schema.actions),
        events: toArray(schema.events),
        trigger: normalizeFields(schema.trigger),
        reward: normalizeFields(schema.reward),
        computed: toArray(schema.computed),
    };
    for (const list of [S.collections, S.steps, S.actions]) {
        for (const entry of list) entry.fields = normalizeFields(entry.fields);
    }
    S.collectionByKey = new Map(S.collections.map((entry) => [entry.key, entry]));
    S.stepByType = new Map(S.steps.map((entry) => [entry.type, entry]));
    S.actionByType = new Map(S.actions.map((entry) => [entry.type, entry]));
    S.eventByValue = new Map(S.events.map((entry) => [entry.value, entry]));
    return S;
}

// Caminhos no formato da validação do Lua: índice começa em 1 (`steps[3].interaction`).
export function pathKey(base, key) {
    return base ? `${base}.${key}` : String(key);
}
export function pathIndex(base, index) {
    return `${base}[${index + 1}]`;
}

/**
 * Campos escondidos por showIf. Controle escondido esconde os dependentes também; repete até
 * estabilizar para não depender da ordem dos campos.
 * @returns {Set<string>}
 */
export function hiddenKeys(fields, obj) {
    const hidden = new Set();
    for (let pass = 0; pass < 4; pass += 1) {
        let changed = false;
        for (const spec of fields) {
            if (!spec.showIf || hidden.has(spec.key)) continue;
            const rule = spec.showIf;
            const visible = !hidden.has(rule.key) && rule.is.some((value) => value === obj[rule.key]);
            if (!visible) { hidden.add(spec.key); changed = true; }
        }
        if (!changed) break;
    }
    return hidden;
}

export function isEmptyValue(value) {
    if (value === undefined || value === null || value === '') return true;
    if (Array.isArray(value)) return value.length === 0;
    if (typeof value === 'object' && 'rules' in value) return toArray(value.rules).length === 0;
    return false;
}

export function clone(value) {
    return value === undefined ? undefined : JSON.parse(JSON.stringify(value));
}

/** Valor inicial de um campo novo. */
export function defaultValue(spec) {
    if (spec.default !== undefined) return clone(spec.default);
    switch (spec.type) {
        case 'list': {
            const count = Math.max(0, spec.min || 0);
            return Array.from({ length: count }, () => defaultsFor(spec.fields));
        }
        case 'strings': case 'refs': case 'positions': case 'actions':
            return [];
        default:
            return undefined;
    }
}

/** Objeto novo com o default de cada campo. */
export function defaultsFor(fields) {
    const out = {};
    for (const spec of toArray(fields)) {
        const value = defaultValue(spec);
        if (value !== undefined) out[spec.key] = value;
    }
    return out;
}

/** Título de um item de coleção ou de lista aninhada. */
export function itemTitle(item, itemLabel, fallback) {
    const value = item && itemLabel ? item[itemLabel] : undefined;
    if (value !== undefined && value !== null && String(value).trim() !== '') return String(value);
    return fallback;
}

/**
 * Visita todo campo da definição (incluindo listas aninhadas e ações recursivas).
 * visit(spec, obj, path) — obj é o objeto que contém spec.key.
 */
export function walkDefinition(S, def, visit) {
    walkFields(S, S.general, def, '', visit);
    if (def.start && typeof def.start === 'object') walkFields(S, S.start, def.start, 'start', visit);
    for (const collection of S.collections) {
        toArray(def[collection.key]).forEach((item, index) => {
            if (item && typeof item === 'object') walkFields(S, collection.fields, item, pathIndex(collection.key, index), visit);
        });
    }
    toArray(def.steps).forEach((step, index) => {
        if (!step || typeof step !== 'object') return;
        const path = pathIndex('steps', index);
        walkFields(S, S.stepCommon, step, path, visit);
        const spec = S.stepByType.get(step.type);
        if (spec) walkFields(S, spec.fields, step, path, visit);
    });
    toArray(def.triggers).forEach((trigger, index) => {
        if (trigger && typeof trigger === 'object') walkFields(S, S.trigger, trigger, pathIndex('triggers', index), visit);
    });
    toArray(def.rewards).forEach((reward, index) => {
        if (reward && typeof reward === 'object') walkFields(S, S.reward, reward, pathIndex('rewards', index), visit);
    });
}

export function walkFields(S, fields, obj, base, visit) {
    for (const spec of fields) {
        const path = pathKey(base, spec.key);
        visit(spec, obj, path, fields);
        const value = obj[spec.key];
        if (!Array.isArray(value)) continue;
        if (spec.type === 'list') {
            value.forEach((item, index) => {
                if (item && typeof item === 'object') walkFields(S, spec.fields, item, pathIndex(path, index), visit);
            });
        } else if (spec.type === 'actions') {
            value.forEach((action, index) => {
                const actionSpec = action && S.actionByType.get(action.type);
                if (actionSpec) walkFields(S, actionSpec.fields, action, pathIndex(path, index), visit);
            });
        }
    }
}
