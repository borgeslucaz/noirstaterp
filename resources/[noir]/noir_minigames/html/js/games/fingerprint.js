// noir_minigames: digital. Uma digital de arquivo e várias candidatas parecidas; só uma
// bate. Cada digital é um laço de sete cristas com deslocamento próprio, e nenhuma
// combinação se repete, então sempre existe uma única resposta. Um clique decide.

'use strict';

(() => {
    const SVG_NS = 'http://www.w3.org/2000/svg';
    const RIDGES = 7;

    function makeSignature(rand) {
        const out = [];
        for (let i = 0; i < RIDGES; i += 1) out.push(rand(-4, 4));
        return out;
    }

    // Cristas em laço: duas pernas que sobem e fecham num arco, centradas pelo deslocamento.
    function drawPrint(signature) {
        const svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('viewBox', '0 0 60 70');
        svg.classList.add('fp-print');
        signature.forEach((shift, i) => {
            const r = 4 + i * 3.6;
            const cx = 30 + shift;
            const cy = 30;
            const path = document.createElementNS(SVG_NS, 'path');
            path.setAttribute('d',
                `M ${cx - r} 68 L ${cx - r} ${cy} A ${r} ${r * 1.1} 0 0 1 ${cx + r} ${cy} L ${cx + r} 68`);
            path.style.opacity = String(0.45 + i * 0.08);
            svg.append(path);
        });
        return svg;
    }

    NoirMG.register('fingerprint', {
        title: 'Leitura de Digital',
        hint: 'Ache a digital igual à de arquivo.',
        keys: [['Clique', 'Escolher']],
        wide: true,

        start(ctx) {
            const { el } = ctx;
            const options = 4 + ctx.difficulty * 2;
            const answer = ctx.rand(0, options - 1);

            const signatures = [];
            const seen = new Set();
            while (signatures.length < options) {
                const candidate = makeSignature(ctx.rand);
                const key = candidate.join(':');
                if (seen.has(key)) continue;
                seen.add(key);
                signatures.push(candidate);
            }

            const layout = el('div', 'fp-layout');

            const file = el('div', 'fp-file');
            file.append(el('span', 'mg-label', 'Arquivo'), drawPrint(signatures[answer]));

            const grid = el('div', 'fp-grid');
            grid.style.gridTemplateColumns = `repeat(${options / 2}, 1fr)`;
            let open = true;
            signatures.forEach((signature, index) => {
                const card = el('button', 'fp-card');
                card.type = 'button';
                card.append(drawPrint(signature), el('span', 'fp-id mg-num', String(index + 1).padStart(2, '0')));
                card.addEventListener('click', () => {
                    if (!open || ctx.ended) return;
                    open = false;
                    const right = index === answer;
                    card.classList.add(right ? 'right' : 'wrong');
                    if (right) ctx.pass(); else ctx.fail();
                });
                grid.append(card);
            });

            layout.append(file, grid);
            ctx.stage.append(layout);
            ctx.clock(9 - ctx.difficulty);
        },
    });
})();
