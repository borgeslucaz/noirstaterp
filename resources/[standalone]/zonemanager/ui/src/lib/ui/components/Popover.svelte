<!-- Popover - wraps Bits UI Popover (Root/Trigger/Portal/Content/Close). Bits owns
the anchored-positioning/dismiss/focus/ARIA contract; this renders the floating
panel with the design-token skin. `open` is two-way bound for programmatic
control; the `trigger` snippet renders inside Bits' Trigger so it inherits the
open-on-click + aria-haspopup wiring. `side`/`align`/`sideOffset` forward to Bits'
floating layer. Portal escapes the scaler-scaled root - rem sizing + a high
z-index keep the panel layered above app content and scaling with the viewport. -->
<script lang="ts">
import Icon from '@iconify/svelte';
import { Popover } from 'bits-ui';
import type { Snippet } from 'svelte';
import { tv } from '../lib/tv';
import { cn } from '../lib/utils';

type Side = 'top' | 'right' | 'bottom' | 'left';
type Align = 'start' | 'center' | 'end';

interface PopoverProps {
	open?: boolean;
	side?: Side;
	align?: Align;
	sideOffset?: number;
	closable?: boolean;
	class?: string;
	trigger?: Snippet;
	children?: Snippet;
}

const content = tv({
	base: 'z-50 w-72 rounded-xl border border-border bg-surface-raised p-4 text-text shadow-lg focus:outline-none',
});
const closeButton = tv({
	base: 'absolute right-3 top-3 inline-flex size-7 items-center justify-center rounded-md text-text-muted transition-colors hover:bg-surface-overlay hover:text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
});
let {
	open = $bindable(false),
	side = 'bottom',
	align = 'center',
	sideOffset = 6,
	closable = true,
	class: className,
	trigger,
	children,
}: PopoverProps = $props();
</script>

<Popover.Root bind:open>
	{#if trigger}
		<Popover.Trigger>
			{@render trigger()}
		</Popover.Trigger>
	{/if}
	<Popover.Portal>
		<Popover.Content
			class={cn(content(), className)}
			{side}
			{align}
			{sideOffset}
		>
			{#if children}
				{@render children()}
			{/if}
			{#if closable}
				<Popover.Close class={closeButton()} aria-label="Close">
					<Icon icon="lucide:x" width="1rem" height="1rem" />
				</Popover.Close>
			{/if}
		</Popover.Content>
	</Popover.Portal>
</Popover.Root>
