const resource = GetParentResourceName();
const pages = ['home', 'phone', 'contacts', 'messages', 'illegal', 'street', 'housechat'];
let closing = false;
let closeTimer;
let messages = [];

function setTyping(active) {
    fetch(`https://${resource}/typing`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ active }),
    });
}

function hideWithAnimation(done) {
    if (!document.body.classList.contains('open')) {
        clearTimeout(closeTimer);
        document.body.classList.remove('open', 'closing');
        document.body.style.display = 'none';
        document.body.style.visibility = 'hidden';
        closing = false;
        done?.();
        return;
    }
    if (closing) return;

    closing = true;
    document.body.classList.add('closing');
    clearTimeout(closeTimer);
    closeTimer = setTimeout(() => {
        document.body.classList.remove('open', 'closing');
        document.body.style.display = 'none';
        document.body.style.visibility = 'hidden';
        closing = false;
        done?.();
    }, 220);
}

function close() {
    fetch(`https://${resource}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    });
}

function showPage(name) {
    pages.forEach((page) => {
        document.getElementById(`${page}-page`).classList.toggle('hidden', page !== name);
    });
}

function startStreetSale() {
    fetch(`https://${resource}/startStreetSale`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    });
}

function renderMessages() {
    const list = document.getElementById('house-messages');
    list.replaceChildren();
    messages.forEach((item) => {
        const bubble = document.createElement('article');
        bubble.className = `message ${item.outgoing ? 'outgoing' : 'incoming'}`;
        const text = document.createElement('span');
        text.textContent = item.message;
        bubble.appendChild(text);
        if (item.location) {
            const gps = document.createElement('button');
            gps.type = 'button';
            gps.textContent = 'ABRIR GPS';
            gps.addEventListener('click', () => fetch(`https://${resource}/setWaypoint`, {
                method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ location: item.location }),
            }));
            bubble.appendChild(gps);
        }
        list.appendChild(bubble);
    });
    list.scrollTop = list.scrollHeight;
}

document.getElementById('close').addEventListener('click', close);
document.querySelectorAll('[data-page]').forEach((tile) => {
    tile.addEventListener('click', () => showPage(tile.dataset.page));
});
document.getElementById('start-street-sale').addEventListener('click', startStreetSale);
const houseMessageInput = document.getElementById('house-message-input');
houseMessageInput.addEventListener('focus', () => setTyping(true));
houseMessageInput.addEventListener('blur', () => setTyping(false));
document.getElementById('house-message-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const input = houseMessageInput;
    const message = input.value.trim();
    if (!message) return;
    const response = await fetch(`https://${resource}/sendHouseMessage`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ message }),
    });
    if (response.ok) {
        messages.push({ outgoing: true, message });
        input.value = '';
        renderMessages();
    }
});

window.addEventListener('message', (event) => {
    if (event.data && event.data.action === 'burner:open') {
        clearTimeout(closeTimer);
        closing = false;
        document.body.classList.remove('closing');
        document.body.style.display = 'block';
        document.body.style.visibility = 'visible';
        document.body.classList.add('open');
        messages = Array.isArray(event.data.messages) ? event.data.messages : [];
        if (event.data.contact) {
            document.getElementById('house-contact-name').textContent = event.data.contact.name;
            document.getElementById('house-contact-number').textContent = event.data.contact.number;
            document.getElementById('house-message-input').placeholder = event.data.contact.requestText;
        }
        renderMessages();
        showPage('home');
    } else if (event.data && event.data.action === 'burner:message') {
        messages.push(event.data.message);
        renderMessages();
    } else if (event.data && event.data.action === 'burner:close') {
        if (document.activeElement === houseMessageInput) houseMessageInput.blur();
        hideWithAnimation();
    }
});

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && document.body.classList.contains('open')) close();
});

window.addEventListener('DOMContentLoaded', () => {
    document.body.classList.remove('open', 'closing');
    document.body.style.display = 'none';
    document.body.style.visibility = 'hidden';
    fetch(`https://${resource}/ready`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    });
});
