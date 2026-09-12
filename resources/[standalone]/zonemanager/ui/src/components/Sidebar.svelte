<script lang="ts">
import PanelCards from './PanelCards.svelte';
</script>

<!-- zoom scales rem-based children up: the NUI scaler pins 1rem to vh/100
(~10.8px @1080p), so without it components render ~30% under the 16px mockup. -->
<aside class="flex h-full w-140 shrink-0 flex-col overflow-hidden border-r border-border bg-surface">
	<PanelCards />
</aside>
