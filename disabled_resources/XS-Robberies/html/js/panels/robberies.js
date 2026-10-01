window.Panels = window.Panels || {};

const CATEGORY_LABELS = {
    store: 'Loja', bank: 'Banco', jewelry: 'Joalheria',
    atm: 'Caixa eletrônico', house: 'Casa', custom: 'Personalizado',
};

function createRobberyModal() {
    const categories = Object.entries(CATEGORY_LABELS)
        .map(([value, label]) => `<option value="${value}">${label}</option>`).join('');

    modal('Novo roubo', `
        <div class="field">
            <label class="field-label" for="new-name">Nome</label>
            <input type="text" id="new-name" placeholder="Loja 24-7">
            <div class="field-hint">O que a staff vê nesta lista. Jogadores nunca leem isso.</div>
        </div>
        <div class="field">
            <label class="field-label" for="new-category">Categoria</label>
            <select id="new-category">${categories}</select>
        </div>
    `, async () => {
        const name = val('new-name');
        if (!name) {
            toast('Dê um nome antes', 'Um roubo precisa de nome para ser salvo.', 'warning');
            return false;
        }

        const res = await nui('createRobbery', { name, category: val('new-category') });
        if (!reportResult(res, 'Criado', name)) return false;

        State.robberies = res.robberies || State.robberies;
        State.current = res.robbery;
        State.selectedStage = null;
        switchPanel('editor');
    }, 'Criar');
}

function importRobberyModal() {
    modal('Importar roubo', `
        <div class="field">
            <label class="field-label" for="import-json">Cole o JSON</label>
            <textarea id="import-json" placeholder='{"name":"Fleeca", "stages":[ ... ]}'></textarea>
            <div class="field-hint">Roubos importados chegam desligados, para nada ficar ativo antes de você conferir.</div>
        </div>
    `, async () => {
        const raw = val('import-json');
        if (!raw) return false;

        const res = await nui('importRobbery', raw);
        if (!reportResult(res, 'Importado', res && res.robbery ? res.robbery.name : '')) return false;

        State.robberies = res.robberies || State.robberies;
        State.current = res.robbery;
        switchPanel('editor');
    }, 'Importar');
}

async function exportRobbery(id, name) {
    const res = await nui('exportRobbery', id);
    if (!res || !res.ok) {
        toast('Não foi possível exportar', (res && res.error) || 'O servidor não respondeu.', 'error');
        return;
    }

    modal(`Exportar — ${name}`, `
        <div class="field">
            <label class="field-label">Copie e compartilhe</label>
            <textarea id="export-json" readonly style="min-height:220px">${esc(res.json)}</textarea>
        </div>
    `, null);

    const box = document.getElementById('export-json');
    if (box) { box.focus(); box.select(); }
}

function robberyCard(r) {
    const locations = State.locations.filter(l => l.robberyId === r.id).length;

    return `
        <div class="card" data-id="${esc(r.id)}" data-cat="${esc(r.category || 'custom')}">
            <div class="card-head">
                <div>
                    <div class="card-title">${esc(r.name)}</div>
                    <div class="cat-chip" style="--cat:var(--cat-${esc(r.category || 'custom')})">${esc(CATEGORY_LABELS[r.category] || r.category)}</div>
                    <div class="card-sub">${esc(r.id)}</div>
                </div>
                <span class="badge ${r.enabled ? 'on' : 'off'}">${r.enabled ? 'Ativo' : 'Rascunho'}</span>
            </div>
            <div class="card-stats">
                <div>
                    <div class="stat-label">Etapas</div>
                    <div class="stat-value">${r.stageCount || 0}</div>
                </div>
                <div>
                    <div class="stat-label">Locais</div>
                    <div class="stat-value">${locations}</div>
                </div>
                <div>
                    <div class="stat-label">Revisão</div>
                    <div class="stat-value">${r.revision || 1}</div>
                </div>
            </div>
            <div class="card-stats" style="border-top:none;padding-top:9px;gap:7px">
                <button class="btn btn-sm btn-ghost" data-act="duplicate">Duplicar</button>
                <button class="btn btn-sm btn-ghost" data-act="export">Exportar</button>
                <button class="btn btn-sm btn-danger" data-act="delete">Excluir</button>
            </div>
        </div>`;
}

async function presetsModal() {
    const res = await nui('presets');
    const presets = (res && res.ok && res.presets) || [];

    if (presets.length === 0) {
        toast('Nenhuma predefinição encontrada', 'A pasta presets não está no resource.', 'warning');
        return;
    }

    const cards = presets.map(p => {
        const missing = (p.missingItems || []).join(', ');
        const anchored = p.anchorKind === 'model';

        return [
            '<div class="card" data-preset="' + esc(p.id) + '" style="cursor:default">',
            '  <div class="card-head">',
            '    <div>',
            '      <div class="card-title">' + esc(p.name) + '</div>',
            '      <div class="card-sub">' + p.stageCount + ' etapas' +
                     (anchored ? ' &middot; acha os próprios pontos' : ' &middot; ' + p.locationCount + ' locais') + '</div>',
            '    </div>',
            p.installed ? '<span class="badge on">Instalado</span>' : '',
            '  </div>',
            '  <div class="field-hint" style="margin:10px 0 0">' + esc(p.description || '') + '</div>',
            p.alignedTo ? '<div class="field-hint" style="margin-top:6px;opacity:.75">Feito para: ' + esc(p.alignedTo) + '</div>' : '',
            missing ? '<div class="issue warn" style="margin-top:10px"><span class="issue-mark">?</span><span>Seu servidor não tem ' + esc(missing) + '. Adicione ' + ((p.missingItems || []).length === 1 ? 'o item' : 'os itens') + ' ou troque a etapa por algo que você tenha.</span></div>' : '',
            '  <div class="card-stats" style="border-top:none;padding-top:11px;gap:7px">',
            '    <button class="btn btn-sm btn-primary" data-install="' + esc(p.id) + '">Instalar</button>',
            (!anchored && p.locationCount > 0) ? '<button class="btn btn-sm btn-ghost" data-stamp="' + esc(p.id) + '">Instalar e carimbar ' + p.locationCount + '</button>' : '',
            '  </div>',
            '</div>',
        ].join('');
    }).join('');

    modal('Predefinições', '<div class="field-hint" style="margin-bottom:14px">Tudo chega desligado, com as tabelas de saque, para você conferir antes que alguém possa roubar. Nada aqui foi testado em jogo &mdash; trate as coordenadas como ponto de partida.</div><div class="card-grid">' + cards + '</div>', null, 'Salvar', 'wide');

    const install = async (id, stampAll) => {
        const result = await nui('installPreset', { id, stampAll });
        if (!reportResult(result, 'Instalado', stampAll ? `${result.stamped} locais carimbados` : 'Agora carimbe em algum local')) return;

        State.robberies = result.robberies || State.robberies;
        State.locations = result.locations || State.locations;
        State.loot = result.loot || State.loot;
        State.current = result.robbery;
        State.issues = result.issues || [];
        closeModal();
        switchPanel('editor');
    };

    document.querySelectorAll('[data-install]').forEach(b =>
        b.addEventListener('click', () => install(b.dataset.install, false)));
    document.querySelectorAll('[data-stamp]').forEach(b =>
        b.addEventListener('click', () => install(b.dataset.stamp, true)));
}
window.Panels.robberies = {
    render(el) {
        setTopbar('Roubos', 'Todos os roubos definidos neste servidor', `
            <button class="btn btn-ghost" id="act-presets">Predefinições</button>
            <button class="btn btn-ghost" id="act-import">Importar</button>
            <button class="btn btn-primary" id="act-new">Novo roubo</button>
        `);

        if (State.robberies.length === 0) {
            el.innerHTML = emptyState('&#9635;', 'Nada construído ainda',
                'Um roubo é um conjunto de etapas que você posiciona no mundo — um caixa, um cofre, uma câmera, uma saída. Monte um e carimbe em quantos locais quiser.',
                '<button class="btn btn-primary" id="empty-presets">Começar de uma predefinição</button>' +
                '<button class="btn btn-ghost" id="empty-new" style="margin-left:8px">Montar do zero</button>');
        } else {
            el.innerHTML = `
                <div class="section-title">Definições</div>
                <div class="card-grid">${State.robberies.map(robberyCard).join('')}</div>`;
        }

        document.getElementById('act-new')?.addEventListener('click', createRobberyModal);
        document.getElementById('act-import')?.addEventListener('click', importRobberyModal);
        document.getElementById('act-presets')?.addEventListener('click', presetsModal);
        document.getElementById('empty-new')?.addEventListener('click', createRobberyModal);
        document.getElementById('empty-presets')?.addEventListener('click', presetsModal);

        el.querySelectorAll('.card').forEach(card => {
            const id = card.dataset.id;
            const entry = State.robberies.find(r => r.id === id);

            card.addEventListener('click', (e) => {
                const act = e.target.dataset.act;
                if (!act) { openRobbery(id); return; }

                e.stopPropagation();

                if (act === 'export') {
                    exportRobbery(id, entry.name);
                } else if (act === 'duplicate') {
                    duplicateRobbery(id, entry.name);
                } else if (act === 'delete') {
                    confirmDanger('Excluir este roubo?',
                        `"${entry.name}" e todos os locais que o usam serão removidos. Não dá para desfazer.`,
                        async () => {
                            const res = await nui('deleteRobbery', id);
                            if (!reportResult(res, 'Excluído', entry.name)) return;
                            State.robberies = res.robberies || [];
                            State.locations = res.locations || [];
                            if (State.current && State.current.id === id) State.current = null;
                            switchPanel('robberies');
                        });
                }
            });
        });
    },
};

async function duplicateRobbery(id, name) {
    const res = await nui('duplicateRobbery', { id, name: `${name} cópia` });
    if (!reportResult(res, 'Duplicado', res && res.robbery ? res.robbery.name : '')) return;

    State.robberies = res.robberies || State.robberies;
    switchPanel('robberies');
}
