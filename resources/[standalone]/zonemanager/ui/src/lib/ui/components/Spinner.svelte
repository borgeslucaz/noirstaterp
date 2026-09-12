<!-- Spinner - CSS-only loading indicator. A spinning ring with a transparent top
segment; color inherits the current text token via border-current. -->
<script lang="ts">
import type { HTMLAttributes } from 'svelte/elements';
import { type Size, tv } from '../lib/tv';
import { cn } from '../lib/utils';

interface SpinnerProps extends HTMLAttributes<HTMLSpanElement> {
	size?: Size;
	class?: string;
}

// Square dims share the Size height steps.
const spinnerSizes: Record<Size, string> = {
	xs: 'size-4',
	sm: 'size-5',
	md: 'size-6',
	lg: 'size-8',
	xl: 'size-10',
	'2xl': 'size-12',
	'3xl': 'size-16',
	'4xl': 'size-20',
};
const spinner = tv({
	base: 'inline-block animate-spin rounded-full border-2 border-current border-t-transparent',
	variants: { size: spinnerSizes },
});
let { size = 'md', class: className, ...rest }: SpinnerProps = $props();
</script>

<span role="status" class={cn(spinner({ size }), className)} {...rest}>
	<span class="sr-only">Loading</span>
</span>
