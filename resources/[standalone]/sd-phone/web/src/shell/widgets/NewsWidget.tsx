import { Newspaper } from 'lucide-react';

import type { WidgetSize, WidgetTheme } from '@/apps/appstore/appsApi';
import type { Article } from '@/apps/weazelnews/data';
import { t } from '@/i18n';
import { useWidgetData } from '@/stores/widgetDataStore';
import { WidgetTile, palette } from './WidgetTile';
import type { Palette } from './WidgetTile';

const BREAKING = '#e0342b';

function Photo({ src, h, radius, p }: { src?: string; h: number; radius: number; p: Palette }) {
    return (
        <div
            className="w-full shrink-0 overflow-hidden bg-cover bg-center"
            style={{
                height: h,
                borderRadius: radius,
                background: src ? `url("${src}") center/cover no-repeat` : p.chip,
            }}
        >
            {!src && (
                <div className="flex h-full w-full items-center justify-center">
                    <Newspaper className="h-5 w-5" strokeWidth={2} style={{ color: p.faint }} />
                </div>
            )}
        </div>
    );
}

function Kicker({ article, p }: { article: Article; p: Palette }) {
    const breaking = !!article.featured;
    return (
        <span
            className="truncate text-[9px] font-bold uppercase tracking-[0.14em]"
            style={{ color: breaking ? BREAKING : p.sub }}
        >
            {breaking ? t('weazelnews.breaking', 'Breaking') : article.category}
        </span>
    );
}

export function NewsWidget({ size, width, height, theme = 'dark' }: {
    size: WidgetSize; width: number; height: number; theme?: WidgetTheme;
}) {
    const articles = useWidgetData(s => s.articles);
    const ticker   = useWidgetData(s => s.ticker);
    const p = palette(theme);
    const radius = size === 'sm' ? 22 : 26;

    const sorted = [...articles].sort((a, b) => Number(!!b.featured) - Number(!!a.featured));
    const lead = sorted[0];

    if (!lead) {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col items-center justify-center gap-2 p-4 text-center">
                    <Newspaper className="h-6 w-6" strokeWidth={2} style={{ color: p.faint }} />
                    <span className="text-[12px] leading-snug" style={{ color: p.sub }}>
                        {t('widgets.noNews', 'No stories yet')}
                    </span>
                </div>
            </WidgetTile>
        );
    }

    if (size === 'sm') {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full flex-col p-3.5">
                    <Kicker article={lead} p={p} />
                    <div
                        className="mt-1 overflow-hidden text-[13px] font-semibold leading-[1.25]"
                        style={{ color: p.fg, display: '-webkit-box', WebkitLineClamp: 4, WebkitBoxOrient: 'vertical' }}
                    >
                        {lead.headline}
                    </div>
                    {ticker[0] && (
                        <div className="mt-auto min-w-0 pt-1.5" style={{ borderTop: `1px solid ${p.rule}` }}>
                            <div className="truncate text-[10px]" style={{ color: p.sub }}>{ticker[0]}</div>
                        </div>
                    )}
                </div>
            </WidgetTile>
        );
    }

    if (size === 'md') {
        return (
            <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
                <div className="flex h-full w-full gap-3 p-3.5">
                    <div className="flex min-w-0 flex-1 flex-col">
                        <Kicker article={lead} p={p} />
                        <div
                            className="mt-1 overflow-hidden text-[14px] font-semibold leading-[1.25]"
                            style={{ color: p.fg, display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical' }}
                        >
                            {lead.headline}
                        </div>
                        <div
                            className="mt-1 overflow-hidden text-[11px] leading-snug"
                            style={{ color: p.sub, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}
                        >
                            {lead.dek}
                        </div>
                        <div className="mt-auto truncate text-[10px]" style={{ color: p.faint }}>
                            {t('weazelnews.byline', 'Weazel News')}
                        </div>
                    </div>
                    <div className="w-[124px] shrink-0">
                        <Photo src={lead.image} h={height - 28} radius={12} p={p} />
                    </div>
                </div>
            </WidgetTile>
        );
    }

    const rest = sorted.slice(1, 3);
    return (
        <WidgetTile width={width} height={height} radius={radius} tint={p.bg} glass={theme === 'glass'} hairline={false}>
            <div className="flex h-full w-full flex-col p-3.5">
                <Photo src={lead.image} h={150} radius={14} p={p} />
                <div className="mt-2.5 shrink-0">
                    <Kicker article={lead} p={p} />
                    <div
                        className="mt-1 overflow-hidden text-[17px] font-semibold leading-[1.22]"
                        style={{ color: p.fg, display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical' }}
                    >
                        {lead.headline}
                    </div>
                    <div
                        className="mt-1 overflow-hidden text-[12px] leading-snug"
                        style={{ color: p.sub, display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}
                    >
                        {lead.dek}
                    </div>
                </div>
                <div className="mt-auto flex flex-col">
                    {rest.map(a => (
                        <div key={a.id} className="pt-2" style={{ borderTop: `1px solid ${p.rule}`, marginTop: 8 }}>
                            <Kicker article={a} p={p} />
                            <div className="mt-0.5 truncate text-[12px] font-medium" style={{ color: p.fg }}>{a.headline}</div>
                        </div>
                    ))}
                </div>
            </div>
        </WidgetTile>
    );
}
