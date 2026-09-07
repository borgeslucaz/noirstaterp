export const HOME_HOLD_MS   = 450;
export const HOME_HOLD_SLOP = 10;
export const SWIPE_HOME     = 55;
export const SWIPE_SWITCHER = 110;

export type HomeAction = 'home' | 'switcher' | 'none';

export function swipeAction(dy: number, hasOpenApp: boolean, canShowSwitcher: boolean): HomeAction {
    if (dy < SWIPE_HOME) return 'none';
    if (!hasOpenApp) return canShowSwitcher ? 'switcher' : 'home';
    if (dy >= SWIPE_SWITCHER && canShowSwitcher) return 'switcher';
    return 'home';
}

export function holdAction(hasOpenApp: boolean, canShowSwitcher: boolean): HomeAction {
    return hasOpenApp && canShowSwitcher ? 'switcher' : 'none';
}

export function tapAction(hasOpenApp: boolean): HomeAction {
    return hasOpenApp ? 'home' : 'none';
}
