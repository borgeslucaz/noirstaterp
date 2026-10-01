// O Lua manda { action: 'open', players, maxPlayers, crimes?, policeUnavailable? } e { action: 'close' }.
// `crimes` só vem para quem está numa gang; sem ele, o placar mostra só os jogadores.
(() => {
  const board = document.getElementById('board');
  const players = document.getElementById('players');
  const crimesSection = document.getElementById('crimes');
  const crimeList = document.getElementById('crime-list');
  const crimeNote = document.getElementById('crime-note');
  const EXIT_MS = 240;
  const STATUS_TEXT = {
    open: 'Liberado',
    closed: 'Polícia insuficiente',
    busy: 'Em andamento',
  };
  let hideTimer = null;

  function renderCrimes(crimes, policeUnavailable) {
    crimeList.replaceChildren();
    crimeNote.textContent = '';

    if (policeUnavailable) {
      crimesSection.hidden = false;
      crimeNote.textContent = 'Contagem da polícia indisponível agora. Nenhum crime está liberado.';
      return;
    }
    if (!Array.isArray(crimes) || crimes.length === 0) {
      crimesSection.hidden = true;
      return;
    }

    for (const crime of crimes) {
      const row = document.createElement('li');
      row.className = 'crime';

      const label = document.createElement('span');
      label.className = 'crime__label';
      label.textContent = crime.label;

      const min = document.createElement('span');
      min.className = 'crime__min';
      min.textContent = `Mín. ${crime.minimumPolice}`;

      const status = document.createElement('span');
      status.className = 'crime__status';
      status.dataset.status = crime.status;
      status.textContent = STATUS_TEXT[crime.status] || '';

      row.append(label, min, status);
      crimeList.append(row);
    }
    crimeNote.textContent = 'Policiais em serviço contados quando o placar abriu.';
    crimesSection.hidden = false;
  }

  function open(data) {
    clearTimeout(hideTimer);
    players.textContent = `${data.players} de ${data.maxPlayers} jogadores`;
    renderCrimes(data.crimes, data.policeUnavailable);
    const wasVisible = board.classList.contains('is-visible');
    board.hidden = false;
    if (!wasVisible) {
      requestAnimationFrame(() => requestAnimationFrame(() => board.classList.add('is-visible')));
    }
  }

  function close() {
    board.classList.remove('is-visible');
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => { board.hidden = true; }, EXIT_MS);
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data.action !== 'string') return;
    if (data.action === 'open') open(data);
    else if (data.action === 'close') close();
  });
})();
