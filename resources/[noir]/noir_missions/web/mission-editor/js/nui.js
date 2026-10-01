// Ponte NUI → Lua. Toda resposta segue o contrato { ok, code?, ... }; falha de rede ou JSON
// quebrado vira { ok:false, code:'transport_error' } para quem chama nunca precisar de try.

/** Fora do jogo (navegador comum): sem invokeNative nem GetParentResourceName. */
export function isEnvBrowser() {
    return !('invokeNative' in window) && typeof window.GetParentResourceName !== 'function';
}

function resourceName() {
    return typeof window.GetParentResourceName === 'function' ? window.GetParentResourceName() : 'noir_missions';
}

let mockModule = null;

// O mock só é importado no navegador: no jogo o arquivo nunca é baixado.
async function mock() {
    if (!mockModule) mockModule = import('./mock.js');
    return mockModule;
}

/**
 * @param {string} name callback registrado no Lua
 * @param {object} [data]
 * @returns {Promise<{ok: boolean, code?: string, [key: string]: any}>}
 */
export async function fetchNui(name, data = {}) {
    if (isEnvBrowser()) {
        try {
            const module = await mock();
            return await module.handle(name, data);
        } catch (error) {
            console.error('[noir_missions] mock', name, error);
            return { ok: false, code: 'internal_error' };
        }
    }
    try {
        const response = await fetch(`https://${resourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data ?? {}),
        });
        const text = await response.text();
        const body = text ? JSON.parse(text) : null;
        if (!body || typeof body !== 'object') return { ok: false, code: 'transport_error' };
        return body;
    } catch {
        return { ok: false, code: 'transport_error' };
    }
}
