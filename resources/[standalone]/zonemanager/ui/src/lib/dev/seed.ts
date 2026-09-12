// Dev-only seed, dynamically imported behind import.meta.env.DEV so it
// tree-shakes out of the shipped build.
import { store } from '../store.svelte';

export function seedDemo(): void {
	const zone = store.createZone('Legion Square');
	const ring: [number, number][] = [
		[180, -960],
		[250, -1010],
		[230, -1090],
		[140, -1080],
		[110, -1000],
	];
	for (const [x, y] of ring) store.addPoint(x, y);
	store.setGroundZ(zone.id, 28);
	store.setHeight(zone.id, 120);
	const circle = store.createZone('Sandy Circle', 'circle');
	store.setCenter(1850, 3700);
	store.setRadius(circle.id, 80);
	store.setGroundZ(circle.id, 35);
	store.setHeight(circle.id, 60);
	// baseline the seed so derived dirty state starts clean (no Save nag)
	store.markPristine();
	store.activeId = null;
}
