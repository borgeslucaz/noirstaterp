<!-- Card - generic raised surface container. Bordered rounded panel; consumers
compose their own header/body/footer inside the children snippet. -->
<script lang="ts">
import type { HTMLAttributes } from 'svelte/elements';
import { cn } from '../lib/utils';

interface CardProps extends HTMLAttributes<HTMLDivElement> {
	class?: string;
	children?: import('svelte').Snippet;
}

let { class: className, children, ...rest }: CardProps = $props();
</script>

<div
	class={cn(
		'rounded-2xl border border-border bg-surface-overlay p-6 text-text shadow-lg',
		className,
	)}
	{...rest}
>
	{@render children?.()}
</div>
