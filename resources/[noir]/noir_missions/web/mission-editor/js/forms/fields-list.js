// list: cartões aninhados (NPCs de um grupo, linhas de informação, ondas), recolhíveis, com
// subir/descer/duplicar/remover e limites min/max do esquema.
import { el, icon, button, iconButton } from '../dom.js';
import { registerField } from './registry.js';
import { defaultsFor, itemTitle, pathIndex, clone } from './schema-util.js';

// Estado recolhido por objeto: sobrevive ao redesenho do campo sem sujar a definição.
const collapsed = new WeakMap();

registerField('list', (f) => {
    const { spec } = f;
    const list = Array.isArray(f.value) ? f.value : [];
    if (!Array.isArray(f.value)) f.obj[spec.key] = list;
    const min = spec.min ?? 0;
    const max = spec.max ?? 64;
    const box = el('div', 'cards');

    const redraw = () => { f.changed(); f.rerender(); };

    list.forEach((item, index) => {
        if (!item || typeof item !== 'object') return;
        const path = pathIndex(f.path, index);
        if (!collapsed.has(item)) {
            const focused = f.focusPath && f.focusPath.startsWith(path);
            collapsed.set(item, !focused && list.length > 2);
        }
        const isCollapsed = collapsed.get(item);
        const fallback = `${spec.itemFallback || spec.label} ${index + 1}`;
        const title = el('span', { class: 'card-title', text: itemTitle(item, spec.itemLabel, fallback) });

        const toggle = el('button', {
            type: 'button', class: 'card-toggle', 'aria-expanded': String(!isCollapsed),
            on: { click: () => { collapsed.set(item, !isCollapsed); f.rerender(); } },
        }, el('span', { class: 'card-chevron', title: isCollapsed ? 'Expandir' : 'Recolher' }, icon(isCollapsed ? 'plus' : 'minus', 14)),
        el('span', { class: 'row-index num', text: String(index + 1).padStart(2, '0') }), title);

        const move = (target) => {
            [list[target], list[index]] = [list[index], list[target]];
            redraw();
        };
        const up = iconButton('up', 'Subir', () => move(index - 1));
        up.disabled = index === 0;
        const down = iconButton('down', 'Descer', () => move(index + 1));
        down.disabled = index === list.length - 1;
        const dup = iconButton('copy', 'Duplicar', () => {
            const copy = clone(item);
            collapsed.set(copy, false);
            list.splice(index + 1, 0, copy);
            redraw();
        });
        dup.disabled = list.length >= max;
        const del = iconButton('trash', 'Remover', () => { list.splice(index, 1); redraw(); }, 'danger');
        del.disabled = list.length <= min;

        const card = el('div', { class: isCollapsed ? 'card collapsed' : 'card', dataset: { path } },
            el('div', 'card-head', toggle, el('div', 'card-actions', up, down, dup, del)));
        if (!isCollapsed) {
            card.append(el('div', 'card-body', f.child(spec.fields, item, path, {
                onChildChange: (key) => {
                    if (key === spec.itemLabel) title.textContent = itemTitle(item, spec.itemLabel, fallback);
                },
            })));
        }
        box.append(card);
    });
    if (!list.length) box.append(el('div', { class: 'field-empty', text: 'Nenhum item.' }));

    const add = button('ADICIONAR', () => {
        const item = defaultsFor(spec.fields);
        collapsed.set(item, false);
        list.push(item);
        redraw();
    }, 'ghost', { small: true, icon: 'plus', disabled: list.length >= max });
    const count = el('span', { class: 'field-count num', text: `${list.length}${spec.max ? ` / ${spec.max}` : ''}${min ? ` · mínimo ${min}` : ''}` });
    return { node: el('div', 'list-field', box, el('div', 'list-foot', add, count)) };
});
