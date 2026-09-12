<!-- Toast - fixed-corner viewport rendering the toast store queue. Mount once per
app; `toast()` calls anywhere push cards that auto-dismiss. Each card carries a
status-keyed icon + tint and a manual dismiss button. -->
<script lang="ts">
import Icon from '@iconify/svelte';
import { dismissToast, toastStore } from '../lib/toast.svelte';
import { type AlertVariant, tv } from '../lib/tv';
import { cn } from '../lib/utils';
import IconButton from './IconButton.svelte';

// Full-strength status color per intent - matches the Alert icon/title color.
const iconColors: Record<AlertVariant, string> = {
	info: 'text-info-400',
	success: 'text-success-400',
	warning: 'text-warning-400',
	danger: 'text-error-400',
};
const statusIcons: Record<AlertVariant, string> = {
	info: 'lucide:info',
	success: 'lucide:check-circle',
	warning: 'lucide:alert-triangle',
	danger: 'lucide:x-circle',
};
const card = tv({
	base: 'pointer-events-auto flex w-96 items-start gap-3 rounded-lg border border-border bg-surface-raised p-5 shadow-lg',
});
</script>

<div class="pointer-events-none fixed bottom-16 right-6 z-50 flex flex-col gap-3">
	{#each toastStore.items as item (item.id)}
		<div class={card()} role="status">
			<Icon
				icon={statusIcons[item.intent]}
				width="1.5rem"
				height="1.5rem"
				class={cn('mt-0.5 shrink-0', iconColors[item.intent])}
			/>
			<div class="flex flex-1 flex-col gap-1">
				<span class="text-base font-medium text-text">{item.title}</span>
				{#if item.description}
					<span class="text-sm text-text-muted">{item.description}</span>
				{/if}
			</div>
			<IconButton
				size="xs"
				intent="ghost"
				aria-label="Dismiss"
				onclick={() => dismissToast(item.id)}
			>
				<Icon icon="lucide:x" width="1rem" height="1rem" />
			</IconButton>
		</div>
	{/each}
</div>
