// Preview no navegador: monta o html/index.html real e faz o papel do client (Lua).
// Catálogo e níveis copiados de config.lua / serverConfig.lua; o resto é exemplo.

window.GetParentResourceName = () => 'noir_taxijob';

const toastEl = document.getElementById('dev-toast');
let toastTimer;
function toast(message) {
  toastEl.textContent = message;
  toastEl.style.display = 'block';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toastEl.style.display = 'none'), 3200);
}

const nui = (action, data) => window.postMessage({ action, data }, '*');
const clone = (value) => JSON.parse(JSON.stringify(value));

// Imagem de cada carro lida do config.lua, para o preview acompanhar o que o jogo mostra.
const configText = await (await fetch('/config.lua')).text();
const imageByModel = {};
for (const [, model, image] of configText.matchAll(/model = '([\w]+)'[\s\S]*?image = '([^']+)'/g)) imageByModel[model] = image;

const LEVEL = 4;
const vehicles = [
  ['standard', 'taxi', 'Táxi Standard', 1, 'O clássico da cidade. Confiável e econômico.'],
  ['economy', 'ingottaxi', 'Táxi Ingot', 2, 'Perua de táxi com mais espaço. Mesmas corridas do Standard.'],
  ['executive', 'tailgater', 'Executivo', 3, 'Passageiros executivos: exigentes com a temperatura, gorjeta de até 15%.'],
  ['van', 'imperialpas', 'Van', 4, 'Grupos de 2 ou 3 passageiros: +15% por passageiro extra, embarque mais demorado.'],
  ['suv', 'granger', 'SUV', 4, 'Chamadas em Sandy Shores e Paleto Bay, com corridas mais longas.'],
  ['luxury', 'cognoscenti', 'Luxo', 5, 'Clientes VIP: bônus de calma maior para quem dirige com cuidado.'],
  ['limousine', 'stretch', 'Limousine', 6, 'Corridas de evento: longas, exigentes e com gorjeta alta.'],
].map(([id, model, label, requiredLevel, description]) => ({
  id, model, label, requiredLevel, description, rentalFee: 0,
  // No jogo o caminho é relativo a html/; aqui a página está em /dev.
  image: `/html/${imageByModel[model] || `img/vehicles/${model}.png`}`,
  status: requiredLevel <= LEVEL ? 'available' : 'locked',
}));

const menuData = {
  header: { brand: 'NOIR CAB CO.', context: 'CENTRAL · LOS SANTOS' },
  serverTime: Math.floor(Date.now() / 1000),
  activeRental: null,
  vehicles,
  profile: {
    displayName: 'Lucas Borges', level: LEVEL, levelLabel: 'Especialista', confidence: 3120, levelStart: 2000,
    nextLevelAt: 5000, nextLevelLabel: 'Veterano', confidenceRemaining: 1880, progressPercent: 37, maxLevel: false,
    earnedToday: 2840, completedRides: 146, ratingAverage: 4.6, ratingCount: 131,
  },
};

const ranking = {
  generatedAt: Math.floor(Date.now() / 1000) - 240,
  entries: [
    { position: 1, displayName: 'Ana Ribeiro', level: 6, confidence: 14210, completedRides: 612 },
    { position: 2, displayName: 'Caio Menezes', level: 5, confidence: 8120, completedRides: 401 },
    { position: 3, displayName: 'Rafa Duarte', level: 5, confidence: 5480, completedRides: 277 },
    { position: 4, displayName: 'Lucas Borges', level: 4, confidence: 3120, completedRides: 146 },
    { position: 5, displayName: 'Bia Lopes', level: 3, confidence: 1540, completedRides: 98 },
  ],
  self: { position: 4, displayName: 'Lucas Borges', level: 4, confidence: 3120, completedRides: 146 },
};

const realFetch = window.fetch.bind(window);
window.fetch = async (url, opts) => {
  const match = String(url).match(/^https:\/\/noir_taxijob\/([\w:]+)/);
  if (!match) return realFetch(url, opts);
  const name = match[1];
  const body = opts && opts.body ? JSON.parse(opts.body) : {};
  const json = (value) => new Response(JSON.stringify(value), { headers: { 'Content-Type': 'application/json' } });
  switch (name) {
    case 'requestRanking': return json({ ok: true, data: ranking });
    case 'rentVehicle': toast(`rentVehicle ${body.vehicleId}`); return json({ ok: true });
    case 'closeMenu': toast('central fechada'); nui('taxiMenu:close'); return json({ ok: true });
    default: return json({ ok: true });
  }
};

// ── Monta a NUI real ──
const html = await (await fetch('/html/index.html')).text();
const doc = new DOMParser().parseFromString(html, 'text/html');
[...doc.body.children].filter((node) => node.tagName !== 'SCRIPT').forEach((node) => document.body.insertBefore(node, toastEl));
await new Promise((resolve) => {
  const script = document.createElement('script');
  script.src = '/html/app.js';
  script.onload = resolve;
  document.body.appendChild(script);
});

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const keys = { fan: 'G', accept: 'E', pause: 'J' };
const hud = (state, data = {}) => {
  nui('taxi:setVisible', true);
  nui('taxi:setState', { state, data: { keys, temperature: 22, fan: 2, mode: 'auto', fare: 0, distance: 0, ...data } });
};

function reset() {
  nui('taxiMenu:close');
  nui('taxi:setVisible', false);
  nui('studio:hide');
}

window.devScenarios = {
  central: 'Central',
  veiculos: 'Central · veículos',
  ranking: 'Central · ranking',
  disponivel: 'HUD · disponível',
  oferta: 'HUD · oferta',
  caminho: 'HUD · a caminho',
  ocupado: 'HUD · ocupado',
  resultado: 'HUD · resultado',
  estudio: 'Estúdio',
};

window.devOpen = async (key) => {
  reset();
  await wait(80);
  if (key === 'central' || key === 'veiculos' || key === 'ranking') {
    nui('taxiMenu:open', clone(menuData));
    await wait(300);
    const tab = { veiculos: 'vehicles', ranking: 'ranking' }[key];
    if (tab) document.querySelector(`.nav-item[data-tab="${tab}"]`)?.click();
    return;
  }
  if (key === 'disponivel') return hud('AVAILABLE');
  if (key === 'oferta') return hud('OFFER', { offer: { origin: 'Vespucci Blvd', distance: 820, estimateMin: 180, estimateMax: 260, remaining: 14000, passengers: 3 } });
  if (key === 'caminho') return hud('EN_ROUTE', { route: { origin: 'Vespucci Blvd', distance: 412 } });
  if (key === 'ocupado') return hud('HIRED', { fare: 214.5, distance: 2400, passenger: { mood: 'happy', fear: { level: 'calm' } } });
  if (key === 'resultado') return hud('COMPLETING', { result: { fare: 286, bonus: 42, confidence: 18, rating: 4 } });
  if (key === 'estudio') nui('studio:show', { label: '1/7 · taxi' });
};

window.parent.postMessage({ devReady: true }, '*');
