// Toast queue. Singleton $state-backed store + a `toast()` push API. Mount one
// <Toast /> viewport; calls anywhere enqueue and auto-dismiss after `duration`.

import type { AlertVariant } from './tv';

export interface ToastOptions {
	intent?: AlertVariant;
	title: string;
	description?: string;
	duration?: number;
}

export interface ActiveToast {
	id: number;
	intent: AlertVariant;
	title: string;
	description?: string;
}

type ToastFn = ((opts: ToastOptions) => number) & {
	success: (title: string, description?: string) => number;
	error: (title: string, description?: string) => number;
	info: (title: string, description?: string) => number;
	warning: (title: string, description?: string) => number;
	clear: () => void;
};

const defaultDuration = 4000;

class ToastStore {
	items = $state<ActiveToast[]>([]);
	private nextId = 0;
	private timers = new Map<number, ReturnType<typeof setTimeout>>();
	push(opts: ToastOptions): number {
		const id = this.nextId++;
		const entry: ActiveToast = {
			id,
			intent: opts.intent ?? 'info',
			title: opts.title,
		};
		if (opts.description !== undefined) {
			entry.description = opts.description;
		}
		this.items.push(entry);
		const duration = opts.duration ?? defaultDuration;
		this.timers.set(
			id,
			setTimeout(() => this.dismiss(id), duration),
		);
		return id;
	}
	dismiss(id: number): void {
		const timer = this.timers.get(id);
		if (timer !== undefined) {
			clearTimeout(timer);
			this.timers.delete(id);
		}
		this.items = this.items.filter(t => t.id !== id);
	}
	// Drop every queued toast + its timer. Host UI calls this on close so toasts
	// never outlive the surface that spawned them, and stale ones don't resurrect
	// on reopen.
	clear(): void {
		for (const timer of this.timers.values()) {
			clearTimeout(timer);
		}
		this.timers.clear();
		this.items = [];
	}
}

export const toastStore = new ToastStore();

function pushToast(opts: ToastOptions): number {
	return toastStore.push(opts);
}

function pushIntent(
	intent: AlertVariant,
	title: string,
	description?: string,
): number {
	const opts: ToastOptions = { intent, title };
	if (description !== undefined) {
		opts.description = description;
	}
	return toastStore.push(opts);
}

export const toast: ToastFn = Object.assign(pushToast, {
	success: (title: string, description?: string): number =>
		pushIntent('success', title, description),
	error: (title: string, description?: string): number =>
		pushIntent('danger', title, description),
	info: (title: string, description?: string): number =>
		pushIntent('info', title, description),
	warning: (title: string, description?: string): number =>
		pushIntent('warning', title, description),
	clear: (): void => toastStore.clear(),
});

export function dismissToast(id: number): void {
	toastStore.dismiss(id);
}
