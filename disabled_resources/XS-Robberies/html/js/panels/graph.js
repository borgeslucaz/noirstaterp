window.Panels = window.Panels || {};

// The stage graph, laid out in columns by how deep a stage sits in the chain.
// Everything with nothing to wait on goes in column one, whatever waits only on
// those goes in column two, and so on — so the picture reads left to right in
// the order a crew actually does it.
function graphColumns(stages) {
    const depth = new Map();
    const byId = new Map(stages.map(s => [s.id, s]));

    let changed = true;
    let guard = 0;

    while (changed && guard < 40) {
        changed = false;
        guard++;

        for (const stage of stages) {
            const requires = (stage.requires || []).filter(id => byId.has(id));
            const known = requires.every(id => depth.has(id));
            if (!known) continue;

            const value = requires.length === 0
                ? 0
                : Math.max(...requires.map(id => depth.get(id))) + 1;

            if (depth.get(stage.id) !== value) {
                depth.set(stage.id, value);
                changed = true;
            }
        }
    }

    // Anything still unplaced is caught in a loop; park it at the end so it is
    // visible rather than silently missing.
    const orphans = stages.filter(s => !depth.has(s.id));
    const deepest = depth.size ? Math.max(...depth.values()) : 0;
    orphans.forEach(s => depth.set(s.id, deepest + 1));

    const columns = [];
    for (const stage of stages) {
        const d = depth.get(stage.id);
        columns[d] = columns[d] || [];
        columns[d].push({ stage, orphan: orphans.includes(stage) });
    }

    return columns.filter(Boolean);
}

function graphNode(entry) {
    const { stage, orphan } = entry;
    const type = stageType(stage.type);
    const colour = type ? rgbSolid(type.colour) : 'var(--accent)';
    const off = stage.enabled === false;

    const flags = [];
    if (stage.opts && stage.opts.optional) flags.push('opcional');
    if (off) flags.push('desligada');
    if (orphan) flags.push('em ciclo');
    if (!stage.coords) flags.push('não posicionada');

    return `
        <div class="gnode ${stage.id === State.selectedStage ? 'selected' : ''} ${off ? 'is-off' : ''}"
             data-node="${esc(stage.id)}" style="--node-colour:${colour}">
            <div class="gnode-type">${esc(type ? type.label : stage.type)}</div>
            <div class="gnode-name">${esc(stage.label || stage.id)}</div>
            ${flags.length ? `<div class="gnode-flags">${esc(flags.join(' · '))}</div>` : ''}
        </div>`;
}

window.Panels.graph = {
    render(el) {
        const def = State.current;

        if (!def) {
            setTopbar('Fluxo', 'Nada aberto');
            el.innerHTML = emptyState('&#9783;', 'Nenhum roubo aberto',
                'Abra um no painel Roubos e o formato dele aparece aqui.',
                '<button class="btn btn-primary" id="graph-back">Ir para Roubos</button>');
            document.getElementById('graph-back')?.addEventListener('click', () => switchPanel('robberies'));
            return;
        }

        const stages = def.stages || [];

        setTopbar(def.name, `${def.id} · como este destrava`, `
            <button class="btn btn-ghost" id="graph-edit">Abrir no Editor</button>
        `);

        if (stages.length === 0) {
            el.innerHTML = emptyState('&#9783;', 'Nada posicionado ainda',
                'Adicione algumas etapas no Editor e o formato do roubo aparece aqui.');
            document.getElementById('graph-edit')?.addEventListener('click', () => switchPanel('editor'));
            return;
        }

        const columns = graphColumns(stages);

        el.innerHTML = `
            <div class="field-hint" style="margin-bottom:16px">
                Cada coluna só começa quando tudo a que ela aponta de volta estiver feito.
                A primeira coluna é onde o assalto começa — se estiver vazia, ninguém consegue iniciar.
            </div>
            <div class="graph">
                ${columns.map((column, i) => `
                    <div class="gcol">
                        <div class="gcol-head">${i === 0 ? 'Abre o assalto' : `Depois da etapa ${i}`}</div>
                        ${column.map(graphNode).join('')}
                    </div>
                    ${i < columns.length - 1 ? '<div class="garrow">&#8594;</div>' : ''}
                `).join('')}
            </div>`;

        document.getElementById('graph-edit')?.addEventListener('click', () => switchPanel('editor'));

        el.querySelectorAll('[data-node]').forEach(node => {
            node.addEventListener('click', () => {
                State.selectedStage = node.dataset.node;
                switchPanel('editor');
            });
        });
    },
};
