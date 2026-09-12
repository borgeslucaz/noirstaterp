<!-- IconButton - square icon-only button. Reuses Button's intent vocab; the icon
arrives as the children Snippet. Consumers MUST pass aria-label via rest. -->
<script lang="ts">
import type { HTMLButtonAttributes } from 'svelte/elements';
import { type IconButtonSize, type Intent, intents, tv } from '../lib/tv';
import { cn } from '../lib/utils';

interface IconButtonProps extends HTMLButtonAttributes {
	size?: IconButtonSize;
	intent?: Intent;
	class?: string;
	disabled?: boolean;
	type?: 'button' | 'submit' | 'reset';
	children?: import('svelte').Snippet;
}

// Square dims mirror the shared size heights (h-6/8/10/12) with equal width and
// no horizontal padding. `border` carries the width the intent map colors.
const iconSizes: Record<IconButtonSize, string> = {
	xs: 'size-6 text-xs',
	sm: 'size-8 text-sm',
	md: 'size-10 text-base',
	lg: 'size-12 text-lg',
	xl: 'size-14 text-xl',
	'2xl': 'size-16 text-2xl',
	'3xl': 'size-20 text-3xl',
	'4xl': 'size-24 text-4xl',
};
const iconButton = tv({
	base: 'inline-flex select-none cursor-pointer items-center justify-center rounded-lg border font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50',
	variants: { size: iconSizes, intent: intents },
});
let {
	size = 'md',
	intent = 'default',
	class: className,
	disabled = false,
	type = 'button',
	children,
	...rest
}: IconButtonProps = $props();
</script>

<button {type} {disabled} class={cn(iconButton({ size, intent }), className)} {...rest}>
	{@render children?.()}
</button>
