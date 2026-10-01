// Passos: lista ordenada (arrastar, ou Alt+↑/↓) e o formulário do passo selecionado —
// campos comuns (schema.stepCommon) e depois os do tipo (schema.steps[].fields).
import { el, icon, button, iconButton } from '../../dom.js';
import { openWindow, confirmWindow } from '../../modal.js';
import { renderForm } from '../../forms/index.js';
import { arrayAt, defaultsFor, pathIndex, clone, toArray } from '../../forms/schema-util.js';
import { countRefs, uniqueId } from '../refs.js';
import { sectionHead } from '../ui.js';
import { idField } from './id-field.js';

const LIMIT = 64;

// Metade de baixo da linha = soltar depois dela. offsetY seria relativo ao filho sob o mouse.
function dropAfter(event, row) {
    const rect = row.getBoundingClientRect();
    return event.clientY - rect.top > rect.height / 2;
}

export function renderSteps(host, ctx) {
    const { S } = ctx;
    const steps = arrayAt(ctx.def, 'steps');
    let selected = Math.min(ctx.getSel('steps'), steps.length - 1);
    if (selected < 0 && steps.length) selected = 0;

    const rows = el('div', { class: 'item-list step-list', role: 'listbox', tabindex: '0', 'aria-label': 'Passos', dataset: { scroll: 'steps-list' } });
    const formPane = el('div', { class: 'pane-scroll form-pane', dataset: { scroll: 'steps-form' } });
    const addBtn = button('ADICIONAR PASSO', () => pickType(), 'ghost', { small: true, icon: 'plus' });

    host.append(
        el('div', 'pane-pad pane-top', sectionHead('Passos', 'Executados em ordem. Arraste pela alça ou use Alt+↑/↓ para reordenar.')),
        el('div', 'split split-steps',
            el('div', 'list-pane', el('div', 'list-tools', addBtn), rows),
            formPane));

    const typeLabel = (step) => S.stepByType.get(step?.type)?.label || `Tipo desconhecido: ${step?.type ?? '?'}`;
    const errorsAt = (index) => {
        const base = pathIndex('steps', index);
        let count = 0;
        for (const path of ctx.errors.keys()) if (path === base || path.startsWith(`${base}.`)) count += 1;
        return count;
    };

    function select(index, focusList = false) {
        selected = index;
        ctx.setSel('steps', index);
        drawList();
        drawForm();
        if (focusList) rows.focus({ preventScroll: true });
    }

    function move(from, to) {
        if (to < 0 || to >= steps.length || from === to) return;
        const [step] = steps.splice(from, 1);
        steps.splice(to, 0, step);
        ctx.onStructure();
        // A seleção segue o passo que estava aberto, não a posição.
        const open = steps.indexOf(openStep);
        select(open >= 0 ? open : to);
    }

    let openStep = steps[selected];
    let dragFrom = -1;

    function drawList() {
        openStep = steps[selected];
        addBtn.disabled = steps.length >= LIMIT;
        rows.replaceChildren();
        if (!steps.length) {
            rows.append(el('div', { class: 'row-info', text: 'Nenhum passo. Use ADICIONAR PASSO.' }));
            return;
        }
        steps.forEach((step, index) => {
            const isSel = index === selected;
            const enabled = el('input', { type: 'checkbox', checked: step.enabled !== false, 'aria-label': 'Passo ativo' });
            enabled.addEventListener('click', (event) => event.stopPropagation());
            enabled.addEventListener('change', () => {
                step.enabled = enabled.checked;
                row.classList.toggle('off', !enabled.checked);
                ctx.onEdit();
                if (index === selected) drawForm();
            });
            const handle = el('span', { class: 'drag-handle', title: 'Arrastar para reordenar', 'aria-hidden': 'true' }, icon('grip', 14));
            const errors = errorsAt(index);
            const dup = iconButton('copy', 'Duplicar passo', (event) => { event.stopPropagation(); duplicate(index); });
            dup.disabled = steps.length >= LIMIT;
            const row = el('div', {
                class: ['row', 'step-row', isSel ? 'selected' : '', step.enabled === false ? 'off' : ''].filter(Boolean).join(' '),
                role: 'option', 'aria-selected': String(isSel), dataset: { index: String(index) },
                on: { click: () => select(index) },
            },
            handle,
            el('span', { class: 'step-num num', text: String(index + 1).padStart(2, '0') }),
            el('div', 'item-text',
                el('span', { class: 'row-label', text: step.label || step.id || 'Sem nome' }),
                el('span', 'row-desc',
                    el('span', { text: typeLabel(step) }),
                    step.condition && toArray(step.condition.rules).length
                        ? el('span', { class: 'step-cond', title: 'Tem condição' }, icon('branch', 12), 'condição') : null)),
            errors ? el('span', { class: 'row-err num', title: `${errors} ${errors === 1 ? 'erro' : 'erros'}`, text: String(errors) }) : null,
            el('label', { class: 'toggle mini', title: 'Ativo', on: { click: (event) => event.stopPropagation() } }, enabled, el('span', 'track')),
            dup,
            iconButton('trash', 'Apagar passo', (event) => { event.stopPropagation(); remove(index); }, 'danger'));

            // Arrastar só pela alça: o resto da linha continua clicável e selecionável.
            handle.addEventListener('mousedown', () => { row.draggable = true; });
            row.addEventListener('mouseup', () => { row.draggable = false; });
            row.addEventListener('dragstart', (event) => {
                dragFrom = index;
                row.classList.add('dragging');
                event.dataTransfer.effectAllowed = 'move';
                event.dataTransfer.setData('text/plain', String(index));
            });
            row.addEventListener('dragend', () => {
                row.draggable = false;
                dragFrom = -1;
                row.classList.remove('dragging');
                for (const node of rows.querySelectorAll('.drop-before, .drop-after')) node.classList.remove('drop-before', 'drop-after');
            });
            row.addEventListener('dragover', (event) => {
                if (dragFrom < 0) return;
                event.preventDefault();
                const after = dropAfter(event, row);
                row.classList.toggle('drop-after', after);
                row.classList.toggle('drop-before', !after);
            });
            row.addEventListener('dragleave', () => row.classList.remove('drop-before', 'drop-after'));
            row.addEventListener('drop', (event) => {
                event.preventDefault();
                if (dragFrom < 0) return;
                const after = dropAfter(event, row);
                let to = after ? index + 1 : index;
                if (dragFrom < to) to -= 1;
                move(dragFrom, to);
            });
            rows.append(row);
        });
        rows.querySelector('.selected')?.scrollIntoView({ block: 'nearest' });
    }

    function drawForm() {
        formPane.replaceChildren();
        const step = steps[selected];
        if (!step) {
            formPane.append(el('div', 'pane-pad', el('div', { class: 'row-info', text: steps.length ? 'Escolha um passo na lista.' : 'Adicione o primeiro passo.' })));
            return;
        }
        const path = pathIndex('steps', selected);
        const typeSpec = S.stepByType.get(step.type);
        const heading = el('h3', { class: 'form-title', text: step.label || step.id });
        const onChange = (key) => {
            ctx.onEdit();
            const row = rows.querySelector(`[data-index="${selected}"]`);
            if (key === 'label') {
                heading.textContent = step.label || step.id;
                const label = row?.querySelector('.row-label');
                if (label) label.textContent = step.label || step.id || 'Sem nome';
            } else if (key === 'enabled' || key === 'condition') {
                drawList();
            }
        };
        const base = { S, def: ctx.def, lists: ctx.lists, errors: ctx.errors, focusPath: ctx.focusPath, depth: 0, path, onChange };
        const common = renderForm(S.stepCommon, step, base);
        const specific = typeSpec ? renderForm(typeSpec.fields, step, base) : null;

        formPane.append(el('div', 'pane-pad',
            heading,
            el('div', 'step-type',
                el('span', { class: 'tag', text: typeLabel(step) }),
                typeSpec?.description ? el('span', { class: 'step-type-desc', text: typeSpec.description }) : null),
            el('div', 'form id-form', idField({
                ctx, collectionKey: 'steps', list: steps, item: step, path,
                onRenamed: () => ctx.rerender(),
            })),
            common,
            specific && typeSpec.fields.length ? el('div', 'block', el('h3', { class: 'block-title', text: typeSpec.label }), specific) : null));
    }

    function newStep(typeSpec) {
        return {
            id: uniqueId(steps, 'step'),
            type: typeSpec.type,
            ...defaultsFor(S.stepCommon),
            ...defaultsFor(typeSpec.fields),
            label: typeSpec.label,
        };
    }

    function pickType() {
        if (steps.length >= LIMIT) return;
        openWindow({
            title: 'ADICIONAR PASSO',
            wide: true,
            cancel: { label: 'CANCELAR' },
            content: (api) => [el('div', 'picker picker-list', S.steps.map((typeSpec) => el('button', {
                type: 'button', class: 'picker-item tall',
                on: {
                    click: () => {
                        api.close();
                        const index = selected >= 0 ? selected + 1 : steps.length;
                        steps.splice(index, 0, newStep(typeSpec));
                        ctx.onStructure();
                        select(index);
                    },
                },
            }, el('span', { class: 'picker-label', text: typeSpec.label }), el('span', { class: 'picker-desc', text: typeSpec.description || '' }))))],
        });
    }

    function duplicate(index) {
        const source = steps[index];
        if (!source || steps.length >= LIMIT) return;
        const copy = clone(source);
        copy.id = uniqueId(steps, 'step');
        copy.label = `${source.label || source.id} (cópia)`;
        steps.splice(index + 1, 0, copy);
        ctx.onStructure();
        select(index + 1);
    }

    async function remove(index) {
        const step = steps[index];
        if (!step) return;
        const uses = step.id ? countRefs(S, ctx.def, 'steps', step.id) : 0;
        const yes = await confirmWindow({
            title: 'APAGAR PASSO',
            object: step.label || step.id,
            detail: `${String(index + 1).padStart(2, '0')} · ${typeLabel(step)}`,
            text: uses
                ? `Usado em ${uses} ${uses === 1 ? 'lugar' : 'lugares'} (Ir para o passo, gatilhos). Essas referências vão aparecer como erro.`
                : 'O passo e as ações dele serão removidos.',
            actionLabel: 'APAGAR',
        });
        if (!yes) return;
        const at = steps.indexOf(step);
        if (at < 0) return;
        steps.splice(at, 1);
        ctx.onStructure();
        select(Math.min(at, steps.length - 1));
    }

    rows.addEventListener('keydown', (event) => {
        if (!steps.length || event.target !== rows) return;
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
        event.preventDefault();
        const step = event.key === 'ArrowDown' ? 1 : -1;
        if (event.altKey) {
            if (selected >= 0) { move(selected, selected + step); rows.focus({ preventScroll: true }); }
        } else {
            select(selected < 0 ? 0 : (selected + step + steps.length) % steps.length, true);
        }
    });

    drawList();
    drawForm();
}
