export function launchOriginFrom(el: HTMLElement | null): { x: number; y: number } {
    const fallback = { x: 0.5, y: 0.8 };
    if (!el) return fallback;

    const rect   = el.getBoundingClientRect();
    const screen = (document.querySelector('[data-phone-screen]') as HTMLElement | null)?.getBoundingClientRect();
    if (!screen || screen.width <= 0 || screen.height <= 0) return fallback;

    const cx = rect.left + rect.width / 2;
    const cy = rect.top + rect.height / 2;
    return {
        x: Math.max(0, Math.min(1, (cx - screen.left) / screen.width)),
        y: Math.max(0, Math.min(1, (cy - screen.top) / screen.height)),
    };
}
