const meter = document.getElementById('noise');
const fill = document.getElementById('fill');
const value = document.getElementById('value');
document.body.style.visibility = 'visible';

function update(amount) {
    const noise = Math.max(0, Math.min(100, Number(amount) || 0));
    value.textContent = Math.round(noise);
    fill.style.width = `${noise}%`;
    meter.dataset.level = noise >= 90 ? 'critical' : noise >= 70 ? 'danger' : noise >= 50 ? 'risk' : noise >= 30 ? 'noticeable' : 'quiet';
}

window.addEventListener('message', ({ data }) => {
    if (!data) return;
    if (data.action === 'noise:show') {
        update(data.value);
        meter.classList.add('visible');
        meter.setAttribute('aria-hidden', 'false');
    } else if (data.action === 'noise:update') {
        update(data.value);
    } else if (data.action === 'noise:hide') {
        meter.classList.remove('visible');
        meter.setAttribute('aria-hidden', 'true');
    }
});
