let currentMods = {};
let availableMods = {};
let currentHandling = {};
let handlingConfig = [];
let currentLocale = {};

function updateTranslations() {
    if (!currentLocale) return;
    document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (currentLocale[key]) {
            el.textContent = currentLocale[key];
        }
    });
}

window.addEventListener('message', function(event) {
    const data = event.data;
    if (data.action === 'open') {
        currentMods = data.mods || {};
        availableMods = data.available || {};
        currentHandling = data.handling || {};
        handlingConfig = data.handlingConfig || [];
        currentLocale = data.locales || {};
        updateTranslations();
        openUI();
        populateUI();
    } else if (data.action === 'close') {
        closeUI();
    } else if (data.action === 'refreshData') {
        currentMods = data.mods || {};
        currentHandling = data.handling || {};
        populateUI();
    } else if (data.action === 'cameraModeEnded') {
        isMouseDown = false;
        if (cameraTimeout) clearTimeout(cameraTimeout);
    }
});
function openUI() {
    document.getElementById('mechanic-container').classList.remove('hidden');
}
function closeUI() {
    document.getElementById('mechanic-container').classList.add('hidden');
    if (isMouseDown) {
        isMouseDown = false;
        if (cameraTimeout) clearTimeout(cameraTimeout);
    }
}
document.getElementById('closeBtn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        fetch(`https://${GetParentResourceName()}/close`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }
});
let isMouseDown = false;
function enableCameraMode() {
    if (!isMouseDown) {
        isMouseDown = true;
        fetch(`https://${GetParentResourceName()}/toggleCameraMode`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                enableCamera: true
            })
        });
    }
}
function disableCameraMode() {
    if (isMouseDown) {
        isMouseDown = false;
        fetch(`https://${GetParentResourceName()}/toggleCameraMode`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                enableCamera: false
            })
        });
    }
}
document.addEventListener('mousedown', function(event) {
    if (event.button === 0) {
        if (event.target.closest('.mechanic-wrapper') || event.target.closest('.modal')) {
            return;
        }
        enableCameraMode();
    }
});
document.addEventListener('mouseup', function(event) {
    if (event.button === 0) {
        if (isMouseDown) {
            disableCameraMode();
        }
    }
});
document.addEventListener('contextmenu', function(event) {
    event.preventDefault();
    return false;
});
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        const tab = this.getAttribute('data-tab');
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        this.classList.add('active');
        document.getElementById(tab + '-content').classList.add('active');
    });
});
function populateUI() {
    populatePerformance();
    populateColors();
    populateWheels();
    populateVisual();
    populateExtras();
    populateHandling();
    populateLightsAndWindows();
}
function populatePerformance() {
    const container = document.getElementById('performance-options');
    container.innerHTML = '';
    if (!availableMods.performance) return;
    for (const [key, mod] of Object.entries(availableMods.performance)) {
        const div = document.createElement('div');
        div.className = 'option-item';
        const label = document.createElement('label');
        label.textContent = mod.label;
        const select = document.createElement('select');
        mod.options.forEach(option => {
            const opt = document.createElement('option');
            opt.value = option.value;
            opt.textContent = option.label;
            if (currentMods.performance && currentMods.performance[key] != null) {
                if (currentMods.performance[key] == option.value) {
                    opt.selected = true;
                }
            }
            select.appendChild(opt);
        });
        select.addEventListener('change', function() {
            let value = this.value;
            if (value === 'true') value = true;
            else if (value === 'false') value = false;
            else value = parseInt(value);
            applyMod('performance', key, value);
        });
        div.appendChild(label);
        div.appendChild(select);
        container.appendChild(div);
    }
}
function populateColors() {
    const primarySelect = document.getElementById('primary-color');
    const secondarySelect = document.getElementById('secondary-color');
    const pearlSelect = document.getElementById('pearlescent-color');
    const wheelCSelect = document.getElementById('wheel-color');
    const interiorSelect = document.getElementById('interior-color');
    const dashboardSelect = document.getElementById('dashboard-color');
    [primarySelect, secondarySelect, pearlSelect, wheelCSelect, interiorSelect, dashboardSelect].forEach(s => {
        if(s) s.innerHTML = '';
    });
    if (!availableMods.colors) return;
    availableMods.colors.forEach(color => {
        const createOpt = (selVal) => {
            const opt = document.createElement('option');
            opt.value = color.id;
            opt.textContent = color.label;
            if (selVal == color.id) opt.selected = true;
            return opt;
        };
        if(currentMods.colors) {
            primarySelect.appendChild(createOpt(currentMods.colors.primary));
            secondarySelect.appendChild(createOpt(currentMods.colors.secondary));
            if(pearlSelect) pearlSelect.appendChild(createOpt(currentMods.colors.pearlescent));
            if(wheelCSelect) wheelCSelect.appendChild(createOpt(currentMods.colors.wheel));
            if(interiorSelect) interiorSelect.appendChild(createOpt(currentMods.colors.interior));
            if(dashboardSelect) dashboardSelect.appendChild(createOpt(currentMods.colors.dashboard));
        }
    });
    primarySelect.onchange = function() { applyMod('colors', null, parseInt(this.value), 'primary'); };
    secondarySelect.onchange = function() { applyMod('colors', null, parseInt(this.value), 'secondary'); };
    if(pearlSelect) pearlSelect.onchange = function() { applyMod('colors', null, parseInt(this.value), 'pearlescent'); };
    if(wheelCSelect) wheelCSelect.onchange = function() { applyMod('colors', null, parseInt(this.value), 'wheel'); };
    if(interiorSelect) interiorSelect.onchange = function() { applyMod('colors', null, parseInt(this.value), 'interior'); };
    if(dashboardSelect) dashboardSelect.onchange = function() { applyMod('colors', null, parseInt(this.value), 'dashboard'); };
}
function populateWheels() {
    const wheelTypeSelect = document.getElementById('wheel-type');
    const varSlider = document.getElementById('wheel-variation');
    const valDisplay = document.getElementById('wheel-val-display');
    
    wheelTypeSelect.innerHTML = '';
    if (!availableMods.wheels || !availableMods.wheels.types) return;

    availableMods.wheels.types.forEach(wheel => {
        const opt = document.createElement('option');
        opt.value = wheel.id;
        opt.textContent = wheel.label;
        if (currentMods.wheels && currentMods.wheels.type == wheel.id) {
            opt.selected = true;
        }
        wheelTypeSelect.appendChild(opt);
    });

    wheelTypeSelect.onchange = function() {
        const selVal = parseInt(this.value);
        applyMod('wheels', null, selVal, 'wheelType');
        
        fetch(`https://${GetParentResourceName()}/getWheelVariations`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({wheelType: selVal})
        }).then(resp => resp.json()).then(resp => {
            availableMods.wheels.maxVariation = resp.max;
            populateWheels();
        });
    };

    if (availableMods.wheels.maxVariation > 0) {
        varSlider.max = availableMods.wheels.maxVariation - 1;
    } else {
        varSlider.max = 0;
    }
    
    var currentVal = -1;
    if (currentMods.wheels && currentMods.wheels.variation !== undefined) {
        currentVal = currentMods.wheels.variation;
    }
    varSlider.value = currentVal;
    
    const maxDisplay = availableMods.wheels.maxVariation > 0 ? availableMods.wheels.maxVariation : 0;
    valDisplay.textContent = (currentVal + 1) + '/' + maxDisplay;

    varSlider.oninput = function() {
        var val = parseInt(this.value);
        const maxDisplay = availableMods.wheels.maxVariation > 0 ? availableMods.wheels.maxVariation : 0;
        valDisplay.textContent = (val + 1) + '/' + maxDisplay;
        applyMod('wheels', null, val, 'variation');
    };
}
function populateVisual() {
    const container = document.getElementById('visual-options');
    container.innerHTML = '';
    if (!availableMods.visual || Object.keys(availableMods.visual).length === 0) {
        const noModsDiv = document.createElement('div');
        noModsDiv.className = 'handling-info';
        noModsDiv.style.marginTop = '0';
        noModsDiv.textContent = 'Este veículo não possui modificações visuais disponíveis';
        container.appendChild(noModsDiv);
        return;
    }
    for (const [key, mod] of Object.entries(availableMods.visual)) {
        const div = document.createElement('div');
        div.className = 'option-item';
        const label = document.createElement('label');
        label.textContent = mod.label;
        const select = document.createElement('select');
        mod.options.forEach(option => {
            const opt = document.createElement('option');
            opt.value = option.value;
            opt.textContent = option.label;
            if (currentMods.visual && currentMods.visual[key] != null) {
                if (currentMods.visual[key] == option.value) {
                    opt.selected = true;
                }
            }
            select.appendChild(opt);
        });
        select.addEventListener('change', function() {
            applyMod('visual', key, parseInt(this.value));
        });
        div.appendChild(label);
        div.appendChild(select);
        container.appendChild(div);
    }
}
function populateExtras() {
    const container = document.getElementById('extras-options');
    container.innerHTML = '';
    if (!availableMods.extras || availableMods.extras.length === 0) {
        const noExtrasDiv = document.createElement('div');
        noExtrasDiv.className = 'handling-info';
        noExtrasDiv.style.marginTop = '0';
        noExtrasDiv.textContent = 'Este veículo não possui extras disponíveis';
        container.appendChild(noExtrasDiv);
        return;
    }
    availableMods.extras.forEach(extra => {
        const div = document.createElement('div');
        div.className = 'extra-item';
        const label = document.createElement('label');
        label.textContent = extra.label;
        const toggleDiv = document.createElement('label');
        toggleDiv.className = 'toggle-switch';
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.checked = extra.enabled;
        const slider = document.createElement('span');
        slider.className = 'toggle-slider';
        checkbox.onchange = function() {
            applyMod('extras', extra.id, this.checked);
        };
        toggleDiv.appendChild(checkbox);
        toggleDiv.appendChild(slider);
        div.appendChild(label);
        div.appendChild(toggleDiv);
        container.appendChild(div);
    });
}
function populateLightsAndWindows() {
    if(currentMods.neons && currentMods.neons.color) {
            document.getElementById('neon-r').value = currentMods.neons.color.r;
            document.getElementById('val-neon-r').textContent = currentMods.neons.color.r;
            document.getElementById('neon-g').value = currentMods.neons.color.g;
            document.getElementById('val-neon-g').textContent = currentMods.neons.color.g;
            document.getElementById('neon-b').value = currentMods.neons.color.b;
            document.getElementById('val-neon-b').textContent = currentMods.neons.color.b;
        }

        ['r', 'g', 'b'].forEach(c => {
            const el = document.getElementById('neon-' + c);
            if (el) el.oninput = function() {
                document.getElementById('val-neon-' + c).textContent = this.value;
                const r = parseInt(document.getElementById('neon-r').value);
                const g = parseInt(document.getElementById('neon-g').value);
                const b = parseInt(document.getElementById('neon-b').value);
                applyMod('neons', 'color', {r: r, g: g, b: b});
            };
        });
    ['left', 'right', 'front', 'back'].forEach(side => {
        const cb = document.getElementById('neon-' + side);
        if(currentMods.neons && currentMods.neons[side] !== undefined) {
            cb.checked = currentMods.neons[side];
        }
        cb.onchange = function() {
            applyMod('neons', side, this.checked);
        };
    });
    if(currentMods.xenon) {
        document.getElementById('xenon-toggle').checked = currentMods.xenon.enabled;
    }
    document.getElementById('xenon-toggle').onchange = function() {
        applyMod('xenon', 'enabled', this.checked);
    };
    const xenonSelect = document.getElementById('xenon-color');
    xenonSelect.innerHTML = '';
    if(availableMods.xenonColors) {
        availableMods.xenonColors.forEach(c => {
            const opt = document.createElement('option');
            opt.value = c.id;
            opt.textContent = c.label;
            if(currentMods.xenon && currentMods.xenon.color == c.id) {
                opt.selected = true;
            }
            xenonSelect.appendChild(opt);
        });
    }
    xenonSelect.onchange = function() {
        applyMod('xenon', 'color', parseInt(this.value));
    };
    const tintSelect = document.getElementById('window-tint');
    tintSelect.innerHTML = '';
    if(availableMods.windowTints) {
        availableMods.windowTints.forEach(t => {
            const opt = document.createElement('option');
            opt.value = t.id;
            opt.textContent = t.label;
            if(currentMods.windowTint == t.id) {
                opt.selected = true;
            }
            tintSelect.appendChild(opt);
        });
    }
    tintSelect.onchange = function() {
        applyMod('windowtint', null, parseInt(this.value));
    };
    const smokeCb = document.getElementById('smoke-toggle');
    if(smokeCb && currentMods.tyresmoke) {
        smokeCb.checked = currentMods.tyresmoke.enabled;
        smokeCb.onchange = function() { applyMod('tyresmoke', 'enabled', this.checked); };
        if(currentMods.tyresmoke.color) {
            document.getElementById('smoke-r').value = currentMods.tyresmoke.color.r;
            document.getElementById('val-smoke-r').textContent = currentMods.tyresmoke.color.r;
            document.getElementById('smoke-g').value = currentMods.tyresmoke.color.g;
            document.getElementById('val-smoke-g').textContent = currentMods.tyresmoke.color.g;
            document.getElementById('smoke-b').value = currentMods.tyresmoke.color.b;
            document.getElementById('val-smoke-b').textContent = currentMods.tyresmoke.color.b;
        }
        ['r', 'g', 'b'].forEach(c => {
            document.getElementById('smoke-' + c).oninput = function() {
                document.getElementById('val-smoke-' + c).textContent = this.value;
                const r = parseInt(document.getElementById('smoke-r').value);
                const g = parseInt(document.getElementById('smoke-g').value);
                const b = parseInt(document.getElementById('smoke-b').value);
                applyMod('tyresmoke', 'color', {r: r, g: g, b: b});
            };
        });
    }
}
function applyMod(category, modId, value, type = null) {
    const data = {
        category: category,
        modId: modId,
        value: value
    };
    if (type) {
        data.type = type;
    }
    fetch(`https://${GetParentResourceName()}/applyMod`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    });
    if (category === 'performance') {
        if (!currentMods.performance) currentMods.performance = {};
        currentMods.performance[modId] = value;
    } else if (category === 'visual') {
        if (!currentMods.visual) currentMods.visual = {};
        currentMods.visual[modId] = value;
    } else if (category === 'colors') {
        if (!currentMods.colors) currentMods.colors = {};
        if (type === 'primary') currentMods.colors.primary = value;
        else if (type === 'secondary') currentMods.colors.secondary = value;
        else if (type === 'pearlescent') currentMods.colors.pearlescent = value;
        else if (type === 'wheel') currentMods.colors.wheel = value;
        else if (type === 'interior') currentMods.colors.interior = value;
        else if (type === 'dashboard') currentMods.colors.dashboard = value;
    } else if (category === 'wheels') {
        if (!currentMods.wheels) currentMods.wheels = {};
        if (type === 'wheelType') {
            currentMods.wheels.type = value;
        } else {
            currentMods.wheels.variation = value;
        }
    } else if (category === 'extras') {
        if (!currentMods.extras) currentMods.extras = {};
        currentMods.extras[modId] = value;
    }
}
function showResetModal() {
    document.getElementById('reset-modal').classList.remove('hidden');
}
function hideResetModal() {
    document.getElementById('reset-modal').classList.add('hidden');
}
document.getElementById('resetBtn').addEventListener('click', function() {
    showResetModal();
});
document.getElementById('confirmReset').addEventListener('click', function() {
    hideResetModal();
    fetch(`https://${GetParentResourceName()}/resetVehicle`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});
document.getElementById('cancelReset').addEventListener('click', function() {
    hideResetModal();
});
document.getElementById('washBtn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/washVehicle`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});
document.getElementById('repairBtn').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/repairVehicle`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});
document.querySelectorAll('.door-controls .reset-btn').forEach(btn => {
    btn.addEventListener('click', function() {
        const doorId = this.getAttribute('data-door');
        fetch(`https://${GetParentResourceName()}/toggleDoor`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ doorId: doorId })
        });
    });
});
function populateHandling() {
    const container = document.getElementById('handling-options');
    container.innerHTML = '';
    if (!handlingConfig || handlingConfig.length === 0) return;
    handlingConfig.forEach(handling => {
        const div = document.createElement('div');
        div.className = 'handling-item';
        const label = document.createElement('label');
        label.textContent = handling.label;
        const sliderContainer = document.createElement('div');
        sliderContainer.className = 'slider-container';
        const slider = document.createElement('input');
        slider.type = 'range';
        slider.min = handling.min;
        slider.max = handling.max;
        slider.step = handling.step;
        slider.value = currentHandling[handling.id] || handling.default;
        const valueDisplay = document.createElement('span');
        valueDisplay.className = 'value-display';
        valueDisplay.textContent = parseFloat(slider.value).toFixed(2);
        slider.addEventListener('input', function() {
            valueDisplay.textContent = parseFloat(this.value).toFixed(2);
            applyHandling(handling.id, parseFloat(this.value));
        });
        sliderContainer.appendChild(slider);
        sliderContainer.appendChild(valueDisplay);
        div.appendChild(label);
        div.appendChild(sliderContainer);
        container.appendChild(div);
    });
}
function applyHandling(handlingId, value) {
    fetch(`https://${GetParentResourceName()}/applyHandling`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            handlingId: handlingId,
            value: value
        })
    });
    currentHandling[handlingId] = value;
}
function GetParentResourceName() {
    return 'grot_fastmechanic';
}
