// actions: lista de ações do esquema (schema.actions). Cada ação é um cartão com os campos do
// tipo; `if`/`chance` têm campos `actions` dentro e o mesmo renderizador desenha o nível de
// baixo. Profundidade como no Lua (definition.lua): a lista do passo é 1, máximo 4.
import { el, button, iconButton } from '../dom.js';
import { openWindow } from '../modal.js';
import { registerField } from './registry.js';
import { defaultsFor, pathIndex, clone } from './schema-util.js';

const MAX_DEPTH = 4;
const PER_LIST = 32;

function hasNestedActions(actionSpec) {
    return actionSpec.fields.some((field) => field.type === 'actions');
}

/** Janela de escolha agrupada por schema.actions[].group. */
function pickAction(S, depth, onPick) {
    const groups = new Map();
    for (const action of S.actions) {
        // No último nível não dá para abrir mais um nível de ações.
        if (depth >= MAX_DEPTH && hasNestedActions(action)) continue;
        const group = action.group || 'Outras';
        if (!groups.has(group)) groups.set(group, []);
        groups.get(group).push(action);
    }
    openWindow({
        title: 'ADICIONAR AÇÃO',
        wide: true,
        cancel: { label: 'CANCELAR' },
        focus: 'input',
        content: (api) => {
            const search = el('input', { class: 'input', type: 'search', placeholder: 'Buscar ação', 'aria-label': 'Buscar ação' });
            const lists = el('div', 'picker');
            const buttons = [];
            for (const [group, actions] of groups) {
                const section = el('div', 'picker-group', el('div', { class: 'picker-title', text: group }));
                const grid = el('div', 'picker-grid');
                for (const action of actions) {
                    const btn = el('button', {
                        type: 'button', class: 'picker-item',
                        on: { click: () => { api.close(); onPick(action); } },
                    }, el('span', { class: 'picker-label', text: action.label }));
                    btn.dataset.search = `${action.label} ${action.type} ${group}`.toLowerCase();
                    buttons.push(btn);
                    grid.append(btn);
                }
                section.append(grid);
                lists.append(section);
            }
            search.addEventListener('input', () => {
                const term = search.value.trim().toLowerCase();
                for (const btn of buttons) btn.hidden = !!term && !btn.dataset.search.includes(term);
                for (const section of lists.children) {
                    section.hidden = ![...section.querySelectorAll('.picker-item')].some((btn) => !btn.hidden);
                }
            });
            search.addEventListener('keydown', (event) => {
                if (event.key === 'Enter') {
                    event.preventDefault();
                    event.stopPropagation();
                    buttons.find((btn) => !btn.hidden)?.click();
                }
            });
            return [search, lists];
        },
    });
}

registerField('actions', (f) => {
    const list = Array.isArray(f.value) ? f.value : [];
    if (!Array.isArray(f.value)) f.obj[f.spec.key] = list;
    const depth = (f.depth || 0) + 1;
    const box = el('div', { class: `actions depth-${Math.min(depth, MAX_DEPTH)}` });
    const redraw = () => { f.changed(); f.rerender(); };

    list.forEach((action, index) => {
        const path = pathIndex(f.path, index);
        const actionSpec = action && f.S.actionByType.get(action.type);
        const move = (target) => { [list[target], list[index]] = [list[index], list[target]]; redraw(); };
        const up = iconButton('up', 'Subir', () => move(index - 1));
        up.disabled = index === 0;
        const down = iconButton('down', 'Descer', () => move(index + 1));
        down.disabled = index === list.length - 1;
        const dup = iconButton('copy', 'Duplicar', () => { list.splice(index + 1, 0, clone(action)); redraw(); });
        dup.disabled = list.length >= PER_LIST;
        const del = iconButton('trash', 'Remover ação', () => { list.splice(index, 1); redraw(); }, 'danger');

        const head = el('div', 'action-head',
            el('span', { class: 'row-index num', text: String(index + 1).padStart(2, '0') }),
            el('span', { class: 'action-label', text: actionSpec ? actionSpec.label : `Ação desconhecida: ${action?.type ?? '?'}` }),
            actionSpec?.group ? el('span', { class: 'action-group', text: actionSpec.group }) : null,
            el('div', 'card-actions', up, down, dup, del));
        const card = el('div', { class: actionSpec ? 'action' : 'action unknown', dataset: { path } }, head);
        if (actionSpec && actionSpec.fields.length) {
            card.append(el('div', 'action-body', f.child(actionSpec.fields, action, path, { depth })));
        }
        if (f.errors?.has(path)) card.append(el('div', { class: 'field-error', text: f.errors.get(path) }));
        box.append(card);
    });

    const add = button('AÇÃO', () => pickAction(f.S, depth, (actionSpec) => {
        list.push({ type: actionSpec.type, ...defaultsFor(actionSpec.fields) });
        redraw();
    }), 'ghost', { small: true, icon: 'plus', disabled: list.length >= PER_LIST || depth > MAX_DEPTH });

    if (!list.length) box.append(el('div', { class: 'field-empty', text: depth > MAX_DEPTH ? 'Nível máximo de ações aninhadas.' : 'Nenhuma ação.' }));
    return { node: el('div', 'actions-field', box, el('div', 'list-foot', add)) };
});
