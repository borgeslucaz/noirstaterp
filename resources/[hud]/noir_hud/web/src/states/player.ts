import { atom, useAtom, useAtomValue, useSetAtom } from "jotai";
import { isDevPreview } from "@/utils/misc";

export interface PlayerStateInterface {
  health: number;
  armor: number;
  hunger?: number;
  thirst?: number;
  stress: number | string;
  oxygen: number;
  stamina: number;
  streetLabel: string;
  areaLabel: string;
  heading: string;
  isSeatbeltOn: boolean;
  isInVehicle: boolean;
  mic : boolean;
  voice : number;
  voiceMode?: string;
}

const mockPlayerState: PlayerStateInterface = {
  health: 100,
  armor: 100,
  hunger: 50,
  thirst: 100,
  oxygen: 100,
  stamina: 100,
  stress: 0,
  voice : 50,
  voiceMode: "Normal",
  streetLabel: "Downtown Vinewood",
  areaLabel: "Vinewood Blvd",
  heading: "NW",
  isSeatbeltOn: false,
  isInVehicle: true,
  mic: true,
};

const playerState = atom<PlayerStateInterface>(isDevPreview() ? mockPlayerState : {
  health: 0, armor: 0, oxygen: 100, stamina: 100, stress: 0, voice: 0, voiceMode: undefined,
  streetLabel: "", areaLabel: "", heading: "", isSeatbeltOn: false, isInVehicle: false, mic: false,
});

export const usePlayerState = () => useAtomValue(playerState);
export const useSetPlayerState = () => useSetAtom(playerState);
export const usePlayerStateStore = () => useAtom(playerState);
