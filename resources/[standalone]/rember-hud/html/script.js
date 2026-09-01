// Rember HUD — component renderer / white-label kit with a drag-to-place editor.
// Lua sends {action:"config", components, theme, scale, layout} once, then
// {action:"update", values} every tick. Each gauge is absolutely positioned and
// can be dragged anywhere in edit mode ({action:"edit", on}); the layout is
// saved per-player (KVP in-game, localStorage in the browser preview).

const SVGNS = 'http://www.w3.org/2000/svg';
const RING_R = 25, RING_C = 2 * Math.PI * RING_R, RING_CX = 29, RING_CY = 29;

const hud = document.getElementById('hud');
const hint = document.getElementById('edit-hint');
const CFX_PREFIX = 'cfx-nui-';
const RESOURCE = location.hostname.startsWith(CFX_PREFIX) ? location.hostname.slice(CFX_PREFIX.length) : 'rember-hud';
const DEV = !location.hostname.startsWith(CFX_PREFIX);

let comps = [];
let speedUnit = 'mph';
let layout = {};          // componentId -> { x, y } in viewport %
let editing = false;
let dragging = null;

const clampFrac = (v, max) => Math.max(0, Math.min(1, (v || 0) / (max || 100)));
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));

// ring geometry (angle = degrees clockwise from 12 o'clock)
function ptOnRing(deg) { const a = (deg * Math.PI) / 180; return { x: RING_CX + RING_R * Math.sin(a), y: RING_CY - RING_R * Math.cos(a) }; }
function segArc(start, size) { const a = ptOnRing(start), b = ptOnRing(start + size); return `M ${a.x.toFixed(2)} ${a.y.toFixed(2)} A ${RING_R} ${RING_R} 0 ${size > 180 ? 1 : 0} 1 ${b.x.toFixed(2)} ${b.y.toFixed(2)}`; }
const svgEl = (name, attrs) => { const e = document.createElementNS(SVGNS, name); for (const k in attrs) e.setAttribute(k, attrs[k]); return e; };

function persist(name, body) { if (!DEV) fetch(`https://${RESOURCE}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) }).catch(() => {}); }

// ---- theme + build -------------------------------------------------------
function applyTheme(theme = {}, scale) {
  const root = document.documentElement.style;
  if (theme.accent) root.setProperty('--accent', theme.accent);
  if (theme.panelAlpha != null) root.setProperty('--panel-alpha', String(theme.panelAlpha));
  if (scale) root.setProperty('--scale', String(scale));
}

// Default placement when a gauge has no saved/config position: a row near the
// bottom-left. Users drag from here to wherever they want.
function autoPos(i) { return { x: 6 + i * 8, y: 90 }; }

function placeAll() {
  comps.forEach((c, i) => {
    const p = layout[c.id] || c.def.pos || autoPos(i);
    c.el.style.left = `${p.x}%`;
    c.el.style.top = `${p.y}%`;
  });
}

function build(config) {
  applyTheme(config.theme, config.scale);
  speedUnit = config.speedUnit || 'mph';
  layout = config.layout || (DEV ? loadDevLayout() : {});
  hud.innerHTML = '';
  hud.className = 'hud';
  comps = (config.components || [])
    .filter((c) => c.enabled !== false)
    .sort((a, b) => (a.order || 0) - (b.order || 0))
    .map((def, i) => { const c = makeComponent(def); c.id = `${def.key}-${def.order ?? i}`; return c; });
  placeAll();
}

const BUILDERS = { radial: makeRadial, segment: makeSegment, bar: makeBar, vbar: makeVbar, pill: makePill, text: makeText };
function makeComponent(def) { return (BUILDERS[def.style] || makeBar)(def); }

function makeRadial(def) {
  const el = document.createElement('div'); el.className = 'comp comp-radial';
  const svg = svgEl('svg', { viewBox: '0 0 58 58' });
  svg.append(svgEl('circle', { class: 'track', cx: RING_CX, cy: RING_CY, r: RING_R }));
  const value = svgEl('circle', { class: 'value', cx: RING_CX, cy: RING_CY, r: RING_R, stroke: def.color });
  value.style.strokeDasharray = String(RING_C); value.style.strokeDashoffset = String(RING_C);
  svg.append(value);
  const icon = document.createElement('div'); icon.className = 'icon'; icon.textContent = def.icon || '';
  el.append(svg, icon); hud.appendChild(el);
  return { def, el, refs: { value } };
}
function makeSegment(def) {
  const n = def.segments || 10, gap = 6, span = 360 / n;
  const el = document.createElement('div'); el.className = 'comp comp-segment';
  const svg = svgEl('svg', { viewBox: '0 0 58 58' }); const segs = [];
  for (let i = 0; i < n; i++) { const p = svgEl('path', { class: 'seg', d: segArc(i * span + gap / 2, span - gap), stroke: 'rgba(255,255,255,0.16)' }); svg.appendChild(p); segs.push(p); }
  const icon = document.createElement('div'); icon.className = 'icon'; icon.textContent = def.icon || '';
  el.append(svg, icon); hud.appendChild(el);
  return { def, el, refs: { segs, n } };
}
function makeBar(def) {
  const el = document.createElement('div'); el.className = 'comp comp-bar';
  el.innerHTML = `<div class="bar-top"><span class="icon">${def.icon || ''}</span><span class="num">0</span></div><div class="bar-track"><div class="bar-fill"></div></div>`;
  el.querySelector('.bar-fill').style.background = def.color; hud.appendChild(el);
  return { def, el, refs: { fill: el.querySelector('.bar-fill'), num: el.querySelector('.num') } };
}
function makeVbar(def) {
  const el = document.createElement('div'); el.className = 'comp comp-vbar';
  el.innerHTML = `<div class="vbar-track"><div class="vbar-fill"></div></div><span class="icon">${def.icon || ''}</span>`;
  el.querySelector('.vbar-fill').style.background = def.color; hud.appendChild(el);
  return { def, el, refs: { fill: el.querySelector('.vbar-fill') } };
}
function makePill(def) {
  const el = document.createElement('div'); el.className = 'comp comp-pill';
  el.innerHTML = `<span class="dot"></span><span class="icon">${def.icon || ''}</span><span class="num">0</span>`;
  el.querySelector('.dot').style.background = def.color; hud.appendChild(el);
  return { def, el, refs: { num: el.querySelector('.num') } };
}
function makeText(def) {
  const el = document.createElement('div'); el.className = 'comp comp-text';
  el.innerHTML = `<div class="num" style="color:${def.color}">0</div><div class="unit"></div>`; hud.appendChild(el);
  return { def, el, refs: { num: el.querySelector('.num'), unit: el.querySelector('.unit') } };
}

// ---- update --------------------------------------------------------------
function update(values) {
  for (const c of comps) {
    const { def, el, refs } = c;
    const v = values[def.key] ?? 0;
    let hide = false;
    if (!editing) {   // in edit mode, show everything so it can be placed
      if (def.vehicleOnly && !values.inVehicle) hide = true;
      if (def.hideAtFull && v >= (def.max || 100)) hide = true;
      if (def.hideAtZero && v <= 0) hide = true;
    }
    el.classList.toggle('comp-hidden', hide);
    if (hide) continue;
    const frac = clampFrac(v, def.max);
    switch (def.style) {
      case 'radial': refs.value.style.strokeDashoffset = String(RING_C * (1 - frac)); break;
      case 'segment': { const lit = Math.round(frac * refs.n); refs.segs.forEach((p, i) => p.setAttribute('stroke', i < lit ? def.color : 'rgba(255,255,255,0.16)')); break; }
      case 'bar': refs.fill.style.width = `${frac * 100}%`; refs.num.textContent = Math.round(v); break;
      case 'vbar': refs.fill.style.height = `${frac * 100}%`; break;
      case 'pill': refs.num.textContent = Math.round(v); break;
      default: refs.num.textContent = Math.round(v); refs.unit.textContent = speedUnit;
    }
  }
}

// ---- edit mode + drag ----------------------------------------------------
function setEdit(on) {
  editing = on;
  hud.classList.toggle('editing', on);
  hint.classList.toggle('hidden', !on);
  if (on) comps.forEach((c) => c.el.classList.remove('comp-hidden'));
  else saveLayout();
}
function saveLayout() {
  if (DEV) { try { localStorage.setItem('rember-hud-layout', JSON.stringify(layout)); } catch {} }
  else persist('saveLayout', { layout });
}
function loadDevLayout() { try { return JSON.parse(localStorage.getItem('rember-hud-layout')) || {}; } catch { return {}; } }
function resetLayout() {
  layout = {};
  placeAll();
  if (DEV) { try { localStorage.removeItem('rember-hud-layout'); } catch {} }
  else persist('resetLayout', {});
}

hud.addEventListener('mousedown', (e) => {
  if (!editing) return;
  const el = e.target.closest('.comp');
  if (!el) return;
  dragging = comps.find((c) => c.el === el) || null;
  e.preventDefault();
});
window.addEventListener('mousemove', (e) => {
  if (!editing || !dragging) return;
  const x = clamp((e.clientX / window.innerWidth) * 100, 3, 97);
  const y = clamp((e.clientY / window.innerHeight) * 100, 5, 95);
  layout[dragging.id] = { x, y };
  dragging.el.style.left = `${x}%`;
  dragging.el.style.top = `${y}%`;
});
window.addEventListener('mouseup', () => { dragging = null; });
window.addEventListener('keydown', (e) => { if (editing && e.code === 'Escape') { setEdit(false); persist('editClosed', {}); } });

// ---- message channel -----------------------------------------------------
window.addEventListener('message', (e) => {
  const d = e.data || {};
  if (d.action === 'config') build(d);
  else if (d.action === 'update') update(d.values || {});
  else if (d.action === 'visible') hud.classList.toggle('hud-hidden', !d.visible);
  else if (d.action === 'edit') setEdit(!!d.on);
  else if (d.action === 'resetLayout') resetLayout();
});

// ---- dev showcase --------------------------------------------------------
if (DEV) {
  document.documentElement.style.background = 'radial-gradient(1100px 650px at 30% 70%, #241c15, #100c09)';
  document.getElementById('devbar').classList.remove('hidden');
  build({
    position: 'bottom-left', speedUnit: 'mph', theme: { accent: '#c8702f', panelAlpha: 0.55 }, scale: 1.1,
    components: [
      { key: 'health',  style: 'radial',  icon: '❤',  color: '#e4544a', max: 100, order: 1 },
      { key: 'armor',   style: 'radial',  icon: '🛡',  color: '#4f83cc', max: 100, order: 2 },
      { key: 'hunger',  style: 'segment', icon: '🍔', color: '#e0a341', max: 100, order: 3, segments: 10 },
      { key: 'thirst',  style: 'segment', icon: '💧', color: '#3fb0e0', max: 100, order: 4, segments: 10 },
      { key: 'oxygen',  style: 'radial',  icon: '🫁', color: '#7fd0e0', max: 100, order: 5 },
      { key: 'stress',  style: 'vbar',    icon: '🧠', color: '#b072d0', max: 100, order: 6 },
      { key: 'stamina', style: 'bar',     icon: '⚡', color: '#f0c04a', max: 100, order: 7 },
      { key: 'voice',   style: 'pill',    icon: '🎤', color: '#4fd18b', max: 100, order: 8 },
      { key: 'speed',   style: 'text',    icon: '',   color: '#f4efe7', max: 220, order: 9, vehicleOnly: true },
    ],
  });
  const sim = { health: 100, armor: 65, hunger: 100, thirst: 100, oxygen: 80, stress: 40, stamina: 100, voice: 90, speed: 0, inVehicle: true };
  let t = 0;
  document.querySelectorAll('.devbar button').forEach((b) => b.addEventListener('click', () => {
    const a = b.dataset.act;
    if (a === 'edit') setEdit(!editing);
    else if (a === 'resetlayout') resetLayout();
    else if (a === 'vehicle') sim.inVehicle = !sim.inVehicle;
    else if (a === 'damage') sim.health = Math.max(0, sim.health - 20);
    else if (a === 'reset') Object.assign(sim, { health: 100, armor: 65, inVehicle: true });
  }));
  setInterval(() => {
    t += 0.1;
    sim.hunger = 60 + 40 * Math.abs(Math.sin(t * 0.3));
    sim.thirst = 45 + 45 * Math.abs(Math.cos(t * 0.22));
    sim.stamina = 30 + 70 * Math.abs(Math.sin(t * 0.8));
    sim.stress = 20 + 60 * Math.abs(Math.sin(t * 0.15));
    sim.voice = Math.sin(t * 2) > 0.4 ? 100 : 0;
    sim.speed = sim.inVehicle ? Math.min(180, sim.speed + 4) : Math.max(0, sim.speed - 12);
    update(sim);
  }, 120);
}
