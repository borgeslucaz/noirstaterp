window.Panels = window.Panels || {};

function lootEntryRow(entry, index) {
    return `
        <div class="input-row" style="margin-bottom:8px" data-entry="${index}">
            ${itemPicker(`le-item-${index}`, entry.item, 'Qualquer nome de item')}
            <div class="unit-input" style="max-width:96px">
                <input type="number" id="le-min-${index}" value="${esc(entry.min ?? 1)}" min="1">
                <span class="unit">mín</span>
            </div>
            <div class="unit-input" style="max-width:96px">
                <input type="number" id="le-max-${index}" value="${esc(entry.max ?? 1)}" min="1">
                <span class="unit">máx</span>
            </div>
            <div class="unit-input" style="max-width:110px">
                <input type="number" id="le-chance-${index}" value="${esc(entry.chance ?? 100)}" min="1" max="100">
                <span class="unit">%</span>
            </div>
        </div>`;
}

function lootModal(existing) {
    const table = existing || { id: '', label: '', entries: [{ item: '', min: 1, max: 1, chance: 100 }] };
    const entries = table.entries.length ? table.entries : [{ item: '', min: 1, max: 1, chance: 100 }];

    modal(existing ? `Editar — ${existing.label}` : 'Nova tabela de saque', `
        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="lt-id">Id</label>
                <input type="text" id="lt-id" value="${esc(table.id)}" ${existing ? 'readonly' : ''}
                       placeholder="store_register">
            </div>
            <div class="field">
                <label class="field-label" for="lt-label">Nome</label>
                <input type="text" id="lt-label" value="${esc(table.label)}" placeholder="Caixa registradora da loja">
            </div>
        </div>
        <div class="section-title">Itens</div>
        <div id="loot-entries">${entries.map(lootEntryRow).join('')}</div>
        <button class="btn btn-ghost btn-sm" id="lt-add-entry">+ Adicionar item</button>
    `, async () => {
        const id = val('lt-id');
        if (!id) {
            toast('Falta o id', 'As etapas apontam para a tabela de saque pelo id.', 'warning');
            return false;
        }

        const collected = [];
        document.querySelectorAll('#loot-entries [data-entry]').forEach(row => {
            const i = row.dataset.entry;
            const item = val(`le-item-${i}`);
            if (!item) return;
            collected.push({
                item,
                min: num(`le-min-${i}`, 1),
                max: num(`le-max-${i}`, 1),
                chance: num(`le-chance-${i}`, 100),
            });
        });

        const res = await nui('saveLoot', { id, label: val('lt-label') || id, entries: collected });
        if (!reportResult(res, 'Salvo', val('lt-label') || id)) return false;

        State.loot = res.loot || State.loot;
        switchPanel('loot');
    });

    bindItemPickers(document.getElementById('modal-root'));

    document.getElementById('lt-add-entry')?.addEventListener('click', () => {
        const list = document.getElementById('loot-entries');
        const index = list.querySelectorAll('[data-entry]').length;
        list.insertAdjacentHTML('beforeend', lootEntryRow({ min: 1, max: 1, chance: 100 }, index));
        bindItemPickers(list);
        list.querySelector(`#le-item-${index}`)?.focus();
    });
}

window.Panels.loot = {
    render(el) {
        setTopbar('Tabelas de saque', 'Saques de itens reutilizáveis para as etapas', `
            <button class="btn btn-primary" id="act-new-loot">Nova tabela</button>
        `);

        if (State.loot.length === 0) {
            el.innerHTML = emptyState('&#9636;', 'Nenhuma tabela de saque',
                'Monte uma aqui e quantas etapas quiser podem pagar a partir dela. Mude uma vez e todas as etapas acompanham.',
                '<button class="btn btn-primary" id="empty-loot">Criar uma</button>');
        } else {
            el.innerHTML = `
                <div class="section-title">Tabelas</div>
                <div class="card-grid">
                    ${State.loot.map(t => `
                        <div class="card" data-id="${esc(t.id)}">
                            <div class="card-head">
                                <div>
                                    <div class="card-title">${esc(t.label)}</div>
                                    <div class="card-sub">${esc(t.id)}</div>
                                </div>
                                <span class="badge info">${(t.entries || []).length} itens</span>
                            </div>
                            <div class="card-stats" style="border-top:none;padding-top:11px;gap:7px">
                                <button class="btn btn-sm btn-ghost" data-act="edit">Editar</button>
                                <button class="btn btn-sm btn-danger" data-act="delete">Excluir</button>
                            </div>
                        </div>`).join('')}
                </div>`;
        }

        document.getElementById('act-new-loot')?.addEventListener('click', () => lootModal(null));
        document.getElementById('empty-loot')?.addEventListener('click', () => lootModal(null));

        el.querySelectorAll('.card').forEach(card => {
            const table = State.loot.find(t => t.id === card.dataset.id);
            card.addEventListener('click', (e) => {
                const act = e.target.dataset.act;
                if (act === 'delete') {
                    confirmDanger('Excluir esta tabela de saque?',
                        `As etapas que usam "${table.label}" não vão pagar nada até você apontá-las para outra tabela.`,
                        async () => {
                            const res = await nui('deleteLoot', table.id);
                            if (!reportResult(res, 'Excluída', table.label)) return;
                            State.loot = res.loot || [];
                            switchPanel('loot');
                        });
                } else {
                    lootModal(table);
                }
            });
        });
    },
};
