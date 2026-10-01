// Geral: metadados (schema.general), início (schema.start) e recompensas (schema.reward).
import { el } from '../../dom.js';
import { renderForm } from '../../forms/index.js';
import { sectionHead } from '../ui.js';

export function renderGeneral(host, ctx) {
    const { S, def } = ctx;
    if (!def.start || typeof def.start !== 'object') def.start = {};
    const base = { S, def, lists: ctx.lists, errors: ctx.errors, focusPath: ctx.focusPath, depth: 0 };

    const general = renderForm(S.general, def, { ...base, path: '', onChange: () => ctx.onEdit() });
    const start = renderForm(S.start, def.start, { ...base, path: 'start', onChange: () => ctx.onEdit() });

    // Recompensas reaproveitam o campo `list` com um spec montado aqui.
    const rewardsSpec = {
        type: 'list', key: 'rewards', label: 'Recompensas', fields: S.reward, itemLabel: 'item', itemFallback: 'Recompensa', max: 16,
    };
    const rewards = renderForm([rewardsSpec], def, {
        ...base, path: '', onChange: () => ctx.onStructure(),
    });
    rewards.classList.add('form-bare');

    host.append(el('div', { class: 'pane-scroll', dataset: { scroll: 'general' } },
        el('div', 'pane-pad',
            sectionHead('Geral', 'Nome, limites de jogadores, cooldown e exigência de gang.'),
            el('div', 'block', general),
            el('div', 'block',
                el('h3', { class: 'block-title', text: 'Início' }),
                el('p', { class: 'block-help', text: 'Como a missão chega aos jogadores.' }),
                start),
            el('div', 'block',
                el('h3', { class: 'block-title', text: 'Recompensas' }),
                el('p', { class: 'block-help', text: 'Entregues quando a missão é concluída.' }),
                rewards))));
}
