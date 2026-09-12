// Typed NUI bridge bound to this resource's contract maps. fetchNui posts a
// NUI->Lua action; useNuiEvent subscribes to a Lua->NUI message.
import { createNuiBridge } from '@/lib/ui/svelte';
import type { IncomingMap, OutgoingMap } from './types';

export const { fetchNui, useNuiEvent } = createNuiBridge<
	IncomingMap,
	OutgoingMap
>();
