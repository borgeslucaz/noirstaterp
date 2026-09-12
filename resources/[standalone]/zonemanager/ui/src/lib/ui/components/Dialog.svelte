<!-- Dialog - wraps Bits UI Dialog (Root/Trigger/Portal/Overlay/Content/Title/
Description/Close). Bits owns the focus-trap/scroll-lock/dismiss/ARIA contract;
this renders the centered modal panel with the design-token skin. `open` is
two-way bound for programmatic control; the optional `trigger` snippet renders
inside Bits' Trigger so it inherits the open-on-click + aria-haspopup wiring.
Portal escapes the scaler-scaled root - overlay + panel use rem sizing + a high
z-index so they layer above app content and keep scaling with the viewport. -->
<script lang="ts">
import Icon from '@iconify/svelte';
import { Dialog } from 'bits-ui';
import type { Snippet } from 'svelte';
import { tv } from '../lib/tv';
import { cn } from '../lib/utils';

interface DialogProps {
	open?: boolean;
	title?: string;
	description?: string;
	closable?: boolean;
	class?: string;
	trigger?: Snippet;
	children?: Snippet;
	footer?: Snippet;
}

const overlay = tv({
	base: 'fixed inset-0 z-50 bg-black/60',
});
const content = tv({
	base: 'fixed left-1/2 top-1/2 z-50 flex w-full max-w-md -translate-x-1/2 -translate-y-1/2 flex-col gap-4 rounded-2xl border border-border bg-surface-raised p-6 text-text shadow-xl focus:outline-none',
});
const closeButton = tv({
	base: 'absolute right-4 top-4 inline-flex size-8 items-center justify-center rounded-md text-text-muted transition-colors hover:bg-surface-overlay hover:text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring',
});
let {
	open = $bindable(false),
	title,
	description,
	closable = true,
	class: className,
	trigger,
	children,
	footer,
}: DialogProps = $props();
</script>

<Dialog.Root bind:open>
	{#if trigger}
		<Dialog.Trigger>
			{@render trigger()}
		</Dialog.Trigger>
	{/if}
	<Dialog.Portal>
		<Dialog.Overlay class={overlay()} />
		<Dialog.Content class={cn(content(), className)}>
			{#if title}
				<Dialog.Title class="text-lg font-semibold text-text">
					{title}
				</Dialog.Title>
			{/if}
			{#if description}
				<Dialog.Description class="text-sm text-text-muted">
					{description}
				</Dialog.Description>
			{/if}
			{#if children}
				{@render children()}
			{/if}
			{#if footer}
				<div class="flex justify-end gap-2">
					{@render footer()}
				</div>
			{/if}
			{#if closable}
				<Dialog.Close class={closeButton()} aria-label="Close">
					<Icon icon="lucide:x" width="1.25rem" height="1.25rem" />
				</Dialog.Close>
			{/if}
		</Dialog.Content>
	</Dialog.Portal>
</Dialog.Root>
