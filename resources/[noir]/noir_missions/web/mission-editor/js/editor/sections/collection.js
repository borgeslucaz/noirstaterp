// Coleção genérica (zonas, NPCs, veículos… e gatilhos): lista à esquerda, formulário do item
// selecionado à direita. Campos vêm do esquema; o id é editável e renomeia as referências.
import { el, button } from '../../dom.js';
import { confirmWindow } from '../../modal.js';
import { renderForm } from '../../forms/index.js';
import { arrayAt, defaultsFor, itemTitle, pathIndex, clone } from '../../forms/schema-util.js';
import { countRefs, idPrefix, uniqueId } from '../refs.js';
import { sectionHead } from '../ui.js';
import { idField } from './id-field.js';

const LIMIT = 64;

/**
 * @param {HTMLElement} host
 * @param {any} ctx
 * @param {{key: string, label: string, singular?: string, itemLabel?: string, help?: string, fields: any[]}} col
 */
export function renderCollection(host, ctx, col) {
    const list = arrayAt(ctx.def, col.key);
    const singular = col.singular || 'item';
    const prefix = idPrefix(col.key);
    const titleOf = (item, index) => itemTitle(item, col.itemLabel, item?.id || `${singular} ${index + 1}`);

    let selected = Math.min(ctx.getSel(col.key), list.length - 1);
    const rows = el('div', { class: 'item-list', role: 'listbox', tabindex: '0', 'aria-label': col.label, dataset: { scroll: `${col.key}-list` } });
    const formPane = el('div', { class: 'pane-scroll form-pane', dataset: { scroll: `${col.key}-form` } });
    const addBtn = button('ADICIONAR', () => add(), 'ghost', { small: true, icon: 'plus' });
    const dupBtn = button('DUPLICAR', () => duplicate(), 'ghost', { small: true, icon: 'copy' });
    const delBtn = el('button', { type: 'button', class: 'btn small ghost danger-text', text: 'APAGAR', on: { click: () => remove() } });

    host.append(
        el('div', 'pane-pad pane-top', sectionHead(col.label, col.help)),
        el('div', 'split',
            el('div', 'list-pane', el('div', 'list-tools', addBtn, dupBtn, delBtn), rows),
            formPane));

    const errorsAt = (index) => {
        const base = pathIndex(col.key, index);
        let count = 0;
        for (const path of ctx.errors.keys()) if (path === base || path.startsWith(`${base}.`) || path.startsWith(`${base}[`)) count += 1;
        return count;
    };

    function select(index) {
        selected = index;
        ctx.setSel(col.key, index);
        drawList();
        drawForm();
    }

    function drawList() {
        rows.replaceChildren();
        addBtn.disabled = list.length >= LIMIT;
        dupBtn.disabled = selected < 0 || list.length >= LIMIT;
        delBtn.disabled = selected < 0;
        if (!list.length) {
            rows.append(el('div', { class: 'row-info', text: `Nenhum ${singular}. Use ADICIONAR.` }));
            return;
        }
        list.forEach((item, index) => {
            const title = titleOf(item, index);
            const errors = errorsAt(index);
            const row = el('div', {
                class: index === selected ? 'row item-row selected' : 'row item-row', role: 'option',
                'aria-selected': String(index === selected), dataset: { index: String(index) },
                on: { click: () => select(index) },
            },
            el('div', 'item-text',
                el('span', { class: 'row-label', text: title }),
                title !== item?.id ? el('span', { class: 'row-desc mono', text: item?.id || '(sem id)' }) : null),
            errors ? el('span', { class: 'row-err num', title: `${errors} ${errors === 1 ? 'erro' : 'erros'}`, text: String(errors) }) : null);
            rows.append(row);
        });
        rows.querySelector('.selected')?.scrollIntoView({ block: 'nearest' });
    }

    function drawForm() {
        formPane.replaceChildren();
        const item = list[selected];
        if (!item || typeof item !== 'object') {
            formPane.append(el('div', 'pane-pad', el('div', { class: 'row-info', text: list.length ? `Escolha um ${singular} na lista.` : `Adicione um ${singular} para editar.` })));
            return;
        }
        const path = pathIndex(col.key, selected);
        const heading = el('h3', { class: 'form-title', text: titleOf(item, selected) });
        const form = renderForm(col.fields, item, {
            S: ctx.S, def: ctx.def, lists: ctx.lists, errors: ctx.errors, focusPath: ctx.focusPath, depth: 0, path,
            onChange: (key) => {
                ctx.onEdit();
                if (key === col.itemLabel) {
                    heading.textContent = titleOf(item, selected);
                    const label = rows.querySelector(`[data-index="${selected}"] .row-label`);
                    if (label) label.textContent = titleOf(item, selected);
                }
            },
        });
        formPane.append(el('div', 'pane-pad',
            heading,
            el('div', 'form id-form', idField({
                ctx, collectionKey: col.key, list, item, path,
                onRenamed: () => ctx.rerender(),
            })),
            form));
    }

    function add() {
        if (list.length >= LIMIT) return;
        const item = { id: uniqueId(list, prefix), ...defaultsFor(col.fields) };
        const index = selected >= 0 ? selected + 1 : list.length;
        list.splice(index, 0, item);
        ctx.onStructure();
        select(index);
        formPane.querySelector('.f-id input')?.focus();
    }

    function duplicate() {
        const source = list[selected];
        if (!source || list.length >= LIMIT) return;
        const copy = clone(source);
        copy.id = uniqueId(list, source.id ? source.id.replace(/_\d+$/, '') : prefix);
        list.splice(selected + 1, 0, copy);
        ctx.onStructure();
        select(selected + 1);
    }

    async function remove() {
        const item = list[selected];
        if (!item) return;
        const uses = item.id ? countRefs(ctx.S, ctx.def, col.key, item.id) : 0;
        const yes = await confirmWindow({
            title: `APAGAR ${singular.toUpperCase()}`,
            object: titleOf(item, selected),
            detail: item.id,
            text: uses
                ? `Usado em ${uses} ${uses === 1 ? 'lugar' : 'lugares'}. Essas referências vão apontar para um item que não existe mais e aparecer como erro.`
                : 'Nada na missão usa este item.',
            actionLabel: 'APAGAR',
        });
        if (!yes) return;
        const index = list.indexOf(item);
        if (index < 0) return;
        list.splice(index, 1);
        ctx.onStructure();
        select(Math.min(index, list.length - 1));
    }

    rows.addEventListener('keydown', (event) => {
        if (!list.length) return;
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            const step = event.key === 'ArrowDown' ? 1 : -1;
            select(selected < 0 ? 0 : (selected + step + list.length) % list.length);
        }
    });

    if (selected < 0 && list.length) selected = 0;
    drawList();
    drawForm();
}
