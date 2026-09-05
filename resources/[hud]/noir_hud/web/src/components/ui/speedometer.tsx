import React from "react";
import type { VehicleStateInterface } from "@/states/vehicle";

type Props = Pick<VehicleStateInterface, "speed" | "rpm" | "currentGear" | "speedUnit">;
function point(angle: number, radius = 42) {
  const radians = (angle - 90) * Math.PI / 180;
  return { x: 50 + radius * Math.cos(radians), y: 50 + radius * Math.sin(radians) };
}
function arc(start: number, end: number) {
  const a = point(start), b = point(end);
  return `M ${a.x} ${a.y} A 42 42 0 ${end - start > 180 ? 1 : 0} 1 ${b.x} ${b.y}`;
}
const Speedometer = React.memo(function Speedometer({ speed, rpm, currentGear, speedUnit }: Props) {
  const rpmPercent = Math.min(100, Math.max(0, Number.isFinite(rpm) ? rpm : 0));
  const speedValue = Math.max(0, Math.round(Number.isFinite(speed) ? speed : 0));
  // Lua already converts m/s into the unit sent alongside speed.
  const unit = speedUnit.toLowerCase() === "mph" ? "MPH" : "km/h";
  const tone = rpmPercent >= 90 ? "danger" : rpmPercent >= 85 ? "warning" : "normal";
  return (
    <div className="speedometer" data-tone={tone} aria-label={`Velocidade ${speedValue} ${unit}; marcha ${currentGear || "—"}; RPM ${Math.round(rpmPercent)}%`}>
      <svg viewBox="0 0 100 92" aria-hidden="true">
        <path d={arc(-125, 125)} className="rpm-track" />
        <path d={arc(-125, 125)} className="rpm-fill" pathLength={100}
          strokeDasharray="100" strokeDashoffset={100 - rpmPercent} />
        <path d={arc(100, 125)} className="rpm-redline" />
        {[0, 25, 50, 75, 100].map((value) => {
          const angle = -125 + value * 2.5;
          const a = point(angle, 35), b = point(angle, 38), label = point(angle, 29);
          return <g key={value}>
            <path d={`M ${a.x} ${a.y} L ${b.x} ${b.y}`} className="rpm-tick" />
            {value % 50 === 0 && <text x={label.x} y={label.y} className="rpm-number">{value}</text>}
          </g>;
        })}
      </svg>
      <div className="speedometer-reading">
        <span className="speedometer-speed">{speedValue}</span>
        <div className="speedometer-meta"><span>{unit}</span><span className="speedometer-gear"><b>{currentGear || "—"}</b></span></div>
      </div>
    </div>
  );
});
export default Speedometer;
