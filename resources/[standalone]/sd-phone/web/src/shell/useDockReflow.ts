import { useLayoutEffect, useRef } from 'react';

const DURATION = 340;
const EASE = 'cubic-bezier(0.32,0.72,0,1)';

function centres(root: HTMLElement): Map<string, number> {
    const out = new Map<string, number>();
    for (const el of root.querySelectorAll<HTMLElement>('[data-dock-id]')) {
        const id = el.dataset.dockId;
        if (id) out.set(id, el.offsetLeft + el.offsetWidth / 2);
    }
    return out;
}

export function useDockReflow<T extends HTMLElement>(key: string) {
    const ref = useRef<T | null>(null);
    const previous = useRef<Map<string, number> | null>(null);

    useLayoutEffect(() => {
        const root = ref.current;
        if (!root) return;

        const now = centres(root);
        const before = previous.current;
        previous.current = now;
        if (!before) return;

        const moved: { el: HTMLElement; shift: number }[] = [];
        for (const el of root.querySelectorAll<HTMLElement>('[data-dock-id]')) {
            const id = el.dataset.dockId;
            if (!id) continue;
            const from = before.get(id);
            const to = now.get(id);
            if (from === undefined || to === undefined || Math.abs(from - to) < 0.5) continue;
            moved.push({ el, shift: from - to });
        }
        if (!moved.length) return;

        for (const { el, shift } of moved) {
            el.style.transition = 'none';
            el.style.transform = `translateX(${shift}px)`;
        }

        void root.offsetWidth;

        for (const { el } of moved) {
            el.style.transition = `transform ${DURATION}ms ${EASE}`;
            el.style.transform = 'translateX(0px)';
        }
    }, [key]);

    return ref;
}
