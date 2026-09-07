import { TrendingUp } from 'lucide-react';

import type { WidgetSize, WidgetTheme } from '@/apps/appstore/appsApi';
import type { Asset } from '@/apps/stocks/data';
import { formatPct, formatPrice, formatUnits, holdingValue, trendColor } from '@/apps/stocks/data';
import { t } from '@/i18n';
import { formatMoney } from '@/lib/money';
import { useWidgetData } from '@/stores/widgetDataStore';
import { WidgetTile, palette } from './WidgetTile';
import type { Palette } from './WidgetTile';

const ROWS: Record<WidgetSize, number> = { sm: 1, md: 3, lg: 6 };

function position(a: Asset) {
    const value = a.units * a.price;
    const cost  = a.units * a.avgCost;
    const pnl   = value - cost;
    return { held: a.units > 0, value, cost, pnl, pct: cost > 0 ? pnl / cost : 0 };
}

function signedMoney(n: number): string {
    return `${n >= 0 ? '+' : '-'}${formatMoney(Math.abs(n), { whole: true })}`;
}

function Spark({ points, color, w, h }: { points: number[]; color: string; w: number; h: number }) {
    if (points.length < 2) return <div style={{ width: w, height: h }} />;
    const min = Math.min(...points);
    const max = Math.max(...points);
    const span = max - min || 1;
    const step = w / (points.length - 1);
    const xy = points.map((p, i) => [i * step, h - 1 - ((p - min) / span) * (h - 2)] as const);
    const line = xy.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
    const id = `sp${Math.round(w)}${Math.round(h)}${color.replace('#', '')}`;
    return (
        <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} aria-hidden style={{ display: 'block' }}>
            <defs>
                <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={color} stopOpacity="0.30" />
                    <stop offset="100%" stopColor={color} stopOpacity="0" />
                </linearGradient>
            </defs>
            <path d={`${line} L${w},${h} L0,${h} Z`} fill={`url(#${id})`} />
            <path d={line} fill="none" stroke={color} strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" />
        </svg>
    );
}

function Chip({ frac, size = 11 }: { frac: number; size?: number }) {
    return (
        <span
            className="shrink-0 rounded-[5px] px-1.5 py-[2px] font-semibold tabular-nums text-white"
            style={{ background: trendColor(frac), fontSize: size }}
        >
            {formatPct(frac)}
        </span>
    );
}

function Row({ a, p, spark }: { a: Asset; p: Palette; spark: boolean }) {
    const pos = position(a);
    return (
        <div className="flex items-center gap-2">
            <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-semibold leading-tight" style={{ color: p.fg }}>{a.symbol}</div>
                {pos.held ? (
                    <div className="flex items-baseline gap-1.5 leading-tight">
                        <span className="shrink-0 text-[12px] font-semibold tabular-nums" style={{ color: trendColor(pos.pnl) }}>
                            {signedMoney(pos.pnl)}
                        </span>
                        <span className="truncate text-[11px] tabular-nums" style={{ color: p.sub }}>
                            {formatMoney(pos.value, { whole: true })}
                        </span>
                    </div>
                ) : (
                    <div className="truncate text-[12px] font-medium leading-tight" style={{ color: p.body }}>{a.name}</div>
                )}
            </div>
            {spark && <Spark points={a.history} color={trendColor(a.changePct)} w={54} h={22} />}
            <div className="flex w-[86px] shrink-0 flex-col items-end gap-[3px]">
                <span className="text-[12px] font-semibold tabular-nums" style={{ color: p.fg }}>{formatPrice(a.price)}</span>
                <Chip frac={a.changePct} size={10} />
            </div>
        </div>
    );
}

export function StocksWidget({ size, width, height, theme = 'dark' }: {
    size: WidgetSize; width: number; height: number; theme?: WidgetTheme;
}) {
    const assets = useWidgetData(s => s.assets);
    const p = palette(theme);
    const radius = size === 'sm' ? 22 : 26;

    const held = assets.filter(a => a.units > 0).sort((a, b) => holdingValue(b) - holdingValue(a));
    const movers = [...assets].sort((a, b) => Math.abs(b.changePct) - Math.abs(a.changePct));
    const ordered = [...held, ...movers.filter(m => !held.some(h => h.symbol === m.symbol))];
    const rows = ordered.slice(0, ROWS[size]);

    const folio = held.reduce(
        (acc, a) => {
            const q = position(a);
            return { held: true, value: acc.value + q.value, cost: acc.cost + q.cost, pnl: acc.pnl + q.pnl };
        },
        { held: false, value: 0, cost: 0, pnl: 0 },
    );

    if (rows.length === 0) {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col items-center justify-center gap-2 p-4 text-center">
                    <TrendingUp className="h-6 w-6" strokeWidth={2} style={{ color: p.faint }} />
                    <span className="text-[12px]" style={{ color: p.sub }}>{t('widgets.noMarket', 'Market closed')}</span>
                </div>
            </WidgetTile>
        );
    }

    if (size === 'sm') {
        const a = rows[0];
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col p-3.5">
                    <div className="truncate text-[16px] font-semibold leading-tight" style={{ color: p.fg }}>{a.symbol}</div>
                    <div className="truncate text-[12px] font-medium leading-tight" style={{ color: p.body }}>{a.name}</div>
                    {position(a).held && (
                        <div className="mt-1 flex items-baseline gap-1.5">
                            <span className="text-[13px] font-semibold tabular-nums" style={{ color: trendColor(position(a).pnl) }}>
                                {signedMoney(position(a).pnl)}
                            </span>
                            <span className="truncate text-[11px] tabular-nums" style={{ color: p.sub }}>
                                {formatMoney(position(a).value, { whole: true })}
                            </span>
                        </div>
                    )}
                    <div className="mt-auto">
                        <Spark points={a.history} color={trendColor(a.changePct)} w={width - 28} h={56} />
                        <div className="mt-1.5 flex items-baseline justify-between gap-1">
                            <span className="truncate text-[15px] font-semibold tabular-nums" style={{ color: p.fg }}>
                                {formatPrice(a.price)}
                            </span>
                            <Chip frac={a.changePct} />
                        </div>
                    </div>
                </div>
            </WidgetTile>
        );
    }

    const lead = size === 'lg' ? rows[0] : null;
    const list = size === 'lg' ? rows.slice(1) : rows;

    return (
        <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
            <div className="flex h-full w-full flex-col p-3.5">
                <div className="mb-2 flex shrink-0 items-center justify-between gap-2">
                    <div className="flex min-w-0 items-center gap-1.5">
                        <TrendingUp className="h-[12px] w-[12px] shrink-0" strokeWidth={2.6} style={{ color: p.sub }} />
                        <span className="truncate text-[11px] font-semibold uppercase tracking-[0.12em]" style={{ color: p.sub }}>
                            {t('widgets.stocks', 'Stocks')}
                        </span>
                    </div>
                    {folio.held && (
                        <div className="flex shrink-0 items-baseline gap-1.5">
                            <span className="text-[12px] font-semibold tabular-nums" style={{ color: p.fg }}>
                                {formatMoney(folio.value, { whole: true })}
                            </span>
                            <span className="text-[11px] font-semibold tabular-nums" style={{ color: trendColor(folio.pnl) }}>
                                {signedMoney(folio.pnl)}
                            </span>
                        </div>
                    )}
                </div>

                {lead && (
                    <div className="mb-2 shrink-0">
                        <div className="flex items-baseline justify-between gap-2">
                            <div className="min-w-0">
                                <div className="truncate text-[18px] font-semibold leading-tight" style={{ color: p.fg }}>{lead.symbol}</div>
                                <div className="truncate text-[13px] font-medium leading-tight" style={{ color: p.body }}>{lead.name}</div>
                                {position(lead).held && (
                                    <div className="mt-1 truncate text-[12px] tabular-nums" style={{ color: p.sub }}>
                                        {t('widgets.unitsHeld', '{n} held', { n: formatUnits(lead.units) })}
                                        {' · '}
                                        <span className="font-semibold" style={{ color: trendColor(position(lead).pnl) }}>
                                            {signedMoney(position(lead).pnl)} ({formatPct(position(lead).pct)})
                                        </span>
                                    </div>
                                )}
                            </div>
                            <div className="flex shrink-0 flex-col items-end gap-1">
                                <span className="text-[17px] font-semibold tabular-nums" style={{ color: p.fg }}>{formatPrice(lead.price)}</span>
                                <Chip frac={lead.changePct} />
                            </div>
                        </div>
                        <div className="mt-1.5">
                            <Spark points={lead.history} color={trendColor(lead.changePct)} w={width - 28} h={64} />
                        </div>
                    </div>
                )}

                <div className="flex min-h-0 flex-1 flex-col justify-between">
                    {list.map(a => <Row key={a.symbol} a={a} p={p} spark={size === 'md'} />)}
                </div>
            </div>
        </WidgetTile>
    );
}
