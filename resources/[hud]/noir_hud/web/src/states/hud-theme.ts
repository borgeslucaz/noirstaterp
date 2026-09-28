import { atom, useAtom, useAtomValue, useSetAtom } from "jotai";

export type HudTheme = "classic" | "painel";

const hudThemeState = atom<HudTheme>("painel");

export const useHudTheme = () => useAtomValue(hudThemeState);
export const useSetHudTheme = () => useSetAtom(hudThemeState);
export const useHudThemeStore = () => useAtom(hudThemeState);
