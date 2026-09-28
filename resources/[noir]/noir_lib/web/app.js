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
