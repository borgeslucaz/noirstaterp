(() => {
    'use strict';

    const resourceName = typeof GetParentResourceName === 'function'
        ? GetParentResourceName()
        : 'noir_houserobbery';
    const app = document.getElementById('app');
    const list = document.getElementById('checklist-list');

    function setVisible(visible) {
        const shouldShow = visible === true && list.childElementCount > 0;
        app.hidden = !shouldShow;
        app.classList.toggle('is-visible', shouldShow);
        app.setAttribute('aria-hidden', shouldShow ? 'false' : 'true');
    }

    function createObjective(id) {
        const item = document.createElement('li');
        const check = document.createElement('span');
        const text = document.createElement('span');

        item.className = 'checklist-item';
        item.dataset.objectiveId = id;
        check.className = 'check';
        check.setAttribute('aria-hidden', 'true');
        check.textContent = '✓';
        text.className = 'label';
        item.append(check, text);
        return item;
    }

    function updateObjective(item, label, completed, count) {
        const text = item.querySelector('.label');
        const content = [];

        if (count) {
            const counter = document.createElement('span');
            counter.className = 'count';
            counter.textContent = count;
            content.push(counter, ' ');
        }

        content.push(document.createTextNode(label));
        text.replaceChildren(...content);
        item.classList.toggle('is-complete', completed === true);
    }

    function renderChecklist(data) {
        const existing = new Map(Array.from(list.children, (item) => [item.dataset.objectiveId, item]));
        const rendered = new Set();
        const search = data && data.search;

        function renderObjective(id, label, completed, count) {
            const item = existing.get(id) || createObjective(id);
            updateObjective(item, label, completed, count);
            list.append(item);
            rendered.add(id);
        }

        if (search && Number(search.total) > 0) {
            const completed = Math.max(0, Number(search.completed) || 0);
            const total = Math.max(0, Number(search.total) || 0);
            renderObjective('search', 'Vasculhar', completed >= total, `${completed}/${total}`);
        }

        const pickups = data && Array.isArray(data.pickups) ? data.pickups : [];
        for (const pickup of pickups) {
            if (!pickup || typeof pickup.id !== 'string' || typeof pickup.name !== 'string') continue;
            renderObjective(`pickup:${pickup.id}`, `Roubar ${pickup.name}`, pickup.completed === true);
        }

        for (const [id, item] of existing) {
            if (!rendered.has(id)) item.remove();
        }
    }

    function clearChecklist() {
        setVisible(false);
        list.replaceChildren();
    }

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data.action !== 'string') return;

        if (data.action === 'checklist:render') {
            renderChecklist(data.data);
            setVisible(data.visible);
        } else if (data.action === 'checklist:visibility') {
            setVisible(data.visible);
        } else if (data.action === 'checklist:clear') {
            clearChecklist();
        }
    });

    clearChecklist();

    fetch(`https://${resourceName}/ready`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}',
    }).catch(() => {});
})();
