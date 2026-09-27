import React from "react";
import { isEnvBrowser } from "../utils/misc";
import { debugData } from "../utils/debugData";
import { debugDepot, debugGarage, defaultVehicles, depotVehicles } from "../debug/data";

const open = (garage: typeof debugGarage, vehicles: typeof defaultVehicles) => {
    debugData([{ action: 'setVisible', data: { visible: true, vehicles, garage } }], 0);
};

// Teste de interface: alterna entre o tema noir (padrao) e o tema "rua" so no navegador.
const THEME_KEY = 'garage_theme';
const applyTheme = (theme: string | null) => {
    if (theme === 'street') document.documentElement.dataset.garageTheme = 'street';
    else delete document.documentElement.dataset.garageTheme;
};
try { applyTheme(localStorage.getItem(THEME_KEY)); } catch { /* sem localStorage: fica no noir */ }

const toggleTheme = () => {
    const next = document.documentElement.dataset.garageTheme === 'street' ? null : 'street';
    applyTheme(next);
    try {
        if (next) localStorage.setItem(THEME_KEY, next);
        else localStorage.removeItem(THEME_KEY);
    } catch { /* so vale ate recarregar */ }
};

/** Botoes do preview no navegador (npm run dev); no jogo nao aparecem. */
const GarageDev: React.FC = () => {
    if (!isEnvBrowser()) return null;
    return (
        <div style={{ position: 'fixed', bottom: 20, left: 20, zIndex: 9999, display: 'flex', gap: 8 }}>
            <button type="button" className="button button--small" onClick={() => open(debugGarage, defaultVehicles)}>Abrir garagem</button>
            <button type="button" className="button button--small" onClick={() => open(debugDepot, depotVehicles)}>Abrir pátio</button>
            <button type="button" className="button button--small" onClick={toggleTheme}>Trocar tema</button>
        </div>
    );
};

export default GarageDev;
