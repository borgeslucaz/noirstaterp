import { useCallback, useEffect, useRef, useState } from 'react';

// Load-on-mount for async data: guards against post-unmount setState and
// re-runs when `deps` change, replacing the hand-rolled cancelled-flag effect.
// The loader resolves null on failure (the apiData convention) — null neither
// stores nor fires onData, so the previous data survives a failed refetch.
// Route through an app's api helper (not raw fetchNui) to keep its dev mocks.
//
// `settled` turns true once a load has finished, success or failure, and never
// goes back. Gate an empty state on it: `data` alone is null both before the
// first load AND after one that failed, so a list keyed on it flashes "nothing
// here" for a frame on every mount. It is deliberately not reset on refetch —
// the previous data is still on screen, so there is nothing to suppress.
export function useAsyncData<T>(
    load: () => Promise<T | null>,
    deps: readonly unknown[],
    opts?: { enabled?: boolean; onData?: (data: T) => void },
): { data: T | null; loading: boolean; settled: boolean; refetch: () => void } {
    const enabled = opts?.enabled !== false;

    const [data, setData]       = useState<T | null>(null);
    const [loading, setLoading] = useState(enabled);
    const [settled, setSettled] = useState(false);
    const [nonce, setNonce]     = useState(0);

    const loadRef = useRef(load);
    loadRef.current = load;
    const onDataRef = useRef(opts?.onData);
    onDataRef.current = opts?.onData;

    useEffect(() => {
        if (!enabled) { setSettled(true); return; }
        let cancelled = false;
        setLoading(true);
        loadRef.current()
            .then(d => {
                if (cancelled) return;
                setLoading(false);
                setSettled(true);
                if (d !== null) { setData(d); onDataRef.current?.(d); }
            })
            .catch(() => { if (!cancelled) { setLoading(false); setSettled(true); } });
        return () => { cancelled = true; };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [enabled, nonce, ...deps]);

    const refetch = useCallback(() => setNonce(n => n + 1), []);
    return { data, loading, settled, refetch };
}
