import { getGrid } from '@/device/grid';
import { freeCellNear } from '../dockMoves';
import type { Density, DeviceGrid } from '@/device/types';
import type { SavedLayout, WidgetSize, WidgetPlacement } from '@/apps/appstore/appsApi';

type Placed = Pick<WidgetPlacement, 'size' | 'col' | 'row'>;

const BASE_SPAN: Record<WidgetSize, { w: number; h: number }> = {
    sm: { w: 2, h: 2 },
    md: { w: 4, h: 2 },
    lg: { w: 4, h: 4 },
};

export function spanFor(size: WidgetSize, cols: number, rows: number): { w: number; h: number } {
    const base = BASE_SPAN[size];
    return { w: Math.min(base.w, cols), h: Math.min(base.h, rows) };
}

export function spanOf(size: WidgetSize): { w: number; h: number } {
    const g = getGrid();
    return spanFor(size, g.cols, g.rows);
}

export function widgetPx(size: WidgetSize, scale = 1): { width: number; height: number } {
    const g = getGrid();
    const { w, h } = spanFor(size, g.cols, g.rows);
    return {
        width:  Math.round((w * g.icon + (w - 1) * (g.colStride - g.icon)) * scale),
        height: Math.round((h * g.icon + (h - 1) * (g.rowStride - g.icon)) * scale),
    };
}

const JIGGLE_SWEEP_PX = 3;

export function jiggleDeg(size: WidgetSize): number {
    const { width, height } = widgetPx(size);
    const halfDiagonal = Math.hypot(width, height) / 2;
    const deg = (Math.asin(Math.min(1, JIGGLE_SWEEP_PX / halfDiagonal)) * 180) / Math.PI;
    return Math.round(deg * 100) / 100;
}

function cellsIn(w: Placed, cols: number, rows: number): number[] {
    const { w: sw, h: sh } = spanFor(w.size, cols, rows);
    const out: number[] = [];
    for (let r = w.row; r < w.row + sh; r++) {
        for (let c = w.col; c < w.col + sw; c++) {
            if (r < rows && c < cols) out.push(r * cols + c);
        }
    }
    return out;
}

export function coveredCells(w: Placed): number[] {
    const g = getGrid();
    return cellsIn(w, g.cols, g.rows);
}

function fitIn(blocked: Set<number>, size: WidgetSize, cols: number, rows: number): { col: number; row: number } | null {
    const { w: sw, h: sh } = spanFor(size, cols, rows);
    for (let row = 0; row + sh <= rows; row++) {
        for (let col = 0; col + sw <= cols; col++) {
            if (cellsIn({ size, col, row }, cols, rows).every(c => !blocked.has(c))) return { col, row };
        }
    }
    return null;
}

export function firstFit(
    size: WidgetSize,
    page: number,
    slots: (string | null)[],
    widgets: WidgetPlacement[],
    itemsPerPage: number,
): { col: number; row: number } | null {
    const g = getGrid();
    const blocked = new Set<number>();

    const base = page * itemsPerPage;
    for (let i = 0; i < itemsPerPage; i++) {
        if (slots[base + i]) blocked.add(i);
    }
    for (const w of widgets) {
        if (w.page === page) cellsIn(w, g.cols, g.rows).forEach(c => blocked.add(c));
    }

    return fitIn(blocked, size, g.cols, g.rows);
}

export function fitsIn(w: Placed, cols: number, rows: number): boolean {
    const { w: sw, h: sh } = spanFor(w.size, cols, rows);
    return w.col >= 0 && w.row >= 0 && w.col + sw <= cols && w.row + sh <= rows;
}

function fitsGrid(w: Placed): boolean {
    const g = getGrid();
    return fitsIn(w, g.cols, g.rows);
}

function overlaps(a: Placed, b: Placed): boolean {
    const cells = new Set(coveredCells(a));
    return coveredCells(b).some(c => cells.has(c));
}

export function trySwap(
    widgets: WidgetPlacement[],
    draggedUid: string,
    target: { page: number; col: number; row: number },
): WidgetPlacement[] | null {
    const dragged = widgets.find(w => w.uid === draggedUid);
    if (!dragged) return null;

    const landing: Placed = { size: dragged.size, col: target.col, row: target.row };
    const hit = widgets.filter(o => o.uid !== draggedUid && o.page === target.page && overlaps(o, landing));
    if (hit.length !== 1) return null;

    const partner = hit[0];
    const nextDragged = { ...dragged, page: target.page, col: target.col, row: target.row };
    const nextPartner = { ...partner, page: dragged.page, col: dragged.col, row: dragged.row };
    if (!fitsGrid(nextDragged) || !fitsGrid(nextPartner)) return null;
    if (nextDragged.page === nextPartner.page && overlaps(nextDragged, nextPartner)) return null;

    for (const o of widgets) {
        if (o.uid === draggedUid || o.uid === partner.uid) continue;
        if (o.page === nextDragged.page && overlaps(o, nextDragged)) return null;
        if (o.page === nextPartner.page && overlaps(o, nextPartner)) return null;
    }

    return widgets.map(w => {
        if (w.uid === draggedUid) return nextDragged;
        if (w.uid === partner.uid) return nextPartner;
        return w;
    });
}

export function refitWidgets(widgets: WidgetPlacement[], cols: number, rows: number): WidgetPlacement[] {
    const taken = new Map<number, Set<number>>();
    const claim = (page: number, w: Placed) => {
        const set = taken.get(page) ?? new Set<number>();
        for (const c of cellsIn(w, cols, rows)) set.add(c);
        taken.set(page, set);
    };

    const order = [...widgets].sort((a, b) => a.page - b.page || a.row - b.row || a.col - b.col);
    const out: WidgetPlacement[] = [];

    for (const w of order) {
        const { w: sw, h: sh } = spanFor(w.size, cols, rows);
        let page = w.page;
        let col  = Math.max(0, Math.min(cols - sw, w.col));
        let row  = Math.max(0, Math.min(rows - sh, w.row));

        for (;;) {
            const blocked = taken.get(page) ?? new Set<number>();
            if (cellsIn({ size: w.size, col, row }, cols, rows).every(c => !blocked.has(c))) break;
            const spot = fitIn(blocked, w.size, cols, rows);
            if (spot) { col = spot.col; row = spot.row; break; }
            page += 1;
            col = 0;
            row = 0;
        }

        claim(page, { size: w.size, col, row });
        out.push(w.page === page && w.col === col && w.row === row ? w : { ...w, page, col, row });
    }

    return out;
}

function flowIcons(ids: string[], widgets: WidgetPlacement[], cols: number, rows: number): (string | null)[] {
    const perPage = cols * rows;
    const covered = new Map<number, Set<number>>();
    for (const w of widgets) {
        const set = covered.get(w.page) ?? new Set<number>();
        for (const c of cellsIn(w, cols, rows)) set.add(c);
        covered.set(w.page, set);
    }

    const out: (string | null)[] = [];
    const grow = (upto: number) => { while (out.length <= upto) out.push(null); };

    let cell = 0;
    for (const id of ids) {
        while (covered.get(Math.floor(cell / perPage))?.has(cell % perPage)) {
            grow(cell);
            cell += 1;
        }
        grow(cell);
        out[cell] = id;
        cell += 1;
    }

    const lastWidgetPage = widgets.reduce((m, w) => Math.max(m, w.page), -1);
    grow((lastWidgetPage + 1) * perPage - 1);
    while (out.length % perPage !== 0) out.push(null);
    return out;
}

export function refitLayout(layout: SavedLayout, from: DeviceGrid, to: DeviceGrid, density?: Density): SavedLayout {
    const sameGrid = from.cols === to.cols && from.rows === to.rows;
    if (sameGrid && (density === undefined || density === layout.density)) return layout;

    const widgets = refitWidgets(layout.widgets ?? [], to.cols, to.rows);
    const ids = layout.slots.filter((id): id is string => id !== null);

    return {
        ...layout,
        slots: flowIcons(ids, widgets, to.cols, to.rows),
        ...(widgets.length ? { widgets } : {}),
        ...(density ? { density } : {}),
    };
}

export function pageMoves(
    before: (string | null)[],
    after: (string | null)[],
    itemsPerPage: number,
): { count: number; page: number } {
    const was = new Map<string, number>();
    before.forEach((id, i) => {
        if (id !== null) was.set(id, Math.floor(i / itemsPerPage));
    });

    let count = 0;
    let page = 0;
    after.forEach((id, i) => {
        if (id === null) return;
        const from = was.get(id);
        if (from === undefined) return;
        const to = Math.floor(i / itemsPerPage);
        if (to === from) return;
        count++;
        if (to > page) page = to;
    });

    return count ? { count, page } : { count: 0, page: 0 };
}

export function landingCell(
    slots: (string | null)[],
    covered: Set<number> | undefined,
    page: number,
    cell: number,
    itemsPerPage: number,
): number | null {
    const base = page * itemsPerPage;
    if (!covered?.has(cell)) return base + cell;

    const local = freeCellNear(slots.slice(base, base + itemsPerPage), covered, cell);
    return local === null ? null : base + local;
}

function coveredByPage(widgets: WidgetPlacement[]): Map<number, Set<number>> {
    const covered = new Map<number, Set<number>>();
    for (const w of widgets) {
        const set = covered.get(w.page) ?? new Set<number>();
        for (const c of coveredCells(w)) set.add(c);
        covered.set(w.page, set);
    }
    return covered;
}

export function placeNewApps(
    slots: (string | null)[],
    ids: string[],
    widgets: WidgetPlacement[],
    itemsPerPage: number,
): (string | null)[] {
    if (!ids.length) return slots;

    const covered = coveredByPage(widgets);
    const out = [...slots];
    let cell = 0;

    const taken = (c: number) => out[c] !== null && out[c] !== undefined;
    const hidden = (c: number) => !!covered.get(Math.floor(c / itemsPerPage))?.has(c % itemsPerPage);

    for (const id of ids) {
        while (taken(cell) || hidden(cell)) cell++;
        while (out.length <= cell) out.push(null);
        out[cell] = id;
        cell++;
    }

    while (out.length % itemsPerPage !== 0) out.push(null);
    return out;
}

export function reflowAround(
    slots: (string | null)[],
    widgets: WidgetPlacement[],
    itemsPerPage: number,
): (string | null)[] {
    const covered = coveredByPage(widgets);

    const out: (string | null)[] = slots.map(() => null);
    let cell = 0;
    for (const id of slots) {
        if (id === null) continue;
        while (covered.get(Math.floor(cell / itemsPerPage))?.has(cell % itemsPerPage)) cell++;
        while (out.length <= cell) out.push(null);
        out[cell] = id;
        cell++;
    }
    while (out.length % itemsPerPage !== 0) out.push(null);
    return out;
}
