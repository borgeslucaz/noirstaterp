<script lang="ts">
import L from 'leaflet';
import { onMount, untrack } from 'svelte';
import gtaMapUrl from '@/assets/maps/map.jpg';
import { contrastText, safeColor } from '@/lib/color';
import {
	distance,
	GRID_SIZE,
	GTA_BOUNDS,
	gtaToLatLng,
	IMG_HEIGHT,
	IMG_WIDTH,
	latLngToGta,
	metersToMapUnits,
	snap,
} from '@/lib/coords';
import { store } from '@/lib/store.svelte';
import type { Zone, ZonePoint } from '@/lib/types';

let mapEl: HTMLDivElement;
let map: L.Map;
let shapeLayer: L.LayerGroup;
let markerLayer: L.LayerGroup;
let playerMarker: L.Marker;
let gridLayer: L.LayerGroup | null = null;
let previewLine: L.Polyline | null = null;
let lastDragEnd = 0;
let dragging = false;
let ready = $state(false);

const toGta = (e: L.LeafletMouseEvent): { x: number; y: number } => {
	const g = latLngToGta(e.latlng.lat, e.latlng.lng);
	return store.snapEnabled ? { x: snap(g.x), y: snap(g.y) } : g;
};
// point -> Leaflet LatLng tuple, projected fresh from the game coords - the
// pixel pair is derived render-time data, never stored on the point.
const ll = (p: ZonePoint): [number, number] => gtaToLatLng(p.x, p.y);

onMount(() => {
	map = L.map(mapEl, {
		crs: L.CRS.Simple,
		minZoom: -2,
		maxZoom: 4,
		zoomControl: false,
		attributionControl: false,
		zoomSnap: 0.1,
		zoomDelta: 0.2,
		// off: recreating the dragged marker mid-drag reads as a dbl-click and
		// zoom-recenters on the point. wheel + Recenter still zoom.
		doubleClickZoom: false,
		wheelPxPerZoomLevel: 120,
		preferCanvas: true,
		inertia: true,
		maxBoundsViscosity: 0.85,
	});
	const bounds: L.LatLngBoundsExpression = [
		[0, 0],
		[IMG_HEIGHT, IMG_WIDTH],
	];
	L.imageOverlay(gtaMapUrl, bounds).addTo(map);
	map.setMaxBounds(bounds);
	shapeLayer = L.layerGroup().addTo(map);
	markerLayer = L.layerGroup().addTo(map);
	// parked at origin until the game feeds store.player (tracked by an effect
	// below); browser dev never feeds it, so it stays at origin
	const [plat, plng] = gtaToLatLng(0, 0);
	playerMarker = L.marker([plat, plng], {
		interactive: false,
		zIndexOffset: 2000,
		icon: L.divIcon({
			className: 'player-dot',
			iconSize: [30, 30],
			iconAnchor: [15, 15],
		}),
	})
		.bindTooltip('Player Location', {
			permanent: true,
			direction: 'center',
			offset: [0, -32],
			className: 'player-label',
		})
		.addTo(map);
	map.on('mousemove', e => {
		const g = toGta(e);
		store.cursor = {
			x: Math.round(g.x * 100) / 100,
			y: Math.round(g.y * 100) / 100,
		};
		const active = store.active;
		if (
			previewLine &&
			active &&
			active.kind === 'poly' &&
			active.points.length > 0
		) {
			const last = active.points[active.points.length - 1];
			if (last)
				previewLine.setLatLngs([
					ll(last),
					[e.latlng.lat, e.latlng.lng],
				]);
		}
	});
	map.on('click', e => {
		if (!store.active || dragging || Date.now() - lastDragEnd < 250) return;
		const g = toGta(e);
		// circle: a click (re)places the single center; poly: appends a vertex
		if (store.active.kind === 'circle') store.setCenter(g.x, g.y);
		else store.addPoint(g.x, g.y);
	});
	// flex column has no measured size at mount; size + fit next frame
	requestAnimationFrame(() => {
		map.invalidateSize();
		map.fitBounds(bounds);
		// start fully zoomed out
		map.setZoom(map.getMinZoom());
		ready = true;
	});
	const onResize = (): void => {
		map.invalidateSize();
	};
	window.addEventListener('resize', onResize);
	return () => {
		window.removeEventListener('resize', onResize);
		map.remove();
	};
});

function pointMarker(zone: Zone, index: number): void {
	const p = zone.points[index];
	if (!p) return;
	const active = zone.id === store.activeId;
	const size = active ? 26 : 20;
	const sc = safeColor(zone.color);
	const marker = L.marker(ll(p), {
		bubblingMouseEvents: false,
		icon: L.divIcon({
			className: '',
			html: `<div class="point-dot ${active ? 'active' : ''}" style="width:${size}px;height:${size}px;background:${sc};border-color:${active ? 'var(--map-fg)' : sc};color:${contrastText(sc)}">${index + 1}</div>`,
			iconSize: [size, size],
			iconAnchor: [size / 2, size / 2],
		}),
	});
	const zTxt = p.z ?? '-';
	marker.bindTooltip(
		`<b>Point ${index + 1}</b><br>X ${p.x} · Y ${p.y} · Z ${zTxt}${active ? "<br><span style='opacity:.6'>drag to move · right-click delete</span>" : ''}`,
		{ className: 'zone-tip', direction: 'top', offset: [0, -48] },
	);
	if (active) {
		marker.on('mousedown', e => {
			L.DomEvent.stop(e.originalEvent);
			dragging = true;
			map.dragging.disable();
			const move = (m: L.LeafletMouseEvent): void => {
				const g = toGta(m);
				store.movePoint(zone.id, p.id, g.x, g.y);
			};
			const up = (): void => {
				dragging = false;
				lastDragEnd = Date.now();
				map.dragging.enable();
				map.off('mousemove', move);
				map.off('mouseup', up);
			};
			map.on('mousemove', move);
			map.on('mouseup', up);
		});
		marker.on('contextmenu', e => {
			L.DomEvent.stop(e.originalEvent);
			store.deletePoint(zone.id, p.id);
		});
	}
	marker.addTo(markerLayer);
}

// Circle center handle: a single draggable marker; drag moves the center.
function centerMarker(zone: Zone): void {
	const c = zone.points[0];
	if (!c) return;
	const active = zone.id === store.activeId;
	const size = active ? 26 : 20;
	const sc = safeColor(zone.color);
	const marker = L.marker(ll(c), {
		bubblingMouseEvents: false,
		icon: L.divIcon({
			className: '',
			html: `<div class="point-dot ${active ? 'active' : ''}" style="width:${size}px;height:${size}px;background:${sc};border-color:${active ? 'var(--map-fg)' : sc};color:${contrastText(sc)}">+</div>`,
			iconSize: [size, size],
			iconAnchor: [size / 2, size / 2],
		}),
	});
	const zTxt = c.z ?? '-';
	marker.bindTooltip(
		`<b>Center</b><br>X ${c.x} · Y ${c.y} · Z ${zTxt} · R ${zone.radius}m${active ? "<br><span style='opacity:.6'>drag to move</span>" : ''}`,
		{ className: 'zone-tip', direction: 'top', offset: [0, -48] },
	);
	if (active) {
		marker.on('mousedown', e => {
			L.DomEvent.stop(e.originalEvent);
			dragging = true;
			map.dragging.disable();
			const move = (m: L.LeafletMouseEvent): void => {
				const g = toGta(m);
				store.setCenter(g.x, g.y);
			};
			const up = (): void => {
				dragging = false;
				lastDragEnd = Date.now();
				map.dragging.enable();
				map.off('mousemove', move);
				map.off('mouseup', up);
			};
			map.on('mousemove', move);
			map.on('mouseup', up);
		});
	}
	marker.addTo(markerLayer);
}

function drawZone(zone: Zone): void {
	if (!zone.visible) return;
	const active = zone.id === store.activeId;
	if (zone.kind === 'circle') {
		const c = zone.points[0];
		if (c) {
			const [clat, clng] = ll(c);
			L.circle([clat, clng], {
				radius: metersToMapUnits(zone.radius),
				color: zone.color,
				weight: active ? 3 : 2,
				fillColor: zone.color,
				fillOpacity: active ? 0.28 : 0.16,
				dashArray: active ? undefined : '6 6',
			}).addTo(shapeLayer);
			// Dist toggle: radius spoke from center to the right edge, labelled.
			if (store.showDistances) {
				const r = metersToMapUnits(zone.radius);
				L.polyline(
					[
						[clat, clng],
						[clat, clng + r],
					],
					{ color: zone.color, weight: 2, interactive: false },
				).addTo(shapeLayer);
				L.marker([clat, clng + r / 2], {
					interactive: false,
					icon: L.divIcon({
						className: '',
						html: `<span class="dist-label">${zone.radius}m</span>`,
						iconSize: [48, 16],
						iconAnchor: [24, 8],
					}),
				}).addTo(shapeLayer);
			}
			centerMarker(zone);
		}
		return;
	}
	const latlngs = zone.points.map(ll);
	if (zone.points.length >= 3) {
		const poly = L.polygon(latlngs, {
			color: zone.color,
			weight: active ? 3 : 2,
			fillColor: zone.color,
			fillOpacity: active ? 0.28 : 0.16,
			dashArray: active ? undefined : '6 6',
		}).addTo(shapeLayer);
		if (active) {
			poly.on('click', e => {
				L.DomEvent.stop(e.originalEvent);
				let best = Number.POSITIVE_INFINITY;
				let at = 0;
				for (let i = 0; i < zone.points.length; i++) {
					const a = zone.points[i];
					const b = zone.points[(i + 1) % zone.points.length];
					if (!a || !b) continue;
					const [alat, alng] = ll(a);
					const [blat, blng] = ll(b);
					const ml = (alat + blat) / 2;
					const mn = (alng + blng) / 2;
					const d = Math.hypot(e.latlng.lat - ml, e.latlng.lng - mn);
					if (d < best) {
						best = d;
						at = i + 1;
					}
				}
				const g = latLngToGta(e.latlng.lat, e.latlng.lng);
				store.insertPoint(zone.id, at, g.x, g.y);
			});
		}
	} else if (zone.points.length === 2) {
		L.polyline(latlngs, {
			color: zone.color,
			weight: 2,
			dashArray: '6 6',
		}).addTo(shapeLayer);
	}
	if (store.showDistances && zone.points.length >= 2) {
		for (let i = 0; i < zone.points.length; i++) {
			const a = zone.points[i];
			const b = zone.points[(i + 1) % zone.points.length];
			if (!a || !b) continue;
			if (zone.points.length === 2 && i === 1) break;
			const [alat, alng] = ll(a);
			const [blat, blng] = ll(b);
			L.marker([(alat + blat) / 2, (alng + blng) / 2], {
				interactive: false,
				icon: L.divIcon({
					className: '',
					html: `<span class="dist-label">${distance(a, b).toFixed(1)}m</span>`,
					iconSize: [48, 16],
					iconAnchor: [24, 8],
				}),
			}).addTo(shapeLayer);
		}
	}
	zone.points.forEach((_, i) => {
		pointMarker(zone, i);
	});
}

// Rebuild all vector layers whenever zone data, selection or toggles change.
$effect(() => {
	if (!ready) return;
	// touch reactive deps so the effect re-runs on nested point edits
	JSON.stringify(store.zones);
	void store.activeId;
	void store.showDistances;
	shapeLayer.clearLayers();
	markerLayer.clearLayers();
	previewLine = null;
	const active = store.active;
	if (active && active.kind === 'poly' && active.points.length > 0) {
		previewLine = L.polyline([], {
			color: active.color,
			weight: 2,
			dashArray: '4 8',
			opacity: 0.6,
		}).addTo(shapeLayer);
	}
	for (const zone of store.zones) drawZone(zone);
});

// Track the live player position onto the marker each push.
$effect(() => {
	const p = store.player;
	if (!ready || !p) return;
	const [lat, lng] = gtaToLatLng(p.x, p.y);
	playerMarker.setLatLng([lat, lng]);
});

// Re-fit zoomed out when openTick bumps (every editor open + close). animate:false
// keeps it instant so an open never jerks; invalidateSize covers a viewport resize.
$effect(() => {
	void store.openTick;
	if (!ready || store.openTick === 0) return;
	map.invalidateSize();
	map.fitBounds(
		[
			[0, 0],
			[IMG_HEIGHT, IMG_WIDTH],
		],
		{ animate: false },
	);
	map.setZoom(map.getMinZoom());
});

// View button frames the zone on the 2D map. Read zones/viewZoneId untracked so a
// zone edit doesn't re-run this and re-frame the last viewed zone; only viewTick does.
$effect(() => {
	const tick = store.viewTick;
	if (!ready || tick === 0) return;
	untrack(() => {
		const zone = store.zones.find(z => z.id === store.viewZoneId);
		if (!zone || zone.points.length === 0) return;
		if (zone.kind === 'circle') {
			const c = zone.points[0];
			if (!c) return;
			const [clat, clng] = ll(c);
			const r = metersToMapUnits(zone.radius);
			map.fitBounds(
				[
					[clat - r, clng - r],
					[clat + r, clng + r],
				],
				{ padding: [80, 80], maxZoom: 3, animate: true },
			);
			return;
		}
		const pts = zone.points.map(ll);
		map.fitBounds(pts, { padding: [80, 80], maxZoom: 3, animate: true });
	});
});

// Major grid overlay tied to the snap toggle.
$effect(() => {
	if (!ready) return;
	if (gridLayer) {
		gridLayer.remove();
		gridLayer = null;
	}
	if (!store.snapEnabled) return;
	const g = L.layerGroup();
	const step = GRID_SIZE * 5;
	// canvas renderer needs a concrete color, not a CSS var
	const accent =
		getComputedStyle(document.documentElement)
			.getPropertyValue('--map-accent')
			.trim() || '#10b981';
	for (let x = GTA_BOUNDS.minX; x <= GTA_BOUNDS.maxX; x += step) {
		L.polyline(
			[gtaToLatLng(x, GTA_BOUNDS.minY), gtaToLatLng(x, GTA_BOUNDS.maxY)],
			{
				color: accent,
				weight: 1.5,
				opacity: 0.6,
				interactive: false,
			},
		).addTo(g);
	}
	for (let y = GTA_BOUNDS.minY; y <= GTA_BOUNDS.maxY; y += step) {
		L.polyline(
			[gtaToLatLng(GTA_BOUNDS.minX, y), gtaToLatLng(GTA_BOUNDS.maxX, y)],
			{
				color: accent,
				weight: 1.5,
				opacity: 0.6,
				interactive: false,
			},
		).addTo(g);
	}
	gridLayer = g.addTo(map);
});
</script>

<div bind:this={mapEl} class="h-full w-full"></div>
