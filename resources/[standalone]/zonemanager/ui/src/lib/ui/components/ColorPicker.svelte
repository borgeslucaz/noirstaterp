<!-- ColorPicker - a swatch button that opens a Popover with an HSV picker: a
saturation/value square, a hue slider, a live preview, and a hex field. `value`
two-way binds the selected hex; `onValueChange` fires on every change so callback
consumers (e.g. a store mutator) stay in sync. HSV is internal state; the bound
value is always the derived hex. Pure CSS gradients + pointer math - no canvas, no
runtime fetch, so it renders offline in CEF. Optional `swatches` add a preset row. -->
<script lang="ts">
import { untrack } from 'svelte';
import { type Size, sizes, tv } from '../lib/tv';
import { cn } from '../lib/utils';
import Input from './Input.svelte';
import Popover from './Popover.svelte';

interface ColorPickerProps {
	value?: string;
	swatches?: string[];
	open?: boolean;
	size?: Size;
	class?: string;
	onValueChange?: (value: string) => void;
}

const triggerVariants = tv({
	base: 'inline-flex cursor-pointer items-center gap-2 rounded-lg border border-border bg-surface-overlay text-text transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring data-[state=open]:border-border-strong',
	variants: {
		size: sizes,
	},
});
const HUE_GRADIENT =
	'linear-gradient(to right, #f00 0%, #ff0 17%, #0f0 33%, #0ff 50%, #00f 67%, #f0f 83%, #f00 100%)';

function hsvToHex(h: number, s: number, v: number): string {
	const c = v * s;
	const x = c * (1 - Math.abs(((h / 60) % 2) - 1));
	const m = v - c;
	let r = 0;
	let g = 0;
	let b = 0;
	if (h < 60) {
		r = c;
		g = x;
	} else if (h < 120) {
		r = x;
		g = c;
	} else if (h < 180) {
		g = c;
		b = x;
	} else if (h < 240) {
		g = x;
		b = c;
	} else if (h < 300) {
		r = x;
		b = c;
	} else {
		r = c;
		b = x;
	}
	const to = (n: number): string =>
		Math.round((n + m) * 255)
			.toString(16)
			.padStart(2, '0');
	return `#${to(r)}${to(g)}${to(b)}`;
}

function hexToHsv(hex: string): { h: number; s: number; v: number } | null {
	const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim());
	if (!m?.[1]) return null;
	const int = Number.parseInt(m[1], 16);
	const r = ((int >> 16) & 255) / 255;
	const g = ((int >> 8) & 255) / 255;
	const b = (int & 255) / 255;
	const max = Math.max(r, g, b);
	const min = Math.min(r, g, b);
	const d = max - min;
	let h = 0;
	if (d !== 0) {
		if (max === r) h = ((((g - b) / d) % 6) + 6) % 6;
		else if (max === g) h = (b - r) / d + 2;
		else h = (r - g) / d + 4;
		h *= 60;
	}
	return { h, s: max === 0 ? 0 : d / max, v: max };
}

let {
	value = $bindable('#22c55e'),
	swatches,
	open = $bindable(false),
	size = 'md',
	class: className,
	onValueChange,
}: ColorPickerProps = $props();
let h = $state(0);
let s = $state(1);
let v = $state(1);
let svEl = $state<HTMLDivElement>();
let hueEl = $state<HTMLDivElement>();
// Sync HSV from an externally-set value. Depends only on `value`; our own commits
// set value to exactly the current HSV's hex, so the guard skips and there is no
// feedback loop with the drag handlers.
$effect(() => {
	const incoming = value;
	const parsed = hexToHsv(incoming);
	if (!parsed) return;
	untrack(() => {
		if (hsvToHex(h, s, v).toLowerCase() === incoming.toLowerCase()) return;
		h = parsed.h;
		s = parsed.s;
		v = parsed.v;
	});
});
function commit(): void {
	const next = hsvToHex(h, s, v);
	value = next;
	onValueChange?.(next);
}
function clamp01(n: number): number {
	return Math.min(Math.max(n, 0), 1);
}
function onSv(e: PointerEvent): void {
	if (!svEl) return;
	const rect = svEl.getBoundingClientRect();
	s = clamp01(rect.width ? (e.clientX - rect.left) / rect.width : 0);
	v = clamp01(rect.height ? 1 - (e.clientY - rect.top) / rect.height : 0);
	commit();
}
function svDown(e: PointerEvent): void {
	(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
	onSv(e);
}
function svMove(e: PointerEvent): void {
	if (e.buttons === 1) onSv(e);
}
function onHue(e: PointerEvent): void {
	if (!hueEl) return;
	const rect = hueEl.getBoundingClientRect();
	h = 360 * clamp01(rect.width ? (e.clientX - rect.left) / rect.width : 0);
	commit();
}
function hueDown(e: PointerEvent): void {
	(e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
	onHue(e);
}
function hueMove(e: PointerEvent): void {
	if (e.buttons === 1) onHue(e);
}
function setHex(hex: string): void {
	value = hex;
	onValueChange?.(hex);
}
function onHexInput(e: Event): void {
	const raw = (e.currentTarget as HTMLInputElement).value.trim();
	if (/^#?[0-9a-fA-F]{6}$/.test(raw))
		setHex(raw.startsWith('#') ? raw : `#${raw}`);
}
</script>

<Popover bind:open closable={false} side="bottom" align="start">
	{#snippet trigger()}
		<span class={cn(triggerVariants({ size }), className)}>
			<span
				class="size-5 shrink-0 rounded-md border border-black/20"
				style:background={value}
			></span>
			<span class="font-mono text-sm uppercase">{value}</span>
		</span>
	{/snippet}
	<div class="flex w-96 flex-col gap-3">
		<div class="flex gap-3">
			<div
				class="w-20 shrink-0 rounded-lg border border-black/20"
				style:background={value}
			></div>
			<div
				bind:this={svEl}
				class="relative h-56 flex-1 cursor-crosshair touch-none rounded-lg"
				style:background="linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, transparent), hsl({h} 100% 50%)"
				onpointerdown={svDown}
				onpointermove={svMove}
				role="slider"
				aria-label="Saturation and brightness"
				aria-valuenow={Math.round(v * 100)}
				aria-valuetext="{Math.round(s * 100)}% saturation, {Math.round(v * 100)}% brightness"
				tabindex="0"
			>
				<div
					class="pointer-events-none absolute size-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_0_0_1px_rgb(0_0_0/0.4)]"
					style:left="{s * 100}%"
					style:top="{(1 - v) * 100}%"
				></div>
			</div>
		</div>
		<div
			bind:this={hueEl}
			class="relative h-6 cursor-pointer touch-none rounded-full border border-black/20"
			style:background={HUE_GRADIENT}
			onpointerdown={hueDown}
			onpointermove={hueMove}
			role="slider"
			aria-label="Hue"
			aria-valuenow={Math.round(h)}
			aria-valuemin={0}
			aria-valuemax={360}
			tabindex="0"
		>
			<div
				class="pointer-events-none absolute top-1/2 size-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-white shadow-[0_0_0_1px_rgb(0_0_0/0.4)]"
				style:left="{(h / 360) * 100}%"
				style:background="hsl({h} 100% 50%)"
			></div>
		</div>
		<Input size="sm" class="font-mono uppercase" value={value} oninput={onHexInput} />
		{#if swatches?.length}
			<div class="flex flex-wrap gap-1.5">
				{#each swatches as swatch (swatch)}
					<button
						type="button"
						class="size-6 rounded-md border border-black/20 transition-transform hover:scale-110 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
						style:background={swatch}
						aria-label={swatch}
						onclick={() => setHex(swatch)}
					></button>
				{/each}
			</div>
		{/if}
	</div>
</Popover>
