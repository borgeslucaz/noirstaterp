import { atom, useAtom, useAtomValue, useSetAtom } from "jotai";
import { isDevPreview } from "@/utils/misc";

export interface MinimapStateInterface {
  width: number;
  height: number;
  left: number;
  top: number;
  screenWidth?: number;
  screenHeight?: number;
}

const mockMinimapState: MinimapStateInterface = {
  height: 197.64,
  left: 20.0000020265579224,
  top: 800.99999797344208,
  width: 314.496,
};

const minimapState = atom<MinimapStateInterface>(isDevPreview() ? {
  height: mockMinimapState.height * window.innerHeight / 1080,
  width: mockMinimapState.width * window.innerHeight / 1080,
  left: mockMinimapState.left * window.innerHeight / 1080,
  top: mockMinimapState.top * window.innerHeight / 1080,
} : { height: 0, width: 0, left: 0, top: 0 });

export const useMinimapState = () => useAtomValue(minimapState);
export const useSetMinimapState = () => useSetAtom(minimapState);
export const useMinimapStateStore = () => useAtom(minimapState);

// Lua sends game pixels; the NUI viewport can differ (Windows scaling, windowed mode).
export const toViewport = (map: MinimapStateInterface) => {
  const sx = map.screenWidth ? window.innerWidth / map.screenWidth : 1;
  const sy = map.screenHeight ? window.innerHeight / map.screenHeight : 1;
  return { left: map.left * sx, top: map.top * sy, width: map.width * sx, height: map.height * sy };
};

// The drawn map sits 28px right and 38px above the anchor Lua reports (1080p reference,
// measured in game; matches previewOffsetX/Y in utility.positionMinimap).
export const DRAWN_MAP_OFFSET = { left: `${28 / 10.8}vh`, top: `${38.01 / 10.8}vh` };
