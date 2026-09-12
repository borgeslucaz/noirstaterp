<script lang="ts">
import { onMount } from 'svelte';
import MapCanvas from '@/components/MapCanvas.svelte';
import Sidebar from '@/components/Sidebar.svelte';
import ViewerControls from '@/components/ViewerControls.svelte';
import { fetchNui, useNuiEvent } from '@/lib/nui';
import { store } from '@/lib/store.svelte';
import { Button, Dialog, Toast, toast } from '@/lib/ui/components';
import { debugData, isEnvBrowser } from '@/lib/ui/nui';

// browser dev: reveal immediately so the editor shows without the game
debugData([{ action: 'setVisible', data: true }]);
let visible = $state(false);
// dev: force the viewer box visible for browser preview
let viewerActive = $state(import.meta.env.DEV);
let viewerHeight = $state(150);
// Escape with unsaved edits opens this confirm instead of closing.
let confirmOpen = $state(false);
const hasUnsaved = $derived(store.hasUnsaved);
useNuiEvent('setVisible', v => {
	visible = v;
	// drop toasts on exit so none linger over gameplay or resurrect on reopen
	if (!v) toast.clear();
	// re-fit the map zoomed out on every open/close (close runs while hidden, no
	// flash). setVisible never fires on viewer return, so viewer framing is kept.
	store.openTick++;
});
useNuiEvent('loadZones', zones => {
	store.replaceAll(zones);
});
useNuiEvent('playerPos', p => {
	store.player = p;
});
useNuiEvent('zonemanager:viewerStarted', ({ height }) => {
	visible = false;
	viewerActive = true;
	viewerHeight = height;
});
useNuiEvent('zonemanager:viewerUpdate', ({ height }) => {
	viewerHeight = height;
});
useNuiEvent('zonemanager:viewerStopped', ({ height }) => {
	store.viewerHeight(height);
	viewerActive = false;
	visible = true;
});
function doClose(): void {
	if (isEnvBrowser()) {
		visible = false;
	} else {
		void fetchNui('hideFrame', {});
	}
}
// Guarded close: unsaved edits open the confirm dialog; otherwise close straight.
function requestClose(): void {
	if (hasUnsaved) {
		confirmOpen = true;
		return;
	}
	doClose();
}
async function saveAndClose(): Promise<void> {
	await store.save();
	confirmOpen = false;
	doClose();
}
function discardAndClose(): void {
	confirmOpen = false;
	doClose();
}
onMount(() => {
	void (async () => {
		await store.load();
		// dynamic import so the dev seed tree-shakes out of the shipped build
		if (import.meta.env.DEV && store.zones.length === 0) {
			const { seedDemo } = await import('@/lib/dev/seed');
			seedDemo();
		}
	})();
	const onKey = (e: KeyboardEvent): void => {
		if (!visible) return;
		// let the open dialog own Escape (it closes itself = stay in editor)
		if (confirmOpen) return;
		if (e.code === 'Escape') requestClose();
	};
	window.addEventListener('keydown', onKey);
	// Alt-tab away with the editor open would otherwise latch SetNuiFocus -> stuck
	// cursor on return. Drop focus when the tab goes hidden while visible.
	const onVisibility = (): void => {
		if (document.hidden && visible) doClose();
	};
	document.addEventListener('visibilitychange', onVisibility);
	return () => {
		window.removeEventListener('keydown', onKey);
		document.removeEventListener('visibilitychange', onVisibility);
	};
});
</script>

<div style:visibility={visible ? 'visible' : 'hidden'} class="fixed inset-0 flex overflow-hidden">
	<Sidebar />
	<div class="relative min-w-0 flex-1">
		<MapCanvas />
	</div>
</div>
{#if viewerActive}
	<ViewerControls height={viewerHeight} />
{/if}
<Dialog
	bind:open={confirmOpen}
	title="Unsaved changes"
	description="You have unsaved zone edits. Save them before closing the editor?"
>
	{#snippet footer()}
		<Button intent="ghost" onclick={() => (confirmOpen = false)}>Keep editing</Button>
		<Button intent="danger" onclick={discardAndClose}>Discard</Button>
		<Button intent="primary" onclick={saveAndClose}>Save &amp; close</Button>
	{/snippet}
</Dialog>
<Toast />
