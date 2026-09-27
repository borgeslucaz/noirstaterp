import { readJson, writeJson } from '@/lib/storage';

export interface PhoneTilt {
    turn: number;
    lean: number;
}

export const TILT_LIMIT = 25;

export const DEFAULT_PHONE_TILT: PhoneTilt = { turn: 0, lean: 0 };

const PHONE_TILT_KEY = 'sd-phone:phoneTilt';

const DEPTH_RATIO = 2.2;

export function clampTiltAngle(v: unknown): number {
    const n = typeof v === 'number' ? v : Number.parseFloat(String(v ?? ''));
    if (!Number.isFinite(n)) return 0;
    return Math.min(TILT_LIMIT, Math.max(-TILT_LIMIT, Math.round(n)));
}

export function normalizeTilt(v: unknown): PhoneTilt {
    const src = (typeof v === 'object' && v !== null ? v : {}) as Partial<Record<keyof PhoneTilt, unknown>>;
    return { turn: clampTiltAngle(src.turn), lean: clampTiltAngle(src.lean) };
}

export function isTilted(tilt: PhoneTilt): boolean {
    return tilt.turn !== 0 || tilt.lean !== 0;
}

export function tiltTransform(tilt: PhoneTilt, height: number): string | undefined {
    if (!isTilted(tilt)) return undefined;
    const depth = Math.round(height * DEPTH_RATIO);
    return `perspective(${depth}px) rotateY(${tilt.turn}deg) rotateX(${tilt.lean}deg)`;
}

export function loadPhoneTiltLocal(): PhoneTilt {
    return normalizeTilt(readJson<unknown>(PHONE_TILT_KEY));
}

export function savePhoneTiltLocal(tilt: PhoneTilt): void {
    writeJson(PHONE_TILT_KEY, tilt);
}
