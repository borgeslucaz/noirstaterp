// Preview no navegador: monta o html/index.html real e faz o papel do client (Lua).
// Dados: dev/mock.json, gerado do data/seed.lua (`lua5.4 dev/mock.lua > dev/mock.json`).

window.GetParentResourceName = () => 'noir_busjob';

const toastEl = document.getElementById('dev-toast');
let toastTimer;
function toast(message) {
  toastEl.textContent = message;
  toastEl.style.display = 'block';
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toastEl.style.display = 'none'), 3200);
}

const mock = await (await fetch('/dev/mock.json')).json();
const catalog = mock.catalog;
const nui = (action, data) => window.postMessage({ action, data }, '*');
const clone = (value) => JSON.parse(JSON.stringify(value));

// ── Catálogo em memória: o que o servidor faria, sem as validações finas ──
function adminView() {
  const usage = {};
  catalog.routes.forEach((route) => route.stops.forEach((id) => { (usage[id] = usage[id] || []).push(route.code); }));
  catalog.stops.forEach((stop) => { stop.usedBy = [...new Set(usage[stop.id] || [])].sort(); });
  return clone(catalog);
}

const editorApi = {
  data: () => ({ ok: true, catalog: adminView() }),
  saveStop: (id, stop) => {
    if (!stop.name || !stop.dock) return { ok: false, code: !stop.name ? 'invalid_name' : 'invalid_dock' };
    if (id) Object.assign(catalog.stops.find((s) => s.id === id), stop);
    else { id = Math.max(...catalog.stops.map((s) => s.id)) + 1; catalog.stops.push({ id, usedBy: [], ...stop }); }
    return { ok: true, id, catalog: adminView() };
  },
  deleteStop: (id) => {
    const usedBy = catalog.routes.filter((r) => r.stops.includes(id)).map((r) => r.code);
    if (usedBy.length) return { ok: false, code: 'stop_in_use', usedBy };
    catalog.stops = catalog.stops.filter((s) => s.id !== id);
    return { ok: true, catalog: adminView() };
  },
  saveRoute: (id, route) => {
    if (route.stops.length < 2) return { ok: false, code: 'invalid_stops' };
    if (!route.vehicles.length) return { ok: false, code: 'invalid_vehicles' };
    const saved = { ...route, code: String(route.code).toUpperCase(), usable: true, distance: 4200, expected: 700 };
    if (id) Object.assign(catalog.routes.find((r) => r.id === id), saved);
    else { id = saved.code.toLowerCase(); catalog.routes.push({ id, ...saved }); }
    return { ok: true, id, catalog: adminView() };
  },
  deleteRoute: (id) => { catalog.routes = catalog.routes.filter((r) => r.id !== id); return { ok: true, catalog: adminView() }; },
  saveVehicle: (isNew, vehicle) => {
    if (isNew) catalog.vehicles.push(vehicle); else Object.assign(catalog.vehicles.find((v) => v.model === vehicle.model), vehicle);
    return { ok: true, id: vehicle.model, catalog: adminView() };
  },
  deleteVehicle: (model) => {
    const usedBy = catalog.routes.filter((r) => r.vehicles.includes(model)).map((r) => r.code);
    if (usedBy.length) return { ok: false, code: 'vehicle_in_use', usedBy };
    catalog.vehicles = catalog.vehicles.filter((v) => v.model !== model);
    return { ok: true, catalog: adminView() };
  },
  saveLevels: (levels) => { catalog.levels = levels.map((l, i) => ({ level: i + 1, ...l })); return { ok: true, catalog: adminView() }; },
  saveSettings: (settings) => { Object.assign(catalog.settings, settings); return { ok: true, catalog: adminView() }; },
};

// Resultado de cada modo no mundo: no jogo o painel some enquanto o admin mira ou dirige.
const modeResults = {
  dock: { x: 302.4, y: -760.2, z: 29.3, w: 256.8 },
  zone: { x: 306.0, y: -766.1, z: 29.8, length: 8.0, width: 2.5, height: 3.0, rotation: 256.8 },
  depotPed: { x: 449.4, y: -658.1, z: 28.5, w: 239.5 },
  depotSpawn: { x: 471.0, y: -583.9, z: 28.5, w: 175.5 },
};

let showState = { world: true, always: false };
const MAP = { tiles: '/territory-tiles/{z}/{x}/{y}.png', maxZoom: 7, maxNativeZoom: 4, maxResolution: 0.25, centerLat: -5525, centerLng: 3755, offset: 0.66 };
function openMap(fromEditor) {
  const view = adminView();
  nui('busMap', { visible: true, data: { stops: view.stops, routes: view.routes, depot: view.settings.depot }, map: MAP, player: { x: 300, y: -770 }, fromEditor });
}

const realFetch = window.fetch.bind(window);
window.fetch = async (url, opts) => {
  const match = String(url).match(/^https:\/\/noir_busjob\/([\w:]+)/);
  if (!match) return realFetch(url, opts);
  const name = match[1];
  const body = opts && opts.body ? JSON.parse(opts.body) : {};
  const json = (value) => new Response(JSON.stringify(value), { headers: { 'Content-Type': 'application/json' } });

  switch (name) {
    case 'editor:request': {
      const handler = editorApi[body.method];
      const result = handler ? handler(...(body.args || [])) : { ok: false, code: 'invalid_payload' };
      if (body.method !== 'data') toast(`${body.method} → ${result.ok ? 'ok' : result.code}`);
      return json(result);
    }
    case 'editor:mode':
      nui('editor', { hidden: true });
      toast(`modo ${body.mode}: no jogo a tela some; aqui volta em 1,2 s`);
      setTimeout(() => nui('editor', { hidden: false, result: { kind: body.mode, value: modeResults[body.mode] } }), 1200);
      return json({ ok: true });
    case 'editor:position': return json({ x: 312.5, y: -770.4, z: 29.3, w: 256.0 });
    case 'editor:zoneCenter': toast(`centro na ${body.source === 'aim' ? 'mira' : 'posição'}`); return json({ ok: true, x: 121.9, y: -783.6, z: 31.3, heading: 155.0 });
    case 'editor:show': showState = { world: body.world ?? showState.world, always: body.always ?? showState.always }; return json({ ok: true, ...showState });
    case 'editor:testPassengers': toast(`${body.count} passageiros de teste`); return json({ ok: true, count: body.count });
    case 'editor:checkModel': return json(/^[a-z0-9_]+$/.test(body.model) ? { ok: true, seats: 15 } : { ok: false, code: 'invalid_model' });
    case 'editor:showRoute': toast(`${body.stops.length} blips no mapa`); return json({ ok: true, count: body.stops.length });
    case 'editor:teleport': toast(`ir até ${body.kind} ${body.id || ''}`); return json({ ok: true });
    case 'editor:close': toast('editor fechado'); return json({ ok: true });
    case 'editor:openMap':
      openMap(true);
      return json({ ok: true });
    case 'map:close': toast('mapa fechado'); return json({ ok: true });
    case 'startRoute': toast(`startRoute ${body.routeId} · ${body.vehicle}`); return json({ ok: true });
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
async function click(depth, key) {
  await wait(60);
  const node = document.querySelector(`.ed-menu[data-depth="${depth}"] .ed-item[data-key="${key}"]`);
  if (node) node.click();
}

function reset() {
  nui('busMenu:close', { immediate: true });
  nui('editor', { visible: false });
  nui('bus:setRouteHud', { visible: false });
  nui('busMap', { visible: false });
}

window.devScenarios = {
  central: 'Central',
  linhas: 'Central · linhas',
  hud: 'HUD da linha',
  editor: 'Editor',
  parada: 'Editor · parada',
  area: 'Editor · área',
  areaNova: 'Editor · área nova',
  linha: 'Editor · linha',
  ajustes: 'Editor · ajustes',
  mapa: 'Mapa',
  mapaLinha: 'Mapa · linha',
};

window.devOpen = async (key) => {
  reset();
  await wait(80);
  if (key === 'central' || key === 'linhas') {
    nui('busMenu:open', clone(mock.menu));
    if (key === 'linhas') { await wait(300); document.getElementById('nav-routes').click(); await wait(80); document.querySelector('.route-card[data-route="airport"]')?.click(); }
    return;
  }
  if (key === 'mapa' || key === 'mapaLinha') {
    openMap(false);
    if (key === 'mapaLinha') { await wait(400); document.querySelector('.bm__item[data-key="airport"]')?.click(); }
    return;
  }
  if (key === 'hud') {
    nui('bus:setRouteHud', { visible: true, routeCode: 'A07', routeName: 'Linha A07 · Aeroporto', stopName: 'LSIA · Air Emu', stopIndex: 4, stopCount: 7, distance: 212, passengers: 6, capacity: 11 });
    return;
  }
  nui('editor', { visible: true, catalog: adminView() });
  if (key === 'parada' || key === 'area') { await click(0, 'stops'); await click(1, 'stop-3'); }
  if (key === 'area') await click(2, 'zone');
  if (key === 'areaNova') { await click(0, 'stops'); await click(1, 'stop-5'); await click(2, 'zone'); }
  if (key === 'linha') { await click(0, 'routes'); await click(1, 'route-airport'); }
  if (key === 'ajustes') { await click(0, 'settings'); await click(1, 'payout'); }
};

window.parent.postMessage({ devReady: true }, '*');
