// noir_minigames: Circuito. Grade de nós ligados e desligados; clicar num nó inverte ele
// e os vizinhos em cruz (cima, baixo, esquerda, direita). Passa com a grade toda apagada.
// O embaralhamento parte da grade apagada e aplica cliques reais, então sempre há solução.

'use strict';

NoirMG.register('circuit', {
    title: 'Circuito',
    hint: 'Apague todos os nós. Cada clique inverte o nó e os vizinhos em cruz.',
    keys: [['CLIQUE', 'Inverter']],

    start(ctx) {
        const d = ctx.difficulty;
        const side = 3 + Math.min(2, d - 1);
        const total = side * side;
        const live = new Array(total).fill(false);

        const crossOf = (index) => {
            const row = Math.floor(index / side);
            const col = index % side;
            const out = [index];
            if (row > 0) out.push(index - side);
            if (row < side - 1) out.push(index + side);
            if (col > 0) out.push(index - 1);
            if (col < side - 1) out.push(index + 1);
            return out;
        };
        const toggle = (index) => { for (const k of crossOf(index)) live[k] = !live[k]; };

        const mixes = 2 + d * 2;
        for (let n = 0; n < mixes; n += 1) toggle(ctx.rand(0, total - 1));
        if (!live.some(Boolean)) toggle(ctx.rand(0, total - 1));

        const info = ctx.el('div', 'ci-info');
        const leftLabel = ctx.el('span', 'mg-label');
        const movesLabel = ctx.el('span', 'mg-label mg-num');
        info.append(leftLabel, movesLabel);

        const board = ctx.el('div', 'ci-board');
        board.style.gridTemplateColumns = `repeat(${side}, 1fr)`;
        board.style.width = `${Math.min(300, side * 60)}px`;

        let moves = 0;
        const nodes = [];

        const paint = () => {
            nodes.forEach((node, i) => node.classList.toggle('on', live[i]));
            const lit = live.filter(Boolean).length;
            leftLabel.textContent = `Ativos ${lit}`;
            movesLabel.textContent = `Toques ${moves}`;
        };

        const aim = (index, active) => {
            for (const k of crossOf(index)) nodes[k].classList.toggle('aim', active);
        };

        for (let i = 0; i < total; i += 1) {
            const node = ctx.el('button', 'ci-node');
            node.type = 'button';
            node.addEventListener('mouseenter', () => { if (!ctx.ended) aim(i, true); });
            node.addEventListener('mouseleave', () => aim(i, false));
            node.addEventListener('click', () => {
                if (ctx.ended) return;
                toggle(i);
                moves += 1;
                paint();
                if (!live.some(Boolean)) ctx.pass();
            });
            nodes.push(node);
            board.append(node);
        }

        ctx.stage.append(info, board);
        paint();
        ctx.clock(14 + d * 4);
    },
});
