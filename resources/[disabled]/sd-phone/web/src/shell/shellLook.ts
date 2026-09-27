import { readJson, writeJson } from '@/lib/storage';

export type DockStyle = 'glass' | 'tinted' | 'solid' | 'outline' | 'clear' | 'hidden';
export type OpenAnim  = 'slide' | 'fade' | 'pop' | 'flip';

export const DOCK_STYLES: DockStyle[] = ['glass', 'tinted', 'solid', 'outline', 'clear', 'hidden'];
export const OPEN_ANIMS:  OpenAnim[]  = ['slide', 'fade', 'pop', 'flip'];

export interface ShellLook {
    dockStyle:         DockStyle;
    openAnim:          OpenAnim;
    wallpaperParallax: boolean;
}

export const DEFAULT_SHELL_LOOK: ShellLook = {
    dockStyle:         'glass',
    openAnim:          'slide',
    wallpaperParallax: true,
};

const SHELL_LOOK_KEY = 'sd-phone:shellLook';

export const PARALLAX_SHIFT = 16;
export const PARALLAX_SCALE = 1 + (PARALLAX_SHIFT * 2) / 430;

export function isDockStyle(v: unknown): v is DockStyle {
    return typeof v === 'string' && (DOCK_STYLES as string[]).includes(v);
}

export function isOpenAnim(v: unknown): v is OpenAnim {
    return typeof v === 'string' && (OPEN_ANIMS as string[]).includes(v);
}

export function normalizeLook(v: unknown): ShellLook {
    const src = (typeof v === 'object' && v !== null ? v : {}) as Partial<ShellLook>;
    return {
        dockStyle:         isDockStyle(src.dockStyle) ? src.dockStyle : DEFAULT_SHELL_LOOK.dockStyle,
        openAnim:          isOpenAnim(src.openAnim)   ? src.openAnim  : DEFAULT_SHELL_LOOK.openAnim,
        wallpaperParallax: typeof src.wallpaperParallax === 'boolean'
            ? src.wallpaperParallax
            : DEFAULT_SHELL_LOOK.wallpaperParallax,
    };
}

export function loadShellLookLocal(): ShellLook {
    return normalizeLook(readJson<unknown>(SHELL_LOOK_KEY));
}

export function saveShellLookLocal(look: ShellLook): void {
    writeJson(SHELL_LOOK_KEY, look);
}
