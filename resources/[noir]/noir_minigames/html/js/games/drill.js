// noir_minigames: furadeira. Segurar W sobe a pressão e a broca avança mais rápido;
// pressão acima do limite esquenta a peça. Chegou ao fundo, abre; calor no máximo, falha.

'use strict';

NoirMG.register('drill', {
    title: 'Furadeira',
    hint: 'W força, S alivia. Passou da marca, esquenta.',
    keys: [['W', 'Forçar'], ['S', 'Aliviar']],

    start(ctx) {
        // Valores por quadro de 60 Hz; o laço multiplica por dt * 60.
        const FEED = 0.16 + ctx.difficulty * 0.05;
        const LIMIT = 55;
        const COOLING = 0.55;

        const state = { depth: 0, heat: 0, pressure: 0, push: false, ease: false };

        const column = (label, extra) => {
            const wrap = ctx.el('div', `dr-col ${extra}`);
            const tube = ctx.el('div', 'dr-tube');
            const fill = ctx.el('div', 'dr-fill');
            tube.append(fill);
            const value = ctx.el('span', 'dr-value mg-num', '0');
            wrap.append(value, tube, ctx.el('span', 'mg-label', label));
            ctx.stage.append(wrap);
            return { wrap, tube, fill, value };
        };

        const depth = column('Profundidade', 'dr-depth');
        const pressure = column('Pressão', 'dr-pressure');
        const heat = column('Calor', 'dr-heat');

        const mark = ctx.el('i', 'dr-mark');
        mark.style.bottom = `${LIMIT}%`;
        pressure.tube.append(mark);

        ctx.clock(16 + ctx.difficulty * 2);

        ctx.onKey((e) => {
            if (e.code === 'KeyW') { e.preventDefault(); state.push = true; }
            if (e.code === 'KeyS') { e.preventDefault(); state.ease = true; }
        });
        ctx.onKeyUp((e) => {
            if (e.code === 'KeyW') state.push = false;
            if (e.code === 'KeyS') state.ease = false;
        });

        const band = (ratio) => (ratio > 60 ? 'hot' : ratio > 35 ? 'warm' : 'cool');

        ctx.loop((dt) => {
            const f = dt * 60;

            if (state.push) state.pressure = Math.min(100, state.pressure + 2.2 * f);
            else if (state.ease) state.pressure = Math.max(0, state.pressure - 3.0 * f);
            else state.pressure = Math.max(0, state.pressure - 1.0 * f);

            state.depth = Math.min(100, state.depth + (state.pressure / 100) * FEED * 2.4 * f);

            const delta = state.pressure > LIMIT ? (state.pressure - LIMIT) * 0.06 : -COOLING;
            state.heat = Math.min(100, Math.max(0, state.heat + delta * f));

            depth.fill.style.height = `${state.depth}%`;
            depth.value.textContent = Math.max(0, Math.floor(state.depth));
            pressure.fill.style.height = `${state.pressure}%`;
            pressure.value.textContent = Math.floor(state.pressure);
            pressure.wrap.classList.toggle('over', state.pressure > LIMIT);
            heat.fill.style.height = `${state.heat}%`;
            heat.value.textContent = Math.floor(state.heat);
            heat.wrap.dataset.band = band(state.heat);

            if (state.heat >= 100) { ctx.fail(); return; }
            if (state.depth >= 100) ctx.pass();
        });
    },
});
