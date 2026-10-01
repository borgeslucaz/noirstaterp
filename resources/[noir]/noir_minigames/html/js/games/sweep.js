// noir_minigames: radar. O feixe gira sem parar; ESPAÇO com o feixe sobre o contato marca
// o ponto e outro contato aparece. Fora da tolerância, falha.

'use strict';

NoirMG.register('sweep', {
    title: 'Radar',
    hint: 'ESPAÇO quando o feixe passar pelo contato.',
    keys: [['ESPAÇO', 'Marcar']],

    start(ctx) {
        const goal = 2 + ctx.difficulty;
        const tolerance = 22 - ctx.difficulty * 5;        // graus
        const turn = (1.4 + ctx.difficulty * 0.55) * 60;  // graus por segundo
        const RADIUS = 62;                                // px do centro ao contato

        const scope = ctx.el('div', 'sw-scope');
        scope.append(ctx.el('i', 'sw-ring sw-ring-outer'), ctx.el('i', 'sw-ring sw-ring-inner'));
        scope.append(ctx.el('i', 'sw-axis sw-axis-h'), ctx.el('i', 'sw-axis sw-axis-v'));
        const beam = ctx.el('div', 'sw-beam');
        const blip = ctx.el('div', 'sw-blip');
        scope.append(blip, beam, ctx.el('i', 'sw-hub'));

        const tally = ctx.el('div', 'sw-tally');
        const got = ctx.el('b', 'mg-num', '0');
        tally.append(ctx.el('span', 'mg-label', 'Contatos'), got, ctx.el('span', 'sw-goal mg-num', `/ ${goal}`));

        ctx.stage.append(scope, tally);

        let heading = 0;
        let target = 0;
        let marked = 0;

        const plant = () => {
            target = Math.random() * 360;
            const rad = (target * Math.PI) / 180;
            blip.style.transform = `translate(${Math.sin(rad) * RADIUS}px, ${-Math.cos(rad) * RADIUS}px)`;
            blip.classList.remove('sw-pop');
            void blip.offsetWidth; // reinicia a animação de entrada
            blip.classList.add('sw-pop');
        };
        plant();

        ctx.clock(8 + goal * 3);

        ctx.loop((dt) => {
            heading = (heading + turn * dt) % 360;
            beam.style.transform = `rotate(${heading}deg)`;
        });

        ctx.onKey((e) => {
            if (e.code !== 'Space') return;
            e.preventDefault();
            if (e.repeat) return;

            const gap = Math.abs(((heading - target + 540) % 360) - 180);
            if (gap > tolerance) {
                blip.classList.add('sw-miss');
                ctx.fail();
                return;
            }

            marked += 1;
            got.textContent = marked;
            if (marked >= goal) { ctx.pass(); return; }
            plant();
        });
    },
});
