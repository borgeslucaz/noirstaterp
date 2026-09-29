import { t } from '@/i18n';

export interface CameraFilter {
    id:  string;
    css: string;
}

export const FILTER_SVG_ID = 'sdCameraFilters';

export const CAMERA_FILTERS: readonly CameraFilter[] = [
    { id: 'original',      css: 'none' },

    { id: 'vivid',         css: 'saturate(1.5) contrast(1.1)' },
    { id: 'vividWarm',     css: 'saturate(1.45) contrast(1.08) sepia(0.14) hue-rotate(-6deg)' },
    { id: 'vividCool',     css: 'saturate(1.45) contrast(1.08) hue-rotate(10deg) brightness(1.03)' },
    { id: 'dramatic',      css: 'contrast(1.35) saturate(0.85) brightness(0.95)' },
    { id: 'dramaticWarm',  css: 'contrast(1.3) saturate(0.9) sepia(0.2) brightness(0.96)' },
    { id: 'dramaticCool',  css: 'contrast(1.3) saturate(0.88) hue-rotate(14deg) brightness(0.95)' },
    { id: 'mono',          css: 'grayscale(1) contrast(1.08)' },
    { id: 'silvertone',    css: 'grayscale(1) sepia(0.16) contrast(0.96) brightness(1.08)' },
    { id: 'noir',          css: 'grayscale(1) contrast(1.45) brightness(0.9)' },

    { id: 'negative',      css: 'invert(1) hue-rotate(180deg) saturate(1.2)' },
    { id: 'thermal',       css: 'url(#sdfThermal)' },
    { id: 'nightVision',   css: 'url(#sdfNightVision)' },
    { id: 'infrared',      css: 'url(#sdfInfrared)' },
    { id: 'duotone',       css: 'url(#sdfDuotone)' },
    { id: 'poster',        css: 'url(#sdfPoster)' },
    { id: 'blueprint',     css: 'url(#sdfBlueprint)' },
    { id: 'acid',          css: 'saturate(6) hue-rotate(150deg) contrast(1.6)' },
    { id: 'toxic',         css: 'sepia(1) hue-rotate(65deg) saturate(6) contrast(1.35)' },
    { id: 'bleach',        css: 'contrast(2.3) brightness(1.28) saturate(0.35)' },
    { id: 'dream',         css: 'url(#sdfDream)' },
    { id: 'vhs',           css: 'url(#sdfVhs)' },
    { id: 'sunburst',      css: 'sepia(1) saturate(5) hue-rotate(-25deg) contrast(1.25) brightness(1.05)' },
    { id: 'frost',         css: 'url(#sdfFrost)' },
    { id: 'ember',         css: 'url(#sdfEmber)' },
] as const;

export function filterLabel(id: string): string {
    switch (id) {
        case 'vivid':        return t('camera.filterVivid', 'Vivid');
        case 'vividWarm':    return t('camera.filterVividWarm', 'Vivid Warm');
        case 'vividCool':    return t('camera.filterVividCool', 'Vivid Cool');
        case 'dramatic':     return t('camera.filterDramatic', 'Dramatic');
        case 'dramaticWarm': return t('camera.filterDramaticWarm', 'Dramatic Warm');
        case 'dramaticCool': return t('camera.filterDramaticCool', 'Dramatic Cool');
        case 'mono':         return t('camera.filterMono', 'Mono');
        case 'silvertone':   return t('camera.filterSilvertone', 'Silvertone');
        case 'noir':         return t('camera.filterNoir', 'Noir');
        case 'negative':     return t('camera.filterNegative', 'Negative');
        case 'thermal':      return t('camera.filterThermal', 'Thermal');
        case 'nightVision':  return t('camera.filterNightVision', 'Night Vision');
        case 'infrared':     return t('camera.filterInfrared', 'Infrared');
        case 'duotone':      return t('camera.filterDuotone', 'Duotone');
        case 'poster':       return t('camera.filterPoster', 'Poster');
        case 'blueprint':    return t('camera.filterBlueprint', 'Blueprint');
        case 'acid':         return t('camera.filterAcid', 'Acid');
        case 'toxic':        return t('camera.filterToxic', 'Toxic');
        case 'bleach':       return t('camera.filterBleach', 'Bleach');
        case 'dream':        return t('camera.filterDream', 'Dream');
        case 'vhs':          return t('camera.filterVhs', 'VHS');
        case 'sunburst':     return t('camera.filterSunburst', 'Sunburst');
        case 'frost':        return t('camera.filterFrost', 'Frost');
        case 'ember':        return t('camera.filterEmber', 'Ember');
        default:             return t('camera.filterOriginal', 'Original');
    }
}

export function filterCss(id: string): string {
    return CAMERA_FILTERS.find(f => f.id === id)?.css ?? 'none';
}
