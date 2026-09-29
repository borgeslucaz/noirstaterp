import { useNuiEvent } from "@/hooks/useNuiEvent";
import { MinimapStateInterface, useMinimapStateStore } from "@/states/minimap";
import { PlayerStateInterface, usePlayerStateStore } from "@/states/player";
import React, { useCallback } from "preact/compat";
import { LuPlus, LuShield, LuUtensils, LuDroplets, LuBrain, LuMic, LuWaves, LuFootprints } from "react-icons/lu";
import { StatBar } from "./ui/status-bars";
import { HudIndicator, clampPercent, lowLevelTone } from "./ui/hud-indicator";
import { useSkewedStyle, useSkewAmount } from "@/states/skewed-style";
import { isDevPreview } from "@/utils/misc";

// Approved map preview in a 1920x1080 reference; scale with viewport height.
const WEB_MINIMAP_PREVIEW = { top: 786.99, left: 48, width: 314.496, height: 197.64 };

const playerStatesEqual = (previous: PlayerStateInterface, current: PlayerStateInterface) =>
  (Object.keys(current) as Array<keyof PlayerStateInterface>).every((key) => previous[key] === current[key]) &&
  Object.keys(previous).length === Object.keys(current).length;

const minimapStatesEqual = (previous: MinimapStateInterface, current: MinimapStateInterface) =>
  previous.width === current.width && previous.height === current.height &&
  previous.left === current.left && previous.top === current.top;

const translateVoiceMode = (mode?: string) => {
  const voiceModes: Record<string, string> = {
    whisper: "Baixo",
    normal: "Normal",
    shouting: "Gritando",
  };

  return voiceModes[mode?.toLowerCase() ?? ""] ?? mode ?? "—";
};

const PlayerStatus = () => {
  const [player, setPlayerState] = usePlayerStateStore();
  const [minimap, setMinimapState] = useMinimapStateStore();
  const skewedStyle = useSkewedStyle(), skewedAmount = useSkewAmount();
  const handlePlayerStateUpdate = useCallback((newState: PlayerStateInterface) => {
    setPlayerState((prev) => playerStatesEqual(prev, newState) ? prev : newState);
  }, [setPlayerState]);
  useNuiEvent<{ minimap: MinimapStateInterface; player: PlayerStateInterface }>("state::global::set", (data) => {
    handlePlayerStateUpdate(data.player);
    setMinimapState((prev) => minimapStatesEqual(prev, data.minimap) ? prev : data.minimap);
  });
  const health = clampPercent(player.health);
  const voiceMode = translateVoiceMode(player.voiceMode);

  return (
    <>
      {isDevPreview() && <div className="debug-minimap-preview" style={{
        top: `${WEB_MINIMAP_PREVIEW.top / 10.8}vh`, left: `${WEB_MINIMAP_PREVIEW.left / 10.8}vh`,
        width: `${WEB_MINIMAP_PREVIEW.width / 10.8}vh`, height: `${WEB_MINIMAP_PREVIEW.height / 10.8}vh`,
      }} aria-hidden={true}><span>MINIMAPA · PREVIEW WEB</span></div>}
      <div className="player-hud" style={{
        left: `calc(${minimap.left}px + 2.315vh)`,
        // Preserve the 115% scale while matching the visible vitals width to the map.
        "--vitals-width": `${minimap.width / 1.07}px`,
      }}>
        <div className="player-hud-content hud-surface" style={{
          transform: skewedStyle ? `perspective(1000px) rotateY(${skewedAmount}deg) scale(1.15)` : "scale(1.15)",
          transformOrigin: "left bottom",
        }}>
          <div className="player-vitals-column">
            <div className="noir-vitals">
              <StatBar Icon={LuPlus} value={health} color={health <= 10 ? "var(--hud-danger)" : health <= 20 ? "var(--hud-warning)" : "var(--vitals-health)"} aria-label="Vida" data-tone={lowLevelTone(health)} />
              <StatBar Icon={LuShield} value={player.armor} color="var(--vitals-armor)" aria-label="Colete" />
            </div>
            <div className="voice-line" data-speaking={player.mic} aria-label={`Voz: ${voiceMode}, ${player.mic ? "falando" : "em silêncio"}`}>
              <span className="voice-line-icon" aria-hidden={true}><LuMic /></span>
              <span>{voiceMode}</span>
            </div>
          </div>
          <div className="player-indicators">
            <div className="voice-indicator-spacer" aria-hidden={true} />
            {typeof player.hunger === "number" && <HudIndicator Icon={LuUtensils} label="Fome" value={player.hunger} tone={lowLevelTone(player.hunger)} />}
            {typeof player.thirst === "number" && <HudIndicator Icon={LuDroplets} label="Sede" value={player.thirst} tone={lowLevelTone(player.thirst)} />}
            {player.oxygen < 100 && <HudIndicator Icon={LuWaves} label="Ar" value={player.oxygen} tone={lowLevelTone(player.oxygen)} />}
            {player.stamina < 100 && <HudIndicator Icon={LuFootprints} label="Fôlego" value={player.stamina} tone={lowLevelTone(player.stamina)} />}
            {typeof player.stress === "number" && player.stress > 0 && <HudIndicator Icon={LuBrain} label="Estresse" value={player.stress} tone={player.stress >= 80 ? "danger" : player.stress >= 60 ? "warning" : "normal"} />}
          </div>
        </div>
      </div>
    </>
  );
};
export default React.memo(PlayerStatus);
