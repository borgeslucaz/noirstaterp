<!-- Badge - small non-interactive status pill. Composes the shared intent colors;
typography from the shared size scale with the height + cursor dropped. -->
<script lang="ts">
import type { HTMLAttributes } from 'svelte/elements';
import { type BadgeSize, type Intent, intents, tv } from '../lib/tv';
import { cn } from '../lib/utils';

interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
	size?: BadgeSize;
	intent?: Intent;
	class?: string;
	children?: import('svelte').Snippet;
}

// Typography pulled from the shared sizes scale; pill shape + tight padding are
// badge-specific. `border` carries the width the intent map colors.
const badgeSizes: Record<BadgeSize, string> = {
	xs: 'px-2 py-0.5 text-xs',
	sm: 'px-2.5 py-0.5 text-sm',
};
const badge = tv({
	base: 'inline-flex select-none items-center justify-center gap-1 rounded-full border font-medium',
	variants: { size: badgeSizes, intent: intents },
});
let {
	size = 'sm',
	intent = 'default',
	class: className,
	children,
	...rest
}: BadgeProps = $props();
</script>

<span class={cn(badge({ size, intent }), className)} {...rest}>
	{@render children?.()}
</span>
