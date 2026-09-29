const inflight = new Map<string, { at: number; p: Promise<unknown> }>();

const TTL_MS = 6000;

export function warm<T>(key: string, load: () => Promise<T>): Promise<T> {
    const hit = inflight.get(key);
    if (hit && performance.now() - hit.at < TTL_MS) return hit.p as Promise<T>;
    const p = load();
    inflight.set(key, { at: performance.now(), p });
    return p;
}
