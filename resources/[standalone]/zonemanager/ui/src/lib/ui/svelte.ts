// Svelte glue: a typed bridge bound to a resource's contract maps. useNuiEvent
// detaches on component teardown via onDestroy, so call it during init.

import { onDestroy } from 'svelte';
import { fetchNui as rawFetch, subscribeNui } from './nui';

// In = Lua -> NUI action map; Out = NUI -> Lua action map. An action the map
// doesn't declare, or a mismatched payload, fails at compile time.
export function createNuiBridge<In, Out>() {
	function fetchNui<R = unknown, A extends keyof Out = keyof Out>(
		action: A,
		data: Out[A],
		mockData?: R,
	): Promise<R> {
		return rawFetch<R>(action as string, data, mockData);
	}
	function useNuiEvent<A extends keyof In>(
		action: A,
		handler: (data: In[A]) => void,
	): void {
		const off = subscribeNui(
			action as string,
			handler as (data: unknown) => void,
		);
		onDestroy(off);
	}
	return { fetchNui, useNuiEvent };
}
