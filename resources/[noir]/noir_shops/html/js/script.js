let currentLocales = {};
let cart = [];
let currentItems = [];
let currentCategory = null; // null = "All"
let isDynamicPricingShop = false;

const money = (v) => '$' + Number(v).toLocaleString('pt-BR');
const escapeHtml = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'openShop') {
        currentLocales = data.locales;
        currentItems = data.items;
        isDynamicPricingShop = data.dynamicPricing || false;

        document.documentElement.setAttribute('data-theme', data.theme || 'default');

        document.getElementById('shop-title').innerText = data.shopName;
        document.getElementById('cart-title').innerText = currentLocales['cart_title'] || 'Carrinho';
        document.getElementById('checkout-btn').innerText = currentLocales['checkout'] || 'Checkout';

        document.getElementById('search-input').placeholder = currentLocales['search_placeholder'] || 'Buscar item';
        document.getElementById('modal-total-label').innerText = currentLocales['payment_total'] || 'Total da compra';
        document.getElementById('modal-hint').innerText = currentLocales['payment_hint'] || 'Escolha como pagar.';
        document.getElementById('modal-title').innerText = currentLocales['payment_method'] || 'Select Payment Method';
        document.getElementById('text-cash').innerText = currentLocales['pay_cash'] || 'Cash';
        document.getElementById('text-card').innerText = currentLocales['pay_card'] || 'Card';

        document.getElementById('app').style.display = 'flex';

        cart = []; // Reset cart on open
        currentCategory = null;
        document.getElementById('search-input').value = '';
        renderCart();
        renderCategoryTabs(currentItems);
        renderFilteredItems();
    } else if (data.action === 'closeShop') {
        document.getElementById('app').style.display = 'none';
    }
});

document.getElementById('search-input').addEventListener('input', function(e) {
    document.getElementById('search-clear').style.display = e.target.value ? 'flex' : 'none';
    renderFilteredItems();
});

document.getElementById('search-clear').addEventListener('click', function() {
    document.getElementById('search-input').value = '';
    this.style.display = 'none';
    renderFilteredItems();
});

function renderFilteredItems() {
    const term = document.getElementById('search-input').value.toLowerCase();
    let filtered = currentItems;
    if (currentCategory) {
        filtered = filtered.filter(item => item.category === currentCategory);
    }
    if (term) {
        filtered = filtered.filter(item => item.label.toLowerCase().includes(term));
    }
    renderItems(filtered);
}

function renderCategoryTabs(items) {
    const container = document.getElementById('category-tabs');
    const categories = [];
    let hasCategories = false;

    items.forEach(item => {
        if (item.category && !categories.includes(item.category)) {
            categories.push(item.category);
            hasCategories = true;
        }
    });

    if (!hasCategories) {
        container.style.display = 'none';
        container.innerHTML = '';
        return;
    }

    container.style.display = 'flex';
    container.innerHTML = '';

    const allLabel = currentLocales['category_all'] || 'All';

    const allTab = document.createElement('button');
    allTab.className = 'store__tab active';
    allTab.textContent = allLabel;
    allTab.addEventListener('click', function() {
        currentCategory = null;
        setActiveTab(container, this);
        renderFilteredItems();
    });
    container.appendChild(allTab);

    categories.forEach(cat => {
        const tab = document.createElement('button');
        tab.className = 'store__tab';
        tab.textContent = cat;
        tab.addEventListener('click', function() {
            currentCategory = cat;
            setActiveTab(container, this);
            renderFilteredItems();
        });
        container.appendChild(tab);
    });
}

function setActiveTab(container, activeBtn) {
    container.querySelectorAll('.store__tab').forEach(t => t.classList.remove('active'));
    activeBtn.classList.add('active');
}

function renderItems(items) {
    const grid = document.getElementById('items-grid');
    grid.innerHTML = '';

    if (items.length === 0) {
        grid.innerHTML = `<div class="store__none">${escapeHtml(currentLocales['no_results'] || 'Nenhum item encontrado.')}</div>`;
        return;
    }

    items.forEach(item => {
        const card = document.createElement('div');
        card.className = 'store-card';

        const displayPrice = item.dynamicPrice !== undefined ? item.dynamicPrice : item.price;
        const name = escapeHtml(item.name);
        const label = escapeHtml(item.label);

        card.innerHTML = `
            ${item.license ? `<i class="fas fa-id-card store-card__license" title="${escapeHtml(currentLocales['license_required'] || 'Exige licença')}"></i>` : ''}
            <div class="store-card__media"></div>
            <div class="store-card__name">${label}</div>
            <div class="store-card__price${item.dynamicPrice !== undefined ? ' store-card__price--dynamic' : ''}">${money(displayPrice)}</div>
            <div class="store-card__actions">
                <div class="store-qty">
                    <button class="store-qty__btn minus" data-item="${name}" aria-label="Menos"><i class="fas fa-minus"></i></button>
                    <input type="number" class="store-qty__input" id="qty-${name}" value="1" min="1" step="1" aria-label="Quantidade">
                    <button class="store-qty__btn plus" data-item="${name}" aria-label="Mais"><i class="fas fa-plus"></i></button>
                </div>
                <button class="store__btn store__btn--secondary store__btn--add" data-item="${name}" data-price="${displayPrice}" data-label="${label}">
                    ${escapeHtml(currentLocales['add_to_cart'] || 'Adicionar')}
                </button>
            </div>
        `;

        card.querySelector('.store-card__media').appendChild(window.createFallbackImg(item.image, 'store-card__img', item.label));

        grid.appendChild(card);
    });

    // Quantity Handlers
    document.querySelectorAll('.store-qty__btn').forEach(btn => {
        btn.addEventListener('click', function () {
            const name = this.getAttribute('data-item');
            const itemDef = currentItems.find(i => i.name === name);
            const mQty = itemDef ? (itemDef.maxQty || 999) : 999;
            const input = document.getElementById(`qty-${name}`);
            let val = parseInt(input.value) || 1;
            if (this.classList.contains('minus') && val > 1) {
                input.value = val - 1;
            } else if (this.classList.contains('plus') && val < mQty) {
                input.value = val + 1;
            }
        });
    });

    // Native Typed Input Handlers
    document.querySelectorAll('.store-qty__input').forEach(input => {
        input.addEventListener('input', function() {
            const name = this.id.replace('qty-', '');
            const itemDef = currentItems.find(i => i.name === name);
            const mQty = itemDef ? (itemDef.maxQty || 999) : 999;
            let val = parseInt(this.value);
            if (val > mQty) this.value = mQty;
            if (val < 1 && this.value !== '') this.value = 1;
        });
        input.addEventListener('blur', function() {
            if (!this.value || parseInt(this.value) < 1) this.value = 1;
        });
    });

    // Add to Cart Handlers
    document.querySelectorAll('.store__btn--add').forEach(btn => {
        btn.addEventListener('click', function () {
            const name = this.getAttribute('data-item');
            const label = this.getAttribute('data-label');
            const price = parseInt(this.getAttribute('data-price'));
            
            const itemDef = currentItems.find(i => i.name === name);
            const mQty = itemDef ? (itemDef.maxQty || 999) : 999;

            const input = document.getElementById(`qty-${name}`);
            let qty = parseInt(input.value) || 1;

            if (qty > mQty) qty = mQty;
            if (qty < 1) qty = 1;

            if (qty > 0) {
                addToCart(name, label, price, qty, mQty);
                input.value = 1;
            }
        });
    });
}

function addToCart(name, label, price, qty, mQty) {
    const existing = cart.find(i => i.name === name);
    if (existing) {
        existing.qty += qty;
        if (existing.qty > mQty) existing.qty = mQty;
    } else {
        if (qty > mQty) qty = mQty;
        cart.push({ name, label, price, qty });
    }
    renderCart();
}

function removeFromCart(name) {
    cart = cart.filter(i => i.name !== name);
    renderCart();
}

function renderCart() {
    const cartContainer = document.getElementById('cart-items');
    const totalEl = document.getElementById('cart-total');
    const checkoutBtn = document.getElementById('checkout-btn');

    cartContainer.innerHTML = '';
    let total = 0;

    if (cart.length === 0) {
        cartContainer.innerHTML = `<div class="store__empty" id="empty-cart-msg">${escapeHtml(currentLocales['empty_cart'] || 'Seu carrinho está vazio')}</div>`;
        checkoutBtn.disabled = true;
    } else {
        checkoutBtn.disabled = false;
        cart.forEach(item => {
            const rowTotal = item.price * item.qty;
            total += rowTotal;

            const el = document.createElement('div');
            el.className = 'store-line';
            el.innerHTML = `
                <div class="store-line__info">
                    <div class="store-line__name">${escapeHtml(item.label)}</div>
                    <div class="store-line__desc">${item.qty} × ${money(item.price)}</div>
                </div>
                <div class="store-line__value">${money(rowTotal)}</div>
                <button class="store-line__remove" data-item="${escapeHtml(item.name)}" aria-label="Remover">
                    <i class="fas fa-trash"></i>
                </button>
            `;
            cartContainer.appendChild(el);
        });

        document.querySelectorAll('.store-line__remove').forEach(btn => {
            btn.addEventListener('click', function () {
                removeFromCart(this.getAttribute('data-item'));
            });
        });
    }

    totalEl.innerHTML = `<span>${escapeHtml(currentLocales['total_label'] || 'Total')}</span><strong>${money(total)}</strong>`;
    document.getElementById('modal-total').innerText = money(total);
}

document.getElementById('checkout-btn').addEventListener('click', function () {
    if (cart.length === 0) return;
    setPaymentModal(true);
});

function setPaymentModal(open) {
    document.getElementById('payment-modal').style.display = open ? 'flex' : 'none';
    document.getElementById('store-keys').style.display = open ? 'none' : 'flex';
    if (open) document.getElementById('pay-cash-btn').focus();
}

document.getElementById('close-modal-btn').addEventListener('click', function () {
    setPaymentModal(false);
});

document.getElementById('pay-cash-btn').addEventListener('click', function () {
    processCheckout('cash');
});

document.getElementById('pay-card-btn').addEventListener('click', function () {
    processCheckout('bank');
});

function processCheckout(paymentType) {
    setPaymentModal(false);
    fetch('https://noir_shops/checkoutCart', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({
            cart: cart,
            paymentType: paymentType
        })
    }).then(() => {
        cart = [];
        renderCart();
        closeUI();
    });
}

document.getElementById('close-btn').addEventListener('click', closeUI);

function closeUI() {
    document.getElementById('app').style.display = 'none';
    fetch('https://noir_shops/closeUI', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify({})
    });
}

document.onkeyup = function (data) {
    if (data.key === 'Escape') {
        // Don't handle shop escape when admin panel is open
        if (document.getElementById('admin-app').style.display === 'flex') return;
        const modal = document.getElementById('payment-modal');
        if (modal.style.display === 'flex') {
            setPaymentModal(false);
        } else {
            closeUI();
        }
    }
};

// --- Image Fallback System ---
// Imagens dos itens vêm do ox_inventory; a pasta própria só guarda o placeholder e imagens extras.
window.inventoryImagePaths = [
    'nui://ox_inventory/web/images/',
    'nui://noir_shops/html/images/'
];

window.createFallbackImg = function(imageName, cssClass, altText) {
    const img = document.createElement('img');
    if (cssClass) img.className = cssClass;
    if (altText) img.alt = altText;
    img.dataset.imageName = imageName;

    const knownPath = imagePathMap[imageName] || imagePathMap[imageName.toLowerCase()];
    if (knownPath) {
        const lowerPath = knownPath.replace(/\.[A-Z]+$/, function(ext) { return ext.toLowerCase(); });
        const hasAltPath = (lowerPath !== knownPath);
        img.onerror = function() {
            if (hasAltPath && this.src !== lowerPath) {
                this.src = lowerPath;
            } else {
                this.onerror = null;
                this.src = 'nui://noir_shops/html/images/placeholder.png';
            }
        };
        img.src = knownPath;
        return img;
    }

    const lowerName = imageName.toLowerCase();
    const hasAltCase = (lowerName !== imageName);
    const candidates = [];
    for (const p of window.inventoryImagePaths) {
        candidates.push(p + imageName);
    }
    if (hasAltCase) {
        for (const p of window.inventoryImagePaths) {
            candidates.push(p + lowerName);
        }
    }
    img.dataset.fallbackIdx = '0';
    img.onerror = function() {
        let idx = parseInt(this.dataset.fallbackIdx) || 0;
        let currentSrc = this.src || '';
        while (idx < candidates.length) {
            let candidate = candidates[idx];
            idx++;
            if (candidate === currentSrc) continue;
            this.dataset.fallbackIdx = idx.toString();
            this.src = candidate;
            return;
        }
        this.onerror = null;
        this.src = 'nui://noir_shops/html/images/placeholder.png';
    };
    img.dataset.fallbackIdx = '1';
    img.src = candidates[0];
    return img;
}

// =============================================================================
// Admin Panel
// =============================================================================

let adminShops = {};
let adminImages = [];
let adminJobs = [];
let adminItems = [];
let adminLicenses = {};
let imagePathMap = {};
let selectedJobs = [];
let selectedLicense = '';
let editingShopId = null;
let editingItemIndex = -1; // -1 = new item
let editingShopItems = [];

// --- Open Admin ---
window.addEventListener('message', function (event) {
    const data = event.data;

    if (data.action === 'openAdmin') {
        adminShops = data.shops || {};
        adminImages = data.images || [];
        adminJobs = data.jobs || [];
        adminItems = data.items || [];
        imagePathMap = data.imagePathMap || {};
        adminLicenses = data.licenses || {};
        currentLocales = data.locales || {};

        document.documentElement.setAttribute('data-theme', data.theme || 'default');
        document.getElementById('admin-app').style.display = 'flex';
        document.getElementById('app').style.display = 'none';

        showAdminShopList();
    } else if (data.action === 'closeAdmin') {
        document.getElementById('admin-app').style.display = 'none';
    }
});

// --- Close Admin ---
document.getElementById('admin-close-btn').addEventListener('click', closeAdmin);

function closeAdmin() {
    document.getElementById('admin-app').style.display = 'none';
    fetch('https://noir_shops/closeAdmin', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

// --- Shop List Screen ---
function showAdminShopList() {
    document.getElementById('admin-shop-list').style.display = '';
    document.getElementById('admin-shop-edit').style.display = 'none';
    document.getElementById('admin-back-btn').style.display = 'none';
    document.getElementById('admin-title').textContent = 'Lojas';
    document.getElementById('admin-search').value = '';
    document.getElementById('admin-search-clear').style.display = 'none';
    updateAdminKeys();
    renderAdminShops(adminShops);
}

document.getElementById('admin-search').addEventListener('input', function() {
    document.getElementById('admin-search-clear').style.display = this.value ? 'flex' : 'none';
    const term = this.value.toLowerCase();
    const filtered = {};
    for (const [id, shop] of Object.entries(adminShops)) {
        if (id.toLowerCase().includes(term) || (shop.name || '').toLowerCase().includes(term)) {
            filtered[id] = shop;
        }
    }
    renderAdminShops(filtered);
});

document.getElementById('admin-search-clear').addEventListener('click', function() {
    document.getElementById('admin-search').value = '';
    this.style.display = 'none';
    renderAdminShops(adminShops);
});

function renderAdminShops(shops) {
    const grid = document.getElementById('admin-shops-grid');
    grid.innerHTML = '';

    const sortedEntries = Object.entries(shops).sort((a, b) => a[0].localeCompare(b[0]));

    for (const [id, shop] of sortedEntries) {
        const card = document.createElement('div');
        card.className = 'admin-shop-card';

        const itemCount = (shop.items || []).length;
        const isConfig = shop._isConfig;
        const isDynamic = shop._dynamic;
        const isOverride = shop._override;

        let badge = '';
        if (isDynamic) badge = '<span class="admin-badge admin-badge-dynamic">Criada no jogo</span>';
        else if (isOverride) badge = '<span class="admin-badge admin-badge-override">Alterada</span>';
        else if (isConfig) badge = '<span class="admin-badge admin-badge-config">Config</span>';

        let jobText = '';
        const restriction = shop.Restriction ?? shop.JobRestriction;
        if (restriction) {
            const jobs = Array.isArray(restriction) ? restriction.join(', ') : restriction;
            jobText = `<div class="admin-shop-jobs"><i class="fas fa-lock"></i>${escapeHtml(jobs)}</div>`;
        }

        const coords = shop.coords || [0,0,0];
        const cx = coords.x !== undefined ? coords.x : (coords[0] || 0);
        const cy = coords.y !== undefined ? coords.y : (coords[1] || 0);
        const cz = coords.z !== undefined ? coords.z : (coords[2] || 0);

        card.innerHTML = `
            <button class="admin-goto-btn" data-x="${cx}" data-y="${cy}" data-z="${cz}" title="Ir até a loja" aria-label="Ir até a loja">
                <i class="fas fa-location-arrow"></i>
            </button>
            <div class="admin-shop-icon"><i class="fas fa-store"></i></div>
            <div class="admin-shop-name">${escapeHtml(shop.name || id)}</div>
            <div class="admin-shop-id">${escapeHtml(id)}</div>
            ${jobText}
            <div class="admin-shop-meta">${itemCount} ${itemCount === 1 ? 'item' : 'itens'} ${badge}</div>
            <button class="admin-edit-shop-btn" data-shop-id="${escapeHtml(id)}">Editar</button>
        `;
        grid.appendChild(card);
    }

    // Add "New Shop" card
    const newCard = document.createElement('div');
    newCard.className = 'admin-shop-card admin-new-shop-card';
    newCard.innerHTML = `
        <div class="admin-new-icon"><i class="fas fa-plus"></i></div>
        <div class="admin-shop-name">Nova loja</div>
        <div class="admin-shop-id">Criada na sua posição</div>
    `;
    newCard.addEventListener('click', function() {
        document.getElementById('new-shop-id').value = '';
        document.getElementById('new-shop-modal').style.display = 'flex';
    });
    grid.appendChild(newCard);

    // Edit button handlers
    grid.querySelectorAll('.admin-edit-shop-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const shopId = this.getAttribute('data-shop-id');
            openShopEditor(shopId);
        });
    });

    // Goto button handlers
    grid.querySelectorAll('.admin-goto-btn').forEach(btn => {
        btn.addEventListener('click', function(e) {
            e.stopPropagation();
            const x = parseFloat(this.getAttribute('data-x'));
            const y = parseFloat(this.getAttribute('data-y'));
            const z = parseFloat(this.getAttribute('data-z'));
            fetch('https://noir_shops/adminGotoShop', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ x, y, z })
            });
        });
    });
}

// --- New Shop Modal ---
document.getElementById('new-shop-modal-close').addEventListener('click', function() {
    document.getElementById('new-shop-modal').style.display = 'none';
});

document.getElementById('new-shop-cancel').addEventListener('click', function() {
    document.getElementById('new-shop-modal').style.display = 'none';
});

document.getElementById('new-shop-create-btn').addEventListener('click', function() {
    const shopId = document.getElementById('new-shop-id').value.trim().replace(/\s+/g, '_');
    if (!shopId) return;
    document.getElementById('new-shop-modal').style.display = 'none';

    fetch('https://noir_shops/adminCreateShop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ shopId: shopId })
    }).then(() => {
        // Shop will arrive via registerShop event; close and reopen admin to refresh
        setTimeout(() => {
            closeAdmin();
        }, 500);
    });
});

// --- Shop Editor Screen ---
function openShopEditor(shopId) {
    const shop = adminShops[shopId];
    if (!shop) return;

    editingShopId = shopId;
    editingShopItems = JSON.parse(JSON.stringify(shop.items || []));

    document.getElementById('admin-shop-list').style.display = 'none';
    document.getElementById('admin-shop-edit').style.display = '';
    document.getElementById('admin-back-btn').style.display = '';
    document.getElementById('admin-title').textContent = shop.name || shopId;
    updateAdminKeys();

    // Fill form
    document.getElementById('admin-shop-id').value = shopId;
    document.getElementById('admin-shop-name').value = shop.name || '';

    // Restriction dropdown (jobs/gangs)
    const jobRestriction = shop.Restriction ?? shop.JobRestriction;
    if (jobRestriction) {
        selectedJobs = Array.isArray(jobRestriction) ? [...jobRestriction] : [jobRestriction];
    } else {
        selectedJobs = [];
    }
    renderJobDropdown();
    updateJobPlaceholder();

    document.getElementById('admin-blip-name').value = shop.Blipname || '';
    document.getElementById('admin-blip-sprite').value = shop.BlipSprite || 52;
    document.getElementById('admin-blip-color').value = shop.BlipColor || 2;
    document.getElementById('admin-blip-minimap').checked = shop.BlipMinimapOnly || false;
    document.getElementById('admin-marker-type').value = shop.MarkerType || 0;

// --- Ped fields --- 
    const hasPed = !!(shop.PedModel && shop.PedModel !== '');
    document.getElementById('admin-ped-enabled').checked = hasPed;
    document.getElementById('admin-ped-fields').style.display = hasPed ? '' : 'none';
    document.getElementById('admin-ped-model').value = shop.PedModel || '';
    document.getElementById('admin-ped-heading').value = shop.PedHeading || 0;
    document.getElementById('admin-ped-scenario').value = shop.PedScenario || '';

    const coords = shop.coords || [0, 0, 0];
    const cx = coords.x !== undefined ? coords.x : (coords[0] || 0);
    const cy = coords.y !== undefined ? coords.y : (coords[1] || 0);
    const cz = coords.z !== undefined ? coords.z : (coords[2] || 0);
    document.getElementById('admin-coord-x').value = cx.toFixed(2);
    document.getElementById('admin-coord-y').value = cy.toFixed(2);
    document.getElementById('admin-coord-z').value = cz.toFixed(2);

    // Show/hide buttons based on shop type
    const isConfig = shop._isConfig && !shop._dynamic;
    document.getElementById('admin-reset-btn').style.display = (isConfig && shop._override) ? '' : 'none';
    document.getElementById('admin-delete-btn').style.display = shop._dynamic ? '' : 'none';

// --- Dynamic Pricing fields ---
    const hasDynamic = !!shop.DynamicPricing;
    document.getElementById('admin-dynamic-enabled').checked = hasDynamic;
    document.getElementById('admin-dynamic-fields').style.display = hasDynamic ? '' : 'none';
    document.getElementById('admin-dynamic-range').value = shop.DynamicPriceRange || 30;
    document.getElementById('admin-dynamic-interval').value = shop.DynamicPriceInterval || 0;

    renderAdminItems();
}

// Back button
document.getElementById('admin-back-btn').addEventListener('click', function() {
    showAdminShopList();
});

// Use current position
document.getElementById('admin-use-pos-btn').addEventListener('click', function() {
    fetch('https://noir_shops/adminGetPlayerCoords', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).then(r => r.json()).then(coords => {
        document.getElementById('admin-coord-x').value = coords.x.toFixed(2);
        document.getElementById('admin-coord-y').value = coords.y.toFixed(2);
        document.getElementById('admin-coord-z').value = coords.z.toFixed(2);
    });
});

// --- Items List ---
function renderAdminItems() {
    const list = document.getElementById('admin-items-list');
    document.getElementById('admin-item-count').textContent = editingShopItems.length;
    list.innerHTML = '';

    if (editingShopItems.length === 0) {
        list.innerHTML = '<div class="admin-empty">Nenhum item ainda.</div>';
        return;
    }

    editingShopItems.forEach((item, index) => {
        const el = document.createElement('div');
        el.className = 'cart-item admin-item-row';

        let meta = money(item.price || 0);
        if (item.minPrice || item.maxPrice) meta += ` (${item.minPrice ? money(item.minPrice) : '?'}–${item.maxPrice ? money(item.maxPrice) : '?'})`;
        if (item.maxQty) meta += ` · máx. ${item.maxQty}`;
        if (item.grade) meta += ` · cargo ${item.grade}`;
        if (item.category) meta += ` · ${escapeHtml(item.category)}`;
        if (item.license) meta += ` · <i class="fas fa-id-card"></i> ${escapeHtml((adminLicenses[item.license] && adminLicenses[item.license].label) || item.license)}`;

        el.innerHTML = `
            <div class="cart-item-info">
                <div class="title">${escapeHtml(item.label || item.name)}</div>
                <div class="price-qty">${meta}</div>
            </div>
            <div class="admin-item-actions">
                <button class="admin-item-edit-btn" data-idx="${index}" title="Editar" aria-label="Editar"><i class="fas fa-pen"></i></button>
                <button class="cart-item-remove" data-idx="${index}" title="Remover" aria-label="Remover"><i class="fas fa-trash"></i></button>
            </div>
        `;
        list.appendChild(el);
    });

    // Edit item
    list.querySelectorAll('.admin-item-edit-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            openItemEditor(parseInt(this.getAttribute('data-idx')));
        });
    });

    // Remove item
    list.querySelectorAll('.cart-item-remove').forEach(btn => {
        btn.addEventListener('click', function() {
            const idx = parseInt(this.getAttribute('data-idx'));
            editingShopItems.splice(idx, 1);
            renderAdminItems();
        });
    });
}

// Add item button
document.getElementById('admin-add-item-btn').addEventListener('click', function() {
    openItemEditor(-1);
});

// --- Save Shop ---
document.getElementById('admin-save-btn').addEventListener('click', function() {
    const shopData = buildShopData();
    const oldShop = adminShops[editingShopId] || {};
    fetch('https://noir_shops/adminSaveShop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ shopId: editingShopId, shopData: shopData })
    }).then(() => {
        if (oldShop._isConfig) {
            shopData._isConfig = true;
            shopData._override = true;
            shopData._dynamic = false;
        } else {
            shopData._isConfig = false;
            shopData._override = false;
            shopData._dynamic = true;
        }
        adminShops[editingShopId] = shopData;
        showAdminShopList();
    });
});

// --- Reset Shop ---
document.getElementById('admin-reset-btn').addEventListener('click', function() {
    fetch('https://noir_shops/adminResetShop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ shopId: editingShopId })
    }).then(() => {
        showAdminShopList();
    });
});

// --- Delete Shop (confirma antes, DESIGN_v4 §5/§6) ---
function setDeleteConfirm(open) {
    document.getElementById('delete-confirm-modal').style.display = open ? 'flex' : 'none';
    if (open) {
        const shop = adminShops[editingShopId] || {};
        document.getElementById('delete-confirm-name').textContent = shop.name || editingShopId;
        document.getElementById('delete-confirm-id').textContent = editingShopId;
        document.getElementById('delete-confirm-cancel').focus();
    } else {
        document.getElementById('admin-delete-btn').focus();
    }
}

document.getElementById('admin-delete-btn').addEventListener('click', function() {
    setDeleteConfirm(true);
});

document.getElementById('delete-confirm-cancel').addEventListener('click', function() {
    setDeleteConfirm(false);
});

document.getElementById('delete-confirm-close').addEventListener('click', function() {
    setDeleteConfirm(false);
});

document.getElementById('delete-confirm-ok').addEventListener('click', function() {
    document.getElementById('delete-confirm-modal').style.display = 'none';
    fetch('https://noir_shops/adminDeleteShop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ shopId: editingShopId })
    }).then(() => {
        delete adminShops[editingShopId];
        showAdminShopList();
    });
});

function buildShopData() {
    let jobRestriction = null;
    if (selectedJobs.length === 1) {
        jobRestriction = selectedJobs[0];
    } else if (selectedJobs.length > 1) {
        jobRestriction = [...selectedJobs];
    }

    const blipName = document.getElementById('admin-blip-name').value.trim();
    const markerType = parseInt(document.getElementById('admin-marker-type').value) || 0;

    const data = {
        name: document.getElementById('admin-shop-name').value.trim() || 'Loja sem nome',
        coords: [
            parseFloat(document.getElementById('admin-coord-x').value) || 0,
            parseFloat(document.getElementById('admin-coord-y').value) || 0,
            parseFloat(document.getElementById('admin-coord-z').value) || 0
        ],
        items: editingShopItems
    };

    if (jobRestriction) data.Restriction = jobRestriction;
    if (blipName) {
        data.Blipname = blipName;
        data.BlipSprite = parseInt(document.getElementById('admin-blip-sprite').value) || 52;
        data.BlipColor = parseInt(document.getElementById('admin-blip-color').value) || 2;
        data.BlipMinimapOnly = document.getElementById('admin-blip-minimap').checked;
    }
    if (markerType > 0) {
        data.MarkerType = markerType;
        data.MarkerSize = [1.0, 1.0, 0.5];
        data.MarkerColor = { r: 30, g: 150, b: 30, a: 100 };
    }

// --- Include ped data only when toggle is on --- 
    if (document.getElementById('admin-ped-enabled').checked) {
        const pedModel = document.getElementById('admin-ped-model').value.trim();
        if (pedModel) {
            data.PedModel = pedModel;
            data.PedHeading = parseFloat(document.getElementById('admin-ped-heading').value) || 0;
            const pedScenario = document.getElementById('admin-ped-scenario').value.trim();
            if (pedScenario) data.PedScenario = pedScenario;
        }
    }

    // --- Dynamic Pricing ---
    if (document.getElementById('admin-dynamic-enabled').checked) {
        data.DynamicPricing = true;
        data.DynamicPriceRange = parseInt(document.getElementById('admin-dynamic-range').value) || 30;
        const interval = parseInt(document.getElementById('admin-dynamic-interval').value) || 0;
        if (interval > 0) data.DynamicPriceInterval = interval;
    }

    return data;
}

// --- Job Dropdown ---
function renderLicenseDropdown() {
    const list = document.getElementById('item-license-list');
    list.innerHTML = '';

    const noneRow = document.createElement('div');
    noneRow.className = 'admin-job-option' + (selectedLicense === '' ? ' selected' : '');
    noneRow.innerHTML = '<span class="admin-job-label">Nenhuma</span>';
    noneRow.addEventListener('click', function() {
        selectedLicense = '';
        updateLicensePlaceholder();
        document.getElementById('item-license-dropdown').style.display = 'none';
        renderLicenseDropdown();
    });
    list.appendChild(noneRow);

    const sortedLicenses = Object.entries(adminLicenses).sort(function(a, b) {
        const aLabel = ((a[1] && a[1].label) || a[0] || '').toString().toLowerCase();
        const bLabel = ((b[1] && b[1].label) || b[0] || '').toString().toLowerCase();
        return aLabel.localeCompare(bLabel);
    });

    for (const [key, lic] of sortedLicenses) {
        const row = document.createElement('div');
        row.className = 'admin-job-option' + (selectedLicense === key ? ' selected' : '');
        row.innerHTML = `<span class="admin-job-label">${escapeHtml(lic.label || key)}</span>`;
        row.addEventListener('click', function() {
            selectedLicense = key;
            updateLicensePlaceholder();
            document.getElementById('item-license-dropdown').style.display = 'none';
            renderLicenseDropdown();
        });
        list.appendChild(row);
    }
}

function updateLicensePlaceholder() {
    const el = document.getElementById('item-license-placeholder');
    if (!selectedLicense) {
        el.textContent = 'Nenhuma';
        el.style.opacity = '0.5';
    } else {
        const lic = adminLicenses[selectedLicense];
        el.textContent = lic ? lic.label : selectedLicense;
        el.style.opacity = '1';
    }
}

function renderJobDropdown(filter = '') {
    const list = document.getElementById('admin-job-list');
    list.innerHTML = '';
    const term = filter.toLowerCase();
    const filtered = adminJobs.filter(j =>
        j.name.toLowerCase().includes(term) || j.label.toLowerCase().includes(term)
    );
    if (filtered.length === 0) {
        list.innerHTML = '<div class="admin-job-empty">Nada encontrado.</div>';
        return;
    }
    for (const job of filtered) {
        const row = document.createElement('label');
        row.className = 'admin-job-option' + (selectedJobs.includes(job.name) ? ' selected' : '');
        row.innerHTML = `
            <input type="checkbox" value="${job.name}" ${selectedJobs.includes(job.name) ? 'checked' : ''}>
            <span class="admin-job-label">${escapeHtml(job.label)}</span>
            <span class="admin-job-name">${escapeHtml(job.name)}</span>
        `;
        row.querySelector('input').addEventListener('change', function() {
            if (this.checked) {
                if (!selectedJobs.includes(job.name)) selectedJobs.push(job.name);
                row.classList.add('selected');
            } else {
                selectedJobs = selectedJobs.filter(j => j !== job.name);
                row.classList.remove('selected');
            }
            updateJobPlaceholder();
        });
        list.appendChild(row);
    }
}

function updateJobPlaceholder() {
    const el = document.getElementById('admin-job-placeholder');
    if (selectedJobs.length === 0) {
        el.textContent = 'Pública (sem restrição)';
        el.style.opacity = '0.5';
    } else {
        const labels = selectedJobs.map(name => {
            const found = adminJobs.find(j => j.name === name);
            return found ? found.label : name;
        });
        el.textContent = labels.join(', ');
        el.style.opacity = '1';
    }
}

document.getElementById('item-license-toggle').addEventListener('click', function() {
    const dd = document.getElementById('item-license-dropdown');
    const isOpen = dd.style.display !== 'none';
    dd.style.display = isOpen ? 'none' : '';
    if (!isOpen) renderLicenseDropdown();
});

document.getElementById('admin-job-toggle').addEventListener('click', function() {
    const dd = document.getElementById('admin-job-dropdown');
    const isOpen = dd.style.display !== 'none';
    dd.style.display = isOpen ? 'none' : '';
    if (!isOpen) {
        document.getElementById('admin-job-search').value = '';
        renderJobDropdown();
        document.getElementById('admin-job-search').focus();
    }
});

document.getElementById('admin-job-search').addEventListener('input', function() {
    renderJobDropdown(this.value);
});

// Close dropdowns when clicking outside
document.addEventListener('click', function(e) {
    const licSelect = document.getElementById('item-license-select');
    if (licSelect && !licSelect.contains(e.target)) {
        document.getElementById('item-license-dropdown').style.display = 'none';
    }
    const select = document.getElementById('admin-job-select');
    if (select && !select.contains(e.target)) {
        document.getElementById('admin-job-dropdown').style.display = 'none';
    }
});

// --- Item Editor Modal ---
function openItemEditor(index) {
    editingItemIndex = index;
    const modal = document.getElementById('item-edit-modal');
    const isNew = index === -1;

    document.getElementById('item-modal-title').textContent = isNew ? 'Adicionar item' : 'Editar item';

    const item = isNew ? { name: '', label: '', price: 0, image: '', maxQty: 999, grade: 0, category: '', license: '' } : editingShopItems[index];

    document.getElementById('item-edit-name').value = item.name || '';
    document.getElementById('item-edit-label').value = item.label || '';
    document.getElementById('item-edit-price').value = item.price || 0;
    document.getElementById('item-edit-maxqty').value = item.maxQty || 999;
    document.getElementById('item-edit-grade').value = item.grade || 0;
    document.getElementById('item-edit-category').value = item.category || '';

    selectedLicense = item.license || '';
    renderLicenseDropdown();
    updateLicensePlaceholder();
    document.getElementById('item-edit-image').value = item.image || '';
    updateItemImagePreview(item.image || '');

    // Dynamic price overrides (show only when shop has dynamic pricing enabled)
    const dynamicEnabled = document.getElementById('admin-dynamic-enabled').checked;
    document.getElementById('item-dynamic-price-row').style.display = dynamicEnabled ? '' : 'none';
    document.getElementById('item-edit-minprice').value = item.minPrice || '';
    document.getElementById('item-edit-maxprice').value = item.maxPrice || '';

    modal.style.display = 'flex';
}

document.getElementById('item-modal-close').addEventListener('click', function() {
    document.getElementById('item-edit-modal').style.display = 'none';
});

document.getElementById('item-edit-cancel').addEventListener('click', function() {
    document.getElementById('item-edit-modal').style.display = 'none';
});

document.getElementById('item-edit-save').addEventListener('click', function() {
    const item = {
        name: document.getElementById('item-edit-name').value.trim(),
        label: document.getElementById('item-edit-label').value.trim(),
        price: parseInt(document.getElementById('item-edit-price').value) || 0,
        maxQty: parseInt(document.getElementById('item-edit-maxqty').value) || 999,
        image: document.getElementById('item-edit-image').value.trim()
    };

    const grade = parseInt(document.getElementById('item-edit-grade').value) || 0;
    if (grade > 0) item.grade = grade;

    const category = document.getElementById('item-edit-category').value.trim();
    if (category) item.category = category;

    if (selectedLicense) item.license = selectedLicense;

    const minPrice = parseInt(document.getElementById('item-edit-minprice').value);
    const maxPrice = parseInt(document.getElementById('item-edit-maxprice').value);
    if (minPrice > 0) item.minPrice = minPrice;
    if (maxPrice > 0) item.maxPrice = maxPrice;

    if (!item.name || !item.label) return;

    if (editingItemIndex === -1) {
        editingShopItems.push(item);
    } else {
        editingShopItems[editingItemIndex] = item;
    }

    document.getElementById('item-edit-modal').style.display = 'none';
    renderAdminItems();
});

// Image field preview
document.getElementById('item-edit-image').addEventListener('input', function() {
    updateItemImagePreview(this.value.trim());
});

function updateItemImagePreview(imageName) {
    const preview = document.getElementById('item-image-preview');
    if (!imageName) {
        preview.innerHTML = '';
        return;
    }
    preview.innerHTML = '';
    preview.appendChild(window.createFallbackImg(imageName, 'admin-preview-img'));
}

// --- Image Picker Modal ---
document.getElementById('item-image-picker-btn').addEventListener('click', function() {
    document.getElementById('image-picker-search').value = '';
    renderImagePicker(adminImages);
    document.getElementById('image-picker-modal').style.display = 'flex';
});

document.getElementById('image-picker-close').addEventListener('click', function() {
    document.getElementById('image-picker-modal').style.display = 'none';
});

document.getElementById('image-picker-search').addEventListener('input', function() {
    const term = this.value.toLowerCase();
    const filtered = adminImages.filter(img => img.toLowerCase().includes(term));
    renderImagePicker(filtered);
});

function renderImagePicker(images) {
    const grid = document.getElementById('image-picker-grid');
    grid.innerHTML = '';

    images.forEach(img => {
        const tile = document.createElement('div');
        tile.className = 'image-picker-tile';
        const imgEl = window.createFallbackImg(img, 'image-picker-img');
        tile.appendChild(imgEl);
        const nameDiv = document.createElement('div');
        nameDiv.className = 'image-picker-name';
        nameDiv.textContent = img;
        tile.appendChild(nameDiv);
        tile.addEventListener('click', function() {
            document.getElementById('item-edit-image').value = img;
            updateItemImagePreview(img);
            document.getElementById('image-picker-modal').style.display = 'none';
        });
        grid.appendChild(tile);
    });

    if (images.length === 0) {
        grid.innerHTML = '<div class="admin-empty">Nenhuma imagem encontrada.</div>';
    }
}

// --- Item Name Picker Modal ---
document.getElementById('item-name-picker-btn').addEventListener('click', function() {
    document.getElementById('item-picker-search').value = '';
    renderItemPicker(adminItems);
    document.getElementById('item-picker-modal').style.display = 'flex';
    document.getElementById('item-picker-search').focus();
});

document.getElementById('item-picker-close').addEventListener('click', function() {
    document.getElementById('item-picker-modal').style.display = 'none';
});

document.getElementById('item-picker-search').addEventListener('input', function() {
    const term = this.value.toLowerCase();
    const filtered = adminItems.filter(i => i.name.toLowerCase().includes(term) || i.label.toLowerCase().includes(term));
    renderItemPicker(filtered);
});

function renderItemPicker(items) {
    const list = document.getElementById('item-picker-list');
    list.innerHTML = '';

    if (items.length === 0) {
        list.innerHTML = '<div class="admin-empty">Nenhum item encontrado.</div>';
        return;
    }

    items.forEach(function(item) {
        const row = document.createElement('div');
        row.className = 'ped-picker-item item-picker-item';
        row.innerHTML = '<div class="item-picker-label">' + escapeHtml(item.label) + '</div><div class="item-picker-name">' + escapeHtml(item.name) + '</div>';
        row.addEventListener('click', function() {
            document.getElementById('item-edit-name').value = item.name;
            document.getElementById('item-edit-label').value = item.label;
            document.getElementById('item-picker-modal').style.display = 'none';
        });
        list.appendChild(row);
    });
}

// --- Admin Escape key ---
document.addEventListener('keyup', function(e) {
    if (e.key !== 'Escape') return;
    const adminApp = document.getElementById('admin-app');
    if (adminApp.style.display !== 'flex') return;

// --- Close modals first, then back, then close admin --- 
    if (document.getElementById('delete-confirm-modal').style.display === 'flex') {
        setDeleteConfirm(false);
    } else if (document.getElementById('item-picker-modal').style.display === 'flex') {
        document.getElementById('item-picker-modal').style.display = 'none';
    } else if (document.getElementById('ped-picker-modal').style.display === 'flex') {
        document.getElementById('ped-picker-modal').style.display = 'none';
    } else if (document.getElementById('image-picker-modal').style.display === 'flex') {
        document.getElementById('image-picker-modal').style.display = 'none';
    } else if (document.getElementById('item-edit-modal').style.display === 'flex') {
        document.getElementById('item-edit-modal').style.display = 'none';
    } else if (document.getElementById('new-shop-modal').style.display === 'flex') {
        document.getElementById('new-shop-modal').style.display = 'none';
    } else if (document.getElementById('admin-shop-edit').style.display !== 'none') {
        showAdminShopList();
    } else {
        closeAdmin();
    }
});

// --- Ped Picker --- 
document.getElementById('admin-ped-enabled').addEventListener('change', function() {
    document.getElementById('admin-ped-fields').style.display = this.checked ? '' : 'none';
    if (!this.checked) {
        document.getElementById('admin-ped-model').value = '';
        document.getElementById('admin-ped-heading').value = 0;
        document.getElementById('admin-ped-scenario').value = '';
    }
});

// --- Dynamic Pricing Toggle ---
document.getElementById('admin-dynamic-enabled').addEventListener('change', function() {
    document.getElementById('admin-dynamic-fields').style.display = this.checked ? '' : 'none';
    // Show/hide minPrice/maxPrice row in item editor when dynamic is active
    document.getElementById('item-dynamic-price-row').style.display = this.checked ? '' : 'none';
});

document.getElementById('admin-use-heading-btn').addEventListener('click', function() {
    fetch('https://noir_shops/adminGetPlayerHeading', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).then(r => r.json()).then(data => {
        document.getElementById('admin-ped-heading').value = data.heading.toFixed(1);
    });
});

document.getElementById('admin-ped-picker-btn').addEventListener('click', function() {
    document.getElementById('ped-picker-search').value = '';
    renderPedPicker(window.PED_MODELS || []);
    document.getElementById('ped-picker-modal').style.display = 'flex';
    document.getElementById('ped-picker-search').focus();
});

document.getElementById('ped-picker-close').addEventListener('click', function() {
    document.getElementById('ped-picker-modal').style.display = 'none';
});

document.getElementById('ped-picker-search').addEventListener('input', function() {
    const term = this.value.toLowerCase();
    const filtered = (window.PED_MODELS || []).filter(m => m.toLowerCase().includes(term));
    renderPedPicker(filtered);
});

function renderPedPicker(models) {
    const list = document.getElementById('ped-picker-list');
    list.innerHTML = '';

    if (models.length === 0) {
        list.innerHTML = '<div class="admin-empty">Nenhum modelo encontrado.</div>';
        return;
    }

    models.forEach(model => {
        const row = document.createElement('div');
        row.className = 'ped-picker-item';
        row.textContent = model;
        row.addEventListener('click', function() {
            document.getElementById('admin-ped-model').value = model;
            document.getElementById('ped-picker-modal').style.display = 'none';
        });
        list.appendChild(row);
    });
}

// --- Teclas visíveis (DESIGN_v4 §7): ESC fecha na lista, volta no editor; somem com janela aberta ---
function updateAdminKeys() {
    const keys = document.getElementById('admin-keys');
    if (!keys) return;
    const modalOpen = Array.from(document.querySelectorAll('#admin-app .admin-modal')).some(m => m.style.display === 'flex');
    const editing = document.getElementById('admin-shop-edit').style.display !== 'none';
    const display = modalOpen ? 'none' : 'flex';
    const label = editing ? 'Voltar' : 'Fechar';
    if (keys.style.display !== display) keys.style.display = display;
    const labelEl = keys.querySelector('.admin-key-label');
    if (labelEl.textContent !== label) labelEl.textContent = label;
}

new MutationObserver(updateAdminKeys).observe(document.getElementById('admin-app'), {
    subtree: true, attributes: true, attributeFilter: ['style'],
});
