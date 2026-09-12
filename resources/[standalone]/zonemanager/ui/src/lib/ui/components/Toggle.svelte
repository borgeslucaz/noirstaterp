<!-- Toggle - wraps Bits UI Toggle.Root. Bits owns the pressed-state/a11y contract;
this adds the design-token skin via data-state on/off styling. `pressed` is
two-way bound. -->
<script lang="ts">
import { Toggle } from 'bits-ui';
import { type Size, sizes, tv } from '../lib/tv';
import { cn } from '../lib/utils';

interface ToggleProps {
	pressed?: boolean;
	size?: Size;
	disabled?: boolean;
	class?: string;
	children?: import('svelte').Snippet;
}

const toggle = tv({
	base: 'inline-flex select-none cursor-pointer items-center justify-center gap-2 rounded-lg border border-border bg-surface-overlay font-medium text-text transition-colors hover:bg-surface-raised focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring data-[state=on]:border-primary data-[state=on]:bg-primary data-[state=on]:text-on-primary data-disabled:pointer-events-none data-disabled:opacity-50',
	variants: { size: sizes },
});
let {
	pressed = $bindable(false),
	size = 'md',
	disabled = false,
	class: className,
	children,
}: ToggleProps = $props();
</script>

<Toggle.Root bind:pressed {disabled} class={cn(toggle({ size }), className)}>
	{@render children?.()}
</Toggle.Root>
