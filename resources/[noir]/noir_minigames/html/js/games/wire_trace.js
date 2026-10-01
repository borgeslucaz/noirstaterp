// noir_minigames: fios. A ordem de corte aparece por um instante e some; depois os fios
// entram no painel e o relógio corre. Um clique corta: fio certo abre, qualquer outro falha.

'use strict';

(() => {
    const SVG_NS = 'http://www.w3.org/2000/svg';

    // Cores reais de fio, em tom sóbrio.
    const CABLES = [
        { name: 'Vermelho', tone: '#b0443c' },
        { name: 'Azul', tone: '#4a74a0' },
        { name: 'Verde', tone: '#5a8b58' },
        { name: 'Amarelo', tone: '#b8963c' },
        { name: 'Roxo', tone: '#7b6494' },
        { name: 'Branco', tone: '#d6d6d2' },
    ];

    const SPAN_W = 300;
    const SPAN_H = 26;

    // Curva própria de cada fio: sobe e desce em pontos sorteados.
    function cablePath(rand) {
        const mid = SPAN_H / 2;
        const a = mid + rand(-8, 8);
        const b = mid + rand(-8, 8);
        return `M 4 ${mid} C 80 ${a}, 140 ${b}, 150 ${mid} S 250 ${mid + rand(-8, 8)}, ${SPAN_W - 4} ${mid}`;
    }

    NoirMG.register('wire_trace', {
        title: 'Corte de Fio',
        hint: 'Guarde a cor da ordem. Depois corte o fio certo.',
        keys: [['Clique', 'Cortar']],

        start(ctx) {
            const { el } = ctx;
            const count = 3 + ctx.difficulty;
            const cables = ctx.shuffle(CABLES).slice(0, count);
            const target = cables[ctx.rand(0, cables.length - 1)];
            const showMs = ctx.pick(1250, 1000, 750);

            const order = el('div', 'wt-order');
            const orderLabel = el('span', 'mg-label', 'Ordem de corte');
            const orderValue = el('strong', 'wt-order-value', target.name);
            const orderTimer = el('div', 'wt-order-timer');
            const orderFill = el('i');
            orderTimer.append(orderFill);
            order.append(orderLabel, orderValue, orderTimer);

            const panel = el('div', 'wt-panel hidden');
            let armed = false;

            cables.forEach((cable, index) => {
                const row = el('button', 'wt-row');
                row.type = 'button';
                row.append(el('span', 'wt-tag mg-num', `L${index + 1}`));

                const svg = document.createElementNS(SVG_NS, 'svg');
                svg.setAttribute('viewBox', `0 0 ${SPAN_W} ${SPAN_H}`);
                svg.setAttribute('preserveAspectRatio', 'none');
                svg.classList.add('wt-cable');
                const path = document.createElementNS(SVG_NS, 'path');
                path.setAttribute('d', cablePath(ctx.rand));
                path.setAttribute('stroke', cable.tone);
                path.setAttribute('pathLength', '100');
                svg.append(path);

                row.append(el('span', 'wt-post'), svg, el('span', 'wt-post'));
                row.addEventListener('click', () => {
                    if (!armed || ctx.ended) return;
                    armed = false;
                    const right = cable === target;
                    row.classList.add('cut', right ? 'right' : 'wrong');
                    if (right) ctx.pass(); else ctx.fail();
                });
                panel.append(row);
            });

            ctx.stage.append(order, panel);

            // A barra da ordem esvazia no tempo de leitura.
            orderFill.style.transitionDuration = `${showMs}ms`;
            requestAnimationFrame(() => { orderFill.style.width = '0%'; });

            ctx.after(showMs, () => {
                order.classList.add('hidden');
                panel.classList.remove('hidden');
                ctx.setHint('Corte o fio da ordem.');
                armed = true;
                ctx.clock(ctx.pick(5, 6, 7));
            });
        },
    });
})();
