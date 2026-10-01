// noir_minigames: núcleo das partidas. Cada jogo se registra com NoirMG.register e
// recebe um contexto com palco, relógio, teclado, laço de animação e timers. Tudo o que
// o contexto cria é desfeito sozinho no fim da partida, então um jogo nunca deixa
// listener ou timer para trás.

'use strict';

const NoirMG = (() => {
    const games = {};
    let session = null;

    const DIFFICULTY_LABEL = { 1: 'Fácil', 2: 'Normal', 3: 'Difícil' };

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text !== undefined && text !== null) node.textContent = String(text);
        return node;
    }

    function rand(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    function shuffle(list) {
        const out = list.slice();
        for (let i = out.length - 1; i > 0; i -= 1) {
            const j = Math.floor(Math.random() * (i + 1));
            [out[i], out[j]] = [out[j], out[i]];
        }
        return out;
    }

    function renderKeys(container, keys) {
        container.replaceChildren();
        for (const [key, label] of keys) {
            const pill = el('span', 'mg-key');
            pill.append(el('kbd', null, key), document.createTextNode(label));
            container.append(pill);
        }
    }

    // Monta a janela: título, relógio, dica, barra, palco e teclas.
    function mount(def, difficulty) {
        const root = document.getElementById('root');
        root.replaceChildren();

        const overlay = el('div', 'mg-overlay');
        const win = el('section', def.wide ? 'mg-window wide' : 'mg-window');
        win.setAttribute('role', 'dialog');
        win.setAttribute('aria-label', def.title);

        const head = el('header', 'mg-head');
        const title = el('h1', 'mg-title', def.title);
        const clock = el('span', 'mg-clock mg-num', DIFFICULTY_LABEL[difficulty] || '');
        head.append(title, clock);

        const hint = el('p', 'mg-hint', def.hint || '');
        const bar = el('div', 'mg-bar');
        const fill = el('i');
        bar.append(fill);
        bar.classList.add('hidden');

        const stage = el('div', `mg-stage mg-${def.kind}`);
        win.append(head, hint, bar, stage);
        overlay.append(win);

        const keys = el('div', 'mg-keys');
        renderKeys(keys, [...(def.keys || []), ['ESC', 'Desistir']]);

        root.append(overlay, keys);
        return { win, clock, hint, bar, fill, stage, keys };
    }

    function cleanup(s) {
        s.timers.forEach((id) => clearTimeout(id));
        s.intervals.forEach((id) => clearInterval(id));
        if (s.raf) cancelAnimationFrame(s.raf);
        window.removeEventListener('keydown', s.onKeyDown, true);
        window.removeEventListener('keyup', s.onKeyUp, true);
        s.timers.clear();
        s.intervals.clear();
        s.loops.length = 0;
        s.raf = null;
    }

    function finish(s, passed) {
        if (s.ended) return;
        s.ended = true;
        cleanup(s);

        const result = el('div', `mg-result ${passed ? 'pass' : 'fail'}`, passed ? 'Aberto' : 'Falhou');
        s.ui.win.append(result);
        s.ui.keys.replaceChildren();

        setTimeout(() => {
            if (session === s) session = null;
            document.getElementById('root').replaceChildren();
            s.resolve(passed === true);
        }, 650);
    }

    function makeContext(s, difficulty) {
        const ctx = {
            difficulty,
            stage: s.ui.stage,
            get ended() { return s.ended; },

            pick(easy, normal, hard) { return [easy, normal, hard][difficulty - 1]; },
            el,
            rand,
            shuffle,

            pass() { finish(s, true); },
            fail() { finish(s, false); },

            setHint(text) { s.ui.hint.textContent = text; },
            setKeys(keys) { renderKeys(s.ui.keys, [...keys, ['ESC', 'Desistir']]); },

            // Relógio regressivo: zerou, falha.
            clock(seconds) {
                const total = seconds * 1000;
                const deadline = performance.now() + total;
                s.ui.bar.classList.remove('hidden');
                const tick = () => {
                    const left = Math.max(0, deadline - performance.now());
                    const ratio = left / total;
                    s.ui.clock.textContent = (left / 1000).toFixed(1);
                    s.ui.fill.style.width = `${ratio * 100}%`;
                    s.ui.bar.classList.toggle('danger', ratio <= 0.35);
                    s.ui.bar.classList.toggle('warn', ratio > 0.35 && ratio <= 0.60);
                    if (left <= 0) finish(s, false);
                };
                tick();
                ctx.every(100, tick);
            },

            onKey(fn) { s.keyDown.push(fn); },
            onKeyUp(fn) { s.keyUp.push(fn); },

            // Laço por frame: fn(dt em segundos, agora em ms).
            loop(fn) {
                s.loops.push(fn);
                if (s.raf) return;
                let last = performance.now();
                const frame = (now) => {
                    if (s.ended) return;
                    const dt = Math.min(0.05, (now - last) / 1000);
                    last = now;
                    for (const f of s.loops.slice()) {
                        f(dt, now);
                        if (s.ended) return;
                    }
                    s.raf = requestAnimationFrame(frame);
                };
                s.raf = requestAnimationFrame(frame);
            },

            after(ms, fn) {
                const id = setTimeout(() => { s.timers.delete(id); if (!s.ended) fn(); }, ms);
                s.timers.add(id);
                return id;
            },

            every(ms, fn) {
                const id = setInterval(() => { if (!s.ended) fn(); }, ms);
                s.intervals.add(id);
                return id;
            },
        };
        return ctx;
    }

    function register(kind, def) {
        games[kind] = { ...def, kind };
    }

    // Uma partida por vez. Jogo desconhecido falha: nunca libera nada por engano.
    function play(kind, difficulty) {
        return new Promise((resolve) => {
            const def = games[kind];
            if (!def || session) { resolve(false); return; }

            const d = Math.max(1, Math.min(3, Math.round(Number(difficulty) || 2)));
            const s = {
                ended: false,
                resolve,
                timers: new Set(),
                intervals: new Set(),
                loops: [],
                raf: null,
                keyDown: [],
                keyUp: [],
            };
            s.ui = mount(def, d);

            s.onKeyDown = (event) => {
                if (s.ended) return;
                if (event.key === 'Escape') { event.preventDefault(); finish(s, false); return; }
                for (const fn of s.keyDown) fn(event);
            };
            s.onKeyUp = (event) => {
                if (s.ended) return;
                for (const fn of s.keyUp) fn(event);
            };
            window.addEventListener('keydown', s.onKeyDown, true);
            window.addEventListener('keyup', s.onKeyUp, true);

            session = s;
            try {
                def.start(makeContext(s, d));
            } catch (err) {
                console.error(`[noir_minigames] ${kind}:`, err);
                finish(s, false);
            }
        });
    }

    function abort() {
        if (session) finish(session, false);
    }

    function list() {
        return Object.keys(games).map((kind) => ({ kind, title: games[kind].title }));
    }

    return { register, play, abort, list, busy: () => session !== null };
})();
