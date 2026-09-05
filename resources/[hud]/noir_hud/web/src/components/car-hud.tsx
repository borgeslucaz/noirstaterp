import React, { useCallback } from "react";
import { useNuiEvent } from "@/hooks/useNuiEvent";
import { usePlayerState } from "@/states/player";
import { useVehicleStateStore, type VehicleStateInterface } from "@/states/vehicle";
import Speedometer from "./ui/speedometer";
import { HudIndicator, clampPercent, lowLevelTone } from "./ui/hud-indicator";
import { LuFuel, LuFlame, LuLightbulb, LuSettings, LuShieldCheck } from "react-icons/lu";
import { useSkewedStyle, useSkewAmount } from "@/states/skewed-style";

const vehicleStatesEqual = (previous: VehicleStateInterface, current: VehicleStateInterface) =>
  (Object.keys(current) as Array<keyof VehicleStateInterface>).every((key) => previous[key] === current[key]) &&
  Object.keys(previous).length === Object.keys(current).length;

const CarHud = React.memo(function CarHud() {
  const [vehicle, setVehicleState] = useVehicleStateStore();
  const player = usePlayerState();
  const skewedStyle = useSkewedStyle();
  const skewedAmount = useSkewAmount();
  const handleVehicleStateUpdate = useCallback((newState: VehicleStateInterface) => {
    setVehicleState((prev) => vehicleStatesEqual(prev, newState) ? prev : newState);
  }, [setVehicleState]);
  useNuiEvent<VehicleStateInterface>("state::vehicle::set", handleVehicleStateUpdate);
  if (!player.isInVehicle) return null;
  const fuel = clampPercent(vehicle.fuel), engine = clampPercent(vehicle.engineHealth), nos = clampPercent(vehicle.nos);
  const engineTone = engine <= 20 ? "danger" : engine <= 40 ? "warning" : vehicle.engineState ? "normal" : "inactive";
  return (
    <div className="car-hud hud-surface" style={skewedStyle ? {
      transform: `perspective(1000px) rotateY(-${skewedAmount}deg)`, transformOrigin: "right bottom",
    } : undefined}>
      <Speedometer speed={vehicle.speed} rpm={vehicle.rpm} currentGear={vehicle.currentGear} speedUnit={vehicle.speedUnit} />
      <div className="vehicle-indicators">
        <HudIndicator Icon={LuFuel} label="Combustível" value={fuel} tone={lowLevelTone(fuel)} />
        <HudIndicator Icon={LuSettings} label={vehicle.engineState ? "Motor ligado" : "Motor desligado"} value={engine} tone={engineTone} />
        <HudIndicator Icon={LuLightbulb} label={vehicle.headlights >= 100 ? "Farol alto" : vehicle.headlights > 0 ? "Farol baixo" : "Farol desligado"} tone={vehicle.headlights > 0 ? "normal" : "inactive"} />
        <HudIndicator Icon={LuShieldCheck} label={player.isSeatbeltOn ? "Cinto preso" : "Cinto solto"} tone={player.isSeatbeltOn ? "active" : "inactive"} />
        <HudIndicator Icon={LuFlame} label="Nitro" value={nos} tone={nos > 0 ? "normal" : "inactive"} />
      </div>
    </div>
  );
});
export default CarHud;
