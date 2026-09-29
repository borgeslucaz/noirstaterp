import type { IconType } from "react-icons";
export type IndicatorTone = "normal" | "inactive" | "warning" | "danger" | "active";
export const clampPercent = (value: number) => Math.min(100, Math.max(0, Number.isFinite(value) ? value : 0));
export const lowLevelTone = (value: number): IndicatorTone => value <= 10 ? "danger" : value <= 20 ? "warning" : "normal";
interface Props { Icon: IconType; label: string; text?: string; tone?: IndicatorTone; value?: number; }
export function HudIndicator({ Icon, label, text, tone = "normal", value }: Props) {
  const alert = tone === "warning" || tone === "danger";
  return (
    <div className="hud-indicator" data-tone={tone} aria-label={`${label}${text ? `: ${text}` : ""}${alert ? ", atenção" : ""}`}>
      <div className="hud-indicator-symbol" aria-hidden="true"><Icon />{alert && <b className="hud-alert-mark">!</b>}</div>
      {typeof value === "number" && <div className="hud-indicator-track" aria-hidden="true"><span style={{ width: `${clampPercent(value)}%` }} /></div>}
    </div>
  );
}
