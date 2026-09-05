import { useEffect, useState } from "react";
import { usePlayerStateStore } from "@/states/player";
import { useVehicleStateStore } from "@/states/vehicle";
import { useSetMinimapState } from "@/states/minimap";

// Imported only by the development build. Never sends game callbacks.
export default function DevPreview() {
  const [background, setBackground] = useState("dark");
  const [, setPlayer] = usePlayerStateStore();
  const [, setVehicle] = useVehicleStateStore();
  const setMinimap = useSetMinimapState();
  useEffect(() => {
    const resize = () => {
      const scale = window.innerHeight / 1080;
      setMinimap({ top: 801 * scale, left: 20 * scale, width: 314.496 * scale, height: 197.64 * scale });
    };
    resize();
    window.addEventListener("resize", resize);
    return () => window.removeEventListener("resize", resize);
  }, [setMinimap]);

  function scenario(name: string) {
    const alert = name === "alert";
    setPlayer(prev => ({ ...prev, health: alert ? 8 : 100, armor: alert ? 0 : 50,
      hunger: alert ? 15 : 65, thirst: alert ? 8 : 80, oxygen: alert ? 12 : 100,
      stamina: alert ? 18 : 100, stress: alert ? 90 : 0, mic: !alert, voice: alert ? 15 : 50,
      voiceMode: alert ? "Whisper" : "Normal",
      isInVehicle: name !== "walk", isSeatbeltOn: !alert }));
    setVehicle(prev => ({ ...prev, speed: alert ? 143 : 86, rpm: alert ? 96 : 55,
      currentGear: alert ? "5" : "3", fuel: alert ? 8 : 70, engineHealth: alert ? 15 : 95,
      engineState: true, nos: alert ? 0 : 40, headlights: alert ? 100 : 0 }));
  }
  return <>
    <div className="dev-preview-backdrop" data-background={background} />
    <aside className="dev-preview-controls">
      <strong>PREVIEW HUD</strong>
      <label>Cenário <select onChange={e => scenario(e.currentTarget.value)}>
        <option value="current">Atual</option><option value="drive">Dirigindo</option><option value="alert">Alertas</option><option value="walk">A pé</option>
      </select></label>
      <label>Fundo <select value={background} onChange={e => setBackground(e.currentTarget.value)}>
        <option value="dark">Escuro</option><option value="light">Claro</option>
      </select></label>
      <label>Unidade <select onChange={e => setVehicle(prev => ({ ...prev, speedUnit: e.currentTarget.value === "mph" ? "mph" : "kph" }))}>
        <option value="kph">km/h</option><option value="mph">MPH</option>
      </select></label>
    </aside>
  </>;
}
