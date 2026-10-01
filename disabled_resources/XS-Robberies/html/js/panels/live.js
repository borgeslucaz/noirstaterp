window.Panels = window.Panels || {};

const ALARM_BADGE = {
    quiet: 'off',
    none: 'off',
    silent: 'info',
    pending: 'warn',
    raised: 'danger',
};

const ALARM_LABEL = {
    quiet: 'sem alarme',
    none: 'sem alarme',
    silent: 'silencioso',
    pending: 'armando',
    raised: 'polícia avisada',
};

function liveCard(run) {
    const crew = (run.participants || []).filter(p => p.name);

    return `
        <div class="card" style="cursor:default" data-run="${esc(run.locationId)}">
            <div class="card-head">
                <div>
                    <div class="card-title">${esc(run.name || 'Roubo')}</div>
                    <div class="card-sub">${esc(run.location || '')}</div>
                </div>
                <span class="badge ${ALARM_BADGE[run.alarm] || 'off'}">${esc(ALARM_LABEL[run.alarm] || run.alarm)}</span>
            </div>
            <div class="card-stats">
                <div>
                    <div class="stat-label">Progresso</div>
                    <div class="stat-value" style="font-size:12px">${esc(run.stage || '')}</div>
                </div>
                <div>
                    <div class="stat-label">Decorrido</div>
                    <div class="stat-value">${esc(fmtDuration(run.elapsed || 0))}</div>
                </div>
                <div>
                    <div class="stat-label">Bolada</div>
                    <div class="stat-value">$${esc(run.pot || 0)}</div>
                </div>
            </div>
            ${crew.length ? `
                <div class="section-title" style="margin:14px 0 8px">Dentro</div>
                <div style="display:flex;flex-wrap:wrap;gap:6px">
                    ${crew.map(p => `
                        <span class="badge off" data-ban="${esc(p.citizenid)}" data-name="${esc(p.name)}"
                              title="Banir dos roubos" style="cursor:pointer">${esc(p.name)} &times;</span>`).join('')}
                </div>` : ''}
            <div class="card-stats" style="border-top:none;padding-top:12px;gap:7px">
                <button class="btn btn-sm btn-danger" data-end="${esc(run.locationId)}">Encerrar</button>
            </div>
        </div>`;
}

async function refreshLive(el) {
    const res = await nui('live');
    const runs = (res && res.ok && res.runs) || [];

    State.liveRuns = runs;
    if (res && res.ok) {
        State.killSwitch = res.killSwitch === true;
        State.blacklist = res.blacklist || {};
    }

    document.getElementById('badge-live').textContent = runs.length || '';
    document.querySelector('.live-dot')?.classList.toggle('on', runs.length > 0);

    if (State.panel !== 'live') return;

    if (runs.length === 0) {
        el.innerHTML = emptyState('&#9679;', 'Nada em andamento',
            'Roubos ativos aparecem aqui assim que começam, com quem está dentro e até onde chegaram.');
    } else {
        el.innerHTML = `
            <div class="section-title">Em andamento</div>
            <div class="card-grid">${runs.map(liveCard).join('')}</div>`;

        el.querySelectorAll('[data-end]').forEach(btn => {
            btn.addEventListener('click', () => {
                const run = runs.find(r => String(r.locationId) === btn.dataset.end);
                confirmDanger('Encerrar este assalto?',
                    `Todos dentro de "${run ? run.location : 'local'}" são avisados de que acabou. Ficam com o que já está no bolso; a bolada é perdida.`,
                    async () => {
                        const result = await nui('forceEnd', parseInt(btn.dataset.end, 10));
                        if (reportResult(result, 'Encerrado', run ? run.location : '')) refreshLive(el);
                    }, 'Encerrar');
            });
        });

        el.querySelectorAll('[data-ban]').forEach(chip => {
            chip.addEventListener('click', () => {
                confirmDanger('Banir dos roubos?',
                    `${chip.dataset.name} não vai poder iniciar nem entrar em roubo até você liberar em Configurações.`,
                    async () => {
                        const result = await nui('blacklist', {
                            citizenid: chip.dataset.ban,
                            name: chip.dataset.name,
                            on: true,
                        });
                        if (reportResult(result, 'Banido', chip.dataset.name)) {
                            State.blacklist = result.blacklist || {};
                        }
                    }, 'Banir');
            });
        });
    }

    setTimeout(() => {
        if (State.panel === 'live') refreshLive(el);
    }, 4000);
}

window.Panels.live = {
    render(el) {
        setTopbar('Ao vivo', 'Assaltos acontecendo agora');
        el.innerHTML = '<div class="field-hint">Verificando…</div>';
        refreshLive(el);
    },
};
