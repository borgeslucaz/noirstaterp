export const ZOOM_PRESETS = [1, 2, 5] as const;
export const ZOOM_MIN = ZOOM_PRESETS[0];
export const ZOOM_MAX = ZOOM_PRESETS[ZOOM_PRESETS.length - 1];

export const ZOOM_WHEEL_RATE = 0.0015;
export const ZOOM_KEY_STEP   = 1.15;

export const clampZoom = (z: number) => Math.min(ZOOM_MAX, Math.max(ZOOM_MIN, z));

export const zoomLabel = (z: number) => `${Number.isInteger(z) ? z : z.toFixed(1)}×`;

export function nextZoomPreset(z: number): number {
    const at = ZOOM_PRESETS.findIndex(p => p > z + 0.001);
    return at === -1 ? ZOOM_PRESETS[0] : ZOOM_PRESETS[at];
}
