// Preview no navegador: monta o html/ui.html real e faz o papel do client.lua.

window.GetParentResourceName = () => 'noir_shops';

// nui:// não existe no navegador: aponta para o vite.
const mapNui = (url) => String(url)
  .replace('nui://ox_inventory/web/images/', '/ox-images/')
  .replace('nui://noir_shops/', '/');
const srcDesc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
Object.defineProperty(HTMLImageElement.prototype, 'src', {
  get() { return srcDesc.get.call(this); },
  set(v) { srcDesc.set.call(this, mapNui(v)); },
});

const toastEl = document.getElementById('dev-toast');
let toastTimer;
function toast(msg) {
  toastEl.textContent = msg;
  toastEl.style.display = 'block';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toastEl.style.display = 'none'), 3500);
}

// Callbacks da NUI (RegisterNUICallback no client.lua).
const realFetch = window.fetch.bind(window);
window.fetch = async (url, opts) => {
  const m = String(url).match(/^https:\/\/noir_shops\/(\w+)/);
  if (!m) return realFetch(url, opts);
  const body = opts && opts.body ? JSON.parse(opts.body) : {};
  const json = (v) => new Response(JSON.stringify(v), { headers: { 'Content-Type': 'application/json' } });
  if (m[1] === 'adminGetPlayerCoords') return json({ x: 25.71, y: -1345.02, z: 29.5 });
  if (m[1] === 'adminGetPlayerHeading') return json({ heading: 271.6 });
  if (m[1] === 'adminPlacePed') {
    // No jogo o painel some enquanto o admin mira; aqui volta depois de 1,5 s com uma posição.
    window.postMessage({ action: 'adminPlacement', hidden: true }, '*');
    toast(`posicionando ${body.model}…`);
    setTimeout(() => window.postMessage({ action: 'adminPlacement', hidden: false, result: { x: 26.12, y: -1345.87, z: 28.52, w: 268 } }, '*'), 1500);
    return json(true);
  }
  if (m[1].startsWith('admin')) toast(`${m[1]} · ${JSON.stringify(body).slice(0, 160)}`);
  if (m[1] === 'checkoutCart') {
    const total = body.cart.reduce((s, it) => s + it.price * it.qty, 0);
    toast(`checkoutCart · ${body.paymentType} · ${body.cart.map((i) => `${i.qty}x ${i.name}`).join(', ')} · $${total}`);
  } else if (m[1] === 'closeUI') {
    toast('closeUI');
  }
  return new Response('"ok"', { headers: { 'Content-Type': 'application/json' } });
};

// Lê a config e o locale reais, para o preview seguir o que vai pro jogo.
function parseCatalog(lua) {
  const block = lua.slice(lua.indexOf('local Catalog = {'), lua.indexOf('local Kinds = {'));
  const catalog = {};
  let kind = null;
  for (const line of block.split('\n')) {
    const k = line.match(/^\s{4}(\w+) = \{/);
    if (k) { kind = k[1]; catalog[kind] = []; continue; }
    if (!kind || !line.includes("name = '")) continue;
    const str = (key) => (line.match(new RegExp(`${key} = '([^']*)'`)) || [])[1];
    const num = (key) => Number((line.match(new RegExp(`${key} = (\\d+)`)) || [])[1]);
    catalog[kind].push({
      name: str('name'), label: str('label'), price: num('price'), image: str('image'),
      maxQty: num('maxQty'), category: str('category'), license: str('license'),
    });
  }
  const names = {};
  for (const m of lua.matchAll(/^\s{4}(\w+)\s+= \{ name = '([^']+)'/gm)) names[m[1]] = m[2];
  return { catalog, names };
}

function parseLocale(lua) {
  const out = {};
  for (const m of lua.matchAll(/\['(\w+)'\]\s*=\s*'((?:[^'\\]|\\.)*)'/g)) out[m[1]] = m[2];
  return out;
}

const [configLua, localeLua, uiHtml] = await Promise.all([
  realFetch('/config.lua').then((r) => r.text()),
  realFetch('/locales/pt.lua').then((r) => r.text()),
  realFetch('/html/ui.html').then((r) => r.text()),
]);
const { catalog, names } = parseCatalog(configLua);
const locales = parseLocale(localeLua);

// Corpo do ui.html antes do script.js, que pega os elementos no carregamento.
const doc = new DOMParser().parseFromString(uiHtml, 'text/html');
doc.querySelectorAll('script').forEach((s) => s.remove());
document.getElementById('nui').innerHTML = doc.body.innerHTML;
const loadScript = (src) => new Promise((resolve, reject) => {
  const s = document.createElement('script');
  s.src = src;
  s.onload = resolve;
  s.onerror = reject;
  document.body.appendChild(s);
});
await loadScript('/html/js/ped_models.js');
await loadScript('/html/js/script.js');

const scenarios = {
  general:     { label: '24/7', kind: 'general' },
  liquor:      { label: 'Bebidas', kind: 'liquor' },
  hardware:    { label: 'Ferramentas', kind: 'hardware' },
  ammuPorte:   { label: 'Ammu-Nation (com porte)', kind: 'ammunation', licensed: true },
  ammuSemPorte:{ label: 'Ammu-Nation (sem porte)', kind: 'ammunation', licensed: false },
  dez:         { label: '10 itens', kind: 'dez' },
  admin:       { label: 'Admin', admin: true },
};

// Lojas da config.lua no formato que o server manda para o admin (SerializeShop).
function parseShops(lua) {
  const kinds = {};
  for (const m of lua.matchAll(/^\s{4}(\w+)\s+= \{ name = '([^']+)',\s+ped = '([^']+)',\s+scenario = '([^']+)',\s+blip = (\d+),\s+label = '([^']+)'/gm)) {
    kinds[m[1]] = { name: m[2], ped: m[3], scenario: m[4], blip: Number(m[5]), label: m[6] };
  }
  const shops = {};
  for (const m of lua.matchAll(/\['(\w+)'\]\s+= Shop\('(\w+)', vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\), ([-\d.]+)\)/g)) {
    const k = kinds[m[2]];
    shops[m[1]] = {
      name: k.name, coords: { x: +m[3], y: +m[4], z: +m[5] }, PedModel: k.ped, PedHeading: +m[6], PedScenario: k.scenario,
      Blipname: k.label, BlipSprite: k.blip, BlipColor: 69, items: catalog[m[2]].map((it) => ({ ...it })), _isConfig: true,
    };
  }
  return shops;
}

async function openAdmin() {
  const shops = parseShops(configLua);
  // Casos que a config não tem: loja alterada no jogo, loja criada no jogo com restrição.
  shops['247_davis']._override = true;
  shops['gang_ballas'] = {
    name: 'Fornecedor dos Ballas', coords: { x: 85.1, y: -1959.4, z: 20.1 }, Restriction: ['ballas'],
    items: catalog.hardware.map((it) => ({ ...it })), _dynamic: true,
  };
  const images = await realFetch('/ox-images-list').then((r) => r.json());
  window.postMessage({
    action: 'openAdmin', shops, images,
    jobs: [
      { name: 'police', label: 'Polícia' }, { name: 'ambulance', label: 'Hospital' },
      { name: 'mechanic', label: 'Mecânico' }, { name: 'ballas', label: 'Ballas' }, { name: 'vagos', label: 'Vagos' },
    ],
    items: [...new Set(Object.values(catalog).flat().map((i) => i.name))].map((name) => ({ name, label: Object.values(catalog).flat().find((i) => i.name === name).label })),
    imagePathMap: Object.fromEntries(images.map((f) => [f, `/ox-images/${f}`])),
    licenses: { weaponlicense: { label: 'Porte de Arma' } },
    locales, theme: 'default',
  }, '*');
}

// Só do preview: catálogo cheio para ver a grade com rolagem e várias categorias.
const item = (name, label, price, category) => ({ name, label, price, image: `${name}.png`, maxQty: 20, category });
catalog.dez = [
  item('burger', 'Burger', 10, 'Comida'),
  item('sandwich', 'Sanduíche', 12, 'Comida'),
  item('tosti', 'Tosti', 8, 'Comida'),
  item('twerks_candy', 'Twerks', 5, 'Comida'),
  item('water', 'Água', 10, 'Bebida'),
  item('sprunk', 'Sprunk', 10, 'Bebida'),
  item('kurkakola', 'Kurkakola', 10, 'Bebida'),
  item('coffee', 'Café', 7, 'Bebida'),
  item('bandage', 'Bandagem', 50, 'Utilidades'),
  item('radio', 'Rádio', 250, 'Utilidades'),
];
names.dez = 'Loja de Conveniência';

// A barra de cenários fica na página de fora (index.html), que chama estas duas.
window.devScenarios = Object.fromEntries(Object.entries(scenarios).map(([k, v]) => [k, v.label]));
window.devOpen = function open(key) {
  const sc = scenarios[key] || scenarios.general;
  document.getElementById('admin-app').style.display = 'none';
  document.getElementById('app').style.display = 'none';
  if (sc.admin) return openAdmin();
  // client.lua esconde item com licença que o jogador não tem.
  const items = catalog[sc.kind].filter((it) => !it.license || sc.licensed);
  window.postMessage({
    action: 'openShop', shopName: names[sc.kind] || sc.label, items,
    dynamicPricing: false, locales, theme: 'default',
  }, '*');
};
window.parent.postMessage({ devReady: true }, '*');
