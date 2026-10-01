// noir_minigames: Trava de Sinal. Um marcador corre de um lado ao outro da pista; com
// ESPAÇO segurado e o marcador dentro da janela, a trava enche. Segurar fora da janela
// esvazia rápido; soltar esvazia devagar. Cada fase cheia muda a janela de lugar e acelera.
// O ganho é medido por travessia (uma passagem limpa enche FILL_PER_PASS da trava), então
// a fase leva o mesmo número de passagens em qualquer velocidade.

'use strict';

NoirMG.register('signal_lock', {
    title: 'Trava de Sinal',
    hint: 'Segure ESPAÇO com o sinal dentro da janela até a trava encher.',
    keys: [['ESPAÇO', 'Segurar']],

    start(ctx) {
        const d = ctx.difficulty;
        const phases = 1 + d;
        const windowSize = 26 - d * 5;          // largura da janela, em % da pista
        const FILL_PER_PASS = 0.85;             // fração da trava por passagem limpa
        const DRAIN_HELD = 40;                  // %/s segurando fora da janela
        const DRAIN_IDLE = 10;                  // %/s com a tecla solta

        let phase = 1;
        let charge = 0;
        let held = false;
        let x = 50;
        let velocity = (Math.random() < 0.5 ? -1 : 1) * (0.35 + d * 0.18) * 60;
        let windowAt = 20 + Math.random() * 55;

        // Pista
        const top = ctx.el('div', 'sl-top');
        const phaseLabel = ctx.el('span', 'mg-label');
        const pctLabel = ctx.el('span', 'sl-pct mg-num');
        top.append(phaseLabel, pctLabel);

        const lane = ctx.el('div', 'sl-lane');
        for (let i = 1; i < 10; i += 1) {
            const tick = ctx.el('span', 'sl-tick');
            tick.style.left = `${i * 10}%`;
            lane.append(tick);
        }
        const zone = ctx.el('div', 'sl-zone');
        zone.style.width = `${windowSize}%`;
        const marker = ctx.el('div', 'sl-marker');
        lane.append(zone, marker);

        // Trava + fases
        const meter = ctx.el('div', 'sl-meter');
        const meterFill = ctx.el('i');
        meter.append(meterFill);

        const steps = ctx.el('div', 'sl-steps');
        const stepEls = [];
        for (let i = 0; i < phases; i += 1) {
            const s = ctx.el('span', 'sl-step');
            stepEls.push(s);
            steps.append(s);
        }

        ctx.stage.append(top, lane, meter, steps);

        const paintPhase = () => {
            phaseLabel.textContent = `Fase ${phase}/${phases}`;
            stepEls.forEach((s, i) => {
                s.classList.toggle('done', i < phase - 1);
                s.classList.toggle('now', i === phase - 1);
            });
        };
        paintPhase();

        ctx.onKey((e) => {
            if (e.code !== 'Space') return;
            e.preventDefault();
            held = true;
        });
        ctx.onKeyUp((e) => {
            if (e.code === 'Space') held = false;
        });

        ctx.clock(9 + d * 2);

        ctx.loop((dt) => {
            x += velocity * dt;
            if (x <= 0) { x = 0; velocity = Math.abs(velocity); }
            if (x >= 100) { x = 100; velocity = -Math.abs(velocity); }

            const inside = x >= windowAt && x <= windowAt + windowSize;
            const gaining = held && inside;
            if (gaining) charge += (Math.abs(velocity) * FILL_PER_PASS * 100 / windowSize) * dt;
            else charge -= (held ? DRAIN_HELD : DRAIN_IDLE) * dt;
            charge = Math.max(0, Math.min(100, charge));

            marker.style.left = `${x}%`;
            zone.style.left = `${windowAt}%`;
            zone.classList.toggle('hit', gaining);
            marker.classList.toggle('in', inside);
            meterFill.style.width = `${charge}%`;
            pctLabel.textContent = `${Math.floor(charge)}%`;

            if (charge < 100) return;

            if (phase >= phases) { ctx.pass(); return; }
            phase += 1;
            charge = 0;
            windowAt = 8 + Math.random() * (84 - windowSize);
            velocity = Math.sign(velocity || 1) * (0.35 + d * 0.2 + phase * 0.1) * 60;
            paintPhase();
        });
    },
});
