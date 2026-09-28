import React, { useCallback } from "react";
import type { IconType } from "react-icons";
import { useNuiEvent } from "@/hooks/useNuiEvent";
import { usePlayerState } from "@/states/player";
import { useVehicleStateStore, type VehicleStateInterface } from "@/states/vehicle";
import { clampPercent, lowLevelTone } from "../ui/hud-indicator";
import { LuFuel, LuFlame, LuLightbulb, LuSettings, LuShieldCheck } from "react-icons/lu";
import { useSkewedStyle, useSkewAmount } from "@/states/skewed-style";
import "./painel.css";

const RPM_SEGMENTS = 14;
const REDLINE_FROM = 10;

const vehicleStatesEqual = (previous: VehicleStateInterface, current: VehicleStateInterface) =>
  (Object.keys(current) as Array<keyof VehicleStateInterface>).every((key) => previous[key] === current[key]) &&
  Object.keys(previous).length === Object.keys(current).length;

// Text laid over a hidden `sizer`, so the pill keeps the width of its widest state.
function Fixed({ sizer, text, className }: { sizer: string; text: string | number; className: string }) {
  return <span className={`pnl-fixed ${className}`}><span aria-hidden={true}>{sizer}</span><span>{text}</span></span>;
}

function Pill({ Icon, label, sizer = label, on, tone, fill }: { Icon: IconType; label: string; sizer?: string; on: boolean; tone?: "warning" | "danger"; fill?: number }) {
  const value = typeof fill === "number" ? Math.round(fill) : undefined;
  return (
    <span className="pnl-pill" data-on={on} data-tone={tone}
      style={typeof fill === "number" ? { "--pnl-fill": `${fill}%` } : undefined}>
      <Icon aria-hidden={true} /><Fixed className="pnl-pill-label" sizer={sizer} text={label} />
      {value !== undefined && <Fixed className="pnl-pill-value" sizer="100" text={value} />}
    </span>
  );
}

function Gauge({ Icon, label, value, tone }: { Icon: IconType; label: string; value: number; tone: string }) {
  return (
    <div className="pnl-gauge" data-tone={tone} role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(value)} aria-label={label}>
      <Icon aria-hidden={true} />
      <span className="pnl-gauge-track" aria-hidden={true}><i style={{ width: `${value}%` }} /></span>
    </div>
  );
}

const PainelCarHud = React.memo(function PainelCarHud() {
  const [vehicle, setVehicleState] = useVehicleStateStore();
  const player = usePlayerState();
  const skewedStyle = useSkewedStyle(), skewedAmount = useSkewAmount();
  const handleVehicleStateUpdate = useCallback((newState: VehicleStateInterface) => {
    setVehicleState((prev) => vehicleStatesEqual(prev, newState) ? prev : newState);
  }, [setVehicleState]);
  useNuiEvent<VehicleStateInterface>("state::vehicle::set", handleVehicleStateUpdate);
  if (!player.isInVehicle) return null;

  const fuel = clampPercent(vehicle.fuel), engine = clampPercent(vehicle.engineHealth), nos = clampPercent(vehicle.nos);
  const rpm = clampPercent(vehicle.rpm);
  const lit = Math.round(rpm / 100 * RPM_SEGMENTS);
  // Whole pixels, or the gaps render as a mix of 3 px and 4 px.
  const blockGap = Math.max(2, Math.round(window.innerHeight * 0.0037));
  const block = Math.floor((window.innerHeight * 0.27 - blockGap * (RPM_SEGMENTS - 1)) / RPM_SEGMENTS);
  const speed = Math.max(0, Math.round(Number.isFinite(vehicle.speed) ? vehicle.speed : 0));
  // Lua already converts m/s into the unit sent alongside speed.
  const unit = vehicle.speedUnit.toLowerCase() === "mph" ? "MPH" : "KM/H";
  const engineTone = engine <= 20 ? "danger" : engine <= 40 ? "warning" : vehicle.engineState ? "normal" : "inactive";

  return (
    // Always an object: Preact leaves the old inline transform behind if style becomes undefined.
    <div className="pnl pnl-car" style={{
      transform: skewedStyle ? `perspective(1000px) rotateY(-${skewedAmount}deg)` : "none", transformOrigin: "right bottom",
      right: `${Math.round(window.innerHeight * 0.045)}px`,
    }}>
      <div className="pnl-pills">
        <Pill Icon={LuShieldCheck} label="Cinto" on={player.isSeatbeltOn} tone={!player.isSeatbeltOn && speed > 40 ? "danger" : undefined} />
        <Pill Icon={LuLightbulb} label={vehicle.headlights >= 100 ? "Alto" : "Farol"} sizer="Farol" on={vehicle.headlights > 0} />
        {nos > 0 && <Pill Icon={LuFlame} label="Nitro" on={true} fill={nos} />}
      </div>
      <div className="pnl-speed" aria-label={`Velocidade ${speed} ${unit}; marcha ${vehicle.currentGear || "—"}; RPM ${Math.round(rpm)}%`}>
        <span className="pnl-speed-value">{speed}</span>
        <span className="pnl-speed-meta">
          <span className="pnl-gear">{vehicle.currentGear || "N"}</span>
          <small>{unit}</small>
        </span>
      </div>
      <div className="pnl-rpm" aria-hidden={true}>
        <div className="pnl-rpm-blocks" style={{ gridTemplateColumns: `repeat(${RPM_SEGMENTS}, ${block}px)`, gap: `${blockGap}px` }}>
          {Array.from({ length: RPM_SEGMENTS }, (_, i) => (
            <i key={i} data-on={i < lit} data-red={i >= REDLINE_FROM} />
          ))}
        </div>
        <span className="pnl-rpm-line"><i style={{ width: `${rpm}%` }} /></span>
      </div>
      <div className="pnl-gauges">
        <Gauge Icon={LuFuel} label="Combustível" value={fuel} tone={lowLevelTone(fuel)} />
        <Gauge Icon={LuSettings} label={vehicle.engineState ? "Motor ligado" : "Motor desligado"} value={engine} tone={engineTone} />
      </div>
    </div>
  );
});
export default PainelCarHud;
