// noir_minigames: Sequência. A grade 3x3 acende uma ordem de casas; depois o jogador
// repete clicando. Um clique errado falha na hora. O relógio só corre na hora de repetir.

'use strict';

NoirMG.register('sequence', {
    title: 'Sequência',
    hint: 'Observe a ordem.',
    keys: [['CLIQUE', 'Repetir']],

    start(ctx) {
        const d = ctx.difficulty;
        const side = 3;
        const length = 3 + d;
        const showMs = 480 - d * 60;
        const gapMs = 160;
        const order = Array.from({ length }, () => ctx.rand(0, side * side - 1));

        let step = 0;
        let open = false;

        const info = ctx.el('div', 'sq-info');
        const modeLabel = ctx.el('span', 'mg-label', 'Memorize');
        const stepLabel = ctx.el('span', 'mg-label mg-num');
        info.append(modeLabel, stepLabel);

        const board = ctx.el('div', 'sq-board');
        const tiles = [];
        for (let i = 0; i < side * side; i += 1) {
            const tile = ctx.el('button', 'sq-tile');
            tile.type = 'button';
            tile.disabled = true;
            tile.addEventListener('click', () => choose(i));
            tiles.push(tile);
            board.append(tile);
        }

        ctx.stage.append(info, board);

        const paintStep = (n) => { stepLabel.textContent = `${n}/${length}`; };
        paintStep(0);

        const blink = (tile, cls, ms) => {
            tile.classList.add(cls);
            ctx.after(ms, () => tile.classList.remove(cls));
        };

        function choose(index) {
            if (!open || ctx.ended) return;
            const tile = tiles[index];
            if (index !== order[step]) {
                tile.classList.add('bad');
                open = false;
                ctx.fail();
                return;
            }
            blink(tile, 'ok', 200);
            step += 1;
            paintStep(step);
            if (step >= length) ctx.pass();
        }

        const show = (n) => {
            if (n >= length) {
                open = true;
                tiles.forEach((t) => { t.disabled = false; });
                board.classList.add('open');
                modeLabel.textContent = 'Repita';
                ctx.setHint('Repita a ordem clicando nas casas.');
                paintStep(0);
                ctx.clock(4 + length * 1.4);
                return;
            }
            paintStep(n + 1);
            const tile = tiles[order[n]];
            tile.classList.add('lit');
            ctx.after(showMs, () => {
                tile.classList.remove('lit');
                ctx.after(gapMs, () => show(n + 1));
            });
        };

        ctx.after(400, () => show(0));
    },
});
