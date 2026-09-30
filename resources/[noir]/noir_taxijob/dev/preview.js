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

// ── Catálogo do editor, montado do config.lua: o que o server/catalog.lua faria ──
const REGIONS = [{ key: 'downtown', label: 'Los Santos' }, { key: 'sandy shores', label: 'Sandy Shores' }, { key: 'paleto bay', label: 'Paleto Bay' }];
const editorCatalog = (() => {
  const points = [];
  let id = 0;
  for (const region of ['downtown', 'paleto bay', 'sandy shores']) {
    const block = configText.split(`['${region}'] = {`)[1].split('},')[0];
    for (const [, x, y, z, w] of block.matchAll(/vec4\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)/g)) {
      points.push({ id: ++id, region, x: +x, y: +y, z: +z, w: +w, enabled: id % 17 !== 0 });
    }
  }
  return {
    regions: REGIONS,
    classes: ['executive', 'limousine', 'luxury', 'standard', 'suv', 'van'].map((key) => ({ key, label: key })),
    points,
    vehicles: vehicles.map((v, i) => ({ id: v.id, model: v.model, label: v.label, class: ['standard', 'standard', 'executive', 'van', 'suv', 'luxury', 'limousine'][i], requiredLevel: v.requiredLevel, rentalFee: 0, image: (imageByModel[v.model] || ''), description: v.description, enabled: true, appearance: v.model === 'taxi' ? { props: { color1: 89, color2: 89 } } : null })),
    levels: [[0, 'Iniciante'], [150, 'Motorista'], [600, 'Profissional'], [2000, 'Especialista'], [5000, 'Veterano'], [10000, 'Elite']].map(([min, label], i) => ({ level: i + 1, min, label })),
    depot: { ped: { x: 894.9, y: -179.17, z: 74.7, w: 242.89 }, pedModel: 'a_m_m_eastsa_02', interactDistance: 15, returnRadius: 30, spawnPoints: [{ x: 906.53, y: -185.91, z: 74.01, w: 60.35 }, { x: 908.81, y: -183.34, z: 74.21, w: 61 }], blip: { sprite: 198, color: 46, scale: 0.7, label: 'Central de Táxi' } },
    settings: {
      meter: { StartingFare: 15, PricePerKm: 12, MaxFare: 600 },
      dispatch: { OfferTimeout: 10000, MinDelay: 10000, MaxDelay: 30000, MinPickupDistance: 300, IdealPickupDistance: 1800, MaxPickupDistance: 3000, MinTripDistance: 400, MaxTripDistance: 4000 },
      payout: { SatisfiedTipPercent: 10, NeutralMultiplier: 0.85, UnhappyMultiplier: 0.7, CalmBonusPercent: 35 },
    },
  };
})();

const editorApi = {
  data: () => ({ ok: true }),
  savePoint: (id, p) => {
    if (id) Object.assign(editorCatalog.points.find((x) => x.id === id), p);
    else { id = Math.max(...editorCatalog.points.map((x) => x.id)) + 1; editorCatalog.points.push({ id, ...p }); }
    return { ok: true, id };
  },
  deletePoint: (id) => { editorCatalog.points = editorCatalog.points.filter((x) => x.id !== id); return { ok: true }; },
  saveVehicle: (isNew, v) => {
    if (isNew) editorCatalog.vehicles.push(v); else Object.assign(editorCatalog.vehicles.find((x) => x.id === v.id), v);
    return { ok: true, id: v.id };
  },
  deleteVehicle: (id) => { editorCatalog.vehicles = editorCatalog.vehicles.filter((x) => x.id !== id); return { ok: true }; },
  moveVehicle: (id, delta) => {
    const list = editorCatalog.vehicles; const i = list.findIndex((x) => x.id === id); const j = i + delta;
    if (j >= 0 && j < list.length) [list[i], list[j]] = [list[j], list[i]];
    return { ok: true };
  },
  saveLevels: (levels) => { editorCatalog.levels = levels.map((l, i) => ({ level: i + 1, ...l })); return { ok: true }; },
  saveDepot: (depot) => { editorCatalog.depot = depot; return { ok: true }; },
  saveSettings: (settings) => { editorCatalog.settings = settings; return { ok: true }; },
};
const MAP = { tiles: '/territory-tiles/{z}/{x}/{y}.png', maxZoom: 7, maxNativeZoom: 4, maxResolution: 0.25, centerLat: -5525, centerLng: 3755, offset: 0.66 };

const realFetch = window.fetch.bind(window);
window.fetch = async (url, opts) => {
  const match = String(url).match(/^https:\/\/noir_taxijob\/([\w:]+)/);
  if (!match) return realFetch(url, opts);
  const name = match[1];
  const body = opts && opts.body ? JSON.parse(opts.body) : {};
  const json = (value) => new Response(JSON.stringify(value), { headers: { 'Content-Type': 'application/json' } });
  switch (name) {
    case 'requestRanking': return json({ ok: true, data: ranking });
    case 'editor:request': {
      const handler = editorApi[body.method];
      const result = handler ? handler(...(body.args || [])) : { ok: false, code: 'invalid_payload' };
      if (body.method !== 'data') toast(`${body.method} → ${result.ok ? 'ok' : result.code}`);
      return json(result.ok ? { ...result, catalog: clone(editorCatalog) } : result);
    }
    case 'editor:mode': {
      nui('editor', { hidden: true });
      toast(`modo ${body.mode}: no jogo a tela some; aqui volta em 1,2 s`);
      const value = { x: 412.3, y: 130.8, z: 101.4, w: 205.5 };
      setTimeout(() => nui('editor', { hidden: false, result: { kind: body.mode, value } }), 1200);
      return json({ ok: true });
    }
    case 'editor:position': return json({ x: 410.1, y: 128.4, z: 101.2, w: 200.0 });
    case 'editor:show': return json({ ok: true, world: body.world ?? true, always: body.always ?? false });
    case 'editor:checkModel': return json(/^[a-z0-9_]+$/.test(body.model) ? { ok: true, seats: 3 } : { ok: false, code: 'invalid_model' });
    case 'editor:copyVisual': toast('visual copiado do carro'); return json({ ok: true, props: { color1: 88, color2: 88, extras: { 5: 0, 7: 1 } } });
    case 'editor:teleport': toast(`ir até ${body.kind} ${body.id || ''}`); return json({ ok: true });
    case 'editor:close': toast('editor fechado'); return json({ ok: true });
    case 'editor:openMap':
      nui('taxiMap', { visible: true, catalog: clone(editorCatalog), map: MAP, player: { x: 410, y: 128 } });
      return json({ ok: true });
    case 'map:close': return json({ ok: true });
    case 'rentVehicle': toast(`rentVehicle ${body.vehicleId}`); return json({ ok: true });
    case 'closeMenu': toast('central fechada'); nui('taxiMenu:close'); return json({ ok: true });
    default: return json({ ok: true });
  }
};

// ── Monta a NUI real ──
const html = await (await fetch('/html/index.html')).text();
const doc = new DOMParser().parseFromString(html, 'text/html');
[...doc.body.children].filter((node) => node.tagName !== 'SCRIPT').forEach((node) => document.body.insertBefore(node, toastEl));
for (const src of ['/html/vendor/leaflet.js', '/html/app.js', '/html/editor.js', '/html/map.js']) {
  await new Promise((resolve) => {
    const script = document.createElement('script');
    script.src = src;
    script.onload = resolve;
    document.body.appendChild(script);
  });
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const keys = { fan: 'G', accept: 'E', pause: 'J' };
const hud = (state, data = {}) => {
  nui('taxi:setVisible', true);
  nui('taxi:setState', { state, data: { keys, temperature: 22, fan: 2, mode: 'heat', outside: 15, fare: 0, distance: 0, ...data } });
};

function reset() {
  nui('taxiMenu:close');
  nui('taxi:setVisible', false);
  nui('studio:hide');
  nui('editor', { visible: false });
  nui('taxiMap', { visible: false });
}

async function click(depth, key) {
  await wait(60);
  const node = document.querySelector(`.ed-menu[data-depth="${depth}"] .ed-item[data-key="${key}"]`);
  if (node) node.click();
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
  editor: 'Editor',
  ponto: 'Editor · ponto',
  carro: 'Editor · carro',
  central2: 'Editor · Central',
  ajustes: 'Editor · ajustes',
  mapa: 'Editor · mapa',
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
  if (key === 'estudio') return nui('studio:show', { label: '1/7 · taxi' });
  nui('editor', { visible: true, catalog: clone(editorCatalog), show: { world: true, always: false } });
  if (key === 'ponto') { await click(0, 'points'); await click(1, 'r-downtown'); await click(2, 'p-3'); }
  if (key === 'carro') { await click(0, 'vehicles'); await click(1, 'v-standard'); }
  if (key === 'central2') await click(0, 'depot');
  if (key === 'ajustes') { await click(0, 'settings'); await click(1, 'dispatch'); }
  if (key === 'mapa') await click(0, 'map');
};

window.parent.postMessage({ devReady: true }, '*');
