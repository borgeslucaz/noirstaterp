import { toast } from '@/lib/ui/components';
import { round, snap } from './coords';
import { fetchNui } from './nui';
import type {
	FetchReply,
	GroundZBatchReply,
	SaveReply,
	WireZone,
	Zone,
	ZonePoint,
} from './types';

const ZONE_COLORS = [
	'#22c55e',
	'#38bdf8',
	'#f59e0b',
	'#ef4444',
	'#a855f7',
	'#ec4899',
	'#14b8a6',
	'#eab308',
];

let seq = 0;
const uid = (prefix: string): string =>
	`${prefix}-${Date.now().toString(36)}-${(seq++).toString(36)}`;

function makePoint(x: number, y: number, z: number | null = null): ZonePoint {
	return {
		id: uid('p'),
		x: round(x, 2),
		y: round(y, 2),
		z,
	};
}

// Wire zones carry no ids (they are never persisted); hydrate UI-session ids
// so keyed each-blocks + drag targets have stable keys until the next load.
function hydrate(zone: WireZone): Zone {
	return {
		id: uid('z'),
		kind: zone.kind === 'circle' ? 'circle' : 'poly',
		name: zone.name,
		color: zone.color,
		visible: zone.visible,
		height: zone.height,
		radius: zone.radius ?? 0,
		points: (zone.points ?? []).map(p => ({
			id: uid('p'),
			x: p.x,
			y: p.y,
			z: p.z ?? null,
		})),
	};
}

// Strip UI-session ids back off for the wire/persisted shape.
function dehydrate(zone: Zone): WireZone {
	const wire: WireZone = {
		name: zone.name,
		kind: zone.kind,
		color: zone.color,
		visible: zone.visible,
		height: zone.height,
		points: zone.points.map(p => ({ x: p.x, y: p.y, z: p.z })),
	};
	if (zone.kind === 'circle') wire.radius = zone.radius;
	return wire;
}

class ZoneStore {
	zones = $state<Zone[]>([]);
	activeId = $state<string | null>(null);
	cursor = $state<{ x: number; y: number } | null>(null);
	// live player position from the game; null until the first push (browser dev
	// never feeds it, so the marker stays at origin)
	player = $state<{ x: number; y: number } | null>(null);
	snapEnabled = $state(false);
	showDistances = $state(false);
	// bumped on editor open + close; the map persists zoom/pan, so reset both ways
	openTick = $state(0);
	// "View" frames the zone on the 2D map alongside the in-game 3D camera
	viewTick = $state(0);
	viewZoneId: string | null = null;
	// id of the zone whose ground Z is currently resolving, for the card spinner
	resolvingId = $state<string | null>(null);
	// id -> JSON snapshot of the last-saved zone. Dirty is DERIVED by diffing the
	// live zone against this, so reverting clears dirty with no per-mutation flag.
	// Reactive so cards re-derive on rebaseline.
	private baseline = $state(new Map<string, string>());
	// Pull the server's saved list. Browser-dev mock resolves empty for the seed.
	async load(): Promise<void> {
		const reply = await fetchNui<FetchReply>(
			'zonemanager:fetch',
			{},
			{ zones: [] },
		);
		this.replaceAll(reply.zones ?? []);
	}
	// Replace the working set with the server-canonical list; becomes the clean
	// baseline.
	replaceAll(zones: WireZone[]): void {
		this.zones = zones.map(hydrate);
		this.activeId = null;
		this.rebaseline();
	}
	private snapshot(zone: Zone): string {
		return JSON.stringify($state.snapshot(zone));
	}
	// Re-cache the current zones as the clean baseline.
	private rebaseline(): void {
		this.baseline = new Map(this.zones.map(z => [z.id, this.snapshot(z)]));
	}
	// Public hook for the dev seed to mark its seeded zones as already-persisted.
	markPristine(): void {
		this.rebaseline();
	}
	// Dirty when it differs from its saved snapshot, or has none yet (never saved).
	isDirty(zone: Zone): boolean {
		return this.baseline.get(zone.id) !== this.snapshot(zone);
	}
	// Any unsaved change: added/removed zone (count differs) or any zone diverged.
	get hasUnsaved(): boolean {
		if (this.zones.length !== this.baseline.size) return true;
		return this.zones.some(z => this.isDirty(z));
	}
	// Per-card Save persists the WHOLE file; success rebaselines every zone clean.
	async save(action: 'save' | 'delete' = 'save'): Promise<void> {
		const wire = this.zones.map(dehydrate);
		const reply = await fetchNui<SaveReply>(
			'zonemanager:save',
			{ zones: wire },
			{ ok: true },
		);
		if (!reply.ok) {
			const reason = reply.collision
				? `A zone named "${reply.collision}" already exists.`
				: reply.error === 'denied'
					? 'Permission denied - you must be an admin to edit zones.'
					: (reply.error ?? 'Unknown error.');
			toast.error(
				`${action === 'delete' ? 'Delete' : 'Save'} failed`,
				reason,
			);
			return;
		}
		this.rebaseline();
		toast.success(action === 'delete' ? 'Zone deleted' : 'Zones saved');
	}
	// Fires the in-game 3D viewer and frames the zone on the 2D map.
	viewZone(id: string): void {
		const zone = this.zones.find(z => z.id === id);
		if (!zone) return;
		void fetchNui('zonemanager:viewZone', {
			zone: dehydrate($state.snapshot(zone) as Zone),
		});
		this.viewZoneId = id;
		this.viewTick++;
	}
	// Apply the height tweaked live in the 3D viewer back onto the viewed zone.
	viewerHeight(height: number): void {
		const zone = this.zones.find(z => z.id === this.viewZoneId);
		if (!zone) return;
		zone.height = height;
	}
	get active(): Zone | undefined {
		return this.zones.find(z => z.id === this.activeId);
	}
	activate(id: string): void {
		this.activeId = id;
	}
	createZone(name: string, kind: Zone['kind'] = 'poly'): Zone {
		const zone: Zone = {
			id: uid('z'),
			kind,
			name:
				name.trim().toLowerCase().replace(/\s+/g, '_') ||
				`zone_${this.zones.length + 1}`,
			color: ZONE_COLORS[
				this.zones.length % ZONE_COLORS.length
			] as string,
			visible: true,
			height: 150,
			points: [],
			radius: kind === 'circle' ? 50 : 0,
		};
		this.zones.push(zone);
		this.activeId = zone.id;
		return zone;
	}
	// Delete drops the zone locally then persists the whole file, so a reopen
	// (which re-fetches the server list) doesn't resurrect it.
	async deleteZone(id: string): Promise<void> {
		this.zones = this.zones.filter(z => z.id !== id);
		if (this.activeId === id) this.activeId = this.zones[0]?.id ?? null;
		await this.save('delete');
	}
	rename(id: string, name: string): void {
		const zone = this.zones.find(z => z.id === id);
		if (!zone) return;
		// match the Lua registry-key normalization so the displayed name IS the key.
		// Cap at 64 so a pasted wall of text can't bloat zones.json.
		const key = name.trim().toLowerCase().replace(/\s+/g, '_').slice(0, 64);
		zone.name = key || zone.name;
	}
	toggleVisible(id: string): void {
		const zone = this.zones.find(z => z.id === id);
		if (!zone) return;
		zone.visible = !zone.visible;
	}
	setHeight(id: string, height: number): void {
		const zone = this.zones.find(z => z.id === id);
		if (!zone || !Number.isFinite(height)) return;
		zone.height = Math.max(0, height);
	}
	setColor(id: string, color: string): void {
		const zone = this.zones.find(z => z.id === id);
		if (!zone) return;
		zone.color = color;
	}
	setRadius(id: string, radius: number): void {
		const zone = this.zones.find(z => z.id === id);
		if (!zone || !Number.isFinite(radius)) return;
		zone.radius = Math.max(0, radius);
	}
	// Circle center lives in points[0]. A move clears its z so the next ground-Z
	// resolve re-reads terrain at the new spot, same as movePoint.
	setCenter(x: number, y: number): void {
		const zone = this.active;
		if (zone?.kind !== 'circle') return;
		const p = this.place(x, y);
		zone.points = [makePoint(p.x, p.y)];
	}
	setGroundZ(id: string, z: number): void {
		const zone = this.zones.find(zo => zo.id === id);
		if (!zone || !Number.isFinite(z)) return;
		for (const p of zone.points) p.z = round(z, 4);
	}
	// x/y are raw game coords; snapping is applied here so every entry point gets
	// identical treatment.
	private place(x: number, y: number): { x: number; y: number } {
		return this.snapEnabled ? { x: snap(x), y: snap(y) } : { x, y };
	}
	addPoint(x: number, y: number): void {
		const zone = this.active;
		if (!zone) return;
		const p = this.place(x, y);
		zone.points.push(makePoint(p.x, p.y));
	}
	insertPoint(zoneId: string, index: number, x: number, y: number): void {
		const zone = this.zones.find(z => z.id === zoneId);
		if (!zone) return;
		const p = this.place(x, y);
		zone.points.splice(index, 0, makePoint(p.x, p.y));
	}
	movePoint(zoneId: string, pointId: string, x: number, y: number): void {
		const zone = this.zones.find(z => z.id === zoneId);
		const point = zone?.points.find(pt => pt.id === pointId);
		if (!zone || !point) return;
		const p = this.place(x, y);
		point.x = round(p.x, 2);
		point.y = round(p.y, 2);
		// z is stale terrain at the old spot; clear so the next resolve re-reads
		point.z = null;
	}
	deletePoint(zoneId: string, pointId: string): void {
		const zone = this.zones.find(z => z.id === zoneId);
		if (!zone) return;
		zone.points = zone.points.filter(p => p.id !== pointId);
	}
	// Resolve ground Z for every vertex in ONE round trip. resolvingId drives the
	// card spinner; browser dev gets flat mocks.
	async resolveGroundZ(id: string): Promise<void> {
		const zone = this.zones.find(z => z.id === id);
		if (!zone || zone.points.length === 0) return;
		this.resolvingId = id;
		try {
			const points = zone.points.map(p => ({ x: p.x, y: p.y }));
			const reply = await fetchNui<GroundZBatchReply>(
				'zonemanager:getPointsZ',
				{ points },
				{ zs: points.map(() => round(20 + Math.random() * 40, 2)) },
			);
			let failed = false;
			zone.points.forEach((p, i) => {
				const z = reply.zs?.[i];
				if (z === false || z == null) {
					failed = true;
					return;
				}
				p.z = round(z, 4);
			});
			if (failed) toast.error('Ground Z lookup failed for some points');
		} finally {
			this.resolvingId = null;
		}
	}
}

export const store = new ZoneStore();
