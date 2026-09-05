import { atom, useAtom, useAtomValue, useSetAtom } from "jotai";
import { isDevPreview } from "@/utils/misc";

export interface MinimapStateInterface {
  width: number;
  height: number;
  left: number;
  top: number;
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
