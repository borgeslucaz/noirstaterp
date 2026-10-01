// Campo de id de item (coleção, passo, gatilho). Valida enquanto digita; ao confirmar (Enter
// ou sair do campo) troca o id e atualiza toda referência a ele na definição. Id inválido
// volta ao anterior em vez de ficar meio aplicado.
import { el, icon } from '../../dom.js';
import { notify } from '../../feedback.js';
import { isValidId, renameRefs } from '../refs.js';

/**
 * @param {object} options
 * @param {any} options.ctx contexto da seção
 * @param {string} options.collectionKey chave da coleção ('steps', 'triggers', 'zones'…)
 * @param {any[]} options.list
 * @param {any} options.item
 * @param {string} options.path caminho do item (`zones[2]`)
 * @param {() => void} options.onRenamed
 */
export function idField({ ctx, collectionKey, list, item, path, onRenamed }) {
    const input = el('input', {
        class: 'input mono', type: 'text', value: item.id ?? '', maxLength: 48, spellcheck: 'false', 'aria-label': 'ID',
    });
    const error = el('div', { class: 'field-error', hidden: true });
    const setError = (message) => {
        error.hidden = !message;
        error.replaceChildren(...(message ? [icon('alert', 13), el('span', { text: message })] : []));
        input.classList.toggle('invalid', !!message);
    };
    const problem = (value) => {
        if (!isValidId(value)) return 'Use minúsculas, números, _ e - (até 48).';
        if (list.some((other) => other !== item && other?.id === value)) return 'Já existe outro item com esse ID.';
        return null;
    };

    input.addEventListener('input', () => {
        const lower = input.value.toLowerCase().replace(/\s+/g, '_');
        if (lower !== input.value) input.value = lower;
        setError(input.value === item.id ? null : problem(input.value));
    });
    input.addEventListener('keydown', (event) => {
        if (event.key === 'Enter') { event.preventDefault(); input.blur(); }
    });
    input.addEventListener('change', () => {
        const next = input.value.trim();
        if (next === item.id) { setError(null); return; }
        const message = problem(next);
        if (message) {
            input.value = item.id ?? '';
            setError(null);
            notify('warning', `ID não trocado: ${message}`);
            return;
        }
        const old = item.id;
        const count = old ? renameRefs(ctx.S, ctx.def, collectionKey, old, next) : 0;
        item.id = next;
        setError(null);
        ctx.onStructure();
        if (count) notify('info', `ID trocado de ${old} para ${next}. ${count} ${count === 1 ? 'referência atualizada' : 'referências atualizadas'}.`);
        // Depois do blur, para o redesenho não roubar o foco de onde o admin clicou.
        setTimeout(onRenamed, 0);
    });

    if (ctx.errors.has(`${path}.id`)) setError(ctx.errors.get(`${path}.id`));
    return el('div', { class: 'field f-id', dataset: { path: `${path}.id` } },
        el('div', 'field-head', el('label', { class: 'field-label', text: 'ID' }), el('span', { class: 'field-req', text: '*' })),
        input,
        el('div', { class: 'field-help', text: 'Usado nas referências. Trocar aqui atualiza passos, ações, gatilhos e condições.' }),
        error);
}
