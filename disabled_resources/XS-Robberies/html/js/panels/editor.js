window.Panels = window.Panels || {};

let editorView = 'stage';
let advancedOpen = false;

function nextStageId(type) {
    const stages = State.current.stages || [];
    let n = 1;
    while (stages.some(s => s.id === `${type}_${n}`)) n++;
    return `${type}_${n}`;
}

function selectedStage() {
    if (!State.current) return null;
    return (State.current.stages || []).find(s => s.id === State.selectedStage) || null;
}

function typePickerModal() {
    const cards = State.stageTypes.map(t => `
        <div class="type-card" data-type="${esc(t.id)}" style="--type-colour:${rgbSolid(t.colour)}">
            <div class="type-name">${esc(t.label)}</div>
            <div class="type-blurb">${esc(t.blurb || '')}</div>
        </div>`).join('');

    modal('Adicionar etapa', `<div class="type-grid">${cards}</div>`, null);

    document.querySelectorAll('.type-card').forEach(card => {
        card.addEventListener('click', async () => {
            const type = card.dataset.type;
            closeModal();
            await addStage(type);
        });
    });
}

async function addStage(type) {
    const def = stageType(type);
    if (!def) return;

    const isZone = type === 'escape' || type === 'hold';

    const coords = await placePoint({
        label: def.label,
        colour: def.colour,
        mode: isZone ? 'zone' : 'point',
        radius: isZone ? 25 : undefined,
        stageType: type,
    });

    if (!coords) return;

    const stages = State.current.stages || (State.current.stages = []);
    const previous = stages[stages.length - 1];

    const opts = {};
    (def.fields || []).forEach(f => { opts[f.key] = f.default; });
    opts.label = `${def.label} ${stages.filter(s => s.type === type).length + 1}`;
    if (coords.radius !== undefined && opts.radius !== undefined) opts.radius = coords.radius;
    if (coords.worldModel) opts.worldModel = coords.worldModel;

    const stage = {
        id: nextStageId(type),
        type,
        label: opts.label,
        coords: { x: coords.x, y: coords.y, z: coords.z, h: coords.h },
        requires: previous ? [previous.id] : [],
        payout: { account: 'cash', min: 0, max: 0, lootTable: '' },
        opts,
    };

    stages.push(stage);
    State.selectedStage = stage.id;
    editorView = 'stage';

    await saveCurrent(true);
    switchPanel('editor');
    toast('Etapa posicionada', stage.label, 'success', 2600);
}

async function duplicateStage(source) {
    const def = stageType(source.type);
    const isZone = source.type === 'escape' || source.type === 'hold';

    const coords = await placePoint({
        label: `${source.label} (cópia)`,
        colour: def ? def.colour : null,
        mode: isZone ? 'zone' : 'point',
        radius: isZone ? (source.opts.radius || 25) : undefined,
        origin: source.coords,
        stageType: source.type,
        stageOpts: source.opts,
    });

    if (!coords) return;

    const stages = State.current.stages;
    const copy = JSON.parse(JSON.stringify(source));

    copy.id = nextStageId(source.type);
    copy.coords = { x: coords.x, y: coords.y, z: coords.z, h: coords.h };
    copy.opts.label = `${source.opts.label || source.label} ${
        stages.filter(s => s.type === source.type).length + 1}`;
    copy.label = copy.opts.label;

    if (coords.radius !== undefined && copy.opts.radius !== undefined) {
        copy.opts.radius = coords.radius;
    }

    // A paired point cannot share its partner — that would make three of them.
    if (copy.opts.pairWith !== undefined) copy.opts.pairWith = '';

    stages.push(copy);
    State.selectedStage = copy.id;

    await saveCurrent(true);
    switchPanel('editor');
    toast('Duplicada', `${copy.label} mantém todas as configurações de ${source.label}.`, 'success', 3200);
}

async function moveStage(stage) {
    const def = stageType(stage.type);
    const isZone = stage.type === 'escape' || stage.type === 'hold';

    const coords = await placePoint({
        label: def ? def.label : stage.type,
        colour: def ? def.colour : null,
        mode: isZone ? 'zone' : 'point',
        radius: isZone ? (stage.opts.radius || 25) : undefined,
        origin: stage.coords,
        stageType: stage.type,
        stageOpts: stage.opts,
    });

    if (!coords) return;

    stage.coords = { x: coords.x, y: coords.y, z: coords.z, h: coords.h };
    if (coords.radius !== undefined && stage.opts.radius !== undefined) stage.opts.radius = coords.radius;
    if (coords.worldModel) stage.opts.worldModel = coords.worldModel;

    await saveCurrent(true);
    switchPanel('editor');
    toast('Movida', stage.label, 'success', 2200);
}

function stageRow(stage, index) {
    const def = stageType(stage.type);
    const colour = def ? rgbSolid(def.colour) : 'var(--accent)';
    const placed = !!stage.coords;

    return `
        <div class="stage-row ${stage.id === State.selectedStage ? 'selected' : ''}"
             data-id="${esc(stage.id)}"
             style="--stage-colour:${colour}${stage.enabled === false ? ';opacity:.5' : ''}">
            <div class="stage-index">${index + 1}</div>
            <div class="stage-meta">
                <div class="stage-name">${esc(stage.label || stage.id)}</div>
                <div class="stage-type">${esc(def ? def.label : stage.type)}</div>
            </div>
            ${stage.enabled === false ? '<span class="badge off">Desligada</span>' : ''}
            ${placed ? '' : '<span class="stage-flag" title="Não posicionada">&#9888;</span>'}
            ${stage.opts && stage.opts.optional ? '<span class="badge off">Opc</span>' : ''}
        </div>`;
}

function requiresChips(stage) {
    const others = (State.current.stages || []).filter(s => s.id !== stage.id);
    if (others.length === 0) {
        return '<div class="field-hint">Ainda não há nada para esperar.</div>';
    }

    return `<div style="display:flex;flex-wrap:wrap;gap:6px">${others.map(o => {
        const on = (stage.requires || []).includes(o.id);
        return `<span class="badge ${on ? 'on' : 'off'}" data-req="${esc(o.id)}"
                      style="cursor:pointer">${esc(o.label || o.id)}</span>`;
    }).join('')}</div>`;
}

// A payout is any mix of cash, named items and a shared loot table. The old
// single-account shape is read back so nothing built before this breaks.
function normalisePayout(payout) {
    payout = payout || {};

    if (payout.cash || payout.items) {
        return {
            cash: payout.cash || null,
            items: payout.items || [],
            lootTable: payout.lootTable || '',
        };
    }

    const hasCash = (payout.max || 0) > 0 || (payout.min || 0) > 0;

    return {
        cash: hasCash
            ? { account: payout.account || 'cash', min: payout.min || 0, max: payout.max || 0 }
            : null,
        items: [],
        lootTable: payout.lootTable || '',
    };
}

function payoutItemRow(entry, index) {
    return `
        <div class="input-row" style="margin-bottom:8px" data-pay-item="${index}">
            ${itemPicker(`pi-item-${index}`, entry.item, 'Qualquer nome de item')}
            <div class="unit-input" style="max-width:88px">
                <input type="number" id="pi-min-${index}" value="${esc(entry.min ?? 1)}" min="1">
                <span class="unit">mín</span>
            </div>
            <div class="unit-input" style="max-width:88px">
                <input type="number" id="pi-max-${index}" value="${esc(entry.max ?? 1)}" min="1">
                <span class="unit">máx</span>
            </div>
            <div class="unit-input" style="max-width:96px">
                <input type="number" id="pi-chance-${index}" value="${esc(entry.chance ?? 100)}" min="1" max="100">
                <span class="unit">%</span>
            </div>
            <button class="btn btn-sm btn-ghost" data-pay-remove="${index}" style="flex:0 0 auto">&times;</button>
        </div>`;
}

function payoutSection(stage) {
    const reward = normalisePayout(stage.payout);
    const cash = reward.cash || { account: 'cash', min: 0, max: 0 };

    const accounts = State.accounts.map(a =>
        `<option value="${esc(a.id)}" ${cash.account === a.id ? 'selected' : ''}>${esc(a.label)}</option>`).join('');

    const loot = ['<option value="">Nenhuma</option>'].concat(State.loot.map(t =>
        `<option value="${esc(t.id)}" ${reward.lootTable === t.id ? 'selected' : ''}>${esc(t.label)}</option>`)).join('');

    return `
        <div class="section-title">Pagamento</div>
        <div class="field-hint" style="margin-bottom:12px">
            O que esta etapa paga vai para quem a fizer. Combine como quiser: só
            dinheiro, só itens, ou os dois. Deixe o dinheiro em zero para pagar só em
            mercadoria. Os itens caem no bolso na hora; o dinheiro vem quando o seu
            servidor fizer o pagamento.
        </div>

        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="p-account">Dinheiro vai para</label>
                <select id="p-account">${accounts}</select>
            </div>
            <div class="field">
                <label class="field-label" for="p-loot">Tabela de saque compartilhada</label>
                <select id="p-loot">${loot}</select>
            </div>
            <div class="field">
                <label class="field-label" for="p-min">Dinheiro mín.</label>
                <input type="number" id="p-min" value="${esc(cash.min || 0)}" min="0">
            </div>
            <div class="field">
                <label class="field-label" for="p-max">Dinheiro máx.</label>
                <input type="number" id="p-max" value="${esc(cash.max || 0)}" min="0">
            </div>
        </div>

        <div class="section-title" style="margin-top:6px">Itens</div>
        <div id="payout-items">${reward.items.map(payoutItemRow).join('')}</div>
        <button class="btn btn-ghost btn-sm" id="p-add-item">+ Adicionar item</button>`;
}

function minigameSelect(field, value) {
    const opts = State.minigames.map(m => {
        const label = m.available ? m.label : `${m.label} — requer ${m.resource}`;
        return `<option value="${esc(m.id)}" ${m.id === value ? 'selected' : ''}
                        ${m.available ? '' : 'disabled'}>${esc(label)}</option>`;
    }).join('');

    return `
        <div class="field">
            <label class="field-label" for="f-${esc(field.key)}">${esc(field.label)}</label>
            <div class="input-row">
                <select id="f-${esc(field.key)}">${opts}</select>
                <button class="btn btn-ghost btn-sm" id="mg-preview" style="flex:0 0 auto">Testar</button>
            </div>
        </div>`;
}

function stageSelect(field, value) {
    const others = (State.current.stages || []).filter(s => s.id !== State.selectedStage);
    const opts = ['<option value="">Nenhuma</option>'].concat(others.map(o =>
        `<option value="${esc(o.id)}" ${o.id === value ? 'selected' : ''}>${esc(o.label || o.id)}</option>`)).join('');

    return `
        <div class="field">
            <label class="field-label" for="f-${esc(field.key)}">${esc(field.label)}</label>
            <select id="f-${esc(field.key)}">${opts}</select>
        </div>`;
}

function itemSelect(field, value) {
    return `
        <div class="field">
            <label class="field-label" for="f-${esc(field.key)}">${esc(field.label)}</label>
            ${itemPicker(`f-${field.key}`, value, 'Deixe vazio para nenhum')}
        </div>`;
}

function renderFields(fields, stage) {
    return fields.map(f => {
        const value = stage.opts ? stage.opts[f.key] : f.default;
        if (f.type === 'minigame') return minigameSelect(f, value);
        if (f.type === 'stage') return stageSelect(f, value);
        if (f.type === 'item') return itemSelect(f, value);
        return fieldControl(f, value);
    }).join('');
}

function stageOptions(stage) {
    const def = stageType(stage.type);
    const fields = def ? def.fields : [];
    // Animation and props get their own section rather than hiding under
    // Advanced. They are the first thing an owner wants to change.
    const LOOK = ['animDict', 'animClip', 'animFlag', 'scenario', 'prop', 'propZ',
        'handProp', 'handBone', 'handOffset', 'progressStyle'];

    const basic = fields.filter(f => !f.advanced && !LOOK.includes(f.key));
    const look = fields.filter(f => LOOK.includes(f.key));
    const advanced = fields.filter(f => f.advanced && !LOOK.includes(f.key));
    const isLoot = ['register', 'safe', 'container'].includes(stage.type);

    return `
        <div class="options-head">
            <div>
                <div class="options-title">${esc(stage.label || stage.id)}</div>
                <div class="options-blurb">${esc(def ? def.blurb : '')}</div>
            </div>
            <div style="display:flex;gap:12px;flex-shrink:0;align-items:center">
                <label class="toggle" title="Desligar esta etapa sem excluí-la">
                    <input type="checkbox" id="stage-enabled" ${stage.enabled === false ? '' : 'checked'}>
                    <span class="toggle-track"></span>
                    <span class="toggle-label">${stage.enabled === false ? 'Desligada' : 'Ligada'}</span>
                </label>
                <button class="btn btn-sm btn-ghost" id="stage-move">Mover</button>
                <button class="btn btn-sm btn-ghost" id="stage-copy">Duplicar</button>
                <button class="btn btn-sm btn-ghost" id="stage-tp">Ir até</button>
                <button class="btn btn-sm btn-danger" id="stage-delete">Excluir</button>
            </div>
        </div>

        <div class="field" style="margin-bottom:14px">
            <label class="field-label">Onde fica
                <span class="mono" style="text-transform:none;letter-spacing:0">&nbsp;${esc(stage.id)}</span>
            </label>
            ${coordRow('sc', stage.coords)}
            <div class="field-hint">Digite, ou cole o conjunto inteiro em qualquer campo. Ou use Mover e posicione no olho.</div>
        </div>

        ${stage.enabled === false ? `
            <div class="issue warn" style="margin-bottom:14px">
                <span class="issue-mark">?</span>
                <span>Esta etapa está desligada. Ela não aparece no mundo, e o que
                estava esperando por ela segue sem ela.</span>
            </div>` : ''}

        <div class="section-title">Opções</div>
        <div class="field-grid">${renderFields(basic, stage)}</div>

        ${look.length ? `
            <div class="section-title">Aparência</div>
            <div class="field-hint" style="margin-bottom:10px">
                Coloque a animação que quiser nesta etapa. Um scenario é o caminho
                fácil; dict e clip dão controle exato. Deixe tudo vazio e a etapa
                usa o que combina com o tipo dela.
            </div>
            <div class="field-grid">${renderFields(look, stage)}</div>` : ''}

        ${advanced.length ? `
            <div class="advanced-toggle" id="adv-toggle">${advancedOpen ? '&#9662;' : '&#9656;'} Avançado</div>
            <div class="advanced-fields ${advancedOpen ? 'open' : ''}" id="adv-fields">
                <div class="field-grid">${renderFields(advanced, stage)}</div>
            </div>` : ''}

        ${isLoot ? payoutSection(stage) : ''}

        <div class="section-title">Requisitos</div>
        <div class="field-hint" style="margin-bottom:8px">
            Etapas que precisam estar concluídas antes de esta liberar. Escolha mais de uma para exigir todas, ou nenhuma para deixá-la disponível desde o início.
        </div>
        ${requiresChips(stage)}`;
}

function collectStage(stage) {
    if (!stage || !document.getElementById('sc-x')) return;

    const def = stageType(stage.type);
    (def ? def.fields : []).forEach(f => {
        if (f.type === 'minigame' || f.type === 'stage' || f.type === 'item') {
            stage.opts[f.key] = val(`f-${f.key}`);
        } else {
            stage.opts[f.key] = readField(f);
        }
    });

    stage.label = stage.opts.label || stage.label;

    if (document.getElementById('stage-enabled')) {
        stage.enabled = checked('stage-enabled');
    }

    if (document.getElementById('sc-x')) {
        stage.coords = readCoords('sc', stage.coords);
    }

    if (document.getElementById('p-account')) {
        const items = [];

        document.querySelectorAll('#payout-items [data-pay-item]').forEach(row => {
            const i = row.dataset.payItem;
            const item = val(`pi-item-${i}`);
            if (!item) return;

            items.push({
                item,
                min: num(`pi-min-${i}`, 1),
                max: num(`pi-max-${i}`, 1),
                chance: num(`pi-chance-${i}`, 100),
            });
        });

        const max = num('p-max', 0);

        stage.payout = {
            cash: max > 0 || num('p-min', 0) > 0
                ? { account: val('p-account'), min: num('p-min', 0), max: max }
                : null,
            items,
            lootTable: val('p-loot'),
        };
    }
}

function robberySettings() {
    const def = State.current;
    const anchor = def.anchor || {};
    const categories = Object.entries(CATEGORY_LABELS).map(([value, label]) =>
        `<option value="${value}" ${def.category === value ? 'selected' : ''}>${label}</option>`).join('');

    const alarmModes = [
        { value: 'instant', label: 'Imediato' },
        { value: 'delayed', label: 'Com atraso' },
        { value: 'silent',  label: 'Silencioso' },
        { value: 'none',    label: 'Sem alarme' },
    ];

    const alarmOptions = (selected) => alarmModes.map(m =>
        `<option value="${m.value}" ${selected === m.value ? 'selected' : ''}>${m.label}</option>`).join('');

    const g = def.gates || {};
    const r = def.response || {};
    const b = def.blip || {};

    return `
        <div class="options-head">
            <div>
                <div class="options-title">${esc(def.name)}</div>
                <div class="options-blurb">Vale para todo local criado a partir deste roubo. Cada local pode sobrescrever os números.</div>
            </div>
            <label class="toggle" style="flex-shrink:0">
                <input type="checkbox" id="r-enabled" ${def.enabled ? 'checked' : ''}>
                <span class="toggle-track"></span>
                <span class="toggle-label">Ativo</span>
            </label>
        </div>

        <div class="section-title">Âncora</div>
        <div class="field-hint" style="margin-bottom:12px">
            Locais carimbados servem para loja ou banco, onde cada ponto é posicionado à mão.
            Modelos de prop servem para o que o mapa já tem às centenas: aponte para os
            modelos de ATM e todo ATM de Los Santos vira roubável, sem carimbar nada.
        </div>
        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="a-kind">Âncora</label>
                <select id="a-kind">
                    <option value="location" ${anchor.kind !== 'model' ? 'selected' : ''}>Locais carimbados</option>
                    <option value="model" ${anchor.kind === 'model' ? 'selected' : ''}>Modelos de prop</option>
                </select>
            </div>
            <div class="field">
                <label class="field-label" for="a-pool">Procurar</label>
                <select id="a-pool">
                    <option value="object" ${(anchor.pool || 'object') === 'object' ? 'selected' : ''}>Props</option>
                    <option value="vehicle" ${anchor.pool === 'vehicle' ? 'selected' : ''}>Veículos</option>
                    <option value="ped" ${anchor.pool === 'ped' ? 'selected' : ''}>Peds</option>
                </select>
            </div>
            <div class="field">
                <label class="field-label" for="a-range">Buscar num raio de</label>
                <div class="unit-input">
                    <input type="number" id="a-range" value="${esc(anchor.scanRange ?? 80)}" min="10" max="300">
                    <span class="unit">m</span>
                </div>
            </div>
            <div class="field wide">
                <label class="field-label" for="a-models">Modelos de prop</label>
                <input type="text" id="a-models" value="${esc((anchor.models || []).join(', '))}"
                       placeholder="prop_atm_01, prop_atm_02, prop_atm_03, prop_fleeca_atm">
                <div class="field-hint">
                    Separados por vírgula. As posições das etapas são lidas como deslocamento de
                    onde você as montou, então uma etapa posta no ATM cai em todo ATM.
                </div>
            </div>
        </div>

        <div class="section-title">Identidade</div>
        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="r-name">Nome</label>
                <input type="text" id="r-name" value="${esc(def.name)}">
            </div>
            <div class="field">
                <label class="field-label" for="r-category">Categoria</label>
                <select id="r-category">${categories}</select>
            </div>
        </div>

        <div class="section-title">Quem pode iniciar</div>
        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="g-policeRequired">Polícia necessária</label>
                <input type="number" id="g-policeRequired" value="${esc(g.policeRequired ?? 2)}" min="0">
            </div>
            <div class="field">
                <label class="toggle" style="margin-top:22px">
                    <input type="checkbox" id="g-policeOnDuty" ${g.policeOnDuty ? 'checked' : ''}>
                    <span class="toggle-track"></span>
                    <span class="toggle-label">Só em serviço</span>
                </label>
            </div>
            <div class="field">
                <label class="field-label" for="g-minCrew">Equipe mínima</label>
                <input type="number" id="g-minCrew" value="${esc(g.minCrew ?? 1)}" min="1">
            </div>
            <div class="field">
                <label class="field-label" for="g-maxCrew">Equipe máxima</label>
                <input type="number" id="g-maxCrew" value="${esc(g.maxCrew ?? 6)}" min="1">
            </div>
            <div class="field">
                <label class="field-label" for="g-locationCooldown">Espera do local</label>
                <div class="unit-input">
                    <input type="number" id="g-locationCooldown" value="${esc(g.locationCooldown ?? 1800)}" min="0">
                    <span class="unit">s</span>
                </div>
            </div>
            <div class="field">
                <label class="field-label" for="g-playerCooldown">Espera do jogador</label>
                <div class="unit-input">
                    <input type="number" id="g-playerCooldown" value="${esc(g.playerCooldown ?? 900)}" min="0">
                    <span class="unit">s</span>
                </div>
            </div>
            <div class="field">
                <label class="field-label" for="g-globalCooldown">Espera global do servidor</label>
                <div class="unit-input">
                    <input type="number" id="g-globalCooldown" value="${esc(g.globalCooldown ?? 0)}" min="0">
                    <span class="unit">s</span>
                </div>
                <div class="field-hint">Bloqueia todos os locais deste roubo, não só o que foi atingido. 0 para nenhuma.</div>
            </div>
            <div class="field">
                <label class="field-label" for="g-proximityMetres">Nenhum outro roubo num raio de</label>
                <div class="unit-input">
                    <input type="number" id="g-proximityMetres" value="${esc(g.proximityMetres ?? 0)}" min="0">
                    <span class="unit">m</span>
                </div>
            </div>
            <div class="field">
                <label class="field-label" for="g-proximitySeconds">…por este tempo</label>
                <div class="unit-input">
                    <input type="number" id="g-proximitySeconds" value="${esc(g.proximitySeconds ?? 0)}" min="0">
                    <span class="unit">s</span>
                </div>
                <div class="field-hint">Impede uma equipe de limpar a rua inteira de uma vez. Os dois campos precisam de um número.</div>
            </div>
        </div>

        <div class="section-title">No mundo</div>
        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="w-radius">Raio</label>
                <div class="unit-input">
                    <input type="number" id="w-radius" value="${esc(def.radius ?? 30)}" min="5" step="any">
                    <span class="unit">m</span>
                </div>
                <div class="field-hint">Até que distância da origem alguém ainda conta como presente.</div>
            </div>
            <div class="field">
                <label class="field-label" for="w-showWhen">Mostrar o blip</label>
                <select id="w-showWhen">
                    ${['always', 'during', 'never'].map(v => `<option value="${v}"
                        ${(b.showWhen || 'during') === v ? 'selected' : ''}>${
                            v === 'always' ? 'Sempre' : v === 'during' ? 'Só durante um assalto' : 'Nunca'
                        }</option>`).join('')}
                </select>
            </div>
            <div class="field">
                <label class="field-label" for="w-label">Nome do blip</label>
                <input type="text" id="w-label" value="${esc(b.label || def.name || '')}">
            </div>
            <div class="field">
                <label class="field-label" for="w-sprite">Sprite do blip</label>
                <input type="number" id="w-sprite" value="${esc(b.sprite ?? 500)}" min="1">
                <div class="field-hint">Qualquer id de sprite de blip do GTA.</div>
            </div>
            <div class="field">
                <label class="field-label" for="w-colour">Cor do blip</label>
                <input type="number" id="w-colour" value="${esc(b.colour ?? 1)}" min="0" max="85">
            </div>
            <div class="field">
                <label class="field-label" for="w-scale">Escala do blip</label>
                <input type="number" id="w-scale" value="${esc(b.scale ?? 0.8)}" min="0.1" max="3" step="0.1">
            </div>
        </div>

        <div class="section-title">Resposta da polícia</div>
        <div class="field-grid">
            <div class="field">
                <label class="field-label" for="p-alarm">Alarme</label>
                <select id="p-alarm">${alarmOptions(r.alarm || 'instant')}</select>
            </div>
            <div class="field">
                <label class="field-label" for="p-alarmDelay">Atraso</label>
                <div class="unit-input">
                    <input type="number" id="p-alarmDelay" value="${esc(r.alarmDelay ?? 30)}" min="0">
                    <span class="unit">s</span>
                </div>
            </div>
            <div class="field">
                <label class="field-label" for="p-cameras">Com câmeras desligadas, vira</label>
                <select id="p-cameras">${alarmOptions(r.camerasChangeTo || 'delayed')}</select>
            </div>
            <div class="field">
                <label class="field-label" for="p-power">Com energia cortada, vira</label>
                <select id="p-power">${alarmOptions(r.powerChangesTo || 'silent')}</select>
            </div>
            <div class="field">
                <label class="field-label" for="p-code">Código do chamado</label>
                <input type="text" id="p-code" value="${esc(r.code || '10-90')}">
            </div>
            <div class="field">
                <label class="field-label" for="p-title">Título do chamado</label>
                <input type="text" id="p-title" value="${esc(r.title || 'Roubo')}">
            </div>
            <div class="field">
                <label class="field-label" for="p-repeat">Repetir alerta a cada</label>
                <div class="unit-input">
                    <input type="number" id="p-repeat" value="${esc(r.repeatAlert ?? 120)}" min="0">
                    <span class="unit">s</span>
                </div>
            </div>
            <div class="field">
                <label class="toggle" style="margin-top:22px">
                    <input type="checkbox" id="p-onfail" ${r.dispatchOnFail ? 'checked' : ''}>
                    <span class="toggle-track"></span>
                    <span class="toggle-label">Abrir chamado quando uma etapa falhar</span>
                </label>
            </div>
        </div>`;
}

function collectSettings() {
    const def = State.current;

    // Reading fields that are not on screen would write empty strings and a
    // false toggle straight over real settings.
    if (!def || !document.getElementById('r-enabled')) return;
    def.name = val('r-name') || def.name;
    def.category = val('r-category');
    def.enabled = checked('r-enabled');

    def.anchor = {
        kind: val('a-kind') || 'location',
        models: val('a-models').split(',').map(m => m.trim()).filter(Boolean),
        pool: val('a-pool') || 'object',
        scanRange: num('a-range', 80),
    };

    def.gates = Object.assign({}, def.gates, {
        policeRequired: num('g-policeRequired', 0),
        policeOnDuty: checked('g-policeOnDuty'),
        minCrew: num('g-minCrew', 1),
        maxCrew: num('g-maxCrew', 6),
        locationCooldown: num('g-locationCooldown', 0),
        playerCooldown: num('g-playerCooldown', 0),
        globalCooldown: num('g-globalCooldown', 0),
        proximityMetres: num('g-proximityMetres', 0),
        proximitySeconds: num('g-proximitySeconds', 0),
    });

    def.radius = num('w-radius', def.radius || 30);
    def.blip = Object.assign({}, def.blip, {
        showWhen: val('w-showWhen'),
        label: val('w-label'),
        sprite: num('w-sprite', 500),
        colour: num('w-colour', 1),
        scale: num('w-scale', 0.8),
    });

    def.response = Object.assign({}, def.response, {
        alarm: val('p-alarm'),
        alarmDelay: num('p-alarmDelay', 0),
        camerasChangeTo: val('p-cameras'),
        powerChangesTo: val('p-power'),
        code: val('p-code'),
        title: val('p-title'),
        repeatAlert: num('p-repeat', 0),
        dispatchOnFail: checked('p-onfail'),
    });
}

function issuesBlock() {
    const issues = State.issues || [];
    if (issues.length === 0) return '';

    return `
        <div class="section-title">Problemas</div>
        ${issues.map(i => `
            <div class="issue ${i.level === 'error' ? 'error' : 'warn'}"
                 ${i.stage ? `data-issue="${esc(i.stage)}" style="cursor:pointer"` : ''}>
                <span class="issue-mark">${i.level === 'error' ? '!' : '?'}</span>
                <span>${esc(i.message)}</span>
            </div>`).join('')}`;
}

window.Panels.editor = {
    render(el) {
        if (!State.current) {
            setTopbar('Editor', 'Nada aberto');
            el.innerHTML = emptyState('&#9881;', 'Nenhum roubo aberto',
                'Escolha um no painel Roubos, ou monte um novo.',
                '<button class="btn btn-primary" id="editor-back">Ir para Roubos</button>');
            document.getElementById('editor-back')?.addEventListener('click', () => switchPanel('robberies'));
            return;
        }

        const def = State.current;
        const stages = def.stages || [];

        setTopbar(def.name, `${def.id} · ${stages.length} etapa${stages.length === 1 ? '' : 's'}`, `
            <button class="btn ${def.enabled ? 'btn-primary' : 'btn-ghost'}" id="act-live"
                    title="${def.enabled ? 'Os jogadores podem roubar isto' : 'Nada aparece no mundo até isto estar ativo'}">
                ${def.enabled ? '&#9679; Ativo' : '&#9675; Rascunho'}
            </button>
            <button class="btn btn-ghost" id="act-settings">Configurações do roubo</button>
            <button class="btn btn-ghost" id="act-validate">Validar</button>
            <button class="btn btn-primary" id="act-save">Salvar</button>
        `);

        const stage = selectedStage();

        el.innerHTML = `
            <div id="editor-layout">
                <div class="editor-col">
                    <div class="section-title">Etapas</div>
                    <div class="stage-list" id="stage-list">
                        ${stages.length ? stages.map(stageRow).join('')
                            : '<div class="field-hint">Nenhuma etapa ainda. Adicione a primeira.</div>'}
                    </div>
                    <button class="btn btn-primary" id="act-add" style="margin-top:11px;justify-content:center">
                        + Adicionar etapa
                    </button>
                </div>
                <div class="editor-col" style="overflow-y:auto;padding-right:4px">
                    ${editorView === 'settings' ? robberySettings()
                        : stage ? stageOptions(stage)
                        : emptyState('&#9635;', 'Nada selecionado', 'Escolha uma etapa à esquerda, ou adicione uma.')}
                    ${issuesBlock()}
                </div>
            </div>`;

        bindItemPickers(el);

        el.addEventListener('change', () => {
            if (editorView === 'settings') collectSettings();
            else if (stage) collectStage(stage);
        });

        document.getElementById('act-live').addEventListener('click', async () => {
            if (editorView === 'settings') collectSettings();
            else if (stage) collectStage(stage);

            def.enabled = !def.enabled;

            if (await saveCurrent(true)) {
                toast(def.enabled ? 'Ativo' : 'De volta ao rascunho',
                    def.enabled
                        ? 'Todo local carimbado a partir deste agora pode ser roubado.'
                        : 'Saiu do mundo até você ativá-lo de novo.',
                    def.enabled ? 'success' : 'info');
            }
            switchPanel('editor');
        });

        document.getElementById('act-add').addEventListener('click', typePickerModal);
        document.getElementById('act-save').addEventListener('click', async () => {
            if (editorView === 'settings') collectSettings();
            else if (stage) collectStage(stage);
            await saveCurrent();
            switchPanel('editor');
        });

        document.getElementById('act-settings').addEventListener('click', () => {
            editorView = editorView === 'settings' ? 'stage' : 'settings';
            switchPanel('editor');
        });

        document.getElementById('act-validate').addEventListener('click', async () => {
            const res = await nui('validateRobbery', def.id);
            if (!res || !res.ok) return;

            State.issues = res.issues || [];
            switchPanel('editor');

            const errors = State.issues.filter(i => i.level === 'error').length;
            if (State.issues.length === 0) toast('Tudo certo', 'Nada a corrigir.', 'success');
            else if (errors > 0) toast('Não está pronto', `${errors} erro${errors === 1 ? '' : 's'} para corrigir.`, 'error');
            else toast('Vale conferir', 'Só avisos, nada bloqueando.', 'warning');
        });

        el.querySelectorAll('[data-issue]').forEach(row => {
            row.addEventListener('click', () => {
                if (!stages.some(s => s.id === row.dataset.issue)) return;
                State.selectedStage = row.dataset.issue;
                editorView = 'stage';
                switchPanel('editor');
            });
        });

        el.querySelectorAll('.stage-row').forEach(row => {
            row.addEventListener('click', () => {
                if (editorView === 'stage' && stage) collectStage(stage);
                State.selectedStage = row.dataset.id;
                editorView = 'stage';
                switchPanel('editor');
            });
        });

        if (editorView === 'stage' && stage) {
            bindCoordPaste('sc');
            document.getElementById('stage-move')?.addEventListener('click', () => moveStage(stage));

            document.getElementById('stage-copy')?.addEventListener('click', () => {
                collectStage(stage);
                duplicateStage(stage);
            });

            document.getElementById('stage-tp')?.addEventListener('click', () => {
                if (stage.coords) nui('teleport', { coords: stage.coords });
            });

            document.getElementById('stage-delete')?.addEventListener('click', () => {
                confirmDanger('Excluir esta etapa?',
                    `"${stage.label}" será removida, e toda etapa que espera por ela perde esse requisito.`,
                    async () => {
                        def.stages = stages.filter(s => s.id !== stage.id);
                        def.stages.forEach(s => {
                            s.requires = (s.requires || []).filter(id => id !== stage.id);
                        });
                        State.selectedStage = def.stages[0]?.id || null;
                        await saveCurrent(true);
                        switchPanel('editor');
                    });
            });

            document.getElementById('adv-toggle')?.addEventListener('click', () => {
                advancedOpen = !advancedOpen;
                collectStage(stage);
                switchPanel('editor');
            });

            document.getElementById('p-add-item')?.addEventListener('click', () => {
                collectStage(stage);
                const reward = normalisePayout(stage.payout);
                reward.items.push({ item: '', min: 1, max: 1, chance: 100 });
                stage.payout = reward;
                switchPanel('editor');
            });

            el.querySelectorAll('[data-pay-remove]').forEach(btn => {
                btn.addEventListener('click', () => {
                    collectStage(stage);
                    const reward = normalisePayout(stage.payout);
                    reward.items.splice(parseInt(btn.dataset.payRemove, 10), 1);
                    stage.payout = reward;
                    switchPanel('editor');
                });
            });

            document.getElementById('mg-preview')?.addEventListener('click', async () => {
                const id = val('f-minigame');
                const res = await nui('previewMinigame', { id });
                if (res && res.ok) {
                    toast(res.passed ? 'Passou' : 'Falhou', 'É assim que fica para quem rouba.',
                        res.passed ? 'success' : 'warning');
                }
            });

            el.querySelectorAll('[data-req]').forEach(chip => {
                chip.addEventListener('click', async () => {
                    const id = chip.dataset.req;
                    const requires = stage.requires || (stage.requires = []);
                    const at = requires.indexOf(id);

                    if (at >= 0) requires.splice(at, 1);
                    else requires.push(id);

                    collectStage(stage);
                    await saveCurrent(true);
                    switchPanel('editor');
                });
            });
        }
    },
};
