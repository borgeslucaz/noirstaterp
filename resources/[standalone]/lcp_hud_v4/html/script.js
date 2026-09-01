/* =====================================================================
   lcp_hud_v4 - NUI controller
   ---------------------------------------------------------------------
   Receives state from Lua (SendNUIMessage) and pushes editor mutations
   back via fetch('https://lcp_hud_v4/...').
   ===================================================================== */

(function () {
  'use strict';

  const RESOURCE = (window.GetParentResourceName && window.GetParentResourceName()) || 'lcp_hud_v4';

  /** All HUD elements registered for editor drag/drop. */
  const ELEMENT_KEYS = ['status', 'voice', 'ammo', 'job', 'playerid'];

  /** Human-readable labels shown in the editor list. */
  const LABELS = {
    status:   'Status (Leben / Rüstung / Hunger / Durst)',
    voice:    'Sprach-Anzeige',
    ammo:     'Munition',
    job:      'Job',
    playerid: 'Spieler-ID',
  };

  /** Voice mode -> distance fallback (kept in sync with Lua side). */
  const VOICE_DISTANCES = { whisper: 1.5, normal: 7.5, shouting: 15.0 };
  const VOICE_LABELS    = { whisper: 'Flüstern', normal: 'Normal', shouting: 'Schreien' };

  // -------------------------------------------------------------------
  //  State
  // -------------------------------------------------------------------

  const state = {
    layout: null,        // { key: { x, y, scale, visible } }
    styleMode: 'circles',
    editorOpen: false,
    dragging: null,
    config: {},
  };

  // -------------------------------------------------------------------
  //  Element references (cached)
  // -------------------------------------------------------------------

  const els = {};
  for (const key of ELEMENT_KEYS) {
    els[key] = document.getElementById('el-' + key);
  }

  const editorEl    = document.getElementById('editor');
  const editorList  = document.getElementById('editor-list');
  const segButtons  = editorEl.querySelectorAll('.seg-btn');

  // -------------------------------------------------------------------
  //  Layout / positioning
  // -------------------------------------------------------------------

  function applyLayout() {
    if (!state.layout) return;
    for (const key of ELEMENT_KEYS) {
      const el = els[key];
      if (!el) continue;
      const cfg = state.layout[key];
      if (!cfg) continue;
      // x,y are 0..100 percent of viewport.
      el.style.left = cfg.x + '%';
      el.style.top  = cfg.y + '%';
      el.style.setProperty('--scale', cfg.scale ?? 1);
      el.style.transform = `translate(-50%, -50%) scale(${cfg.scale ?? 1})`;
      el.classList.toggle('is-hidden', cfg.visible === false);
    }
  }

  function applyStyle() {
    document.body.dataset.currentStyle = state.styleMode;
    segButtons.forEach(btn => btn.classList.toggle('is-active', btn.dataset.style === state.styleMode));
  }

  // -------------------------------------------------------------------
  //  Renderers
  // -------------------------------------------------------------------

  function setRingArc(selector, percent) {
    const arc = document.querySelector(selector);
    if (!arc) return;
    const v = Math.max(0, Math.min(100, percent));
    arc.style.strokeDashoffset = 100 - v;
  }

  function renderStatus(s) {
    if (typeof s.health === 'number') {
      setRingArc('.ring-arc--health', s.health);
      const txt = document.getElementById('val-health'); if (txt) txt.textContent = s.health;
      const rowVal = document.getElementById('row-health-val'); if (rowVal) rowVal.textContent = s.health;
      const rowFill = document.getElementById('row-health-fill'); if (rowFill) rowFill.style.width = s.health + '%';
    }
    if (typeof s.armor === 'number') {
      setRingArc('.ring-arc--armor', s.armor);
      const txt = document.getElementById('val-armor'); if (txt) txt.textContent = s.armor;
      const rowVal = document.getElementById('row-armor-val'); if (rowVal) rowVal.textContent = s.armor;
      const rowFill = document.getElementById('row-armor-fill'); if (rowFill) rowFill.style.width = s.armor + '%';
    }
    if (typeof s.hunger === 'number') {
      setRingArc('.ring-arc--hunger', s.hunger);
      const txt = document.getElementById('val-hunger'); if (txt) txt.textContent = s.hunger;
      const rowVal = document.getElementById('row-hunger-val'); if (rowVal) rowVal.textContent = s.hunger;
      const rowFill = document.getElementById('row-hunger-fill'); if (rowFill) rowFill.style.width = s.hunger + '%';
    }
    if (typeof s.thirst === 'number') {
      setRingArc('.ring-arc--thirst', s.thirst);
      const txt = document.getElementById('val-thirst'); if (txt) txt.textContent = s.thirst;
      const rowVal = document.getElementById('row-thirst-val'); if (rowVal) rowVal.textContent = s.thirst;
      const rowFill = document.getElementById('row-thirst-fill'); if (rowFill) rowFill.style.width = s.thirst + '%';
    }
  }

  function renderVoice(mode, distance) {
    const valid = ['whisper', 'normal', 'shouting'];
    if (!valid.includes(mode)) mode = 'normal';
    const d = (typeof distance === 'number' ? distance : VOICE_DISTANCES[mode]);
    const root = els.voice.querySelector('.voice');
    if (root) root.dataset.mode = mode;
    const modeEl = document.getElementById('voice-mode');
    const distEl = document.getElementById('voice-distance');
    if (modeEl) modeEl.textContent = VOICE_LABELS[mode];
    if (distEl) distEl.textContent = d.toFixed(1) + 'm';
  }

  function renderAmmo(data) {
    const root = document.getElementById('ammo-root');
    if (!root) return;
    if (!data || data.visible === false) {
      root.classList.add('hidden');
      return;
    }
    root.classList.remove('hidden');
    const cur = document.getElementById('ammo-current');
    const max = document.getElementById('ammo-max');
    if (cur) cur.textContent = data.current ?? 0;
    if (max) max.textContent = data.max ?? 0;
  }

  function renderJob(job) {
    const label = document.getElementById('job-label');
    const grade = document.getElementById('job-grade');
    if (!job) {
      if (label) label.textContent = '—';
      if (grade) grade.textContent = '';
      els.job.classList.add('is-empty');
      return;
    }
    els.job.classList.remove('is-empty');
    if (label) label.textContent = job.label || job.name || '—';
    if (grade) grade.textContent = job.grade || '';
  }

  function renderPlayerId(id, visible) {
    const root = els.playerid.querySelector('.pid');
    const value = document.getElementById('pid-value');
    if (value) value.textContent = (typeof id === 'number' && id > 0) ? id : '—';
    if (root) root.classList.toggle('hidden', !visible);
  }

  // -------------------------------------------------------------------
  //  Editor
  // -------------------------------------------------------------------

  function buildEditorList() {
    editorList.innerHTML = '';
    for (const key of ELEMENT_KEYS) {
      const li = document.createElement('li');
      li.className = 'editor-item';
      li.dataset.key = key;

      const cfg = state.layout?.[key] || { scale: 1, visible: true };

      li.innerHTML = `
        <div class="editor-item-name">${LABELS[key]}</div>
        <div class="editor-item-controls">
          <input type="range" min="0.5" max="1.6" step="0.05" value="${cfg.scale ?? 1}" data-action="scale" />
          <div class="tgl ${cfg.visible === false ? '' : 'is-on'}" data-action="toggle" title="Sichtbar"></div>
          <button class="btn-icon" data-action="reset" title="Zurücksetzen">↺</button>
        </div>
      `;
      editorList.appendChild(li);
    }

    editorList.addEventListener('input', onEditorInput);
    editorList.addEventListener('click', onEditorClick);
  }

  function onEditorInput(e) {
    const t = e.target;
    if (t.matches('input[type="range"][data-action="scale"]')) {
      const key = t.closest('.editor-item').dataset.key;
      const v = parseFloat(t.value);
      if (!state.layout[key]) return;
      state.layout[key].scale = v;
      applyLayout();
      scheduleSave();
    }
  }

  function onEditorClick(e) {
    const tgl = e.target.closest('[data-action="toggle"]');
    if (tgl) {
      const key = tgl.closest('.editor-item').dataset.key;
      const next = !(state.layout[key].visible !== false);
      state.layout[key].visible = next;
      tgl.classList.toggle('is-on', next);
      applyLayout();
      scheduleSave();
      return;
    }
    const reset = e.target.closest('[data-action="reset"]');
    if (reset) {
      const key = reset.closest('.editor-item').dataset.key;
      post('editor:resetElement', { key });
    }
  }

  function setEditorOpen(open) {
    state.editorOpen = !!open;
    editorEl.classList.toggle('hidden', !state.editorOpen);
    document.body.classList.toggle('editor-on', state.editorOpen);
    if (state.editorOpen) buildEditorList();
  }

  // -------------------------------------------------------------------
  //  Drag & drop
  // -------------------------------------------------------------------

  function snap(value, grid) {
    if (!grid || grid < 1) return value;
    const px = (value / 100) * (document.documentElement.clientWidth || 1);
    const snapped = Math.round(px / grid) * grid;
    return (snapped / (document.documentElement.clientWidth || 1)) * 100;
  }

  function startDrag(el, e) {
    if (!state.editorOpen) return;
    const key = el.dataset.key;
    if (!state.layout[key]) return;
    const rect = el.getBoundingClientRect();
    const vw = document.documentElement.clientWidth;
    const vh = document.documentElement.clientHeight;
    state.dragging = {
      key,
      el,
      // pointer offset relative to element top-left, kept in viewport pixels.
      offsetX: e.clientX - rect.left,
      offsetY: e.clientY - rect.top,
      width:  rect.width,
      height: rect.height,
      vw,
      vh,
      shift: e.shiftKey,
    };
    el.classList.add('is-dragging');
    e.preventDefault();
  }

  function moveDrag(e) {
    if (!state.dragging) return;
    const d = state.dragging;
    let newLeft = e.clientX - d.offsetX + d.width / 2;
    let newTop  = e.clientY - d.offsetY + d.height / 2;
    // Convert to percentage of viewport.
    let xp = (newLeft / d.vw) * 100;
    let yp = (newTop  / d.vh) * 100;
    // Snap unless shift held.
    if (!e.shiftKey && state.config?.editor?.snapToGrid !== false) {
      const g = state.config?.editor?.gridSize || 8;
      xp = snap(xp, g);
      yp = snap(yp, g);
    }
    xp = Math.max(0, Math.min(100, xp));
    yp = Math.max(0, Math.min(100, yp));
    state.layout[d.key].x = xp;
    state.layout[d.key].y = yp;
    applyLayout();
  }

  function endDrag() {
    if (!state.dragging) return;
    state.dragging.el.classList.remove('is-dragging');
    state.dragging = null;
    scheduleSave();
  }

  document.addEventListener('mousedown', (e) => {
    if (!state.editorOpen) return;
    const el = e.target.closest('.hud-element');
    if (!el) return;
    startDrag(el, e);
  });
  document.addEventListener('mousemove', moveDrag);
  document.addEventListener('mouseup', endDrag);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && state.editorOpen) post('editor:close');
  });

  // -------------------------------------------------------------------
  //  Editor controls
  // -------------------------------------------------------------------

  document.getElementById('editor-close').addEventListener('click', () => post('editor:close'));
  document.getElementById('editor-save').addEventListener('click', () => {
    saveNow();
    post('editor:close');
  });
  document.getElementById('editor-reset').addEventListener('click', () => post('editor:reset'));
  segButtons.forEach(btn => btn.addEventListener('click', () => {
    post('editor:setStyle', { style: btn.dataset.style });
  }));

  // -------------------------------------------------------------------
  //  NUI <- Lua message handler
  // -------------------------------------------------------------------

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    switch (d.type) {
      case 'init':
        state.config    = d.config || {};
        state.styleMode = d.layout?.__style || d.config?.layout || 'circles';
        state.layout    = d.layout || {};
        applyStyle();
        applyLayout();
        document.body.classList.remove('hidden');
        break;

      case 'layout':
        state.layout = d.layout || state.layout;
        if (state.layout.__style) state.styleMode = state.layout.__style;
        applyLayout();
        if (state.editorOpen) buildEditorList();
        break;

      case 'style':
        state.styleMode = d.style;
        applyStyle();
        break;

      case 'state':
        if (d.state) {
          renderStatus(d.state);
          if (d.state.voice) renderVoice(d.state.voice.mode, d.state.voice.distance);
          if (d.state.ammo)  renderAmmo({ visible: !!d.state.weapon, current: d.state.ammo.current, max: d.state.ammo.max });
          if (d.state.job)   renderJob(d.state.job);
          renderPlayerId(d.state.id, true);
        }
        if (typeof d.visible === 'boolean') document.body.classList.toggle('hidden', !d.visible);
        break;

      case 'status':
        renderStatus(d);
        break;

      case 'voice':
        renderVoice(d.mode, d.distance);
        break;

      case 'ammo':
        renderAmmo(d);
        break;

      case 'job':
        renderJob(d.job);
        break;

      case 'playerid':
        renderPlayerId(d.id, d.visible);
        break;

      case 'visibility':
        document.body.classList.toggle('hidden', !d.visible);
        break;

      case 'pause':
        document.body.classList.toggle('paused', !!d.paused);
        break;

      case 'editor':
        if (d.layout) state.layout = d.layout;
        if (d.styleConfig?.current) { state.styleMode = d.styleConfig.current; applyStyle(); }
        setEditorOpen(!!d.open);
        applyLayout();
        break;
    }
  });

  // -------------------------------------------------------------------
  //  Save throttling
  // -------------------------------------------------------------------

  let saveHandle = null;

  function scheduleSave() {
    if (saveHandle) clearTimeout(saveHandle);
    saveHandle = setTimeout(saveNow, 250);
  }

  function saveNow() {
    if (!state.layout) return;
    post('editor:saveLayout', { layout: state.layout });
  }

  // -------------------------------------------------------------------
  //  Helpers
  // -------------------------------------------------------------------

  function post(action, data = {}) {
    return fetch(`https://${RESOURCE}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    }).catch(() => {});
  }

  // -------------------------------------------------------------------
  //  Boot
  // -------------------------------------------------------------------

  // Hide body until init arrives.
  document.body.classList.add('hidden');
})();
