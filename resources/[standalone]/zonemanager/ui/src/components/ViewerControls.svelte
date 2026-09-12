<script lang="ts">
import Icon from '@/lib/Icon.svelte';
import { Kbd } from '@/lib/ui/components';

let { height }: { height: number } = $props();
const hints: [string, string][] = [
	['WASD', 'Move'],
	['Q / E', 'Up / Down'],
	['Mouse', 'Look'],
	['Shift', 'Increase Speed'],
	['↑ / ↓', 'Height'],
	['Escape', 'Exit'],
];
</script>

<div class="pointer-events-none fixed inset-x-0 bottom-8 flex justify-center">
	<div class="panel flex items-center gap-5 rounded-lg border border-border px-5 py-4 shadow-2xl">
		<div class="flex items-center gap-3 border-r border-border pr-5">
			<span class="text-primary"><Icon name="video" size={22} /></span>
			<div class="leading-tight">
				<div class="text-xl font-bold tracking-[0.2em] uppercase">Zone Preview</div>
				<div class="flex items-baseline gap-1.5 font-mono text-base tabular-nums">
					<span class="text-text-subtle">HEIGHT</span>
					<span class="text-primary">{height.toFixed(1)}</span>
				</div>
			</div>
		</div>
		<div class="grid grid-cols-3 gap-x-5 gap-y-2 text-base">
			{#each hints as [k, v] (k)}
				<div class="flex items-center gap-2.5">
					<Kbd class="rounded-md! border-border-strong! bg-surface-600! px-2! py-0.5! font-semibold! text-text!">{k}</Kbd>
					<span class="text-text">{v}</span>
				</div>
			{/each}
		</div>
	</div>
</div>

<style>
/* Flat grey instrument chrome, matching the editor panel. */
.panel {
	background: linear-gradient(
		180deg,
		var(--color-surface-overlay) 0%,
		var(--color-surface-raised) 100%
	);
}
</style>
