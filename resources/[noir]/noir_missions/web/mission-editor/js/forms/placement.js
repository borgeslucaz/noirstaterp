// Posicionamento no mundo: editorPlace devolve só { ok }; a posição chega depois por
// editor:placementResult com o mesmo requestId (o jogador pode levar o tempo que quiser).
import { fetchNui } from '../nui.js';

const pending = new Map();
let counter = 0;

/**
 * @param {{kind: string, model?: string, heading: boolean, current?: any}} request
 * @returns {Promise<{ok: boolean, position?: {x:number,y:number,z:number,w?:number}, code?: string}>}
 */
export async function requestPlacement(request) {
    counter += 1;
    const requestId = `place_${Date.now().toString(36)}_${counter}`;
    // Registra antes de pedir: a resposta pode chegar antes do fetch terminar.
    const result = new Promise((resolve) => pending.set(requestId, resolve));
    const response = await fetchNui('editorPlace', { requestId, ...request });
    if (!response.ok) {
        pending.delete(requestId);
        return { ok: false, code: response.code };
    }
    return result;
}

/** editor:placementResult */
export function placementResult(data) {
    const resolve = data && pending.get(data.requestId);
    if (!resolve) return;
    pending.delete(data.requestId);
    resolve({ ok: !!data.ok && !!data.position, position: data.position, cancelled: !data.ok });
}

/** Editor fechou: ninguém fica esperando para sempre. */
export function cancelPlacements() {
    for (const resolve of pending.values()) resolve({ ok: false, cancelled: true });
    pending.clear();
}

export function round3(value) {
    return Math.round(Number(value) * 1000) / 1000;
}

/** Posição limpa: 3 casas, heading 0–360 só quando o campo usa. */
export function cleanPosition(position, heading) {
    if (!position || !Number.isFinite(Number(position.x)) || !Number.isFinite(Number(position.y)) || !Number.isFinite(Number(position.z))) return null;
    const out = { x: round3(position.x), y: round3(position.y), z: round3(position.z) };
    if (heading) {
        const w = Number(position.w);
        out.w = Number.isFinite(w) ? round3(((w % 360) + 360) % 360) : 0;
    }
    return out;
}
