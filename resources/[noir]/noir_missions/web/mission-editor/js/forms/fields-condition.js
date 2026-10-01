// condition: { mode: 'all'|'any', rules: [{ var, op, value }] }. Sem regra = sem condição
// (a chave sai da definição). Operadores iguais aos de shared/utils/conditions.lua.
import { el, button, iconButton } from '../dom.js';
import { registerField } from './registry.js';
import { valueSelect } from './fields-basic.js';
import { toArray } from './schema-util.js';

export const OPS = [
    { value: 'eq', label: 'igual a' },
    { value: 'neq', label: 'diferente de' },
    { value: 'gt', label: 'maior que' },
    { value: 'gte', label: 'maior ou igual a' },
    { value: 'lt', label: 'menor que' },
    { value: 'lte', label: 'menor ou igual a' },
    { value: 'true', label: 'é verdadeiro' },
    { value: 'false', label: 'é falso' },
];
const NO_VALUE = new Set(['true', 'false']);
const RULE_LIMIT = 12;

registerField('condition', (f) => {
    const condition = f.value && typeof f.value === 'object' ? f.value : null;
    const rules = condition ? toArray(condition.rules) : [];
    if (condition && !Array.isArray(condition.rules)) condition.rules = rules;

    const addRule = () => {
        const target = f.obj[f.spec.key] && typeof f.obj[f.spec.key] === 'object' ? f.obj[f.spec.key] : { mode: 'all', rules: [] };
        target.rules = toArray(target.rules);
        target.rules.push({ var: '', op: 'true' });
        f.set(target);
        f.rerender();
        requestAnimationFrame(() => {
            document.querySelector(`[data-path="${CSS.escape(f.path)}"] .rule:last-child .rule-var`)?.focus();
        });
    };

    const add = button('REGRA', addRule, 'ghost', { small: true, icon: 'plus', disabled: rules.length >= RULE_LIMIT });

    if (!rules.length) {
        return { node: el('div', 'cond cond-empty', el('span', { class: 'field-empty', text: 'Sem condição.' }), add) };
    }

    const mode = valueSelect(
        [{ value: 'all', label: 'Todas as regras' }, { value: 'any', label: 'Qualquer regra' }],
        condition.mode === 'any' ? 'any' : 'all',
        (value) => { condition.mode = value; f.changed(); f.rerender(); },
        { 'aria-label': 'Modo da condição', class: 'select cond-mode' },
    );

    const list = el('div', 'rules');
    rules.forEach((rule, index) => {
        const varInput = el('input', {
            class: 'input rule-var', type: 'text', list: 'dl-vars', value: rule.var ?? '', maxLength: 64,
            placeholder: 'variável ou valor', 'aria-label': `Regra ${index + 1}: variável`, spellcheck: 'false',
        });
        varInput.addEventListener('input', () => {
            rule.var = varInput.value.trim();
            varInput.classList.toggle('invalid', !rule.var);
            f.changed();
        });
        varInput.classList.toggle('invalid', !rule.var);

        const valueInput = el('input', {
            class: 'input rule-value', type: 'text', value: rule.value === undefined || rule.value === null ? '' : String(rule.value),
            maxLength: 120, placeholder: 'valor', 'aria-label': `Regra ${index + 1}: valor`, spellcheck: 'false',
        });
        valueInput.hidden = NO_VALUE.has(rule.op);
        valueInput.addEventListener('input', () => {
            if (valueInput.value === '') delete rule.value; else rule.value = valueInput.value;
            f.changed();
        });

        const op = valueSelect(OPS, OPS.some((entry) => entry.value === rule.op) ? rule.op : 'eq', (value) => {
            rule.op = value;
            valueInput.hidden = NO_VALUE.has(value);
            row.classList.toggle('no-value', NO_VALUE.has(value));
            if (NO_VALUE.has(value)) delete rule.value;
            f.changed();
        }, { 'aria-label': `Regra ${index + 1}: operador`, class: 'select rule-op' });

        const row = el('div', NO_VALUE.has(rule.op) ? 'rule no-value' : 'rule',
            el('span', { class: 'rule-join', text: index === 0 ? 'SE' : condition.mode === 'any' ? 'OU' : 'E' }),
            varInput, op, valueInput,
            iconButton('trash', 'Remover regra', () => {
                rules.splice(index, 1);
                if (!rules.length) f.set(undefined); else f.changed();
                f.rerender();
            }, 'danger'));
        list.append(row);
    });

    return { node: el('div', 'cond', el('div', 'cond-head', mode), list, el('div', 'list-foot', add)) };
});
