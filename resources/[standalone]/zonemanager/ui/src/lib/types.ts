// One polygon vertex (or a circle's center). x/y/z are raw game coords; z is
// null until resolved. `id` is a UI-session key for keyed each-blocks + drag
// targets - regenerated on every load, never persisted. Map-pixel coords are
// derived from x/y at render time (coords.ts), never stored.
export interface ZonePoint {
	id: string;
	x: number;
	y: number;
	z: number | null;
}

// Zone shape. 'poly' reads points as a ring (>=3); 'circle' reads points[0] as
// the center and radius (meters) as the footprint.
export type ZoneKind = 'poly' | 'circle';

// A zone the editor owns. Dirty state is derived by the store, not a field.
// `radius` is meaningful only for circle zones. `id` is UI-session-only.
export interface Zone {
	id: string;
	kind: ZoneKind;
	name: string;
	color: string;
	visible: boolean;
	height: number;
	points: ZonePoint[];
	radius: number;
}

// The persisted wire shape the server sends/accepts: no ids, flat points.
export interface WireZone {
	name: string;
	kind?: ZoneKind;
	color: string;
	visible: boolean;
	height: number;
	points: { x: number; y: number; z?: number | null }[];
	radius?: number;
}

// ---- NUI bridge contracts ----

// Lua -> NUI (SendNUIMessage). Keys are the `action` field.
export interface IncomingMap {
	setVisible: boolean;
	// server live-reload push after a save elsewhere
	loadZones: WireZone[];
	// live player position, pushed each tick while the editor is open
	playerPos: { x: number; y: number };
	// 3D viewer lifecycle; payload height lands back on the zone when it closes
	'zonemanager:viewerStarted': { height: number };
	// live height tweaked in-world, pushed each change so the HUD readout tracks
	'zonemanager:viewerUpdate': { height: number };
	'zonemanager:viewerStopped': { height: number };
}

// NUI -> Lua (fetchNui). Keys are the RegisterNUICallback names; the value is
// the request payload. Reply shapes are the fetchNui<R> result types below.
export interface OutgoingMap {
	hideFrame: Record<string, never>;
	'zonemanager:save': { zones: WireZone[] };
	'zonemanager:fetch': Record<string, never>;
	'zonemanager:getPointsZ': { points: { x: number; y: number }[] };
	'zonemanager:viewZone': { zone: WireZone };
}

export interface SaveReply {
	ok: boolean;
	error?: string;
	collision?: string;
}

export interface FetchReply {
	zones: WireZone[];
}

// One entry per input point, aligned by index; false where the lookup failed.
export interface GroundZBatchReply {
	zs: (number | false)[];
}
