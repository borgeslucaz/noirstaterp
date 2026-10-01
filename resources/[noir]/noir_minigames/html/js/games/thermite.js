// noir_minigames: termita. Algumas células acendem na grade e apagam. Depois é marcar as
// mesmas, em qualquer ordem. Uma célula fora do padrão falha na hora.

'use strict';

(() => {
    NoirMG.register('thermite', {
        title: 'Carga de Termita',
        hint: 'Memorize as células acesas.',
        keys: [['Clique', 'Marcar']],

        start(ctx) {
            const { el } = ctx;
            const side = ctx.pick(3, 4, 5);
            const total = side * side;
            const litCount = Math.min(3 + ctx.difficulty, total - 1);
            const showMs = ctx.pick(2100, 1600, 1100);

            const pattern = new Set();
            while (pattern.size < litCount) pattern.add(ctx.rand(0, total - 1));

            const marked = new Set();
            let armed = false;

            const status = el('div', 'th-status');
            const phase = el('span', 'mg-label', 'Memorize');
            const count = el('span', 'th-count mg-num', `0 / ${litCount}`);
            status.append(phase, count);

            const grid = el('div', `th-grid th-size-${side}`);
            grid.style.gridTemplateColumns = `repeat(${side}, 1fr)`;
            const cells = [];
            for (let i = 0; i < total; i += 1) {
                const cell = el('button', 'th-cell');
                cell.type = 'button';
                cell.addEventListener('click', () => mark(i));
                cells.push(cell);
                grid.append(cell);
            }

            ctx.stage.append(status, grid);
            pattern.forEach((i) => cells[i].classList.add('lit'));

            function mark(i) {
                if (!armed || ctx.ended || marked.has(i)) return;
                marked.add(i);
                if (!pattern.has(i)) {
                    cells[i].classList.add('miss');
                    ctx.fail();
                    return;
                }
                cells[i].classList.add('lit');
                count.textContent = `${marked.size} / ${litCount}`;
                if (marked.size === litCount) ctx.pass();
            }

            ctx.after(showMs, () => {
                pattern.forEach((i) => cells[i].classList.remove('lit'));
                grid.classList.add('armed');
                phase.textContent = 'Repita';
                ctx.setHint('Marque as mesmas células.');
                armed = true;
                ctx.clock(3 + litCount * 1.2);
            });
        },
    });
})();
