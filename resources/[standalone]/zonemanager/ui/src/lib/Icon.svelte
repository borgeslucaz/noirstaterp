<!-- Icon wrapper over per-component Phosphor imports. Each `ph` icon is a
bundled SVG component, so the set ships offline + tree-shaken (only the icons
named here land in the bundle) - no addCollection, no runtime api.iconify.design
fetch that would render blank in CEF. -->
<script lang="ts" module>
import CaretDown from '@iconify-svelte/ph/caret-down';
import CaretUp from '@iconify-svelte/ph/caret-up';
import Check from '@iconify-svelte/ph/check';
import CircleIcon from '@iconify-svelte/ph/circle';
import Crosshair from '@iconify-svelte/ph/crosshair';
import Cursor from '@iconify-svelte/ph/cursor';
import Eye from '@iconify-svelte/ph/eye';
import EyeSlash from '@iconify-svelte/ph/eye-slash';
import FloppyDisk from '@iconify-svelte/ph/floppy-disk';
import GridFour from '@iconify-svelte/ph/grid-four';
import MapPin from '@iconify-svelte/ph/map-pin';
import Mountains from '@iconify-svelte/ph/mountains';
import PencilSimple from '@iconify-svelte/ph/pencil-simple';
import Plus from '@iconify-svelte/ph/plus';
import Polygon from '@iconify-svelte/ph/polygon';
import Ruler from '@iconify-svelte/ph/ruler';
import Trash from '@iconify-svelte/ph/trash';
import VideoCamera from '@iconify-svelte/ph/video-camera';
import X from '@iconify-svelte/ph/x';

export type IconName =
	| 'pin'
	| 'grid'
	| 'ruler'
	| 'target'
	| 'plus'
	| 'circle'
	| 'polygon'
	| 'cursor'
	| 'chevron'
	| 'caret-up'
	| 'caret-down'
	| 'video'
	| 'eye'
	| 'eye-off'
	| 'pencil'
	| 'check'
	| 'save'
	| 'trash'
	| 'mountain'
	| 'x';

const ICONS = {
	pin: MapPin,
	grid: GridFour,
	ruler: Ruler,
	target: Crosshair,
	plus: Plus,
	circle: CircleIcon,
	polygon: Polygon,
	cursor: Cursor,
	chevron: CaretDown,
	'caret-up': CaretUp,
	'caret-down': CaretDown,
	video: VideoCamera,
	eye: Eye,
	'eye-off': EyeSlash,
	pencil: PencilSimple,
	check: Check,
	save: FloppyDisk,
	trash: Trash,
	mountain: Mountains,
	x: X,
};
</script>

<script lang="ts">
let { name, size = 18 }: { name: IconName; size?: number } = $props();
const Glyph = $derived(ICONS[name]);
</script>

<Glyph width={`${size}px`} height={`${size}px`} />
