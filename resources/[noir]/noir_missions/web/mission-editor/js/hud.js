// HUD da missão: objetivo discreto e cartão de informação revelada. Sem foco e sem ponteiro:
// nunca captura entrada. O timer conta localmente a partir dos segundos recebidos.
import { el, pad2 } from './dom.js';
import { fetchNui } from './nui.js';

let refs = null;
let timerEnd = 0;
let timerHandle = 0;
let infoHandle = 0;

function mount() {
    if (refs) return refs;
    const root = document.getElementById('hud');
    const objTitle = el('div', 'hud-title');
    const objText = el('div', 'hud-text');
    const progressValue = el('span', 'hud-progress-value num');
    const progressFill = el('i');
    const progress = el('div', 'hud-progress', el('div', 'hud-bar', progressFill), progressValue);
    const timerLabel = el('span', 'hud-timer-label');
    const timerValue = el('span', 'hud-timer-value num');
    const timer = el('div', 'hud-timer', timerLabel, timerValue);
    const objective = el('div', { class: 'hud-card hud-objective', hidden: true }, objTitle, objText, progress, timer);

    const infoTitle = el('div', 'hud-info-title');
    const infoLines = el('div', 'hud-info-lines');
    const info = el('div', { class: 'hud-card hud-info', hidden: true }, infoTitle, infoLines);

    root.append(el('div', 'hud-stack', objective, info));
    refs = { objective, objTitle, objText, progress, progressFill, progressValue, timer, timerLabel, timerValue, info, infoTitle, infoLines };
    return refs;
}

// Entra/sai com transição e depois sai do fluxo, para o cartão de baixo subir.
const hideTimers = new WeakMap();
function show(node, visible) {
    clearTimeout(hideTimers.get(node));
    if (visible) {
        node.hidden = false;
        void node.offsetWidth;
        node.classList.add('in');
    } else {
        node.classList.remove('in');
        hideTimers.set(node, setTimeout(() => { if (!node.classList.contains('in')) node.hidden = true; }, 260));
    }
}

function tick() {
    const left = Math.max(0, Math.ceil((timerEnd - Date.now()) / 1000));
    refs.timerValue.textContent = `${pad2(Math.floor(left / 60))}:${pad2(left % 60)}`;
    refs.timer.classList.toggle('low', left <= 10);
    if (left <= 0) { clearInterval(timerHandle); timerHandle = 0; }
}

/** hud:objective */
export function setObjective(data) {
    const r = mount();
    if (!data || data.visible === false) {
        show(r.objective, false);
        clearInterval(timerHandle);
        timerHandle = 0;
        return;
    }
    r.objTitle.textContent = data.title || '';
    r.objTitle.hidden = !data.title;
    r.objText.textContent = data.text || '';

    const progress = data.progress;
    if (progress && Number(progress.max) > 0) {
        const current = Math.max(0, Number(progress.current) || 0);
        const max = Number(progress.max);
        r.progressValue.textContent = `${current} / ${max}`;
        r.progressFill.style.width = `${Math.min(100, (current / max) * 100)}%`;
        r.progress.hidden = false;
    } else {
        r.progress.hidden = true;
    }

    clearInterval(timerHandle);
    timerHandle = 0;
    if (data.timer && Number.isFinite(Number(data.timer.seconds))) {
        r.timerLabel.textContent = data.timer.label || 'Tempo';
        timerEnd = Date.now() + Math.max(0, Number(data.timer.seconds)) * 1000;
        r.timer.hidden = false;
        tick();
        timerHandle = setInterval(tick, 250);
    } else {
        r.timer.hidden = true;
    }
    show(r.objective, true);
}

function hideInfo(notifyLua) {
    if (!refs) return;
    clearTimeout(infoHandle);
    infoHandle = 0;
    const wasVisible = refs.info.classList.contains('in');
    show(refs.info, false);
    if (notifyLua && wasVisible) fetchNui('infoClose', {});
}

/** hud:info */
export function showInfo(data) {
    const r = mount();
    if (!data) return;
    r.infoTitle.textContent = data.title || '';
    r.infoLines.replaceChildren(...(Array.isArray(data.lines) ? data.lines : []).map((line) => el('div', 'hud-info-line',
        el('span', { class: 'hud-info-label', text: line?.label ?? '' }),
        el('span', { class: 'hud-info-value', text: line?.value ?? '' }))));
    show(r.info, true);
    clearTimeout(infoHandle);
    const seconds = Number(data.seconds);
    if (Number.isFinite(seconds) && seconds > 0) infoHandle = setTimeout(() => hideInfo(true), seconds * 1000);
}

/** hud:infoClose — o Lua já sabe, não avisa de volta. */
export function closeInfo() {
    hideInfo(false);
}

export function resetHud() {
    if (!refs) return;
    setObjective({ visible: false });
    hideInfo(false);
}
