// Projection between GTA V world coords and the satellite map image. Under
// Leaflet CRS.Simple, "lat" is image-pixel Y, "lng" is image-pixel X. The
// scale/offset factors are fitted calibration constants for the 4096x6144 tile,
// not derivable.

export const IMG_WIDTH = 4096;
export const IMG_HEIGHT = 6144;
export const GRID_SIZE = 10;

export const GTA_BOUNDS = { minX: -4000, maxX: 4500, minY: -4000, maxY: 8000 };

const PROJECTION = {
	scaleX: 0.454685,
	scaleY: -0.45483,
	offsetX: 1882.72,
	offsetY: 3826.58,
};

export interface Vec2 {
	x: number;
	y: number;
}

// world (x,y) -> map (lat,lng) pixel pair
export function gtaToLatLng(x: number, y: number): [number, number] {
	const lng = x * PROJECTION.scaleX + PROJECTION.offsetX;
	const lat = IMG_HEIGHT - (y * PROJECTION.scaleY + PROJECTION.offsetY);
	return [lat, lng];
}

// map (lat,lng) pixel pair -> world (x,y)
export function latLngToGta(lat: number, lng: number): Vec2 {
	const x = (lng - PROJECTION.offsetX) / PROJECTION.scaleX;
	const y = (IMG_HEIGHT - lat - PROJECTION.offsetY) / PROJECTION.scaleY;
	return { x, y };
}

// A circle radius is authored in game meters but L.circle on CRS.Simple takes
// its radius in map-image units, so scale by the projection's pixels-per-metre.
export function metersToMapUnits(meters: number): number {
	return meters * Math.abs(PROJECTION.scaleX);
}

export function snap(value: number, grid = GRID_SIZE): number {
	return Math.round(value / grid) * grid;
}

export function round(value: number, digits: number): number {
	const f = 10 ** digits;
	return Math.round(value * f) / f;
}

export function distance(a: Vec2, b: Vec2): number {
	return Math.hypot(b.x - a.x, b.y - a.y);
}
