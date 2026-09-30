// Teclas visíveis: o Lua manda { action: 'keyhints:show', position, keys } e { action: 'keyhints:hide' }.
(() => {
  const root = document.getElementById('keyhints');
  const EXIT_MS = 180;
  let hideTimer = null;

  function render(position, keys) {
    const horizontal = position === 'baixo' || position === 'cima';
    root.dataset.position = position;
    root.replaceChildren();

    keys.forEach((hint, index) => {
      if (horizontal && index > 0) {
        const sep = document.createElement('span');
        sep.className = 'keyhints__sep';
        sep.textContent = '/';
        root.append(sep);
      }
      const pill = document.createElement('span');
      pill.className = 'keyhints__key';
      const kbd = document.createElement('kbd');
      kbd.textContent = hint.key;
      pill.append(kbd, document.createTextNode(hint.label));
      root.append(pill);
    });
  }

  function show(position, keys) {
    clearTimeout(hideTimer);
    const wasVisible = root.classList.contains('is-visible');
    render(position, keys);
    root.hidden = false;
    if (!wasVisible) {
      // Um frame com a classe de fora para a transição de entrada acontecer.
      requestAnimationFrame(() => requestAnimationFrame(() => root.classList.add('is-visible')));
    }
  }

  function hide() {
    root.classList.remove('is-visible');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      root.hidden = true;
      root.replaceChildren();
    }, EXIT_MS);
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;
    if (data.action === 'keyhints:show' && Array.isArray(data.keys)) show(data.position, data.keys);
    else if (data.action === 'keyhints:hide') hide();
  });
})();

// Fala do ped: { action: 'speech:add', id, text, tone }, 'speech:frame' com as posições
// (x, y de 0 a 1 na tela, na ponta do balão) e 'speech:remove'.
(() => {
  const root = document.getElementById('speech');
  const EXIT_MS = 160;
  const bubbles = new Map();

  function add(id, text, tone) {
    remove(id, true);
    const el = document.createElement('div');
    el.className = 'speech__bubble';
    el.dataset.tone = tone === 'alert' ? 'alert' : 'neutral';
    el.textContent = text;
    el.hidden = true;
    root.append(el);
    bubbles.set(id, el);
  }

  function place(item) {
    const el = bubbles.get(item.id);
    if (!el) return;
    if (!item.visible) {
      el.classList.remove('is-visible');
      return;
    }
    el.hidden = false;
    el.style.left = `${item.x * 100}%`;
    el.style.top = `${item.y * 100}%`;
    el.style.setProperty('--scale', item.scale);
    if (!el.classList.contains('is-visible')) requestAnimationFrame(() => el.classList.add('is-visible'));
  }

  function remove(id, now) {
    const el = bubbles.get(id);
    if (!el) return;
    bubbles.delete(id);
    if (now) return el.remove();
    el.classList.remove('is-visible');
    setTimeout(() => el.remove(), EXIT_MS);
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;
    if (data.action === 'speech:add' && typeof data.text === 'string') add(data.id, data.text, data.tone);
    else if (data.action === 'speech:frame' && Array.isArray(data.items)) data.items.forEach(place);
    else if (data.action === 'speech:remove') remove(data.id, false);
  });
})();
