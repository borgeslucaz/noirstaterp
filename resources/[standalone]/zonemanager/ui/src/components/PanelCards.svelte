<script lang="ts">
import { contrastText } from '@/lib/color';
import Icon from '@/lib/Icon.svelte';
import { store } from '@/lib/store.svelte';
import {
	Badge,
	Button,
	Card,
	ColorPicker,
	IconButton,
	Input,
	Kbd,
	Spinner,
	Toggle,
} from '@/lib/ui/components';

const POLY_HINTS: [string, string][] = [
	['Click', 'Add point'],
	['Drag', 'Move point'],
	['Right-click', 'Delete point'],
	['Click edge', 'Insert point'],
];
const CIRCLE_HINTS: [string, string][] = [
	['Click', 'Set center'],
	['Drag', 'Move center'],
	['Radius', 'Edit in card'],
];
</script>

<div class="panel flex h-full flex-col text-base">
	<div class="flex items-center justify-between gap-4 border-b border-border px-5 pt-7 pb-4">
		<div class="flex items-center gap-2.5">
			<span class="text-primary"><Icon name="pin" size={30} /></span>
			<div class="flex flex-col">
				<div class="flex items-baseline gap-0">
					<span class="text-3xl font-bold tracking-[0.25em] uppercase">Zone</span>
					<span class="text-3xl font-light tracking-[0.25em] text-text-muted uppercase">Manager</span>
				</div>
				<span class="text-xs text-text-subtle">Created by Scrubz | github:itsxScrubz - discord:scrubz</span>
			</div>
		</div>
		<div class="mt-2 mr-2 flex items-baseline gap-2 font-mono text-xl tabular-nums">
			<span class="text-text-subtle">ZONES</span> <span class="text-text">{store.zones.length}</span>
		</div>
	</div>
	<div class="mx-5 mt-4 flex items-center gap-2.5 rounded-lg border border-border-strong bg-surface-overlay p-2">
		<Toggle bind:pressed={store.snapEnabled} size="lg" class="rounded-lg! gap-2 px-3 border-border! bg-surface-600! text-text-muted! data-[state=off]:hover:bg-surface-500! data-[state=off]:hover:text-text! data-[state=on]:border-primary! data-[state=on]:bg-primary! data-[state=on]:text-on-primary!">
			<Icon name="grid" size={20} /> Grid
		</Toggle>
		<Toggle bind:pressed={store.showDistances} size="lg" class="rounded-lg! gap-2 px-3 border-border! bg-surface-600! text-text-muted! data-[state=off]:hover:bg-surface-500! data-[state=off]:hover:text-text! data-[state=on]:border-primary! data-[state=on]:bg-primary! data-[state=on]:text-on-primary!">
			<Icon name="ruler" size={20} /> Dist
		</Toggle>
		<div class="ml-auto flex items-center gap-1.5 px-2 font-mono text-base tabular-nums text-text-muted">
			<Icon name="cursor" size={16} />
			<span class="w-40 overflow-hidden text-left whitespace-nowrap">{#if store.cursor}{store.cursor.x}, {store.cursor.y}{:else}-{/if}</span>
		</div>
	</div>
	<div class="grid grid-cols-2 gap-2.5 px-5 py-4">
		<Button intent="primary" size='2xl' class="rounded-lg! w-full" onclick={() => store.createZone('', 'poly')}>
			<Icon name="polygon" size={24} /> Polygon
		</Button>
		<Button intent="primary" size='2xl' class="rounded-lg! w-full" onclick={() => store.createZone('', 'circle')}>
			<Icon name="circle" size={24} /> Circle
		</Button>
	</div>
	{#snippet stepper(up: () => void, down: () => void)}
		<div class="flex h-12 w-9 shrink-0 flex-col overflow-hidden rounded-md border border-border">
			<button type="button" class="flex flex-1 items-center justify-center border-b border-border bg-surface-600 text-text-muted hover:bg-surface-500 hover:text-text" aria-label="Increase" onclick={up}>
				<Icon name="caret-up" size={14} />
			</button>
			<button type="button" class="flex flex-1 items-center justify-center bg-surface-600 text-text-muted hover:bg-surface-500 hover:text-text" aria-label="Decrease" onclick={down}>
				<Icon name="caret-down" size={14} />
			</button>
		</div>
	{/snippet}
	<div class="scroll min-h-0 flex-1 space-y-3 overflow-y-auto px-5 pb-4">
		{#each store.zones as zone (zone.id)}
			{@const active = zone.id === store.activeId}
			<Card class="relative overflow-hidden rounded-xl! bg-surface-overlay! p-5! {active ? 'border-primary!' : 'border-border-strong!'}">
				{#if store.resolvingId === zone.id}
					<div class="absolute inset-0 z-10 grid place-items-center bg-surface">
						<div class="flex flex-col items-center gap-2 text-text-muted">
							<Spinner size="2xl" />
							<span class="text-lg">Resolving ground Z…</span>
						</div>
					</div>
				{/if}
				<div class="flex items-center gap-2.5">
					<button type="button" class="size-4 shrink-0 {zone.kind === 'circle' ? 'rounded-full' : 'rounded-sm'}" style:background={zone.visible ? 'var(--color-success-500)' : 'var(--color-error-300)'} onclick={() => store.activate(zone.id)} aria-label="Activate"></button>
					{#if active}
						<Input size="lg" value={zone.name} class="min-w-0 flex-1 rounded-md! border-border! bg-surface-600! text-xl! font-semibold!" aria-label="Zone name" onblur={(e: FocusEvent) => store.rename(zone.id, (e.currentTarget as HTMLInputElement).value)} onkeydown={(e: KeyboardEvent) => e.key === 'Enter' && (e.currentTarget as HTMLInputElement).blur()} />
					{:else}
						<button type="button" class="min-w-0 flex-1 truncate text-left text-xl font-semibold" onclick={() => store.activate(zone.id)}>{zone.name}</button>
					{/if}
					{#if store.isDirty(zone)}
						<Badge size="sm" class="border-primary/30! bg-primary/15! text-primary-hover!">Unsaved</Badge>
					{/if}
					<Badge size="sm" class="text-base!">{zone.kind === 'circle' ? `${zone.radius}m` : `${zone.points.length} pts`}</Badge>
					<ColorPicker size="sm" class="shrink-0" value={zone.color} onValueChange={(c) => store.setColor(zone.id, c)} />
				</div>
				{#if active}
					<div class="mt-5 grid grid-cols-2 gap-4">
						<label class="block">
							<span class="text-base font-bold tracking-wider text-text-subtle uppercase">Ground Z</span>
							<div class="mt-1.5 flex gap-1.5">
								<Input size="lg" type="number" step="0.01" class="rounded-md! border-border! bg-surface-600! font-mono" value={zone.points[0]?.z != null ? String(zone.points[0].z) : ''} oninput={(e: Event) => { const v = (e.currentTarget as HTMLInputElement).value; if (v !== '') store.setGroundZ(zone.id, Number(v)); }} />
								{@render stepper(
									() => store.setGroundZ(zone.id, Math.round(((zone.points[0]?.z ?? 0) + 1) * 100) / 100),
									() => store.setGroundZ(zone.id, Math.round(((zone.points[0]?.z ?? 0) - 1) * 100) / 100),
								)}
								<IconButton size="lg" intent="ghost" class="w-auto! rounded-md! bg-surface-600! border-border! px-4! text-text!" title="Auto-fill ground Z from the map surface" aria-label="Auto-fill ground Z" onclick={() => store.resolveGroundZ(zone.id)}>
									<Icon name="mountain" size={20} />
								</IconButton>
							</div>
						</label>
						<label class="block">
							<span class="text-base font-bold tracking-wider text-text-subtle uppercase">Height</span>
							<div class="mt-1.5 flex gap-1.5">
								<Input size="lg" type="number" min="0" class="rounded-md! border-border! bg-surface-600! font-mono" value={String(zone.height)} oninput={(e: Event) => store.setHeight(zone.id, Number((e.currentTarget as HTMLInputElement).value))} />
								{@render stepper(
									() => store.setHeight(zone.id, zone.height + 5),
									() => store.setHeight(zone.id, Math.max(0, zone.height - 5)),
								)}
							</div>
						</label>
					</div>
					{#if zone.kind === 'circle'}
						<label class="mt-5 block">
							<span class="text-base font-bold tracking-wider text-text-subtle uppercase">Radius (m)</span>
							<Input size="lg" type="number" min="0" step="0.5" class="mt-1.5 rounded-md! border-border! bg-surface-600! font-mono" value={String(zone.radius)} oninput={(e: Event) => store.setRadius(zone.id, Number((e.currentTarget as HTMLInputElement).value))} />
						</label>
						<div class="mt-5 mb-2 text-base font-bold tracking-wider text-text-subtle uppercase">Center</div>
						{#if zone.points[0]}
							<div class="rounded-md border border-border bg-surface-600 px-3 py-2 font-mono text-lg">{zone.points[0].x}, {zone.points[0].y}{zone.points[0].z !== null ? `, ${zone.points[0].z}` : ''}</div>
						{:else}
							<div class="rounded-md border border-border bg-surface-600 px-3 py-2 text-lg text-text-muted">Click the map to place the center.</div>
						{/if}
					{:else if zone.points.length}
						<div class="mt-5 mb-2 text-base font-bold tracking-wider text-text-subtle uppercase">Points</div>
						<div class="scroll scroll-primary max-h-72 space-y-2 overflow-y-auto">
							{#each zone.points as p, i (p.id)}
								<div class="flex items-center gap-2.5 rounded-md border border-border bg-surface-600 px-3.5 py-3 font-mono text-lg">
									<span class="grid size-7 shrink-0 place-items-center rounded-md text-sm font-bold" style:background={zone.color} style:color={contrastText(zone.color)}>{i + 1}</span>
									<span class="truncate">{p.x}, {p.y}{p.z !== null ? `, ${p.z}` : ''}</span>
									<IconButton size="sm" intent="ghost" class="ml-auto size-7" aria-label="Delete point" onclick={() => store.deletePoint(zone.id, p.id)}>
										<Icon name="x" size={16} />
									</IconButton>
								</div>
							{/each}
						</div>
					{/if}
					<div class="mt-6 flex gap-2">
						<Button size="md" intent="ghost" class="h-auto! rounded-lg! flex-1 px-3! py-2.5! bg-surface-600! border-border! text-text! hover:bg-surface-500!" onclick={() => store.viewZone(zone.id)}>
							<Icon name="video" size={20} /> Preview
						</Button>
						<Button size="md" intent="ghost" class="h-auto! rounded-lg! flex-1 px-3! py-2.5! bg-surface-600! border-border! text-text! hover:bg-surface-500!" onclick={() => store.toggleVisible(zone.id)}>
							<Icon name={zone.visible ? 'eye' : 'eye-off'} size={20} /> {zone.visible ? 'Visible' : 'Hidden'}
						</Button>
						<Button size="md" intent="primary" class="h-auto! rounded-lg! flex-1 px-3! py-2.5!" onclick={() => store.save()}>
							<Icon name={store.isDirty(zone) ? 'save' : 'check'} size={20} /> {store.isDirty(zone) ? 'Save' : 'Saved'}
						</Button>
						<Button size="md" intent="danger" class="h-auto! rounded-lg! shrink-0 px-3! py-2.5!" aria-label="Delete" onclick={() => store.deleteZone(zone.id)}>
							<Icon name="trash" size={20} />
						</Button>
					</div>
				{/if}
			</Card>
		{/each}
	</div>
	<div class="mx-5 mb-4 grid grid-cols-2 gap-x-3 gap-y-2.5 rounded-lg border border-border-strong bg-surface-raised p-3.5 text-base">
		{#each (store.active?.kind === 'circle' ? CIRCLE_HINTS : POLY_HINTS) as [k, v] (k)}
			<div class="flex items-center gap-2.5">
				<Kbd class="rounded-md! border-border-strong! bg-surface-600! px-2! py-0.5! font-semibold! text-text!">{k}</Kbd>
				<span class="text-text">{v}</span>
			</div>
		{/each}
	</div>
</div>

<style>
/* Surface-token gradient so a :root re-skin moves with it. */
.panel {
	background: linear-gradient(
		180deg,
		var(--color-surface-overlay) 0%,
		var(--color-surface-raised) 100%
	);
}
</style>
