// Mesa de embalar. Telas: escolha -> mesa (arrastar) -> resultado.
// A tela só apresenta; quem entrega é o servidor (ingredientes e distância).
(() => {
  const isBrowser = !window.invokeNative;
  const resource = isBrowser ? 'noir_weed' : GetParentResourceName();

  const app = document.getElementById('app');
  const overlay = document.getElementById('overlay');
  const keys = document.getElementById('keys');

  let data = null;       // { title, recipes, game, locale }
  let screen = 'closed'; // setup | game | sending | result
  let pick = null;       // receita escolhida
  let qty = 1;
  let game = null;
  let drag = null;

  // Sons CC0 da Kenney (web/sounds). Mudo fica salvo no navegador do jogador.
  const SOUNDS = { grab: 'sounds/grab.ogg', drop: 'sounds/drop.ogg', seal: 'sounds/seal.ogg', miss: 'sounds/miss.ogg' };
  // Volume do jogador (0 a 100), salvo no navegador. O ícone liga/desliga lembrando o nível.
  let volume = null;
  let lastVolume = 35;
  try {
    const saved = localStorage.getItem('noir_weed:volume');
    if (saved !== null) volume = Math.max(0, Math.min(100, +saved));
    const last = localStorage.getItem('noir_weed:lastVolume');
    if (last !== null) lastVolume = +last || 35;
  } catch (e) {}

  const currentVolume = () => (volume ?? Math.round(((data && data.game && data.game.volume) ?? 0.35) * 100));

  function play(kind) {
    const v = currentVolume();
    if (!v || !SOUNDS[kind]) return;
    try {
      const a = new Audio(SOUNDS[kind]);
      a.volume = v / 100;
      a.play().catch(() => {});
    } catch (e) {}
  }

  const SVG_ON = '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M4 9v6h4l5 4V5L8 9H4zm12.5 3a4.5 4.5 0 0 0-2.5-4v8a4.5 4.5 0 0 0 2.5-4zM14 3.2v2.1a7 7 0 0 1 0 13.4v2.1a9 9 0 0 0 0-17.6z"/></svg>';
  const SVG_OFF = '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M4 9v6h4l5 4V5L8 9H4zm12.6 3 2.7-2.7-1.4-1.4-2.7 2.7-2.7-2.7-1.4 1.4 2.7 2.7-2.7 2.7 1.4 1.4 2.7-2.7 2.7 2.7 1.4-1.4z"/></svg>';

  const volumeControl = () => {
    const v = currentVolume();
    return `<div class="volume">
      <button class="mute" id="mute" aria-label="${v ? 'Desligar som' : 'Ligar som'}" title="${v ? 'Desligar som' : 'Ligar som'}">${v ? SVG_ON : SVG_OFF}</button>
      <input id="vol" type="range" min="0" max="100" step="5" value="${v}" aria-label="${esc(L('volume'))}">
    </div>`;
  };

  function saveVolume() {
    try {
      localStorage.setItem('noir_weed:volume', String(volume));
      if (volume) localStorage.setItem('noir_weed:lastVolume', String(volume));
    } catch (e) {}
  }

  function bindVolume() {
    const b = app.querySelector('#mute');
    const r = app.querySelector('#vol');
    if (!b || !r) return;
    const refresh = () => {
      const v = currentVolume();
      b.innerHTML = v ? SVG_ON : SVG_OFF;
      b.title = b.ariaLabel = v ? 'Desligar som' : 'Ligar som';
      r.value = v;
    };
    b.onclick = () => {
      const v = currentVolume();
      if (v) lastVolume = v;
      volume = v ? 0 : lastVolume;
      saveVolume(); refresh();
      play('seal');
    };
    r.oninput = () => { volume = +r.value; if (volume) lastVolume = volume; saveVolume(); refresh(); };
    r.onchange = () => play('seal');
  }

  const L = (key, ...args) => {
    let text = (data && data.locale && data.locale[key]) || key;
    args.forEach((a) => { text = text.replace('%s', a); });
    return text;
  };
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // Transporte ---------------------------------------------------------------------------
  async function nui(name, body) {
    if (isBrowser) return mock(name, body);
    try {
      const res = await fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
      });
      return await res.json();
    } catch (e) {
      return { ok: false };
    }
  }

  window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') open(msg.data);
    if (msg.action === 'close') hide();
  });

  function setKeys(list) {
    keys.hidden = !list.length;
    keys.innerHTML = list.map(([k, t]) => `<span class="key"><kbd>${k}</kbd>${esc(t)}</span>`).join('');
  }

  function open(payload) {
    data = payload;
    pick = data.recipes[0];
    qty = 1;
    overlay.hidden = false;
    renderSetup();
  }

  function hide() {
    screen = 'closed';
    if (game) { clearInterval(game.timer); game = null; }
    if (drag) { drag.ghost.remove(); drag = null; }
    overlay.hidden = true;
    setKeys([]);
    app.innerHTML = '';
  }

  function requestClose() {
    if (screen === 'game' || screen === 'sending') return;
    hide();
    nui('close');
  }

  // Escolha -----------------------------------------------------------------------------
  function renderSetup() {
    screen = 'setup';
    const max = pick.max;
    qty = Math.max(1, Math.min(qty, max));
    app.innerHTML = `
      <header class="head">
        <div><h1>${esc(data.title)}</h1><div class="sub">${esc(L('pick'))}</div></div>
        <div class="tools">${volumeControl()}<button class="close" id="close" aria-label="Fechar">✕</button></div>
      </header>
      <div class="setup">
        <div class="list">
          ${data.recipes.map((r, i) => `
            <button class="row" data-i="${i}" aria-pressed="${r === pick}">
              <img src="${r.images.drag}" alt="">
              <span class="grow">${esc(r.label)}<small>${esc(L('have', r.have))}</small></span>
              <span class="qty">${r.max}x</span>
            </button>`).join('')}
        </div>
        <div class="summary">
          <div class="name">${esc(pick.label)}</div>
          <div class="recipe">
            <img src="${pick.images.drag}" alt=""> + <img src="${pick.images.target}" alt=""> → <img src="${pick.images.result}" alt="">
          </div>
          <div class="hint">${esc(L('recipe'))}</div>
          <div class="stepper">
            <button id="minus" aria-label="Menos">−</button>
            <output id="qty">${qty}</output>
            <button id="plus" aria-label="Mais">+</button>
            <span class="hint">${esc(L('max', max))}</span>
          </div>
          <button class="btn go" id="start">${esc(L('start'))}</button>
        </div>
      </div>`;
    app.querySelectorAll('.row').forEach((b) => b.onclick = () => { pick = data.recipes[+b.dataset.i]; renderSetup(); });
    app.querySelector('#minus').onclick = () => { qty = Math.max(1, qty - 1); renderSetup(); };
    app.querySelector('#plus').onclick = () => { qty = Math.min(max, qty + 1); renderSetup(); };
    app.querySelector('#start').onclick = start;
    app.querySelector('#close').onclick = requestClose;
    bindVolume();
    setKeys([['↵', L('start')], ['Esc', 'Fechar']]);
  }

  async function start() {
    const btn = app.querySelector('#start');
    btn.disabled = true;
    const res = await nui('start', { recipe: pick.key, qty });
    if (!res || !res.ok) { btn.disabled = false; return; }
    startGame();
  }

  // Mesa --------------------------------------------------------------------------------
  function startGame() {
    screen = 'game';
    const cfg = data.game;
    game = {
      recipe: pick, total: qty, remainingBuds: qty, remainingBags: qty,
      done: 0, wasted: 0, started: performance.now(), slots: [], timer: 0,
    };
    app.innerHTML = `
      <header class="head">
        <div><h1>${esc(L('playing', pick.label))}</h1><div class="sub">${esc(L('drag'))}</div></div>
        <div class="stats">
          <div class="stat"><b id="sDone">0/${qty}</b><span>${esc(L('done'))}</span></div>
          ${data.game.wasteOnMiss ? `<div class="stat"><b id="sLost">0</b><span>Perdidos</span></div>` : '<i id="sLost" hidden></i>'}
          <div class="stat"><b id="sTime">0:00</b><span>Tempo</span></div>
          ${volumeControl()}
        </div>
      </header>
      <div class="table">
        <div class="zone"><h2>${esc(L('buds'))} <i id="budCount">${qty}</i></h2><div class="tray buds" id="buds"></div></div>
        <div class="zone"><h2>${esc(L('bags'))} <i id="bagCount">${qty}</i></h2><div class="tray bags" id="bags"></div></div>
        <div class="done-row"><span class="label">${esc(L('done'))}</span><div class="done-stack" id="doneStack"></div></div>
      </div>
      <div class="foot"><div class="btn-row"><button class="btn sec" id="stop">${esc(L('stop'))}</button><span></span></div></div>`;
    app.querySelector('#stop').onclick = wrapUp;
    bindVolume();
    layBuds();
    fillSlots(cfg.slots);
    game.timer = setInterval(() => {
      const el = document.getElementById('sTime');
      if (el && game) el.textContent = fmt((performance.now() - game.started) / 1000);
    }, 250);
    setKeys([['Mouse', 'Arrastar'], ['Esc', L('stop')]]);
  }

  // Bandeja de buds: até 9 à vista, cada um numa das 9 vagas. Nunca é redesenhada no
  // meio do jogo: só completa vagas livres, e o bud na mão (escondido) segue ocupando a
  // dele. Redesenhar apagava o bud arrastado e o contava de novo, sobrando um no fim.
  function layBuds() {
    const tray = document.getElementById('buds');
    const want = Math.min(game.remainingBuds, 9);
    const taken = new Set([...tray.children].map((el) => +el.dataset.spot));
    for (let spot = 0; spot < 9 && tray.children.length < want; spot++) {
      if (taken.has(spot)) continue;
      const el = document.createElement('div');
      el.className = 'bud';
      el.dataset.spot = spot;
      const col = spot % 3, row = Math.floor(spot / 3);
      el.style.left = `${18 + col * 32 + (Math.random() * 8 - 4)}%`;
      el.style.top = `${20 + row * 30 + (Math.random() * 8 - 4)}%`;
      el.style.rotate = `${Math.round(Math.random() * 50 - 25)}deg`;
      el.innerHTML = `<img src="${game.recipe.images.drag}" alt="">`;
      el.addEventListener('pointerdown', (e) => grab(e, el));
      tray.appendChild(el);
    }
  }

  function fillSlots(slots) {
    const box = document.getElementById('bags');
    const want = Math.min(slots || data.game.slots, game.total);
    while (game.slots.length < want) game.slots.push({ state: 'empty' });
    let pending = game.remainingBags - game.slots.filter((s) => s.state !== 'empty').length;
    game.slots.forEach((slot) => {
      if (slot.state === 'empty' && pending > 0) { slot.state = 'ready'; pending--; }
    });
    box.innerHTML = '';
    game.slots.forEach((slot) => {
      const el = document.createElement('div');
      el.className = `bag ${slot.state}`;
      if (slot.state === 'ready') el.innerHTML = `<img src="${game.recipe.images.target}" alt="">`;
      if (slot.state === 'sealing') el.innerHTML = `<img src="${game.recipe.images.result}" alt=""><div class="ring"></div>`;
      slot.el = el;
      box.appendChild(el);
    });
  }

  function grab(e, el) {
    if (drag || !game || screen !== 'game') return;
    e.preventDefault();
    el.style.visibility = 'hidden';
    const ghost = document.createElement('div');
    ghost.className = 'ghost';
    ghost.innerHTML = `<img src="${game.recipe.images.drag}" alt="">`;
    document.body.appendChild(ghost);
    const r = el.getBoundingClientRect();
    drag = { el, ghost, home: { x: r.left + r.width / 2, y: r.top + r.height / 2 } };
    play('grab');
    move(e);
    window.addEventListener('pointermove', move);
    window.addEventListener('pointerup', drop, { once: true });
  }

  function targetAt(x, y) {
    let best = null, bestD = Infinity;
    game.slots.forEach((slot) => {
      if (slot.state !== 'ready') return;
      const r = slot.el.getBoundingClientRect();
      const d = Math.hypot(x - (r.left + r.width / 2), y - (r.top + r.height / 2));
      if (d < data.game.radius + r.width * 0.2 && d < bestD) { best = slot; bestD = d; }
    });
    return best;
  }

  function move(e) {
    if (!drag) return;
    drag.ghost.style.transform = `translate(${e.clientX}px, ${e.clientY}px)`;
    const t = targetAt(e.clientX, e.clientY);
    game.slots.forEach((s) => s.el.classList.toggle('hot', s === t));
  }

  function drop(e) {
    window.removeEventListener('pointermove', move);
    if (!drag || !game) return;
    const d = drag; drag = null;
    const slot = targetAt(e.clientX, e.clientY);
    game.slots.forEach((s) => s.el.classList.remove('hot'));
    if (slot) {
      d.ghost.remove(); d.el.remove();
      game.remainingBuds--;
      document.getElementById('budCount').textContent = game.remainingBuds;
      play('drop');
      seal(slot);
    } else if (data.game.wasteOnMiss) {
      // Errou: o bud cai e se perde.
      play('miss');
      d.el.remove();
      d.ghost.style.transition = 'transform .3s ease-in, opacity .3s ease-in';
      d.ghost.style.transform += ' translateY(48px) scale(.6) rotate(40deg)';
      d.ghost.style.opacity = '0';
      setTimeout(() => d.ghost.remove(), 320);
      game.remainingBuds--; game.wasted++;
      document.getElementById('budCount').textContent = game.remainingBuds;
      document.getElementById('sLost').textContent = game.wasted;
      layBuds();
      checkEnd();
    } else {
      // Errou: o bud volta para o lugar.
      play('miss');
      d.ghost.classList.add('back');
      d.ghost.style.transform = `translate(${d.home.x}px, ${d.home.y}px)`;
      setTimeout(() => { d.ghost.remove(); d.el.style.visibility = ''; }, 260);
    }
  }

  // Acabou quando não há mais bud na mesa nem saquinho selando.
  function checkEnd() {
    if (!game) return;
    const sealing = game.slots.some((s) => s.state === 'sealing');
    if (!sealing && game.remainingBuds <= 0) setTimeout(wrapUp, 350);
  }

  function seal(slot) {
    slot.state = 'sealing';
    fillSlots();
    const began = performance.now(), dur = data.game.seal * 1000;
    const step = () => {
      if (!game) return;
      const p = dur ? Math.min(1, (performance.now() - began) / dur) : 1;
      const ring = slot.el.querySelector('.ring');
      if (ring) ring.style.setProperty('--p', p);
      if (p < 1) return requestAnimationFrame(step);
      slot.state = 'empty';
      game.remainingBags--; game.done++;
      play('seal');
      const im = document.createElement('img');
      im.src = game.recipe.images.result; im.alt = '';
      document.getElementById('doneStack').appendChild(im);
      document.getElementById('sDone').textContent = `${game.done}/${game.total}`;
      document.getElementById('bagCount').textContent = game.remainingBags;
      fillSlots();
      layBuds();
      checkEnd();
    };
    requestAnimationFrame(step);
  }

  // Fim da rodada: manda o que ficou pronto. Saquinho ainda selando não conta.
  function wrapUp() {
    if (!game || screen !== 'game') return;
    const g = game;
    clearInterval(g.timer);
    game = null;
    if (drag) { drag.ghost.remove(); drag = null; }
    screen = 'sending';
    setKeys([]);
    send(g);
  }

  async function send(g) {
    const res = await nui('finish', { done: g.done, wasted: g.wasted });
    const ok = res && res.ok;
    renderResult(g.recipe, ok ? res.done : 0, ok ? res.wasted : 0);
  }

  // Resultado ---------------------------------------------------------------------------
  function renderResult(recipe, done, wasted) {
    screen = 'result';
    app.innerHTML = `
      <header class="head">
        <div><h1>${esc(data.title)}</h1><div class="sub">${esc(recipe.label)}</div></div>
        <button class="close" id="close" aria-label="Fechar">✕</button>
      </header>
      <div class="result">
        <div class="big"><img src="${recipe.images.result}" alt=""><b>${done ? esc(L('result', done)) : esc(L('resultNone'))}</b></div>
        ${wasted ? `<div class="lost">${esc(L('wasted', wasted))}</div>` : ''}
        <div class="btn-row">
          <button class="btn sec" id="back">${esc(L('closeTable'))}</button>
          <button class="btn go" id="again">${esc(L('again'))}</button>
        </div>
      </div>`;
    app.querySelector('#back').onclick = requestClose;
    app.querySelector('#close').onclick = requestClose;
    app.querySelector('#again').onclick = again;
    setKeys([['↵', L('again')], ['Esc', L('closeTable')]]);
  }

  async function again() {
    const res = await nui('again');
    if (!res || !res.ok) return hide();
    data.recipes = res.recipes;
    pick = data.recipes.find((r) => pick && r.key === pick.key) || data.recipes[0];
    renderSetup();
  }

  // Teclado -----------------------------------------------------------------------------
  window.addEventListener('keydown', (e) => {
    if (screen === 'closed') return;
    if (e.key === 'Escape') {
      if (screen === 'game') wrapUp();
      else requestClose();
    }
    if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') {
      if (screen === 'setup') app.querySelector('#start')?.click();
      if (screen === 'result') app.querySelector('#again')?.click();
    }
  });

  function fmt(sec) {
    sec = Math.max(0, Math.round(sec));
    return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
  }

  // Preview no navegador (§10) ----------------------------------------------------------
  function mock(name, body) {
    if (name === 'start') return { ok: true };
    if (name === 'finish') return { ok: true, done: body.done, wasted: body.wasted };
    if (name === 'again') return { ok: true, recipes: mockData().recipes };
    return { ok: true };
  }

  function mockData() {
    const img = (n) => `../../../[ox]/ox_inventory/web/images/${n}.png`;
    const strains = [['og-kush', 'OG Kush', 12], ['purple-haze', 'Purple Haze', 6], ['skunk', 'Skunk', 30]];
    return {
      title: 'Mesa de embalar',
      game: { seal: 2.0, radius: 70, slots: 6, volume: 0.35, wasteOnMiss: true },
      recipes: strains.map(([id, label, n]) => ({
        key: `pack_weed_${id}`, label, max: n, have: n,
        images: { drag: img(`weed_${id}`), target: img('empty_weed_bag'), result: img(`weed_${id}_baggy`) },
      })),
      locale: {
        pick: 'Escolha a variedade e quantos saquinhos quer fazer.',
        recipe: 'Cada saquinho usa 1 bud e 1 saquinho vazio.',
        start: 'Começar a embalar', playing: 'Embalando %s', drag: 'Arraste cada bud até um saquinho vazio.',
        buds: 'Buds', bags: 'Saquinhos', done: 'Prontos', stop: 'Encerrar',
        result: '%sx saquinhos', resultNone: 'Nenhum saquinho embalado',
        closeTable: 'Fechar mesa', again: 'Embalar mais', max: 'máx. %s', have: 'Você tem %s buds',
        wasted: 'Buds perdidos: %s', volume: 'Volume',
      },
    };
  }

  if (isBrowser) {
    const dev = document.getElementById('dev');
    dev.hidden = false;
    dev.innerHTML = '<button id="devOpen">Abrir mesa</button>';
    document.getElementById('devOpen').onclick = () => open(mockData());
    document.documentElement.style.setProperty('background', '#1a1d22', 'important');
  }
})();
