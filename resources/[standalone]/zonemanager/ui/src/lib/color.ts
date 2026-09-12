// Zone color helpers shared by the map and the panel.

// Marker/index label: black on light fills, white on dark, so it never blends.
export function contrastText(hex: string): string {
	const h = hex.replace('#', '');
	const r = parseInt(h.slice(0, 2), 16);
	const g = parseInt(h.slice(2, 4), 16);
	const b = parseInt(h.slice(4, 6), 16);
	return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.37 ? '#000' : '#fff';
}

// zone.color is interpolated into Leaflet divIcon HTML (assigned via innerHTML);
// clamp to a #rrggbb hex so a crafted value can't break out of the style
// attribute into an event handler. Falls back to a neutral grey on any miss.
export function safeColor(color: string): string {
	return /^#[0-9a-fA-F]{6}$/.test(color) ? color : '#888888';
}
