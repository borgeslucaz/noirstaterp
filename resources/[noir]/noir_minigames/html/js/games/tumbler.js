// noir_minigames: Tambor. Um pino por vez sobe e desce no canal; ESPAÇO trava o pino se
// a altura estiver dentro do encaixe marcado. Errou, todos os pinos caem e recomeça do
// primeiro. Passa com todos travados.

'use strict';

NoirMG.register('tumbler', {
    title: 'Tambor',
    hint: 'Aperte ESPAÇO quando o pino estiver no encaixe marcado. Errou, cai tudo.',
    keys: [['ESPAÇO', 'Travar']],

    start(ctx) {
        const d = ctx.difficulty;
        const count = 3 + d;
        const slack = 16 - d * 3;            // folga do encaixe, em % da altura
        const speed = (1.4 + d * 0.55) * 60; // % por segundo
        const seats = Array.from({ length: count }, () => 30 + Math.random() * 55);

        let current = 0;
        let lift = 0;
        let goingUp = true;

        const row = ctx.el('div', 'tb-row');
        const pins = seats.map((seat) => {
            const col = ctx.el('div', 'tb-pin');
            const channel = ctx.el('div', 'tb-channel');
            const notch = ctx.el('div', 'tb-notch');
            notch.style.bottom = `${Math.max(0, seat - slack)}%`;
            notch.style.height = `${Math.min(100, seat + slack) - Math.max(0, seat - slack)}%`;
            const body = ctx.el('div', 'tb-body');
            channel.append(notch, body);
            const tag = ctx.el('span', 'tb-tag mg-label');
            col.append(channel, tag);
            row.append(col);
            return { col, body, tag };
        });

        const status = ctx.el('div', 'tb-status mg-label mg-num');
        ctx.stage.append(row, status);

        const paint = () => {
            pins.forEach((p, i) => {
                const h = i < current ? 100 : (i === current ? lift : 0);
                p.body.style.height = `${h}%`;
                p.col.classList.toggle('now', i === current);
                p.col.classList.toggle('set', i < current);
                p.tag.textContent = i < current ? 'OK' : String(i + 1);
            });
            status.textContent = `Travados ${current}/${count}`;
        };

        ctx.onKey((e) => {
            if (e.code !== 'Space') return;
            e.preventDefault();
            if (e.repeat) return;

            if (Math.abs(lift - seats[current]) <= slack) {
                current += 1;
                lift = 0;
                goingUp = true;
                paint();
                if (current >= count) ctx.pass();
                return;
            }

            const missed = pins[current].col;
            missed.classList.add('miss');
            ctx.after(220, () => missed.classList.remove('miss'));
            current = 0;
            lift = 0;
            goingUp = true;
            paint();
        });

        ctx.clock(11 + d * 3);
        paint();

        ctx.loop((dt) => {
            lift += (goingUp ? speed : -speed) * dt;
            if (lift >= 100) { lift = 100; goingUp = false; }
            if (lift <= 0) { lift = 0; goingUp = true; }
            pins[current].body.style.height = `${lift}%`;
        });
    },
});
