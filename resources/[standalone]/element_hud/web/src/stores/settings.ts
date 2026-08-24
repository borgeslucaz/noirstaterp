import { create } from "zustand";

export type PlayerStatusIndicator =
  | "square"
  | "bar"
  | "circle"
  | "segmented"
  | "segmented-bar";

export type VehicleHudStyle =
  | "bars"
  | "speedometer"
  | "speedometer-column";

export type CompassHudStyle = "default" | "compact";

export type PlayerHudPosition =
  | "bottom-left"
  | "top-left"
  | "top-right"
  | "bottom-center";

export type CompassPosition = "top-center" | "bottom-center";
export type HudPosition = { x: number; y: number };
export type HudItemLayout = HudPosition & { scale: number };
export type LayoutEditMode = "all" | "icons" | false;

interface SettingsStore {
  hudDisabled: boolean;
  cinematicBarsHeight: number;
  playerStatusIndicator: PlayerStatusIndicator;
  playerHudPosition: PlayerHudPosition;
  playerHudCustomPosition: HudPosition | false;
  playerHudScale: number;
  playerHudIconLayouts: Record<string, HudItemLayout>;
  layoutEditing: boolean;
  layoutEditMode: LayoutEditMode;
  vehicleHudStyle: VehicleHudStyle;
  compassStyle: CompassHudStyle;
  compassPosition: CompassPosition;

  setHudDisabled: (disabled: boolean) => void;
  setCinematicBarsHeight: (height: number) => void;
  setPlayerStatusIndicator: (indicator: PlayerStatusIndicator) => void;
  setPlayerHudPosition: (position: PlayerHudPosition) => void;
  setPlayerHudCustomPosition: (position: HudPosition | false) => void;
  setPlayerHudScale: (scale: number) => void;
  setPlayerHudIconLayout: (id: string, layout: HudItemLayout) => void;
  setLayoutEditing: (editing: boolean) => void;
  setLayoutEditMode: (mode: LayoutEditMode) => void;
  setVehicleHudStyle: (style: VehicleHudStyle) => void;
  setCompassStyle: (style: CompassHudStyle) => void;
  setCompassPosition: (position: CompassPosition) => void;

  updateSettings: (settings: {
    hudDisabled?: boolean;
    cinematicBarsHeight?: number;
    playerStatusIndicator?: PlayerStatusIndicator;
    playerHudPosition?: PlayerHudPosition;
    playerHudCustomPosition?: HudPosition | false;
    playerHudScale?: number;
    playerHudIconLayouts?: Record<string, HudItemLayout>;
    vehicleHudStyle?: VehicleHudStyle;
    compassStyle?: CompassHudStyle;
    compassPosition?: CompassPosition;
  }) => void;
}

export const settingsStore = create<SettingsStore>((set) => ({
  hudDisabled: false,
  cinematicBarsHeight: 0,
  playerStatusIndicator: "square",
  playerHudPosition: "bottom-left",
  playerHudCustomPosition: false,
  playerHudScale: 1,
  playerHudIconLayouts: {},
  layoutEditing: false,
  layoutEditMode: false,
  vehicleHudStyle: "speedometer-column",
  compassStyle: "default",
  compassPosition: "top-center",

  setHudDisabled: (disabled) => set({ hudDisabled: disabled }),
  setCinematicBarsHeight: (height) => set({ cinematicBarsHeight: height }),
  setPlayerStatusIndicator: (indicator) =>
    set({ playerStatusIndicator: indicator }),
  setPlayerHudPosition: (position) => set({ playerHudPosition: position }),
  setPlayerHudCustomPosition: (position) =>
    set({ playerHudCustomPosition: position }),
  setPlayerHudScale: (scale) => set({ playerHudScale: scale }),
  setPlayerHudIconLayout: (id, layout) =>
    set((state) => ({
      playerHudIconLayouts: { ...state.playerHudIconLayouts, [id]: layout },
    })),
  setLayoutEditing: (editing) => set({ layoutEditing: editing }),
  setLayoutEditMode: (mode) =>
    set({ layoutEditMode: mode, layoutEditing: mode !== false }),
  setVehicleHudStyle: (style) => set({ vehicleHudStyle: style }),
  setCompassStyle: (style) => set({ compassStyle: style }),
  setCompassPosition: (position) => set({ compassPosition: position }),

  updateSettings: (settings) => set((state) => ({ ...state, ...settings })),
}));
