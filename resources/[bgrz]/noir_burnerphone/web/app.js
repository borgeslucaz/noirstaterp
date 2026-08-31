const resource = GetParentResourceName();
const pages = ['home', 'phone', 'contacts', 'messages', 'illegal', 'street'];
let closing = false;
let closeTimer;

function hideWithAnimation(done) {
    if (!document.body.classList.contains('open') || closing) return;

    closing = true;
    document.body.classList.add('closing');
    clearTimeout(closeTimer);
    closeTimer = setTimeout(() => {
        document.body.classList.remove('open', 'closing');
        closing = false;
        done?.();
    }, 220);
}

function close() {
    hideWithAnimation(() => fetch(`https://${resource}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    }));
}

function showPage(name) {
    pages.forEach((page) => {
        document.getElementById(`${page}-page`).classList.toggle('hidden', page !== name);
    });
}

function startStreetSale() {
    hideWithAnimation(() => fetch(`https://${resource}/startStreetSale`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    }));
}

document.getElementById('close').addEventListener('click', close);
document.querySelectorAll('[data-page]').forEach((tile) => {
    tile.addEventListener('click', () => showPage(tile.dataset.page));
});
document.getElementById('start-street-sale').addEventListener('click', startStreetSale);

window.addEventListener('message', (event) => {
    if (event.data && event.data.action === 'burner:open') {
        clearTimeout(closeTimer);
        closing = false;
        document.body.classList.remove('closing');
        document.body.classList.add('open');
        showPage('home');
    } else if (event.data && event.data.action === 'burner:close') {
        hideWithAnimation();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && document.body.classList.contains('open')) close();
});
