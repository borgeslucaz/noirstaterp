<!-- Button - canonical interactive primitive. Composes the shared size + intent
scales from ../lib/tv; consumers re-skin via the @theme color tokens. -->
<script lang="ts">
import type { HTMLButtonAttributes } from 'svelte/elements';
import { type Intent, intents, type Size, sizes, tv } from '../lib/tv';
import { cn } from '../lib/utils';

interface ButtonProps extends HTMLButtonAttributes {
	size?: Size;
	intent?: Intent;
	class?: string;
	disabled?: boolean;
	type?: 'button' | 'submit' | 'reset';
	children?: import('svelte').Snippet;
}

// `border` carries the width - the intent map only sets border color, so without
// a width here the outline/default borders never render.
const button = tv({
	base: 'inline-flex select-none cursor-pointer items-center justify-center gap-2 rounded-lg border font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
	variants: { size: sizes, intent: intents },
});
let {
	size = 'md',
	intent = 'default',
	class: className,
	disabled = false,
	type = 'button',
	children,
	...rest
}: ButtonProps = $props();
</script>

<button {type} {disabled} class={cn(button({ size, intent }), className)} {...rest}>
	{@render children?.()}
</button>
