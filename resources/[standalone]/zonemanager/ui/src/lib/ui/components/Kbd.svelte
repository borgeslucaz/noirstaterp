<!-- Kbd - keyboard-key hint. Monospace, subtle bordered surface, tiny. Single
muted style, no intent. -->
<script lang="ts">
import type { HTMLAttributes } from 'svelte/elements';
import { cn } from '../lib/utils';

interface KbdProps extends HTMLAttributes<HTMLElement> {
	class?: string;
	children?: import('svelte').Snippet;
}

const kbd =
	'inline-flex select-none items-center justify-center rounded-md border border-border bg-surface-raised px-1.5 py-0.5 font-mono text-xs leading-none text-text-muted';
let { class: className, children, ...rest }: KbdProps = $props();
</script>

<kbd class={cn(kbd, className)} {...rest}>
	{@render children?.()}
</kbd>
