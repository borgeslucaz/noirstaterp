import { useNuiEvent } from "@/hooks/useNuiEvent";
import { MinimapStateInterface, useMinimapStateStore, toViewport, DRAWN_MAP_OFFSET } from "@/states/minimap";
import { PlayerStateInterface, usePlayerStateStore } from "@/states/player";
import React, { useCallback } from "preact/compat";
import type { IconType } from "react-icons";
import { LuUtensils, LuDroplets, LuBrain, LuMic, LuMicOff, LuWaves, LuFootprints, LuNavigation, LuMapPin } from "react-icons/lu";
import { TiHeartFullOutline } from "react-icons/ti";
import { clampPercent, lowLevelTone, type IndicatorTone } from "../ui/hud-indicator";
import { useSkewedStyle, useSkewAmount } from "@/states/skewed-style";
import { useCompassLocation, useCompassAlways } from "@/states/compass-location";
import { isDevPreview } from "@/utils/misc";
import "./painel.css";

// Same 1920x1080 reference the classic theme uses for the fake map.
// Mirrors the in-game offset (DRAWN_MAP_OFFSET): reported anchor 801 - 38.01.
const WEB_MINIMAP_PREVIEW = { top: 762.99, left: 48, width: 314.496, height: 197.64 };

const playerStatesEqual = (previous: PlayerStateInterface, current: PlayerStateInterface) =>
  (Object.keys(current) as Array<keyof PlayerStateInterface>).every((key) => previous[key] === current[key]) &&
  Object.keys(previous).length === Object.keys(current).length;

const minimapStatesEqual = (previous: MinimapStateInterface, current: MinimapStateInterface) =>
  previous.width === current.width && previous.height === current.height &&
  previous.left === current.left && previous.top === current.top &&
  previous.screenWidth === current.screenWidth && previous.screenHeight === current.screenHeight;

const VOICE_MODES: Record<string, { label: string; level: number }> = {
  whisper: { label: "Baixo", level: 1 },
  normal: { label: "Normal", level: 2 },
  shouting: { label: "Gritando", level: 3 },
};

function Status({ Icon, label, value, color, tone }: { Icon: IconType; label: string; value: number; color: string; tone: IndicatorTone }) {
  const alert = tone === "warning" || tone === "danger";
  return (
    <div className="pnl-status" data-tone={tone} style={{ "--pnl-accent": color }}
      role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(value)} aria-label={`${label}${alert ? ", atenção" : ""}`}>
      <span className="pnl-status-icon" aria-hidden={true}><Icon /></span>
      <span className="pnl-status-bar" aria-hidden={true}><i style={{ height: `${clampPercent(value)}%` }} /></span>
    </div>
  );
}

const PainelPlayerStatus = () => {
  const [player, setPlayerState] = usePlayerStateStore();
  const [minimapState, setMinimapState] = useMinimapStateStore();
  const minimap = toViewport(minimapState);
  const skewedStyle = useSkewedStyle(), skewedAmount = useSkewAmount();
  const compassLocation = useCompassLocation(), compassAlways = useCompassAlways();
  const handlePlayerStateUpdate = useCallback((newState: PlayerStateInterface) => {
    setPlayerState((prev) => playerStatesEqual(prev, newState) ? prev : newState);
  }, [setPlayerState]);
  useNuiEvent<{ minimap: MinimapStateInterface; player: PlayerStateInterface }>("state::global::set", (data) => {
    handlePlayerStateUpdate(data.player);
    setMinimapState((prev) => minimapStatesEqual(prev, data.minimap) ? prev : data.minimap);
  });

  const health = clampPercent(player.health), armor = clampPercent(player.armor);
  const healthTone = lowLevelTone(health);
  const voice = VOICE_MODES[player.voiceMode?.toLowerCase() ?? ""] ?? { label: player.voiceMode ?? "—", level: 0 };
  const stress = typeof player.stress === "number" ? player.stress : 0;
  const showLocation = compassLocation !== "hidden" && (compassAlways || player.isInVehicle);
  const skew = skewedStyle ? `perspective(1000px) rotateY(${skewedAmount}deg)` : "none";

  return (
    <>
      {isDevPreview() && <div className="debug-minimap-preview" style={{
        top: `${WEB_MINIMAP_PREVIEW.top / 10.8}vh`, left: `${WEB_MINIMAP_PREVIEW.left / 10.8}vh`,
        width: `${WEB_MINIMAP_PREVIEW.width / 10.8}vh`, height: `${WEB_MINIMAP_PREVIEW.height / 10.8}vh`,
      }} aria-hidden={true}><span>MINIMAPA · PREVIEW WEB</span></div>}
      {showLocation && <div className="pnl pnl-top" style={{
        left: `calc(${minimap.left}px + ${DRAWN_MAP_OFFSET.left})`,
        // 0.8vh gap above the drawn map.
        bottom: `calc(100vh - ${minimap.top}px + ${DRAWN_MAP_OFFSET.top} + 0.8vh)`,
        transform: skew,
      }}>
        <div className="pnl-info">
          <span className="pnl-info-icon" aria-hidden={true}><LuNavigation /></span>
          <div><b>{player.heading || "—"}</b><small>Direção</small></div>
        </div>
        <div className="pnl-info">
          <span className="pnl-info-icon" aria-hidden={true}><LuMapPin /></span>
          <div><b>{player.streetLabel || "—"}</b><small>{player.areaLabel}</small></div>
        </div>
      </div>}

      <div className="pnl pnl-player" style={{
        left: `calc(${minimap.left}px + ${DRAWN_MAP_OFFSET.left})`,
        // 1.3vh gap below the drawn map.
        top: `calc(${minimap.top + minimap.height}px - ${DRAWN_MAP_OFFSET.top} + 1.3vh)`,
        width: `${minimap.width}px`,
        transform: skew,
      }}>
        <div className="pnl-bars">
          <div className="pnl-armor" role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(armor)} aria-label="Colete">
            {[0, 1, 2, 3].map((i) => (
              <span key={i}><i style={{ width: `${Math.min(100, Math.max(0, (armor - i * 25) * 4))}%` }} /></span>
            ))}
          </div>
          <div className="pnl-health" data-tone={healthTone}>
            <span className="pnl-health-icon" aria-hidden={true}><TiHeartFullOutline /></span>
            <span className="pnl-health-value">{Math.round(health)}</span>
            <div className="pnl-health-track" role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(health)} aria-label="Vida">
              <i style={{ width: `${health}%` }} />
            </div>
          </div>

          <div className="pnl-statuses">
            {typeof player.hunger === "number" && <Status Icon={LuUtensils} label="Fome" value={player.hunger} color="var(--pnl-hunger)" tone={lowLevelTone(player.hunger)} />}
            {typeof player.thirst === "number" && <Status Icon={LuDroplets} label="Sede" value={player.thirst} color="var(--pnl-thirst)" tone={lowLevelTone(player.thirst)} />}
            {player.oxygen < 100 && <Status Icon={LuWaves} label="Ar" value={player.oxygen} color="var(--pnl-oxygen)" tone={lowLevelTone(player.oxygen)} />}
            {player.stamina < 100 && <Status Icon={LuFootprints} label="Fôlego" value={player.stamina} color="var(--pnl-stamina)" tone={lowLevelTone(player.stamina)} />}
            {stress > 0 && <Status Icon={LuBrain} label="Estresse" value={stress} color="var(--pnl-stress)" tone={stress >= 80 ? "danger" : stress >= 60 ? "warning" : "normal"} />}
          </div>
        </div>
        <div className="pnl-voice" data-speaking={player.mic} aria-label={`Voz: ${voice.label}, ${player.mic ? "falando" : "em silêncio"}`}>
          <span className="pnl-voice-badge" aria-hidden={true}>{player.mic ? <LuMic /> : <LuMicOff />}</span>
          <span className="pnl-voice-level" aria-hidden={true}>
            {[1, 2, 3].map((i) => <i key={i} data-on={i <= voice.level} />)}
          </span>
          <span className="pnl-voice-label">{voice.label}</span>
        </div>
      </div>
    </>
  );
};
export default React.memo(PainelPlayerStatus);
