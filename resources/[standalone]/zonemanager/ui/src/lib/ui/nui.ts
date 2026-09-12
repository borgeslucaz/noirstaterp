// Framework-agnostic NUI runtime: the cfx <-> CEF bridge + the rem scaler.
// Svelte lifecycle glue lives in ./svelte.

declare global {
	interface Window {
		invokeNative?: (action: string, ...args: unknown[]) => void;
		GetParentResourceName?: () => string;
	}
}

// True under vite dev (plain browser), false inside cfx CEF. cfx injects
// invokeNative into the global; a browser never has it.
export function isEnvBrowser(): boolean {
	return !window.invokeNative;
}

// POST a NUI -> Lua action to its RegisterNUICallback. In browser dev (no CEF)
// resolves with mockData when supplied, else undefined. Typed wrappers come from
// createNuiBridge; this raw form is string-keyed.
export async function fetchNui<R = unknown>(
	action: string,
	data: unknown = {},
	mockData?: R,
): Promise<R> {
	if (isEnvBrowser()) {
		return mockData as R;
	}
	const resource = window.GetParentResourceName?.() ?? 'nui-frame-app';
	const res = await fetch(`https://${resource}/${action}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(data),
	});
	return (await res.json()) as R;
}

// Subscribe to a Lua -> NUI SendNUIMessage({ action, data }) stream. Returns an
// unsubscribe fn - framework glue pairs it with the component teardown hook.
export function subscribeNui<T = unknown>(
	action: string,
	handler: (data: T) => void,
): () => void {
	const listener = (event: MessageEvent): void => {
		// Match on `action` only. cfx delivers SendNUIMessage into the frame via
		// the parent cfx-root window's postMessage, so event.source is that parent
		// (foreign), NOT null and NOT this frame's window. A source filter here
		// drops every real Lua -> NUI message. The CEF root frame tree is cfx-owned
		// (no cross-resource iframe injection), so action-matching is the contract.
		const message = event.data as
			| { action?: string; data?: unknown }
			| undefined;
		if (!message || message.action !== action) return;
		handler(message.data as T);
	};
	window.addEventListener('message', listener);
	return () => window.removeEventListener('message', listener);
}

// One-shot. Root font-size so 1rem == 1vh (1080p -> 10.8px, 2160p -> 21.6px).
// 8px floor keeps browser-dev previews readable. resize listener tracks dev
// window changes; the in-game viewport is fixed per session.
export function installScaler(): void {
	const apply = (): void => {
		const px = Math.max(8, window.innerHeight / 100);
		document.documentElement.style.fontSize = `${px}px`;
	};
	apply();
	window.addEventListener('resize', apply, { passive: true });
}

interface DebugEvent<T = unknown> {
	action: string;
	data: T;
}

// Emulates cfx SendNUIMessage in browser dev: fires { action, data } message
// events after `timer` ms so subscribeNui handlers pick them up. No-op in CEF.
export function debugData<T = unknown>(
	events: DebugEvent<T>[],
	timer = 1000,
): void {
	if (!isEnvBrowser()) return;
	setTimeout(() => {
		for (const ev of events) {
			window.dispatchEvent(
				new MessageEvent('message', {
					data: { action: ev.action, data: ev.data },
				}),
			);
		}
	}, timer);
}
