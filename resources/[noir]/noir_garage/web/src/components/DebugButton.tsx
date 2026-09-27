import React from "react";
import { isEnvBrowser } from "../utils/misc";
import { debugData } from "../utils/debugData";
import { debugDepot, debugEditorGarages, debugGarage, defaultVehicles, depotVehicles } from "../debug/data";

const open = (garage: typeof debugGarage, vehicles: typeof defaultVehicles) => {
    debugData([{ action: 'setVisible', data: { visible: true, vehicles, garage } }], 0);
};

/** Botoes do preview no navegador (npm run dev); no jogo nao aparecem. */
const GarageDev: React.FC = () => {
    if (!isEnvBrowser()) return null;
    return (
        <div style={{ position: 'fixed', bottom: 20, left: 20, zIndex: 9999, display: 'flex', gap: 8 }}>
            <button type="button" className="button button--small" onClick={() => open(debugGarage, defaultVehicles)}>Abrir garagem</button>
            <button type="button" className="button button--small" onClick={() => open(debugDepot, depotVehicles)}>Abrir pátio</button>
            <button
                type="button"
                className="button button--small"
                onClick={() => debugData([{ action: 'editor', data: { visible: true, garages: debugEditorGarages } }], 0)}
            >
                Abrir editor
            </button>
        </div>
    );
};

export default GarageDev;
