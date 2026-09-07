export const DOCK_MAX = 4;

export function insertIntoDock(dock: string[], id: string, index: number, max: number = DOCK_MAX): { dock: string[]; displaced: string | null } {
    const rest = dock.filter(x => x !== id);
    if (rest.length < max) {
        const at = Math.max(0, Math.min(rest.length, index));
        const next = [...rest];
        next.splice(at, 0, id);
        return { dock: next, displaced: null };
    }
    const at = Math.max(0, Math.min(rest.length - 1, index));
    const next = [...rest];
    const displaced = next[at] ?? null;
    next[at] = id;
    return { dock: next, displaced };
}

export function freeCellNear(cells: (string | null)[], covered: Set<number>, from: number): number | null {
    const usable = (c: number) => c >= 0 && c < cells.length && !covered.has(c) && cells[c] === null;
    if (usable(from)) return from;
    for (let d = 1; d < cells.length; d++) {
        if (usable(from - d)) return from - d;
        if (usable(from + d)) return from + d;
    }
    return null;
}

export interface DockDrag {
    id:           string;
    dock:         string[];
    slots:        (string | null)[];
    dockIndex:    number | null;
    fromDock:     boolean;
    fromIndex:    number;
    page:         number;
    overCell:     number;
    blocked:      Set<number>;
    merge:        boolean;
    itemsPerPage: number;
    max?:         number;
}

export interface DockPlan {
    dock:          string[];
    slots:         (string | null)[];
    displaced:     string | null;
    displacedCell: number | null;
    intoDock:      string | null;
    landedCell:    number | null;
}

export function planDockDrag(d: DockDrag): DockPlan | null {
    if (d.dockIndex !== null) {
        const { dock, displaced } = insertIntoDock(d.dock, d.id, d.dockIndex, d.max ?? DOCK_MAX);
        if (d.fromDock) {
            return { dock, slots: d.slots, displaced: null, displacedCell: null, intoDock: null, landedCell: null };
        }
        return {
            dock,
            slots:         d.slots.map((x, i) => (i === d.fromIndex ? displaced : x)),
            displaced,
            displacedCell: displaced !== null ? d.fromIndex : null,
            intoDock:      null,
            landedCell:    null,
        };
    }
    if (!d.fromDock || d.merge) return null;

    const base  = d.page * d.itemsPerPage;
    const cells = Array.from({ length: d.itemsPerPage }, (_, i) => d.slots[base + i] ?? null);
    const stay: DockPlan = { dock: d.dock, slots: d.slots, displaced: null, displacedCell: null, intoDock: null, landedCell: null };
    let cell = d.overCell;
    if (cell < 0 || cell >= d.itemsPerPage) return stay;
    if (d.blocked.has(cell)) {
        const free = freeCellNear(cells, d.blocked, cell);
        if (free === null) return stay;
        cell = free;
    }
    const intoDock = cells[cell];
    const slots    = [...d.slots];
    while (slots.length <= base + cell) slots.push(null);
    slots[base + cell] = d.id;
    return {
        dock:          intoDock ? d.dock.map(x => (x === d.id ? intoDock : x)) : d.dock.filter(x => x !== d.id),
        slots,
        displaced:     null,
        displacedCell: null,
        intoDock,
        landedCell:    base + cell,
    };
}
