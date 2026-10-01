// ref, refs e eventMatch: escolhem itens de outra parte da definição pelo id. Referência que
// não existe mais aparece em vermelho com "(não existe mais)" (DESIGN_v4 ML.4).
import { el } from '../dom.js';
import { registerField } from './registry.js';
import { valueSelect } from './fields-basic.js';
import { refItems } from '../editor/refs.js';

function refOptions(f, refKey, emptyLabel, allowEmpty) {
    const items = refItems(f.S, f.def, refKey);
    const current = f.value;
    const options = [];
    if (allowEmpty || !items.length || current === undefined || current === null || current === '') {
        options.push({ value: undefined, label: emptyLabel });
    }
    for (const item of items) options.push({ value: item.id, label: item.label === item.id ? item.id : `${item.label} (${item.id})` });
    if (current && !items.some((item) => item.id === current)) {
        options.push({ value: current, label: `${current} (não existe mais)`, missing: true });
    }
    return options;
}

registerField('ref', (f) => {
    const options = refOptions(f, f.spec.ref, '—', !f.spec.required);
    const select = valueSelect(options, f.value, (value) => f.set(value), { 'aria-labelledby': f.labelId });
    select.classList.toggle('invalid', options.some((option) => option.missing && option.value === f.value));
    return { node: select };
});

registerField('refs', (f) => {
    const items = refItems(f.S, f.def, f.spec.ref);
    const list = Array.isArray(f.value) ? f.value : [];
    if (!Array.isArray(f.value)) f.obj[f.spec.key] = list;
    const box = el('div', { class: 'refs', role: 'group', 'aria-labelledby': f.labelId });
    const all = [...items];
    for (const id of list) if (!items.some((item) => item.id === id)) all.push({ id, label: id, missing: true });
    for (const item of all) {
        const input = el('input', { type: 'checkbox', checked: list.includes(item.id) });
        input.addEventListener('change', () => {
            const index = list.indexOf(item.id);
            if (input.checked && index < 0) list.push(item.id);
            if (!input.checked && index >= 0) list.splice(index, 1);
            f.changed();
        });
        box.append(el('label', { class: item.missing ? 'check missing' : 'check' },
            input, el('span', 'check-box'),
            el('span', { class: 'check-label', text: item.missing ? `${item.id} (não existe mais)` : item.label }),
            item.missing || item.label === item.id ? null : el('span', { class: 'check-id', text: item.id })));
    }
    if (!all.length) box.append(el('div', { class: 'field-empty', text: 'Nada para escolher ainda.' }));
    return { node: box };
});

// Filtro do gatilho: a coleção vem do evento escolhido no campo irmão (eventKey).
registerField('eventMatch', (f) => {
    const eventKey = f.spec.eventKey || 'on';
    const event = f.S.eventByValue.get(f.obj[eventKey]);
    const match = event?.match;
    let node;
    if (!match) {
        node = el('div', { class: 'field-empty', text: 'Este evento não tem filtro.' });
    } else if (match.ref) {
        const options = refOptions(f, match.ref, 'Qualquer', true);
        node = valueSelect(options, f.value, (value) => f.set(value), { 'aria-labelledby': f.labelId });
    } else {
        node = el('input', {
            class: 'input', type: 'text', value: f.value ?? '', maxLength: 48,
            placeholder: `Qualquer ${match.key || ''}`.trim(), 'aria-labelledby': f.labelId, spellcheck: 'false',
        });
        node.addEventListener('input', () => f.set(node.value.trim() === '' ? undefined : node.value.trim()));
    }
    return {
        node,
        onSibling(key) {
            if (key !== eventKey) return;
            const next = f.S.eventByValue.get(f.obj[eventKey])?.match;
            // Trocou para outra coleção: o filtro antigo não faz sentido nela.
            if ((next?.ref || null) !== (match?.ref || null) || !next) {
                if (f.obj[f.spec.key] !== undefined) delete f.obj[f.spec.key];
            }
            f.rerender();
        },
    };
});
