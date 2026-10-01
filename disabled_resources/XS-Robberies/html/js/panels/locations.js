window.Panels = window.Panels || {};

let openLocation = null;
let resolved = null;

async function stampLocation(robberyId) {
    const def = State.robberies.find(r => r.id === robberyId);
    if (!def) return;

    const coords = await placePoint({
        label: `${def.name}: origem`,
        colour: [25, 224, 140],
        mode: 'point',
    });

    if (!coords) return;

    const existing = State.locations.filter(l => l.robberyId === robberyId).length;

    const res = await nui('saveLocation', {
        robberyId,
        label: `${def.name} ${existing + 1}`,
        enabled: true,
        origin: coords,
        overrides: {},
        offsets: {},
    });

    if (!reportResult(res, 'Local carimbado', `${def.name} ${existing + 1}`)) return;

    State.locations = res.locations || State.locations;
    State.robberies = res.robberies || State.robberies;
    openLocation = res.location ? res.location.id : null;
    switchPanel('locations');
}

function stampModal() {
    if (State.robberies.length === 0) {
        toast('Nada para carimbar', 'Monte um roubo primeiro.', 'warning');
        return;
    }

    const options = State.robberies.map(r =>
        `<option value="${esc(r.id)}">${esc(r.name)}</option>`).join('');

    modal('Carimbar um local', `
        <div class="field">
            <label class="field-label" for="stamp-robbery">Roubo</label>
            <select id="stamp-robbery">${options}</select>
            <div class="field-hint">Cada etapa é posicionada em relação à origem que você escolher a seguir. Depois, ajuste etapas individuais se o interior não bater.</div>
        </div>
    `, async () => {
        const id = val('stamp-robbery');
        closeModal();
        await stampLocation(id);
        return false;
    }, 'Posicionar origem');
}

async function saveLocation(loc, quiet) {
    const res = await nui('saveLocation', loc);
    if (!reportResult(res, quiet ? null : 'Salvo', loc.label)) return false;

    State.locations = res.locations || State.locations;
    State.robberies = res.robberies || State.robberies;
    return true;
}

function overrideField(key, label, placeholder, overrides, unit) {
    const value = overrides[key];

    return `
        <div class="field">
            <label class="field-label" for="o-${key}">${esc(label)}</label>
            <div class="unit-input">
                <input type="number" id="o-${key}" value="${value === undefined ? '' : esc(value)}"
                       placeholder="${esc(placeholder)}" step="any">
                ${unit ? `<span class="unit">${esc(unit)}</span>` : ''}
            </div>
        </div>`;
}

function collectOverrides(inherited) {
    const overrides = {};

    const put = (key, target) => {
        const raw = val(`o-${key}`);
        if (raw === '') return;

        const value = parseFloat(raw);
        if (!Number.isFinite(value)) return;

        if (target) {
            overrides[target] = overrides[target] || {};
            overrides[target][key] = value;
        } else {
            overrides[key] = value;
        }
    };

    put('payoutMultiplier');
    put('radius');
    put('policeRequired', 'gates');
    put('locationCooldown', 'gates');

    const disabled = {};
    document.querySelectorAll('[data-stage-on]').forEach(box => {
        if (!box.checked) disabled[box.dataset.stageOn] = true;
    });
    if (Object.keys(disabled).length > 0) overrides.disabledStages = disabled;

    return overrides;
}

function offsetLabel(offset) {
    if (!offset) return 'como projetado';
    if (offset.worldModel) return 'preso no objeto do mapa';
    const parts = [offset.x || 0, offset.y || 0, offset.z || 0];
    if (parts.every(v => Math.abs(v) < 0.005)) return 'como projetado';
    return parts.map(v => (v >= 0 ? '+' : '') + v.toFixed(2)).join(' ');
}

async function nudgeStage(loc, stage) {
    const def = stageType(stage.type);

    const coords = await placePoint({
        label: `${stage.label} aqui`,
        colour: def ? def.colour : null,
        mode: 'point',
        origin: stage.coords,
        stageType: stage.type,
        stageOpts: stage.opts,
    });

    if (!coords) return;

    const current = loc.offsets[stage.id] || { x: 0, y: 0, z: 0 };
    loc.offsets[stage.id] = {
        x: Number((current.x + (coords.x - stage.coords.x)).toFixed(3)),
        y: Number((current.y + (coords.y - stage.coords.y)).toFixed(3)),
        z: Number((current.z + (coords.z - stage.coords.z)).toFixed(3)),
    };
    // Noir: G no posicionamento prende a etapa no objeto do mapa desta loja. Fica no
    // ajuste do local; Restaurar solta.
    const worldModel = coords.worldModel || current.worldModel;
    if (worldModel) loc.offsets[stage.id].worldModel = worldModel;

    if (await saveLocation(loc, true)) {
        toast('Ajustado', stage.label, 'success', 2400);
        // Noir: recarrega o local. Só trocar de painel redesenhava com os ajustes de antes,
        // e o próximo Ajustar/Salvar regravava por cima deste.
        openLocationDetail(loc.id);
    }
}

async function openLocationDetail(id) {
    const res = await nui('resolveLocation', id);
    if (!res || !res.ok) {
        toast('Não foi possível abrir', (res && res.error) || 'O servidor não respondeu.', 'error');
        openLocation = null;
        switchPanel('locations');
        return;
    }

    resolved = res;
    openLocation = id;
    switchPanel('locations');
}

function detailView(el) {
    const raw = State.locations.find(l => l.id === openLocation);
    const location = resolved.location;
    const overrides = resolved.overrides || {};
    const offsets = resolved.offsets || {};
    const def = State.robberies.find(r => r.id === location.robberyId);

    setTopbar(location.label, `${def ? def.name : location.robberyId} · ${location.stages.length} etapas`, `
        <button class="btn btn-ghost" id="act-back">Todos os locais</button>
        <button class="btn btn-primary" id="act-save-loc">Salvar</button>
    `);

    el.innerHTML = `
        <div class="options-head">
            <div style="flex:1">
                <div class="field" style="max-width:340px;margin:0">
                    <label class="field-label" for="loc-label">Nome</label>
                    <input type="text" id="loc-label" value="${esc(location.label)}">
                </div>
            </div>
            <div style="display:flex;align-items:center;gap:14px;flex-shrink:0">
                <label class="toggle">
                    <input type="checkbox" id="loc-enabled" ${raw && raw.enabled ? 'checked' : ''}>
                    <span class="toggle-track"></span>
                    <span class="toggle-label">Ativo</span>
                </label>
                <button class="btn btn-sm btn-ghost" id="act-move">Mover origem</button>
                <button class="btn btn-sm btn-ghost" id="act-goto">Ir até</button>
                <button class="btn btn-sm btn-danger" id="act-delete-loc">Excluir</button>
            </div>
        </div>

        <div class="section-title">Onde fica</div>
        <div class="field" style="margin-bottom:16px">
            ${coordRow('lo', location.origin)}
            <div class="field-hint">
                A âncora em volta da qual todo o resto é posicionado. Digite ou cole coordenadas
                para um interior personalizado, ou use Mover origem e posicione no olho. A direção
                é para onde o lugar está virado — acerte isso e todas as etapas giram junto.
            </div>
        </div>

        <div class="section-title">Ajustes do local</div>
        <div class="field-hint" style="margin-bottom:12px">
            Deixe um campo vazio e este local segue o roubo. Preencha e só este local muda.
        </div>
        <div class="field-grid">
            ${overrideField('payoutMultiplier', 'Multiplicador de pagamento', '1.0', overrides, '×')}
            ${overrideField('radius', 'Raio', String(def && def.radius || 30), overrides, 'm')}
            ${overrideField('policeRequired', 'Polícia necessária',
                String((def && def.gates && def.gates.policeRequired) ?? 2), overrides.gates || {})}
            ${overrideField('locationCooldown', 'Tempo de espera',
                String((def && def.gates && def.gates.locationCooldown) ?? 1800), overrides.gates || {}, 's')}
        </div>

        <div class="section-title">Etapas aqui</div>
        <div class="field-hint" style="margin-bottom:12px">
            As posições reais no mundo neste local. Ajuste as que não ficarem certas neste
            interior, ou desligue de vez a que este prédio não tiver — uma loja personalizada
            sem sala dos fundos pode tirar o cofre e manter todo o resto. De um jeito ou de
            outro, só este local muda.
        </div>
        ${location.stages.map(stage => {
            const type = stageType(stage.type);
            const colour = type ? rgbSolid(type.colour) : 'var(--accent)';
            const moved = offsetLabel(offsets[stage.id]);

            const gone = (overrides.disabledStages || {})[stage.id] === true;

            return `
                <div class="stage-row" data-stage="${esc(stage.id)}"
                     style="--stage-colour:${colour};cursor:default${gone ? ';opacity:.5' : ''}">
                    <label class="toggle" title="Desligar esta etapa só neste local">
                        <input type="checkbox" data-stage-on="${esc(stage.id)}" ${gone ? '' : 'checked'}>
                        <span class="toggle-track"></span>
                    </label>
                    <div class="stage-meta">
                        <div class="stage-name">${esc(stage.label || stage.id)}</div>
                        <div class="stage-type">${esc(fmtCoords(stage.coords))} · ${esc(moved)}</div>
                    </div>
                    ${gone ? '<span class="badge off">Não aqui</span>' : `
                        <button class="btn btn-sm btn-ghost" data-nudge="${esc(stage.id)}">Ajustar</button>
                        <button class="btn btn-sm btn-ghost" data-goto="${esc(stage.id)}">Ir até</button>`}
                    ${offsets[stage.id] ? `<button class="btn btn-sm btn-ghost" data-reset="${esc(stage.id)}">Restaurar</button>` : ''}
                </div>`;
        }).join('')}`;

    const model = () => ({
        id: location.id,
        robberyId: location.robberyId,
        label: val('loc-label') || location.label,
        enabled: checked('loc-enabled'),
        origin: document.getElementById('lo-x')
            ? readCoords('lo', location.origin)
            : (raw ? raw.origin : location.origin),
        overrides: collectOverrides(),
        // Noir: local sem ajuste volta do Lua como [] (tabela vazia vira array no JSON), e
        // chave posta num array some no JSON.stringify. Copia para objeto antes de usar.
        offsets: Object.assign({}, resolved.offsets || {}),
    });

    bindCoordPaste('lo');

    document.getElementById('act-back').addEventListener('click', () => {
        openLocation = null;
        switchPanel('locations');
    });

    document.getElementById('act-save-loc').addEventListener('click', async () => {
        if (await saveLocation(model())) openLocationDetail(location.id);
    });

    document.getElementById('act-move').addEventListener('click', async () => {
        const coords = await placePoint({
            label: `${location.label}: origem`,
            colour: [25, 224, 140],
            mode: 'point',
            origin: location.origin,
        });

        if (!coords) return;

        const next = model();
        next.origin = coords;

        if (await saveLocation(next, true)) {
            toast('Origem movida', 'Todas as etapas daqui foram junto.', 'success', 3000);
            openLocationDetail(location.id);
        }
    });

    document.getElementById('act-goto').addEventListener('click', () => {
        nui('teleport', { coords: location.origin });
    });

    document.getElementById('act-delete-loc').addEventListener('click', () => {
        confirmDanger('Excluir este local?', `"${location.label}" vai deixar de existir no mundo.`,
            async () => {
                const res = await nui('deleteLocation', location.id);
                if (!reportResult(res, 'Excluído', location.label)) return;
                State.locations = res.locations || [];
                State.robberies = res.robberies || State.robberies;
                openLocation = null;
                switchPanel('locations');
            });
    });

    el.querySelectorAll('[data-stage-on]').forEach(box => {
        box.addEventListener('change', async () => {
            if (await saveLocation(model(), true)) {
                toast(box.checked ? 'Ligada de novo aqui' : 'Desligada neste local',
                    'Só este local mudou.', 'success', 2600);
                openLocationDetail(location.id);
            }
        });
    });

    el.querySelectorAll('[data-nudge]').forEach(btn => {
        btn.addEventListener('click', () => {
            const stage = location.stages.find(s => s.id === btn.dataset.nudge);
            if (stage) nudgeStage(model(), stage);
        });
    });

    el.querySelectorAll('[data-goto]').forEach(btn => {
        btn.addEventListener('click', () => {
            const stage = location.stages.find(s => s.id === btn.dataset.goto);
            if (stage) nui('teleport', { coords: stage.coords });
        });
    });

    el.querySelectorAll('[data-reset]').forEach(btn => {
        btn.addEventListener('click', async () => {
            const next = model();
            delete next.offsets[btn.dataset.reset];
            if (await saveLocation(next, true)) {
                toast('De volta ao projeto', '', 'success', 2200);
                openLocationDetail(location.id);
            }
        });
    });
}

window.Panels.locations = {
    render(el) {
        if (openLocation && resolved && resolved.location && resolved.location.id === openLocation) {
            detailView(el);
            return;
        }

        setTopbar('Locais', 'Onde cada roubo existe de fato no mundo', `
            <button class="btn btn-primary" id="act-stamp">Carimbar um local</button>
        `);

        if (State.locations.length === 0) {
            el.innerHTML = emptyState('&#9678;', 'Nenhum local ainda',
                'Um roubo é só um modelo até você carimbá-lo em algum lugar. Carimbe o mesmo em todas as lojas e todas funcionam do mesmo jeito.',
                '<button class="btn btn-primary" id="empty-stamp">Carimbar o primeiro</button>');
        } else {
            const rows = State.locations.map(loc => {
                const def = State.robberies.find(r => r.id === loc.robberyId);
                const tweaks = Object.keys(loc.offsets || {}).length;
                const overrides = Object.keys(loc.overrides || {}).length;

                return `
                    <tr data-id="${loc.id}">
                        <td>${esc(loc.label)}</td>
                        <td>${esc(def ? def.name : loc.robberyId)}</td>
                        <td class="mono">${esc(fmtCoords(loc.origin))}</td>
                        <td>${tweaks ? `<span class="badge info">${tweaks} ajustadas</span>` : ''}
                            ${overrides ? '<span class="badge warn">com ajustes</span>' : ''}</td>
                        <td><span class="badge ${loc.enabled ? 'on' : 'off'}">${loc.enabled ? 'Ativo' : 'Desligado'}</span></td>
                        <td style="text-align:right">
                            <button class="btn btn-sm btn-ghost" data-act="open">Abrir</button>
                            <button class="btn btn-sm btn-ghost" data-act="go">Ir até</button>
                        </td>
                    </tr>`;
            }).join('');

            el.innerHTML = `
                <div class="section-title">Locais carimbados</div>
                <table class="table">
                    <thead>
                        <tr><th>Nome</th><th>Roubo</th><th>Origem</th><th>Alterações</th><th>Estado</th><th></th></tr>
                    </thead>
                    <tbody>${rows}</tbody>
                </table>`;
        }

        document.getElementById('act-stamp')?.addEventListener('click', stampModal);
        document.getElementById('empty-stamp')?.addEventListener('click', stampModal);

        el.querySelectorAll('tbody tr').forEach(row => {
            const id = parseInt(row.dataset.id, 10);
            const loc = State.locations.find(l => l.id === id);

            row.addEventListener('click', (e) => {
                if (e.target.dataset.act === 'go') {
                    nui('teleport', { coords: loc.origin });
                    return;
                }
                openLocationDetail(id);
            });
        });
    },
};
