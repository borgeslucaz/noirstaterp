// Guia de Cultivo: livro de duas páginas por vez. O Lua manda { action: 'manual:open', data }
// com os números do config do servidor; as páginas são montadas aqui a partir deles.
(() => {
  const isBrowser = !window.invokeNative;
  const resource = isBrowser ? 'noir_weed' : GetParentResourceName();
  const root = document.getElementById('manual');
  const IMG = isBrowser ? '../../../[ox]/ox_inventory/web/images/' : 'nui://ox_inventory/web/images/';

  let pages = [];
  let spread = 0; // índice da página da esquerda (sempre par)

  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const img = (item) => `<img src="${IMG}${item}.png" alt="">`;

  // Uma linha de item com imagem, nome e para que serve.
  const itemRow = (item, name, text) => `
    <li class="mn-item">${img(item)}<span><b>${esc(name)}</b>${esc(text)}</span></li>`;

  // O texto é do mundo do jogo: um livreto da Head Shop, escrito por quem planta. Nada de
  // tecla, inventário ou nível; a progressão aparece pelos títulos do Cultivo (os mesmos do
  // painel de habilidades), e os números vêm do config do servidor.
  function build(d) {
    const care = (g) => d.gradeByCare.find((b) => b.grade === g).care;
    const yieldAt = (level) => d.yieldByLevel.reduce((found, b) => (level >= b.level ? b.percent : found), 0);
    const pct = (n) => (n > 0 ? `${n}% a mais` : 'o normal');

    return [
      // 1 — capa
      { cover: true, html: `
        <div class="mn-cover">
          <div class="mn-cover__leaf">${img('weed_skunk')}</div>
          <h1>Guia de Cultivo</h1>
          <p>Do vaso à colheita, do jeito que a gente faz aqui na loja.</p>
          <span class="mn-cover__foot">Head Shop · Rockford Hills</span>
        </div>` },
      // 2 — sumário
      { title: 'Sumário', html: `
        <ol class="mn-toc">
          <li data-go="2"><span>O que levar para casa</span><i>3</i></li>
          <li data-go="3"><span>Plantando</span><i>4</i></li>
          <li data-go="4"><span>O dia a dia da planta</span><i>5</i></li>
          <li data-go="5"><span>Qualidade da erva</span><i>6</i></li>
          <li data-go="6"><span>Hora de colher</span><i>7</i></li>
          <li data-go="7"><span>Mão boa se aprende</span><i>8</i></li>
          <li data-go="8"><span>O caminho do cultivador</span><i>9</i></li>
          <li data-go="9"><span>Depois da colheita</span><i>10</i></li>
          <li data-go="10"><span>Aviso da loja</span><i>11</i></li>
          <li data-go="11"><span>O que diz a lei</span><i>12</i></li>
        </ol>
        <p class="mn-note">Leia antes de sujar as mãos. A planta agradece.</p>` },
      // 3
      { title: 'O que levar para casa', html: `
        <p>Tudo isso tem aqui no balcão. Não economize no básico.</p>
        <ul class="mn-items">
          ${itemRow('weed_skunk_seed', 'Semente', 'Uma por vaso. É ela que decide a variedade que você vai colher.')}
          ${itemRow('weed_pot', 'Vaso', 'Já vem com terra. É a casa da planta, dentro de casa ou onde você montar.')}
          ${itemRow('garden_shovel', 'Pá de jardim', 'Para ajeitar a terra do vaso na hora de plantar e de colher. Dura a vida toda.')}
          ${itemRow('water', 'Água', 'Planta com sede não cresce.')}
          ${itemRow('weed_nutrition', 'Fertilizante', 'O alimento da planta. Acabou, ela para.')}
          ${itemRow('herbicide', 'Herbicida', 'Mantém praga e doença longe. Uma borrifada rende bem.')}
        </ul>` },
      // 4
      { title: 'Plantando', html: `
        <p>Escolha bem o cômodo. Planta tem cheiro e não se esconde sozinha, e a polícia queima o que encontra. Perto de delegacia, nem pense.</p>
        <p>Com a pá e o vaso em mãos, é só colocar a semente na terra do vaso. Se depois achar que o lugar não ficou bom, dá para mudar o vaso de lugar sem perder nada.</p>
        <p>Toda muda sai daqui com sede e fome: água, adubo e saúde lá embaixo. <b>Cuide dela logo no primeiro dia.</b></p>
        <p>Uma pessoa sozinha dá conta de uns <b>${d.maxPlants} vasos</b>. Mais que isso vira bagunça e a planta sente.</p>` },
      // 5
      { title: 'O dia a dia da planta', html: `
        <p>Chegue perto e olhe a planta: dá para ver na hora quanto ela cresceu e como estão água, adubo e saúde.</p>
        <p>Ela gasta tudo aos poucos. E tem uma regra que muita gente aprende do jeito difícil: <b>se qualquer um dos três acabar, ela para de crescer</b> até você repor.</p>
        <p>Bem cuidada, vai de muda a planta pronta em uns <b>${d.minutes} minutos</b>, e continua crescendo mesmo sem você por perto.</p>
        <div class="mn-tip"><b>Conselho da casa</b>Passe para ver a planta a cada dez minutos e complete tudo de uma vez. Quem só aparece quando lembra colhe erva fraca.</div>` },
      // 6
      { title: 'Qualidade da erva', html: `
        <p>A planta lembra de tudo: cada vez que ficou com sede, com fome ou doente. Na colheita, esse histórico vira a qualidade do que sai dela. A gente classifica assim:</p>
        <table class="mn-table">
          <thead><tr><th>Grau</th><th>Como a planta foi tratada</th></tr></thead>
          <tbody>
            <tr><td><b>S</b></td><td>Mimada: sempre cheia, do plantio à colheita (${care('S')}% ou mais de cuidado).</td></tr>
            <tr><td><b>A</b></td><td>Bem tratada, com uma folga aqui e ali (${care('A')}% ou mais).</td></tr>
            <tr><td><b>B</b></td><td>Cuidada de vez em quando (${care('B')}% ou mais).</td></tr>
            <tr><td><b>C</b></td><td>Largada. Sobreviveu, mas só isso.</td></tr>
          </tbody>
        </table>
        <p>O grau acompanha a erva e tudo o que for feito com ela. <b>Erva de grau alto vale mais</b>, em qualquer lugar.</p>
        <p class="mn-note">Olhando a planta, dá para ter uma ideia do grau que ela daria se fosse colhida agora.</p>` },
      // 7
      { title: 'Hora de colher', html: `
        <p>Planta pronta, pá na mão. O vaso vai embora e os buds ficam com você.</p>
        <p>Quantos buds saem depende da <b>saúde da planta na hora</b>: doente, ela rende uns ${d.reward.min}; saudável, até ${d.reward.max}. E quem tem mais experiência tira mais de cada planta.</p>
        <p>Buds da mesma variedade, da mesma qualidade e colhidos juntos ficam juntos no pacote.</p>
        <div class="mn-tip"><b>Conselho da casa</b>Dê uma última borrifada de herbicida antes de colher. É a saúde que decide quanto você leva.</div>` },
      // 8
      { title: 'Mão boa se aprende', html: `
        <p>Ninguém nasce sabendo. Cada colheita ensina alguma coisa, e colheita farta ensina mais.</p>
        <p>Com o tempo, quem planta:</p>
        <ul class="mn-bullets">
          <li>tira mais buds de cada planta;</li>
          <li>consegue erva de qualidade melhor (no começo, o máximo é o grau ${d.gradeCapByLevel[0].grade});</li>
          <li>aprende truques que mudam o jeito de plantar.</li>
        </ul>
        <p>Um detalhe: a planta cresce com o jeito de quem <b>plantou</b>. O que você aprender depois de plantar a semente vale para a colheita, mas não muda como aquela planta bebe ou cresce.</p>` },
      // 9
      { title: 'O caminho do cultivador', html: `
        <table class="mn-table mn-table--levels">
          <thead><tr><th>Quem é</th><th>O que já sabe fazer</th></tr></thead>
          <tbody>
            <tr><td><b>Curioso</b></td><td>Erva até grau ${d.gradeCapByLevel[0].grade}. Depois das primeiras colheitas, aprende a não desperdiçar: a planta gasta ${d.perks.thirst.percent}% menos água e adubo.</td></tr>
            <tr><td><b>Jardineiro</b></td><td>Já tira grau A e colhe ${pct(yieldAt(5))}. Pouco depois, as plantas ficam prontas em ${d.minutesFast} minutos em vez de ${d.minutes}.</td></tr>
            <tr><td><b>Cultivador</b></td><td>Sabe guardar semente: toda colheita devolve ${d.perks.seedBack.amount}. Colhe ${pct(yieldAt(9))}.</td></tr>
            <tr><td><b>Botânico</b></td><td>Chega ao grau S e colhe ${pct(yieldAt(11))}. Mais adiante, dá conta de ${d.perks.extraPot.amount} vaso a mais.</td></tr>
            <tr><td><b>Mestre do Cultivo</b></td><td>Tira o máximo de cada planta: ${pct(yieldAt(15))}.</td></tr>
          </tbody>
        </table>` },
      // 10
      { title: 'Depois da colheita', html: `
        <p>Para fumar, é com o <b>dixavador</b> e a <b>seda</b>: ${d.roll.buds} bud e ${d.roll.papers} sedas dão ${d.roll.joints} baseados. Um dixavador bom aguenta uns ${d.grinderUses} baseados antes de gastar.</p>
        <ul class="mn-items">
          ${itemRow('grinder_crank', 'Dixavador', 'Tem vários modelos no balcão. Escolha pelo estilo.')}
          ${itemRow('rolling_paper', 'Seda', `${d.roll.papers} por baseado.`)}
        </ul>
        <p>Erva é coisa viva: o <b>bud fica bom por uns 5 dias</b> e o <b>baseado por uns 15</b>, esteja onde estiver. Use primeiro o que é mais velho.</p>
        <p class="mn-note">Boa colheita. E você não comprou este guia aqui.</p>` },
      // 11
      { title: 'Aviso da loja', html: `
        <p>A Head Shop vende sementes, vasos, adubo e acessórios. O que cada um faz com eles é problema de cada um.</p>
        <p>Plantar para o próprio consumo é uma coisa. <b>Vender, embalar para venda ou carregar quantidade de comerciante é outra</b>, e a polícia de Los Santos sabe muito bem a diferença.</p>
        <p>Se for pego, não diga onde comprou. A gente também não lembra de você.</p>
        <div class="mn-tip"><b>Conselho da casa</b>Leia a página ao lado com atenção. Ela não foi escrita pela gente.</div>` },
      // 12 — texto provisório; a redação final do código penal vem depois
      { title: 'O que diz a lei', html: `
        <p class="mn-law__code">Código Penal do Estado de San Andreas<br>Título IV · Dos crimes contra a saúde pública</p>
        <div class="mn-law">
          <p><b>Art. 184-B. Tráfico de cannabis.</b> Vender, expor à venda, oferecer, entregar, transportar, guardar ou ter em depósito, para fins de comércio, <i>cannabis</i> ou produto dela derivado, sem autorização do Estado.</p>
          <p><b>Pena:</b> reclusão de <b>5 a 30 meses</b>, e apreensão do produto, dos instrumentos e do dinheiro obtido com o crime.</p>
          <p><b>§ 1º</b> Na mesma pena incorre quem cultiva, colhe ou prepara a planta para o comércio.</p>
          <p><b>§ 2º</b> A pena é aumentada de metade se o crime for cometido perto de escola, hospital ou repartição pública, ou com uso de arma.</p>
        </div>
        <p class="mn-note">Transcrito para fins informativos.</p>` },
    ];
  }

  function pageHtml(page, index) {
    if (!page) return '<div class="mn-page mn-page--blank"></div>';
    return `
      <div class="mn-page${page.cover ? ' mn-page--cover' : ''}">
        ${page.title ? `<h2>${esc(page.title)}</h2>` : ''}
        <div class="mn-body">${page.html}</div>
        ${page.cover ? '' : `<span class="mn-num">${index + 1}</span>`}
      </div>`;
  }

  function render() {
    const last = Math.max(0, pages.length - 1);
    root.innerHTML = `
      <div class="mn-overlay">
        <section class="mn-book" role="dialog" aria-label="Guia de Cultivo">
          <header class="mn-head">
            <h1>Guia de Cultivo</h1>
            <span class="mn-count">${spread + 1}–${Math.min(spread + 2, pages.length)} de ${pages.length}</span>
            <button class="mn-close" id="mnClose" aria-label="Fechar">✕</button>
          </header>
          <div class="mn-spread">
            ${pageHtml(pages[spread], spread)}
            ${pageHtml(pages[spread + 1], spread + 1)}
          </div>
          <footer class="mn-foot">
            <button class="mn-btn" id="mnPrev" ${spread === 0 ? 'disabled' : ''}>Anterior</button>
            <button class="mn-btn" id="mnNext" ${spread + 2 > last ? 'disabled' : ''}>Próxima</button>
          </footer>
        </section>
        <div class="mn-keys">
          <span class="mn-key"><kbd>←→</kbd>Virar página</span>
          <span class="mn-key"><kbd>Esc</kbd>Fechar</span>
        </div>
      </div>`;
    root.querySelector('#mnClose').onclick = close;
    root.querySelector('#mnPrev').onclick = () => turn(-2);
    root.querySelector('#mnNext').onclick = () => turn(2);
    root.querySelectorAll('[data-go]').forEach((el) => {
      el.onclick = () => { spread = Math.floor(+el.dataset.go / 2) * 2; render(); };
    });
  }

  function turn(delta) {
    const next = spread + delta;
    if (next < 0 || next > pages.length - 1) return;
    spread = next;
    render();
  }

  function open(data) {
    pages = build(data);
    spread = 0;
    root.hidden = false;
    render();
  }

  function hide() {
    root.hidden = true;
    root.innerHTML = '';
  }

  function close() {
    hide();
    if (isBrowser) return;
    fetch(`https://${resource}/manualClose`, { method: 'POST', body: '{}' }).catch(() => {});
  }

  window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg.action !== 'string') return;
    if (msg.action === 'manual:open' && msg.data) open(msg.data);
    else if (msg.action === 'manual:close') hide();
  });

  window.addEventListener('keydown', (e) => {
    if (root.hidden) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'ArrowRight') turn(2);
    else if (e.key === 'ArrowLeft') turn(-2);
  });

  // Preview no navegador: números iguais aos do config/server.lua de hoje.
  if (isBrowser) {
    const dev = document.getElementById('dev');
    const button = document.createElement('button');
    button.textContent = 'Abrir guia';
    button.onclick = () => open({
      maxPlants: 5, reward: { min: 2, max: 10 }, minutes: 25, minutesFast: 20,
      care: { water: 10, fertilizer: 10, herbicide: 25 }, initial: { health: 30, water: 30, fertilizer: 30 },
      gradeByCare: [{ care: 0, grade: 'C' }, { care: 50, grade: 'B' }, { care: 70, grade: 'A' }, { care: 85, grade: 'S' }],
      xpPerHarvest: 10, xpPerBud: 2,
      yieldByLevel: [{ level: 1, percent: 0 }, { level: 3, percent: 5 }, { level: 5, percent: 10 }, { level: 9, percent: 15 }, { level: 11, percent: 20 }, { level: 15, percent: 25 }],
      gradeCapByLevel: [{ level: 1, grade: 'B' }, { level: 5, grade: 'A' }, { level: 11, grade: 'S' }],
      perks: { thirst: { level: 3, percent: 20 }, fastGrowth: { level: 7 }, seedBack: { level: 9, amount: 1 }, extraPot: { level: 13, amount: 1 } },
      roll: { buds: 1, papers: 2, joints: 2 }, grinderUses: 10,
    });
    const wait = setInterval(() => {
      if (!dev.hidden) { dev.append(button); clearInterval(wait); }
    }, 100);
  }
})();
