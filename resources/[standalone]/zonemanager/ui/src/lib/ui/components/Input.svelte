<!-- Input - single-line text field. Height + padding + typography from the shared
size scale; bordered surface matches Button's default look. `invalid` swaps the
border to the error token. -->
<script lang="ts">
import type { HTMLInputAttributes } from 'svelte/elements';
import { type Size, sizes, tv } from '../lib/tv';
import { cn } from '../lib/utils';

// HTMLInputAttributes types `size` as the numeric attribute; override it with
// the design-system size scale.
interface InputProps extends Omit<HTMLInputAttributes, 'size'> {
	size?: Size;
	invalid?: boolean;
	value?: string;
	class?: string;
}

// `border` carries the width; the base sets the resting border color and the
// invalid variant overrides it. focus ring + disabled match Button.
const input = tv({
	base: 'w-full rounded-lg border border-border bg-surface-overlay text-text placeholder:text-text-subtle transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
	variants: {
		size: sizes,
		invalid: { true: 'border-error-500', false: '' },
	},
});
let {
	size = 'md',
	invalid = false,
	value = $bindable(''),
	class: className,
	...rest
}: InputProps = $props();
</script>

<input
	bind:value
	aria-invalid={invalid || undefined}
	class={cn(input({ size, invalid }), className)}
	{...rest}
/>
