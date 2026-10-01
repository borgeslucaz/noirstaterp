// noir_minigames: teclado de senha. Código de dígitos aleatórios; cada tentativa completa
// diz quantos estão na posição certa e quantos existem no código em outra posição.

'use strict';

NoirMG.register('pinpad', {
    title: 'Teclado numérico',
    hint: 'Cada tentativa mostra dígitos exatos e dígitos perto.',
    keys: [['0-9', 'Digitar'], ['⌫', 'Apagar']],

    start(ctx) {
        const size = 3 + Math.min(2, ctx.difficulty - 1);
        let tries = 6 - ctx.difficulty;
        const secret = Array.from({ length: size }, () => ctx.rand(0, 9));
        let typed = [];

        const display = ctx.el('div', 'pp-display');
        const cells = Array.from({ length: size }, () => {
            const cell = ctx.el('span', 'pp-cell mg-num', '');
            display.append(cell);
            return cell;
        });

        const counter = ctx.el('div', 'pp-tries');
        const triesNum = ctx.el('b', 'mg-num', tries);
        counter.append(ctx.el('span', 'mg-label', 'Tentativas'), triesNum);

        const pad = ctx.el('div', 'pp-pad');
        const log = ctx.el('ol', 'pp-log');

        const left = ctx.el('div', 'pp-left');
        left.append(display, counter, log);
        ctx.stage.append(left, pad);

        const render = () => {
            cells.forEach((cell, i) => {
                const has = typed[i] !== undefined;
                cell.textContent = has ? String(typed[i]) : '';
                cell.classList.toggle('filled', has);
                cell.classList.toggle('next', i === typed.length);
            });
        };

        const judge = () => {
            const exact = typed.filter((d, i) => d === secret[i]).length;
            if (exact === size) { ctx.pass(); return; }

            const near = typed.filter((d, i) => d !== secret[i] && secret.includes(d)).length;
            tries -= 1;
            triesNum.textContent = tries;

            const row = ctx.el('li', 'pp-row');
            row.append(
                ctx.el('span', 'pp-guess mg-num', typed.join(' ')),
                ctx.el('span', 'pp-exact mg-num', `${exact} exato${exact === 1 ? '' : 's'}`),
                ctx.el('span', 'pp-near mg-num', `${near} perto`),
            );
            log.prepend(row);

            typed = [];
            render();
            if (tries <= 0) ctx.fail();
        };

        const press = (digit) => {
            if (ctx.ended || typed.length >= size) return;
            typed.push(digit);
            render();
            if (typed.length === size) judge();
        };

        const erase = () => {
            if (ctx.ended || typed.length === 0) return;
            typed.pop();
            render();
        };

        const clear = () => {
            if (ctx.ended) return;
            typed = [];
            render();
        };

        const button = (label, action, extra) => {
            const b = ctx.el('button', `pp-key mg-num${extra ? ` ${extra}` : ''}`, label);
            b.type = 'button';
            b.tabIndex = -1;
            // Sem foco no botão: Enter ou Espaço depois de um clique não repete o dígito.
            b.addEventListener('mousedown', (e) => e.preventDefault());
            b.addEventListener('click', action);
            pad.append(b);
        };

        for (const n of [1, 2, 3, 4, 5, 6, 7, 8, 9]) button(n, () => press(n));
        button('Limpar', clear, 'pp-aux');
        button(0, () => press(0));
        button('⌫', erase, 'pp-aux');

        render();
        ctx.clock(16 + ctx.difficulty * 4);

        ctx.onKey((e) => {
            if (e.key === 'Backspace') { e.preventDefault(); erase(); return; }
            if (e.key === 'Delete') { e.preventDefault(); clear(); return; }
            if (e.key.length === 1 && e.key >= '0' && e.key <= '9') {
                e.preventDefault();
                press(Number(e.key));
            }
        });
    },
});
