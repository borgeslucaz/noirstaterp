// Ids e referências entre partes da definição: id novo único, nomes legíveis para condições
// e textos, contagem e troca de referências quando um id muda. Tudo guiado pelo esquema
// (ref/refs/eventMatch/var/condition/computed), sem lista fixa de componentes.
import { toArray, walkDefinition, itemTitle } from '../forms/schema-util.js';

export const ID_PATTERN = /^[a-z0-9][a-z0-9_-]*$/;

/** Id de item (coleção, passo, gatilho). */
export function isValidId(id) {
    return typeof id === 'string' && id.length >= 1 && id.length <= 48 && ID_PATTERN.test(id);
}

/** Id de missão: 2 a 48 caracteres. */
export function isValidMissionId(id) {
    return typeof id === 'string' && id.length >= 2 && id.length <= 48 && ID_PATTERN.test(id);
}

/** zones → zone, pedGroups → ped_group, deliveryGroups → delivery_group, cargo → cargo. */
export function idPrefix(collectionKey) {
    const snake = collectionKey.replace(/([a-z0-9])([A-Z])/g, '$1_$2').toLowerCase();
    return snake.length > 3 && snake.endsWith('s') ? snake.slice(0, -1) : snake;
}

export function uniqueId(list, prefix) {
    const taken = new Set(toArray(list).map((item) => item && item.id));
    let n = 1;
    while (taken.has(`${prefix}_${n}`)) n += 1;
    return `${prefix}_${n}`;
}

/** Itens referenciáveis de uma coleção (ou 'steps'), já com rótulo. */
export function refItems(S, def, refKey) {
    const list = toArray(def?.[refKey]);
    const itemLabel = refKey === 'steps' || refKey === 'triggers' ? 'label' : S.collectionByKey.get(refKey)?.itemLabel;
    return list
        .filter((item) => item && typeof item.id === 'string')
        .map((item) => ({ id: item.id, label: itemTitle(item, itemLabel, item.id) }));
}

/**
 * Nomes que condições, campos `var` e textos {{nome}} conseguem ler: variáveis da missão e os
 * valores calculados de schema.computed com {id} trocado por cada item da coleção.
 * @returns {{name: string, label: string}[]}
 */
export function readableNames(S, def) {
    const out = [];
    for (const variable of toArray(def?.variables)) {
        if (variable && variable.id) out.push({ name: variable.id, label: `Variável (${variable.type || 'boolean'})` });
    }
    for (const computed of S.computed) {
        if (!computed.collection) {
            out.push({ name: computed.name, label: computed.label });
            continue;
        }
        const collection = S.collectionByKey.get(computed.collection);
        for (const item of refItems(S, def, computed.collection)) {
            out.push({
                name: computed.name.replace('{id}', item.id),
                label: `${collection?.label || computed.collection}: ${item.label} — ${computed.label}`,
            });
        }
    }
    return out;
}

function escapeRegExp(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Pares [nome antigo, nome novo] que dependem do id (variável e calculados). */
function namePairs(S, collectionKey, oldId, newId) {
    const pairs = [];
    if (collectionKey === 'variables') pairs.push([oldId, newId]);
    for (const computed of S.computed) {
        if (computed.collection === collectionKey) {
            pairs.push([computed.name.replace('{id}', oldId), computed.name.replace('{id}', newId)]);
        }
    }
    return pairs;
}

/**
 * Percorre toda referência a `collectionKey/oldId`. Com newId troca no lugar; sem ele só conta.
 * @returns {number} quantidade de referências
 */
function visitRefs(S, def, collectionKey, oldId, newId) {
    let hits = 0;
    const pairs = namePairs(S, collectionKey, oldId, newId ?? oldId);
    const nameMap = new Map(pairs);
    const templates = pairs.map(([from, to]) => [new RegExp(`\\{\\{\\s*${escapeRegExp(from)}\\s*\\}\\}`, 'g'), `{{${to}}}`]);
    const replaceText = (text) => {
        let out = text;
        for (const [pattern, to] of templates) {
            out = out.replace(pattern, () => { hits += 1; return to; });
        }
        return out;
    };

    walkDefinition(S, def, (spec, obj) => {
        const value = obj[spec.key];
        if (value === undefined || value === null) return;
        switch (spec.type) {
            case 'ref':
                if (spec.ref === collectionKey && value === oldId) { hits += 1; if (newId) obj[spec.key] = newId; }
                break;
            case 'refs':
                if (spec.ref === collectionKey && Array.isArray(value)) {
                    value.forEach((entry, index) => { if (entry === oldId) { hits += 1; if (newId) value[index] = newId; } });
                }
                break;
            case 'eventMatch': {
                const event = S.eventByValue.get(obj[spec.eventKey || 'on']);
                if (event?.match?.ref === collectionKey && value === oldId) { hits += 1; if (newId) obj[spec.key] = newId; }
                break;
            }
            case 'var':
                if (nameMap.has(value)) { hits += 1; if (newId) obj[spec.key] = nameMap.get(value); }
                break;
            case 'condition':
                for (const rule of toArray(value.rules)) {
                    if (rule && nameMap.has(rule.var)) { hits += 1; if (newId) rule.var = nameMap.get(rule.var); }
                }
                break;
            case 'text': case 'textarea':
                if (templates.length && typeof value === 'string') {
                    const next = replaceText(value);
                    if (newId) obj[spec.key] = next;
                }
                break;
            case 'strings':
                if (templates.length && Array.isArray(value)) {
                    value.forEach((entry, index) => {
                        if (typeof entry !== 'string') return;
                        const next = replaceText(entry);
                        if (newId) value[index] = next;
                    });
                }
                break;
            default:
                break;
        }
    });
    return hits;
}

export function countRefs(S, def, collectionKey, id) {
    return visitRefs(S, def, collectionKey, id, null);
}

/** Troca o id em toda referência. Devolve quantas mudaram. */
export function renameRefs(S, def, collectionKey, oldId, newId) {
    if (!oldId || oldId === newId) return 0;
    return visitRefs(S, def, collectionKey, oldId, newId);
}
