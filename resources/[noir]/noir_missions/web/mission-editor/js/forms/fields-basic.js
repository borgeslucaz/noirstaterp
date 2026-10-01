// Campos simples: text, textarea, number, bool, select, model, item, weapon, minigame, var,
// strings.
import { el, icon, iconButton, button } from '../dom.js';
import { fetchNui } from '../nui.js';
import { registerField } from './registry.js';
import { toArray } from './schema-util.js';

const TEXT_MAX = 120;
const TEXTAREA_MAX = 600;
const STRING_MAX = 300;
const STRINGS_LIMIT = 32;

function asText(value) {
    return value === undefined || value === null ? '' : String(value);
}

function textInput(f, extra = {}) {
    return el('input', {
        class: 'input', type: 'text', value: asText(f.value),
        maxLength: f.spec.maxLength || TEXT_MAX,
        readOnly: !!f.spec.readonly,
        'aria-labelledby': f.labelId,
        spellcheck: 'false',
        ...extra,
    });
}

registerField('text', (f) => {
    const input = textInput(f);
    if (!f.spec.readonly) input.addEventListener('input', () => f.set(input.value === '' ? undefined : input.value));
    return { node: input };
});

registerField('textarea', (f) => {
    const area = el('textarea', {
        class: 'textarea', rows: 3, maxLength: f.spec.maxLength || TEXTAREA_MAX,
        'aria-labelledby': f.labelId, spellcheck: 'false',
    });
    area.value = asText(f.value);
    const counter = el('span', { class: 'field-count num' });
    const update = () => { counter.textContent = `${area.value.length} / ${area.maxLength}`; };
    update();
    area.addEventListener('input', () => { update(); f.set(area.value === '' ? undefined : area.value); });
    return { node: el('div', 'textarea-wrap', area, counter) };
});

registerField('number', (f) => {
    const { spec } = f;
    const input = el('input', {
        class: 'input num', type: 'number', value: asText(f.value), step: spec.step ?? 'any',
        'aria-labelledby': f.labelId,
    });
    if (spec.min !== undefined) input.min = String(spec.min);
    if (spec.max !== undefined) input.max = String(spec.max);
    const range = spec.min !== undefined && spec.max !== undefined ? el('span', { class: 'field-range num', text: `${spec.min}–${spec.max}` }) : null;
    input.addEventListener('input', () => {
        const number = input.value === '' ? NaN : Number(input.value);
        f.set(Number.isFinite(number) ? number : undefined);
    });
    // Limite aplicado ao sair do campo, para não brigar com quem está digitando.
    input.addEventListener('change', () => {
        let number = Number(input.value);
        if (input.value === '' || !Number.isFinite(number)) return;
        if (spec.min !== undefined && number < spec.min) number = spec.min;
        if (spec.max !== undefined && number > spec.max) number = spec.max;
        if (String(number) !== input.value) { input.value = String(number); f.set(number); }
    });
    return { node: range ? el('div', 'number-wrap', input, range) : input };
});

registerField('bool', (f) => {
    const input = el('input', { type: 'checkbox', checked: f.value === true, 'aria-labelledby': f.labelId });
    const state = el('span', { class: 'state', text: f.value === true ? 'Sim' : 'Não' });
    input.addEventListener('change', () => {
        state.textContent = input.checked ? 'Sim' : 'Não';
        f.set(input.checked);
    });
    return { node: el('label', 'toggle', input, el('span', 'track'), state) };
});

/**
 * Select com valores de qualquer tipo (número, booleano): o <option> guarda o índice.
 * @param {{value: any, label: string, disabled?: boolean, missing?: boolean}[]} options
 */
export function valueSelect(options, current, onPick, attrs = {}) {
    const select = el('select', { class: 'select', ...attrs });
    let selected = -1;
    options.forEach((option, index) => {
        const node = el('option', { value: String(index), text: option.label, disabled: option.disabled });
        if (option.missing) node.className = 'missing';
        if (selected < 0 && option.value === current) selected = index;
        select.append(node);
    });
    // Valor numérico salvo como texto (ou o contrário) ainda casa com a opção certa.
    if (selected < 0 && current !== undefined && current !== null) {
        selected = options.findIndex((option) => String(option.value) === String(current));
    }
    select.selectedIndex = Math.max(0, selected);
    select.addEventListener('change', () => onPick(options[Number(select.value)]?.value));
    return select;
}

registerField('select', (f) => {
    const options = toArray(f.spec.options).map((option) => ({ value: option.value, label: option.label ?? String(option.value) }));
    const current = f.value;
    const known = options.some((option) => option.value === current || String(option.value) === String(current));
    if (current !== undefined && current !== null && !known) {
        options.unshift({ value: current, label: `${current} (valor inválido)`, missing: true });
    } else if ((current === undefined || current === null) && f.spec.default === undefined) {
        options.unshift({ value: undefined, label: '—' });
    }
    return { node: valueSelect(options, current, (value) => f.set(value), { 'aria-labelledby': f.labelId }) };
});

// Modelo: validado pelo cliente do jogo (IsModelInCdimage + tipo) ao sair do campo.
const modelCache = new Map();

registerField('model', (f) => {
    const kind = f.spec.kind || 'object';
    const input = textInput(f, { placeholder: kind === 'ped' ? 'ex.: g_m_y_mexgoon_01' : kind === 'vehicle' ? 'ex.: speedo' : 'ex.: prop_barrel_02a', maxLength: 64 });
    const marker = el('span', { class: 'model-mark', 'aria-live': 'polite' });
    let ticket = 0;

    const show = (status) => {
        marker.dataset.status = status || '';
        marker.replaceChildren();
        marker.title = '';
        if (status === 'valid') { marker.append(icon('check', 14)); marker.title = 'Modelo existe'; }
        else if (status === 'invalid') { marker.append(icon('alert', 14), el('span', { text: 'Não existe' })); marker.title = 'Modelo não existe neste build'; }
        else if (status === 'checking') marker.append(el('span', { class: 'mini-spin' }));
    };

    const check = async () => {
        const model = input.value.trim().toLowerCase();
        if (model !== input.value) { input.value = model; f.set(model === '' ? undefined : model); }
        if (!model) { show(''); return; }
        const key = `${kind}:${model}`;
        if (modelCache.has(key)) { show(modelCache.get(key)); return; }
        const mine = ++ticket;
        show('checking');
        const response = await fetchNui('editorValidateModel', { kind, model });
        if (mine !== ticket) return;
        if (!response.ok) { show(''); return; }
        const status = response.valid ? 'valid' : 'invalid';
        modelCache.set(key, status);
        show(status);
    };

    const current = asText(f.value).toLowerCase();
    if (current && modelCache.has(`${kind}:${current}`)) show(modelCache.get(`${kind}:${current}`));
    input.addEventListener('input', () => { ticket += 1; show(''); f.set(input.value.trim() === '' ? undefined : input.value.trim()); });
    input.addEventListener('change', check);
    input.addEventListener('keydown', (event) => { if (event.key === 'Enter') { event.preventDefault(); check(); } });
    return { node: el('div', 'model-wrap', input, marker) };
});

registerField('item', (f) => {
    const input = textInput(f, { list: 'dl-items', placeholder: 'Nome do item', maxLength: 64 });
    const meta = el('span', 'field-meta');
    const update = () => {
        const name = input.value.trim();
        const item = toArray(f.lists?.items).find((entry) => entry.name === name);
        meta.textContent = !name ? '' : item ? item.label : 'Fora da lista de itens';
        meta.classList.toggle('warn', !!name && !item);
    };
    update();
    input.addEventListener('input', () => { update(); f.set(input.value.trim() === '' ? undefined : input.value.trim()); });
    return { node: el('div', 'meta-wrap', input, meta) };
});

registerField('weapon', (f) => {
    const input = textInput(f, { list: 'dl-weapons', placeholder: 'WEAPON_PISTOL', maxLength: 64 });
    input.addEventListener('input', () => f.set(input.value.trim() === '' ? undefined : input.value.trim()));
    input.addEventListener('change', () => {
        const upper = input.value.trim().toUpperCase();
        if (upper !== input.value) { input.value = upper; f.set(upper === '' ? undefined : upper); }
    });
    return { node: input };
});

registerField('var', (f) => {
    const input = textInput(f, { list: 'dl-vars', placeholder: 'nome da variável', maxLength: 64 });
    input.addEventListener('input', () => f.set(input.value.trim() === '' ? undefined : input.value.trim()));
    return { node: input };
});

registerField('minigame', (f) => {
    const current = f.value;
    const options = [{ value: undefined, label: 'Nenhum' }];
    for (const game of toArray(f.lists?.minigames)) {
        const available = game.available !== false;
        options.push({
            value: game.id,
            label: available ? game.label : `${game.label} (indisponível)`,
            // Indisponível não entra numa missão nova, mas o valor atual continua visível.
            disabled: !available && game.id !== current,
            missing: !available,
        });
    }
    if (current && !options.some((option) => option.value === current)) {
        options.push({ value: current, label: `${current} (não existe)`, missing: true });
    }
    return { node: valueSelect(options, current, (value) => f.set(value), { 'aria-labelledby': f.labelId }) };
});

registerField('strings', (f) => {
    const list = Array.isArray(f.value) ? f.value : [];
    if (!Array.isArray(f.value)) f.obj[f.spec.key] = list;
    const rows = el('div', 'strings');
    list.forEach((value, index) => {
        const input = el('input', {
            class: 'input', type: 'text', value: asText(value), maxLength: STRING_MAX,
            'aria-label': `${f.spec.label} ${index + 1}`, spellcheck: 'false',
        });
        input.addEventListener('input', () => { list[index] = input.value; f.changed(); });
        rows.append(el('div', 'strings-row',
            el('span', { class: 'row-index num', text: String(index + 1).padStart(2, '0') }),
            input,
            iconButton('trash', 'Remover', () => { list.splice(index, 1); f.changed(); f.rerender(); }, 'danger')));
    });
    const add = button('ADICIONAR', () => {
        list.push('');
        f.changed();
        f.rerender();
        // Foco no campo novo depois do redesenho.
        requestAnimationFrame(() => {
            document.querySelector(`[data-path="${CSS.escape(f.path)}"] .strings-row:last-child input`)?.focus();
        });
    }, 'ghost', { small: true, icon: 'plus', disabled: list.length >= STRINGS_LIMIT });
    if (!list.length) rows.append(el('div', { class: 'field-empty', text: 'Nenhum valor.' }));
    return { node: el('div', 'strings-wrap', rows, add) };
});
