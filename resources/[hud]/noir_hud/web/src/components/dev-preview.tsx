import { useEffect, useState } from "react";
import { usePlayerStateStore } from "@/states/player";
import { useVehicleStateStore } from "@/states/vehicle";
import { useSetMinimapState } from "@/states/minimap";
import { useSkewedStyleStore, useSkewAmountStore } from "@/states/skewed-style";
import { useCompassLocationStore, useCompassAlwaysStore } from "@/states/compass-location";
import { useHudThemeStore, type HudTheme } from "@/states/hud-theme";

// Imported only by the development build. Never sends game callbacks.
export default function DevPreview() {
  const [background, setBackground] = useState("dark");
  const [player, setPlayer] = usePlayerStateStore();
  const [vehicle, setVehicle] = useVehicleStateStore();
  const setMinimap = useSetMinimapState();
  const [skewed, setSkewed] = useSkewedStyleStore();
  const [skewAmount, setSkewAmount] = useSkewAmountStore();
  const [compassLocation, setCompassLocation] = useCompassLocationStore();
  const [compassAlways, setCompassAlways] = useCompassAlwaysStore();
  const [theme, setTheme] = useHudThemeStore();
  // Mirrors config/shared.lua; APP_LOADED never answers in the browser.
  useEffect(() => {
    setSkewed(false); setSkewAmount(10);
    setCompassLocation("hidden"); setCompassAlways(false);
    const params = new URLSearchParams(location.search);
    if (params.get("tema") === "classico") setTheme("classic");
    if (params.get("skew") === "0") setSkewed(false);
    if (params.get("bussola") === "topo") setCompassLocation("top");
    const preset = params.get("cenario");
    if (preset) scenario(preset);
    const nitro = params.get("nitro");
    if (nitro !== null) setVehicle(prev => ({ ...prev, nos: Math.min(100, Math.max(0, Number(nitro) || 0)) }));
  }, []);
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
      <label>Tema <select value={theme} onChange={e => setTheme(e.currentTarget.value as HudTheme)}>
        <option value="classic">Clássico</option><option value="painel">Painel</option>
      </select></label>
      <label>Cenário <select onChange={e => scenario(e.currentTarget.value)}>
        <option value="current">Atual</option><option value="drive">Dirigindo</option><option value="alert">Alertas</option><option value="walk">A pé</option>
      </select></label>
      <label>Fundo <select value={background} onChange={e => setBackground(e.currentTarget.value)}>
        <option value="dark">Escuro</option><option value="light">Claro</option>
      </select></label>
      <label>Velocidade <input type="range" min={0} max={300} value={vehicle.speed}
        onInput={e => setVehicle(prev => ({ ...prev, speed: Number(e.currentTarget.value) }))} /> {vehicle.speed}</label>
      <label>RPM <input type="range" min={0} max={100} value={vehicle.rpm}
        onInput={e => setVehicle(prev => ({ ...prev, rpm: Number(e.currentTarget.value) }))} /> {vehicle.rpm}</label>
      <label>Farol <select value={vehicle.headlights >= 100 ? "high" : vehicle.headlights > 0 ? "low" : "off"}
        onChange={e => setVehicle(prev => ({ ...prev, headlights: { off: 0, low: 50, high: 100 }[e.currentTarget.value as "off" | "low" | "high"] }))}>
        <option value="off">Desligado</option><option value="low">Baixo</option><option value="high">Alto</option>
      </select></label>
      <label><input type="checkbox" checked={player.isSeatbeltOn} onChange={e => setPlayer(prev => ({ ...prev, isSeatbeltOn: e.currentTarget.checked }))} /> Cinto</label>
      <label>Nitro <input type="range" min={0} max={100} value={vehicle.nos}
        onInput={e => setVehicle(prev => ({ ...prev, nos: Number(e.currentTarget.value) }))} /> {vehicle.nos}</label>
      <button type="button" onClick={() => setVehicle(prev => ({ ...prev, nos: 100 }))}>Nitro 100%</button>
      <label>Unidade <select onChange={e => setVehicle(prev => ({ ...prev, speedUnit: e.currentTarget.value === "mph" ? "mph" : "kph" }))}>
        <option value="kph">km/h</option><option value="mph">MPH</option>
      </select></label>
      <label><input type="checkbox" checked={skewed} onChange={e => setSkewed(e.currentTarget.checked)} /> Skew</label>
      <label>Inclinação <input type="range" min={0} max={30} value={skewAmount} disabled={!skewed}
        onInput={e => setSkewAmount(Number(e.currentTarget.value))} /> {skewAmount}°</label>
      <label>Bússola <select value={compassLocation} onChange={e => setCompassLocation(e.currentTarget.value as typeof compassLocation)}>
        <option value="hidden">Desligada</option><option value="top">Topo</option><option value="bottom">Embaixo</option>
      </select></label>
      <label><input type="checkbox" checked={compassAlways} disabled={compassLocation === "hidden"}
        onChange={e => setCompassAlways(e.currentTarget.checked)} /> Bússola a pé</label>
    </aside>
  </>;
}
