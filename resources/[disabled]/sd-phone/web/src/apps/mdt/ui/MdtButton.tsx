import type { CSSProperties, ReactNode } from 'react';

import { isFiveM } from '@/core/nui';

type MdtButtonVariant = 'filled' | 'text' | 'plain' | 'destructive';
type MdtButtonSize = 'sm' | 'md';

const METRICS: Record<MdtButtonSize, { filled: string; bare: string }> = {
    sm: {
        filled: 'gap-1 rounded-full px-2.5 py-[4px] text-[13px] font-semibold',
        bare:   'gap-1 px-1 py-[4px] text-[13px] font-semibold',
    },
    md: {
        filled: 'gap-1.5 rounded-full px-4 py-[7px] text-[15px] font-semibold',
        bare:   'gap-1.5 px-1 py-[7px] text-[15px] font-medium',
    },
};

export function MdtButton({
    variant = 'filled', size = 'md', icon, accent, disabled = false, className = '', style, onClick, children,
}: {
    variant?:   MdtButtonVariant;
    size?:      MdtButtonSize;
    icon?:      ReactNode;
    accent?:    string;
    disabled?:  boolean;
    className?: string;
    style?:     CSSProperties;
    onClick?:   () => void;
    children:   ReactNode;
}) {
    const filled = variant === 'filled';
    const metrics = METRICS[size][filled ? 'filled' : 'bare'];

    const tone = filled
        ? 'text-white'
        : variant === 'destructive'
            ? 'text-ios-red'
            : 'text-ios-blue';

    const state = disabled
        ? 'cursor-default opacity-40'
        : 'transition-opacity duration-150 hover:opacity-85 active:opacity-60';

    const fill: CSSProperties | undefined = filled
        ? { background: accent ?? 'var(--mdt-accent, #0a84ff)' }
        : undefined;

    return (
        <button
            type="button"
            disabled={disabled}
            onClick={disabled ? undefined : onClick}
            onKeyDown={e => { if (e.key === ' ' && isFiveM) e.preventDefault(); }}
            className={`inline-flex shrink-0 items-center justify-center whitespace-nowrap ${metrics} ${tone} ${state} ${className}`}
            style={{ ...fill, ...style }}
        >
            {icon}
            {children}
        </button>
    );
}
