window.Panels = window.Panels || {};

function bridgeRow(label, value, ok) {
    return `
        <div class="card" style="cursor:default">
            <div class="card-head">
                <div>
                    <div class="card-title">${esc(label)}</div>
                    <div class="card-sub">${esc(value || 'não detectado')}</div>
                </div>
                <span class="badge ${ok ? 'on' : 'warn'}">${ok ? 'Conectado' : 'Ausente'}</span>
            </div>
        </div>`;
}

function tunablesBlock() {
    const settings = State.settings || [];
    if (settings.length === 0) return '';

    const row = (s) => {
        const id = `t-${s.key}`;

        if (s.kind === 'choice') {
            const colours = {
                emerald: '#19e08c', amber: '#f5a524', violet: '#a882ff',
                rose: '#ff4d9d', ice: '#4fd2ff', gold: '#e8c37a',
            };

            const swatch = (name) => `
                <div class="swatch ${name === s.value ? 'active' : ''}"
                     data-theme-pick="${esc(name)}" title="${esc(name)}"
                     style="color:${colours[name] || '#19e08c'}"></div>`;

            return `
                <div class="tunable">
                    <span class="toggle-label" style="flex:1">${esc(s.label)}</span>
                    <div class="swatches">${(s.options || []).map(swatch).join('')}</div>
                </div>`;
        }

        if (s.kind === 'toggle') {
            return `
                <div class="tunable">
                    <label class="toggle">
                        <input type="checkbox" id="${esc(id)}" data-tunable="${esc(s.key)}" ${s.value ? 'checked' : ''}>
                        <span class="toggle-track"></span>
                        <span class="toggle-label">${esc(s.label)}</span>
                    </label>
                    ${s.fromConfig ? '<span class="badge off">do config.lua</span>' : '<span class="badge on">definido aqui</span>'}
                </div>`;
        }

        return `
            <div class="tunable">
                <label class="toggle-label" for="${esc(id)}" style="flex:1">${esc(s.label)}</label>
                <div class="unit-input" style="max-width:130px">
                    <input type="number" id="${esc(id)}" data-tunable="${esc(s.key)}"
                           value="${esc(s.value)}" step="${esc(s.step || 1)}"
                           ${s.min !== undefined ? `min="${s.min}"` : ''}
                           ${s.max !== undefined ? `max="${s.max}"` : ''}>
                    ${s.unit ? `<span class="unit">${esc(s.unit)}</span>` : ''}
                </div>
                ${s.fromConfig ? '<span class="badge off">do config.lua</span>' : '<span class="badge on">definido aqui</span>'}
            </div>`;
    };

    return `
        <div class="section-title">Ajustes</div>
        <div class="field-hint" style="margin-bottom:12px">
            Valem na hora e sobrevivem a um restart. O que estiver marcado
            <b>do config.lua</b> ainda usa o valor do arquivo; mude aqui e este painel passa a valer.
        </div>
        <div class="card" style="cursor:default;padding:6px 16px 14px">
            ${settings.map(row).join('')}
        </div>
        <div style="display:flex;justify-content:flex-end;margin-top:11px">
            <button class="btn btn-primary" id="s-save-tunables">Aplicar</button>
        </div>`;
}

function controlsBlock() {
    const banned = Object.entries(State.blacklist || {});

    return `
        <div class="section-title">Controles</div>
        <div class="card" style="cursor:default">
            <div class="card-head">
                <div>
                    <div class="card-title">Trava geral</div>
                    <div class="card-sub">Nenhum roubo pode ser iniciado com isto ligado. Assaltos em andamento continuam.</div>
                </div>
                <label class="toggle">
                    <input type="checkbox" id="s-killswitch" ${State.killSwitch ? 'checked' : ''}>
                    <span class="toggle-track"></span>
                    <span class="toggle-label">${State.killSwitch ? 'Ligada' : 'Desligada'}</span>
                </label>
            </div>
        </div>

        <div class="section-title" style="margin-top:26px">Banidos dos roubos</div>
        ${banned.length === 0
            ? '<div class="field-hint">Ninguém. Bana alguém pelo painel Ao vivo enquanto a pessoa estiver num roubo.</div>'
            : `<table class="table">
                <thead><tr><th>Nome</th><th>Citizen ID</th><th></th></tr></thead>
                <tbody>
                    ${banned.map(([citizenid, name]) => `
                        <tr>
                            <td>${esc(name)}</td>
                            <td class="mono">${esc(citizenid)}</td>
                            <td style="text-align:right">
                                <button class="btn btn-sm btn-ghost" data-unban="${esc(citizenid)}">Liberar</button>
                            </td>
                        </tr>`).join('')}
                </tbody>
            </table>`}`;
}

async function loadControls(el) {
    const res = await nui('live');
    if (res && res.ok) {
        State.killSwitch = res.killSwitch === true;
        State.blacklist = res.blacklist || {};
    }
    if (State.panel === 'settings') switchPanel('settings');
}

window.Panels.settings = {
    render(el) {
        setTopbar('Configurações', 'O que este servidor está rodando por baixo');

        if (State.killSwitch === undefined) {
            State.killSwitch = false;
            State.blacklist = {};
            loadControls(el);
        }

        const boot = State.boot || {};
        const minigames = State.minigames || [];
        const available = minigames.filter(m => m.available);

        el.innerHTML = `
            ${tunablesBlock()}

            ${controlsBlock()}

            <div class="section-title" style="margin-top:26px">Integrações</div>
            <div class="card-grid">
                ${bridgeRow('Framework', boot.framework, !!boot.framework)}
                ${bridgeRow('Inventário', boot.inventory, !!boot.inventory)}
                ${bridgeRow('Target', boot.target, !!boot.target)}
                ${bridgeRow('Chamado', boot.dispatch || 'só notificações', true)}
                ${bridgeRow('Trancas de porta', boot.doorlock || 'nenhuma encontrada', !!boot.doorlock)}
                ${bridgeRow('MDT', boot.mdt || 'sem registro', !!boot.mdt)}
            </div>

            <div class="section-title" style="margin-top:26px">Minigames</div>
            <div class="field-hint" style="margin-bottom:12px">
                ${available.length} de ${minigames.length} disponíveis neste servidor. Os ausentes continuam listados para você ver o que ganharia instalando.
            </div>
            <table class="table">
                <thead><tr><th>Minigame</th><th>Origem</th><th>O que é</th><th>Estado</th></tr></thead>
                <tbody>
                    ${minigames.map(m => `
                        <tr>
                            <td>${esc(m.label)}</td>
                            <td class="mono">${esc(m.resource || 'embutido')}</td>
                            <td style="color:var(--text-muted)">${esc(m.blurb || '')}</td>
                            <td><span class="badge ${m.available ? 'on' : 'off'}">${m.available ? 'Pronto' : 'Ausente'}</span></td>
                        </tr>`).join('')}
                </tbody>
            </table>

            <div class="section-title" style="margin-top:26px">Tipos de etapa</div>
            <div class="card-grid">
                ${(State.stageTypes || []).map(t => `
                    <div class="card" style="cursor:default;--type-colour:${rgbSolid(t.colour)}">
                        <div class="card-head">
                            <div>
                                <div class="card-title" style="color:${rgbSolid(t.colour)}">${esc(t.label)}</div>
                                <div class="card-sub">${esc(t.blurb || '')}</div>
                            </div>
                        </div>
                    </div>`).join('')}
            </div>`;

        let pickedTheme = null;

        document.querySelectorAll('[data-theme-pick]').forEach(sw => {
            sw.addEventListener('click', () => {
                pickedTheme = sw.dataset.themePick;
                applyTheme(pickedTheme);
                document.querySelectorAll('[data-theme-pick]').forEach(o =>
                    o.classList.toggle('active', o === sw));
            });
        });

        document.getElementById('s-save-tunables')?.addEventListener('click', async () => {
            const values = {};

            document.querySelectorAll('[data-tunable]').forEach(field => {
                values[field.dataset.tunable] = field.type === 'checkbox'
                    ? field.checked
                    : parseFloat(field.value);
            });

            if (pickedTheme) values.theme = pickedTheme;

            const res = await nui('saveTunables', values);
            if (!reportResult(res, 'Aplicado', 'Já vale no servidor.')) return;

            State.settings = res.settings || State.settings;
            switchPanel('settings');
        });

        document.getElementById('s-killswitch')?.addEventListener('change', async (e) => {
            const on = e.target.checked;
            const res = await nui('killSwitch', on);
            if (!reportResult(res, on ? 'Tudo travado' : 'Destravado',
                on ? 'Ninguém pode iniciar roubo.' : 'Roubos podem ser iniciados de novo.')) {
                e.target.checked = !on;
                return;
            }
            State.killSwitch = res.killSwitch === true;
            switchPanel('settings');
        });

        el.querySelectorAll('[data-unban]').forEach(btn => {
            btn.addEventListener('click', async () => {
                const res = await nui('blacklist', { citizenid: btn.dataset.unban, on: false });
                if (!reportResult(res, 'Liberado', '')) return;
                State.blacklist = res.blacklist || {};
                switchPanel('settings');
            });
        });
    },
};
