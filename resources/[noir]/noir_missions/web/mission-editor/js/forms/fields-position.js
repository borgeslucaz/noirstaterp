// position e positions: coordenadas editáveis + DEFINIR POSIÇÃO (posiciona no mundo),
// TELEPORTAR e PRÉVIA (entidade fantasma com o modelo do campo irmão `preview.modelKey`).
import { el, button, iconButton } from '../dom.js';
import { fetchNui } from '../nui.js';
import { codeText } from '../codes.js';
import { notify } from '../feedback.js';
import { registerField } from './registry.js';
import { requestPlacement, cleanPosition, round3 } from './placement.js';

function previewModel(f) {
    const key = f.spec.preview?.modelKey;
    const model = key ? f.obj[key] : undefined;
    return typeof model === 'string' && model.trim() ? model.trim() : null;
}

function isPosition(value) {
    return value && typeof value === 'object' && ['x', 'y', 'z'].every((axis) => Number.isFinite(Number(value[axis])));
}

async function place(f, current) {
    const model = previewModel(f);
    const kind = f.spec.preview && model ? f.spec.preview.kind : 'position';
    const result = await requestPlacement({
        kind,
        model: kind === 'position' ? undefined : model,
        heading: !!f.spec.heading,
        current: isPosition(current) ? current : undefined,
    });
    if (!result.ok) {
        if (!result.cancelled) notify('danger', codeText(result.code));
        return null;
    }
    return cleanPosition(result.position, !!f.spec.heading);
}

async function teleport(position) {
    const response = await fetchNui('editorTeleport', { position });
    if (!response.ok) notify('danger', codeText(response.code));
}

async function preview(f, position) {
    const model = previewModel(f);
    if (!model) return;
    const response = await fetchNui('editorPreview', { kind: f.spec.preview.kind, model, position });
    if (!response.ok) notify('danger', codeText(response.code));
}

/** Entradas X/Y/Z(/H) que editam o objeto da posição no lugar. */
function coordInputs(position, heading, onEdit, labelPrefix) {
    const axes = heading ? ['x', 'y', 'z', 'w'] : ['x', 'y', 'z'];
    return axes.map((axis) => {
        const input = el('input', {
            class: 'input num coord-input', type: 'number', step: '0.001',
            value: position[axis] === undefined ? (axis === 'w' ? '0' : '') : String(round3(position[axis])),
            'aria-label': `${labelPrefix} ${axis === 'w' ? 'H' : axis.toUpperCase()}`,
        });
        if (axis === 'w') { input.min = '0'; input.max = '360'; }
        input.addEventListener('input', () => {
            const number = Number(input.value);
            if (input.value === '' || !Number.isFinite(number)) return;
            position[axis] = number;
            onEdit();
        });
        input.addEventListener('change', () => {
            let number = Number(input.value);
            if (!Number.isFinite(number)) number = 0;
            if (axis === 'w') number = ((number % 360) + 360) % 360;
            number = round3(number);
            input.value = String(number);
            position[axis] = number;
            onEdit();
        });
        return el('label', 'coord', el('span', { class: 'coord-axis', text: axis === 'w' ? 'H' : axis.toUpperCase() }), input);
    });
}

registerField('position', (f) => {
    const { spec } = f;
    const value = f.value;
    const placeBtn = button('DEFINIR POSIÇÃO', async () => {
        const position = await place(f, f.value);
        if (position) { f.set(position); f.rerender(); }
    }, '', { small: true, icon: 'target' });

    if (!isPosition(value)) {
        return { node: el('div', 'pos pos-empty', el('span', { class: 'pos-none', text: 'Sem posição' }), placeBtn) };
    }

    const previewBtn = button('PRÉVIA', () => preview(f, f.value), '', { small: true, icon: 'eye' });
    previewBtn.hidden = !spec.preview || !previewModel(f);
    const actions = el('div', 'pos-actions',
        placeBtn,
        button('TELEPORTAR', () => teleport(f.value), '', { small: true, icon: 'teleport' }),
        previewBtn,
        spec.required ? null : iconButton('close', 'Limpar posição', () => { f.set(undefined); f.rerender(); }, 'danger'));
    const coords = el('div', 'coords', coordInputs(value, !!spec.heading, () => f.changed(), spec.label));
    return {
        node: el('div', 'pos', coords, actions),
        onSibling(key) {
            if (spec.preview && key === spec.preview.modelKey) previewBtn.hidden = !previewModel(f);
        },
    };
});

registerField('positions', (f) => {
    const { spec } = f;
    const list = Array.isArray(f.value) ? f.value : [];
    if (!Array.isArray(f.value)) f.obj[spec.key] = list;
    const max = spec.max ?? 64;
    const min = spec.min ?? 0;
    const hasPreview = !!spec.preview;
    const previewButtons = [];

    const rows = el('div', 'pos-list');
    list.forEach((position, index) => {
        if (!isPosition(position)) return;
        const previewBtn = iconButton('eye', 'Prévia', () => preview(f, position));
        previewBtn.hidden = !hasPreview || !previewModel(f);
        previewButtons.push(previewBtn);
        rows.append(el('div', 'pos-row',
            el('span', { class: 'row-index num', text: String(index + 1).padStart(2, '0') }),
            el('div', 'coords', coordInputs(position, !!spec.heading, () => f.changed(), `${spec.label} ${index + 1}`)),
            el('div', 'pos-row-actions',
                iconButton('target', 'Definir posição', async () => {
                    const next = await place(f, position);
                    if (next) { list[index] = next; f.changed(); f.rerender(); }
                }),
                iconButton('teleport', 'Teleportar', () => teleport(position)),
                previewBtn,
                moveButton('up', index, list, f),
                moveButton('down', index, list, f),
                removeButton(index, list, f, min))));
    });
    if (!list.length) rows.append(el('div', { class: 'field-empty', text: 'Nenhuma posição.' }));

    const add = button('ADICIONAR POSIÇÃO', async () => {
        const position = await place(f, list[list.length - 1]);
        if (position) { list.push(position); f.changed(); f.rerender(); }
    }, 'ghost', { small: true, icon: 'plus', disabled: list.length >= max });
    const count = el('span', { class: 'field-count num', text: `${list.length}${spec.max ? ` / ${spec.max}` : ''}${min ? ` · mínimo ${min}` : ''}` });

    return {
        node: el('div', 'positions', rows, el('div', 'list-foot', add, count)),
        onSibling(key) {
            if (hasPreview && key === spec.preview.modelKey) for (const btn of previewButtons) btn.hidden = !previewModel(f);
        },
    };
});

function moveButton(direction, index, list, f) {
    const target = direction === 'up' ? index - 1 : index + 1;
    const btn = iconButton(direction, direction === 'up' ? 'Subir' : 'Descer', () => {
        [list[target], list[index]] = [list[index], list[target]];
        f.changed();
        f.rerender();
    });
    btn.disabled = target < 0 || target >= list.length;
    return btn;
}

function removeButton(index, list, f, min) {
    const btn = iconButton('trash', 'Remover', () => { list.splice(index, 1); f.changed(); f.rerender(); }, 'danger');
    btn.disabled = list.length <= min;
    return btn;
}
