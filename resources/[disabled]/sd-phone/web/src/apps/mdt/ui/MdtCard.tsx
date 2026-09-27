import type { ReactNode } from 'react';

import { mdtCardSurface } from '../mdtTheme';

export function MdtCard({ className = '', children }: {
    className?: string;
    children:   ReactNode;
}) {
    return <div className={`${mdtCardSurface} ${className}`}>{children}</div>;
}
