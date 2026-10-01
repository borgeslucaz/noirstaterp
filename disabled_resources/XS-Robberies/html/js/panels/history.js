window.Panels = window.Panels || {};

const OUTCOME_BADGE = {
    completed: 'on',
    failed: 'danger',
    abandoned: 'warn',
    active: 'info',
};

const OUTCOME_LABEL = {
    completed: 'concluído',
    failed: 'falhou',
    abandoned: 'abandonado',
    active: 'em andamento',
};

window.Panels.history = {
    async render(el) {
        setTopbar('Histórico', 'Todos os assaltos registrados neste servidor');

        el.innerHTML = '<div class="field-hint">Carregando…</div>';

        const res = await nui('history', 100);
        const runs = (res && res.ok && res.runs) || [];

        if (runs.length === 0) {
            el.innerHTML = emptyState('&#9202;', 'Nenhum assalto ainda',
                'Quando começarem a roubar os locais que você montou, cada tentativa aparece aqui com quem participou e quanto pagou.');
            return;
        }

        el.innerHTML = `
            <div class="section-title">Assaltos recentes</div>
            <table class="table">
                <thead>
                    <tr><th>Roubo</th><th>Início</th><th>Resultado</th><th>Equipe</th><th>Pagamento</th></tr>
                </thead>
                <tbody>
                    ${runs.map(run => `
                        <tr>
                            <td>${esc(run.name)}</td>
                            <td class="mono">${esc(run.started_at || '')}</td>
                            <td><span class="badge ${OUTCOME_BADGE[run.outcome] || 'off'}">${esc(OUTCOME_LABEL[run.outcome] || run.outcome)}</span></td>
                            <td>${(run.participants || []).length}</td>
                            <td class="mono">$${esc(run.payout || 0)}</td>
                        </tr>`).join('')}
                </tbody>
            </table>`;
    },
};
