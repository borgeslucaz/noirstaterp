export const STREAMER_HIDE_KEYS = [
    'balance',
    'transactions',
    'card',
    'investments',
    'number',
    'previews',
] as const;

export type StreamerHideKey = typeof STREAMER_HIDE_KEYS[number];

export type StreamerHide = Record<StreamerHideKey, boolean>;

export const STREAMER_HIDE_ALL: StreamerHide = {
    balance:      true,
    transactions: true,
    card:         true,
    investments:  true,
    number:       true,
    previews:     true,
};

export const HIDDEN_TEXT = '••••';

export function normalizeStreamerHide(raw: unknown): StreamerHide {
    const out = { ...STREAMER_HIDE_ALL };
    if (raw && typeof raw === 'object') {
        for (const key of STREAMER_HIDE_KEYS) {
            const v = (raw as Record<string, unknown>)[key];
            if (typeof v === 'boolean') out[key] = v;
        }
    }
    return out;
}
