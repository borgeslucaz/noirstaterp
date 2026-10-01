// noir_minigames: sintonia de frequência. O dial anda de 0 a 100 com A e D. Existe uma
// faixa escondida; perto dela o ruído do osciloscópio some e a faixa aparece no dial.
// Dentro da faixa a trava enche, fora dela esvazia. Trava cheia abre.

'use strict';

(() => {
    const SPEED = 54;        // unidades do dial por segundo
    const FILL_RATE = 102;   // % de trava por segundo dentro da faixa
    const DRAIN_RATE = 84;   // % de trava por segundo fora da faixa
    const REVEAL_SPAN = 40;  // distância em que a faixa começa a aparecer

    const MHZ_MIN = 88;
    const MHZ_SPAN = 20;

    function readVar(name, fallback) {
        const value = getComputedStyle(document.documentElement).getPropertyValue(name).trim();
        return value || fallback;
    }

    NoirMG.register('frequency', {
        title: 'Sintonia de Frequência',
        hint: 'Ache o sinal e segure nele até a trava fechar.',
        keys: [['A', 'Baixar'], ['D', 'Subir']],

        start(ctx) {
            const { el } = ctx;
            const tolerance = ctx.pick(5.5, 4, 2.5);
            const target = 15 + Math.random() * 70;
            let dial = Math.random() < 0.5 ? 5 : 95;
            let lock = 0;
            let phase = 0;
            const held = { left: false, right: false };

            // Osciloscópio
            const scope = el('div', 'fq-scope');
            const canvas = el('canvas', 'fq-canvas');
            const W = 380;
            const H = 96;
            const ratio = window.devicePixelRatio || 1;
            canvas.width = W * ratio;
            canvas.height = H * ratio;
            const g = canvas.getContext('2d');
            if (g) g.scale(ratio, ratio);
            const readout = el('span', 'fq-readout mg-num', '');
            scope.append(canvas, readout);

            // Dial com marcas
            const dialBox = el('div', 'fq-dial');
            const ticks = el('div', 'fq-ticks');
            for (let i = 0; i <= 20; i += 1) {
                const t = el('i', i % 5 === 0 ? 'major' : null);
                t.style.left = `${i * 5}%`;
                ticks.append(t);
            }
            const band = el('div', 'fq-band');
            band.style.left = `${target - tolerance}%`;
            band.style.width = `${tolerance * 2}%`;
            const needle = el('div', 'fq-needle');
            dialBox.append(ticks, band, needle);

            const scale = el('div', 'fq-scale mg-num');
            for (let i = 0; i <= 4; i += 1) scale.append(el('span', null, (MHZ_MIN + i * 5).toFixed(0)));

            // Trava
            const lockRow = el('div', 'fq-lock');
            const lockLabel = el('span', 'mg-label', 'Trava');
            const lockTrack = el('div', 'fq-lock-track');
            const lockFill = el('i');
            lockTrack.append(lockFill);
            const lockPct = el('span', 'fq-lock-pct mg-num', '0%');
            lockRow.append(lockLabel, lockTrack, lockPct);

            ctx.stage.append(scope, dialBox, scale, lockRow);

            const colLine = readVar('--noir-text-strong', '#fff');
            const colGrid = readVar('--noir-border-soft', 'rgba(255,255,255,.05)');
            const colMid = readVar('--noir-border', 'rgba(255,255,255,.11)');

            function draw(clarity) {
                if (!g) return;
                g.clearRect(0, 0, W, H);
                g.strokeStyle = colGrid;
                g.lineWidth = 1;
                g.beginPath();
                for (let x = 0; x <= W; x += 38) { g.moveTo(x + 0.5, 0); g.lineTo(x + 0.5, H); }
                for (let y = 0; y <= H; y += 24) { g.moveTo(0, y + 0.5); g.lineTo(W, y + 0.5); }
                g.stroke();
                g.strokeStyle = colMid;
                g.beginPath();
                g.moveTo(0, H / 2 + 0.5);
                g.lineTo(W, H / 2 + 0.5);
                g.stroke();

                const amp = 8 + clarity * 26;
                const noise = (1 - clarity) * 30;
                g.strokeStyle = colLine;
                g.lineWidth = 1.5;
                g.beginPath();
                for (let x = 0; x <= W; x += 3) {
                    const y = H / 2
                        + Math.sin(x / 22 + phase) * amp
                        + (Math.random() - 0.5) * noise;
                    if (x === 0) g.moveTo(x, y); else g.lineTo(x, y);
                }
                g.stroke();
            }

            ctx.onKey((e) => {
                if (e.code === 'KeyA') { held.left = true; e.preventDefault(); }
                if (e.code === 'KeyD') { held.right = true; e.preventDefault(); }
            });
            ctx.onKeyUp((e) => {
                if (e.code === 'KeyA') held.left = false;
                if (e.code === 'KeyD') held.right = false;
            });

            ctx.clock(ctx.pick(13, 15, 17));

            ctx.loop((dt) => {
                if (held.left && !held.right) dial = Math.max(0, dial - SPEED * dt);
                if (held.right && !held.left) dial = Math.min(100, dial + SPEED * dt);

                const off = Math.abs(dial - target);
                const inside = off <= tolerance;
                lock += (inside ? FILL_RATE : -DRAIN_RATE) * dt;
                lock = Math.max(0, Math.min(100, lock));

                const clarity = Math.max(0, 1 - off / REVEAL_SPAN);
                phase += dt * 6;

                needle.style.left = `${dial}%`;
                band.style.opacity = String(clarity);
                band.classList.toggle('on', inside);
                lockFill.style.width = `${lock}%`;
                lockPct.textContent = `${Math.floor(lock)}%`;
                readout.textContent = `${(MHZ_MIN + (dial / 100) * MHZ_SPAN).toFixed(1)} MHz`;
                draw(clarity);

                if (lock >= 100) ctx.pass();
            });
        },
    });
})();
