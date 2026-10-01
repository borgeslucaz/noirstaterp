// Formulário genérico: um renderizador por tipo de campo do esquema. Tipo novo = um
// registerField() num arquivo de forms/ importado por forms/index.js.
//
// Cada campo muta o objeto no lugar e avisa o formulário; o formulário reaplica showIf,
// valida "obrigatório" e sobe a mudança por opts.onChange. Só o campo que mudou de forma
// (lista, ações) se redesenha — o resto do formulário fica como está.
import { el, icon } from '../dom.js';
import { hiddenKeys, isEmptyValue, pathKey } from './schema-util.js';

/** @type {Map<string, (fctx: any) => {node: Node, onSibling?: (key: string) => void}>} */
const renderers = new Map();

// Tipos que ocupam a linha toda da grade de duas colunas.
const WIDE = new Set(['textarea', 'position', 'positions', 'actions', 'condition', 'list', 'refs', 'strings']);

export function registerField(type, render, { wide = false } = {}) {
    renderers.set(type, render);
    if (wide) WIDE.add(type);
}

/**
 * @typedef {object} FormOptions
 * @property {any} S esquema preparado
 * @property {any} def definição inteira (para refs e nomes legíveis)
 * @property {any} lists listas do servidor (itens, minigames, armas)
 * @property {string} path caminho do objeto (`steps[2]`)
 * @property {number} [depth] profundidade de ações (1 = lista de ações do passo)
 * @property {(key: string) => void} onChange
 * @property {Map<string,string>} [errors] erros do servidor por caminho
 * @property {string|null} [focusPath] caminho a destacar (painel de erros)
 * @property {Set<string>} [skip] chaves a não desenhar
 */

/**
 * @param {any[]} fields
 * @param {object} obj
 * @param {FormOptions} opts
 * @returns {HTMLElement}
 */
export function renderForm(fields, obj, opts) {
    const form = el('div', 'form');
    const entries = [];

    const applyVisibility = () => {
        const hidden = hiddenKeys(fields, obj);
        for (const entry of entries) entry.wrap.hidden = hidden.has(entry.spec.key);
        return hidden;
    };

    const validate = (entry) => {
        const { spec } = entry;
        let message = null;
        if (spec.required && !entry.wrap.hidden && isEmptyValue(obj[spec.key])) message = 'Obrigatório';
        else if (!entry.touched && opts.errors?.has(entry.path)) message = opts.errors.get(entry.path);
        entry.setError(message);
    };

    for (const spec of fields) {
        if (opts.skip?.has(spec.key)) continue;
        const path = pathKey(opts.path, spec.key);
        const wrap = el('div', { class: `field f-${spec.type}${WIDE.has(spec.type) ? ' wide' : ''}`, dataset: { path } });
        const labelId = `l${Math.random().toString(36).slice(2, 9)}`;
        const head = el('div', 'field-head',
            el('label', { class: 'field-label', id: labelId, text: spec.label || spec.key }),
            spec.required ? el('span', { class: 'field-req', title: 'Obrigatório', text: '*' }) : null);
        const body = el('div', 'field-body');
        const errorLine = el('div', { class: 'field-error', hidden: true });
        wrap.append(head, body);
        if (spec.help) wrap.append(el('div', { class: 'field-help', text: spec.help }));
        wrap.append(errorLine);

        const entry = {
            spec, wrap, path, touched: false, inst: null,
            setError(message) {
                errorLine.hidden = !message;
                errorLine.replaceChildren();
                if (message) errorLine.append(icon('alert', 13), el('span', { text: message }));
                wrap.classList.toggle('has-error', !!message);
            },
        };

        const fctx = {
            spec, obj, path, labelId,
            S: opts.S, def: opts.def, lists: opts.lists,
            depth: opts.depth || 0,
            focusPath: opts.focusPath,
            errors: opts.errors,
            get value() { return obj[spec.key]; },
            /** grava e avisa; undefined apaga a chave (o Lua aplica o default) */
            set(value) {
                if (value === undefined) delete obj[spec.key];
                else obj[spec.key] = value;
                fctx.changed();
            },
            changed() {
                entry.touched = true;
                applyVisibility();
                for (const other of entries) {
                    if (other !== entry) other.inst?.onSibling?.(spec.key);
                    validate(other);
                }
                opts.onChange(spec.key);
            },
            /** formulário filho (lista, ação) com o mesmo contexto */
            child(childFields, childObj, childPath, extra = {}) {
                const { onChildChange, ...rest } = extra;
                return renderForm(childFields, childObj, {
                    ...opts, path: childPath, skip: undefined, ...rest,
                    onChange: (key) => { if (onChildChange) onChildChange(key); fctx.changed(); },
                });
            },
            rerender() {
                const next = build();
                body.replaceChildren(next.node);
                entry.inst = next;
            },
        };

        const build = () => {
            const render = renderers.get(spec.type) || renderers.get('_unknown');
            return render(fctx);
        };
        entry.inst = build();
        body.append(entry.inst.node);
        entries.push(entry);
        form.append(wrap);
    }

    applyVisibility();
    for (const entry of entries) validate(entry);
    return form;
}

registerField('_unknown', (fctx) => ({
    node: el('div', { class: 'field-unknown', text: `Tipo de campo não suportado: ${fctx.spec.type}` }),
}));
