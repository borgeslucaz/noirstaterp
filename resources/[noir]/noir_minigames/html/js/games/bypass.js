// noir_minigames: bypass. Um cursor vai e volta numa trilha com janelas; ESPAÇO dentro da
// janela da vez libera a próxima. Fora dela, falha.

'use strict';

NoirMG.register('bypass', {
    title: 'Bypass',
    hint: 'ESPAÇO com o cursor dentro da janela marcada. Na ordem.',
    keys: [['ESPAÇO', 'Travar']],

    start(ctx) {
        const count = 2 + ctx.difficulty;
        const span = 15 - ctx.difficulty * 2.5;      // largura da janela, em % da trilha
        const pace = (0.55 + ctx.difficulty * 0.28) * 60; // % por segundo
        const slot = 76 / count;

        const windows = Array.from({ length: count }, (_, i) => 12 + i * slot + Math.random() * (slot - span));

        const rail = ctx.el('div', 'bp-rail');
        const marks = windows.map((start, i) => {
            const w = ctx.el('div', 'bp-window');
            w.style.left = `${start}%`;
            w.style.width = `${span}%`;
            w.append(ctx.el('span', 'bp-tag mg-num', i + 1));
            rail.append(w);
            return w;
        });
        const needle = ctx.el('div', 'bp-needle');
        rail.append(needle);

        const status = ctx.el('div', 'bp-status');
        const done = ctx.el('b', 'mg-num', '0');
        status.append(ctx.el('span', 'mg-label', 'Janelas'), done, ctx.el('span', 'bp-total mg-num', `/ ${count}`));

        ctx.stage.append(rail, status);

        let pos = 0;
        let way = 1;
        let current = 0;
        marks[0].classList.add('armed');

        ctx.clock(6 + count * 2.5);

        ctx.loop((dt) => {
            pos += way * pace * dt;
            if (pos >= 100) { pos = 100; way = -1; }
            if (pos <= 0) { pos = 0; way = 1; }
            needle.style.left = `${pos}%`;
        });

        ctx.onKey((e) => {
            if (e.code !== 'Space') return;
            e.preventDefault();
            if (e.repeat) return;

            const start = windows[current];
            if (pos < start || pos > start + span) {
                marks[current].classList.add('missed');
                ctx.fail();
                return;
            }

            marks[current].classList.remove('armed');
            marks[current].classList.add('cleared');
            current += 1;
            done.textContent = current;

            if (current >= count) { ctx.pass(); return; }
            marks[current].classList.add('armed');
        });
    },
});
