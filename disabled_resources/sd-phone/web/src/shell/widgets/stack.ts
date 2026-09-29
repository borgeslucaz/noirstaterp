import type { WidgetCard, WidgetPlacement } from '@/apps/appstore/appsApi';

export function cardsOf(w: WidgetPlacement): WidgetCard[] {
    return [{ kind: w.kind, align: w.align, theme: w.theme, picks: w.picks }, ...(w.stack ?? [])];
}

export function withCards(w: WidgetPlacement, cards: WidgetCard[]): WidgetPlacement {
    const [head, ...rest] = cards;
    return {
        ...w,
        kind:  head.kind,
        align: head.align,
        theme: head.theme,
        picks: head.picks,
        stack: rest.length ? rest : undefined,
    };
}

export function addCard(w: WidgetPlacement, card: WidgetCard): WidgetPlacement {
    return { ...w, stack: [...(w.stack ?? []), card] };
}

export function removeCard(w: WidgetPlacement, index: number): WidgetPlacement | null {
    const cards = cardsOf(w);
    if (index < 0 || index >= cards.length) return w;
    const next = cards.filter((_, i) => i !== index);
    return next.length ? withCards(w, next) : null;
}

export function patchCard(w: WidgetPlacement, index: number, patch: Partial<WidgetCard>): WidgetPlacement {
    const cards = cardsOf(w);
    if (index < 0 || index >= cards.length) return w;
    return withCards(w, cards.map((c, i) => (i === index ? { ...c, ...patch } : c)));
}
