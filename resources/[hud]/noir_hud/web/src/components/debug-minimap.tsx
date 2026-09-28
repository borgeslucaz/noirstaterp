import { useState } from "react";
import { useNuiEvent } from "@/hooks/useNuiEvent";
import { useMinimapState, toViewport, DRAWN_MAP_OFFSET } from "@/states/minimap";
import { fetchNui } from "@/utils/fetchNui";

interface DebugInfo { enabled: boolean; aspect: number; safezone: number; }

// Toggled by /hudmapa: cyan outline = where the NUI believes the drawn map is.
export default function DebugMinimap() {
  const [info, setInfo] = useState<DebugInfo | null>(null);
  const map = useMinimapState();
  useNuiEvent<DebugInfo>("debug::minimap", (data) => {
    setInfo(data.enabled ? data : null);
    if (data.enabled) fetchNui("debug::viewport", { width: window.innerWidth, height: window.innerHeight, dpr: window.devicePixelRatio });
  });
  if (!info) return null;
  const vp = toViewport(map);
  const f = (n: number) => n.toFixed(1);
  return <>
    <div style={{
      position: "fixed", zIndex: 60, pointerEvents: "none", border: "2px solid #00e5ff",
      left: `calc(${vp.left}px + ${DRAWN_MAP_OFFSET.left})`, top: `calc(${vp.top}px - ${DRAWN_MAP_OFFSET.top})`,
      width: `${vp.width}px`, height: `${vp.height}px`,
    }} />
    <pre style={{
      position: "fixed", zIndex: 60, top: "1vh", right: "1vh", margin: 0, padding: "8px 10px",
      background: "rgba(0,0,0,0.8)", color: "#fff", font: "12px/1.4 monospace", pointerEvents: "none",
    }}>{[
      "HUDMAPA  vermelho=Lua  ciano=HUD",
      `jogo ${map.screenWidth ?? "?"}x${map.screenHeight ?? "?"}  aspect ${info.aspect.toFixed(4)}  safezone ${info.safezone.toFixed(4)}`,
      `NUI  ${window.innerWidth}x${window.innerHeight}  dpr ${window.devicePixelRatio}`,
      `Lua  left ${f(map.left)} top ${f(map.top)} w ${f(map.width)} h ${f(map.height)}`,
      `NUI  left ${f(vp.left)} top ${f(vp.top)} w ${f(vp.width)} h ${f(vp.height)}`,
    ].join("\n")}</pre>
  </>;
}
