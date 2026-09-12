// Shared tailwind-variants config. Reusable size + intent scales components
// compose into their own tv({ ... }) call. Colors reference the @theme tokens
// from ../../tokens.css (bg-primary, text-on-primary, border-border, ...) so a
// :root override re-skins every component without a rebuild.

import { tv } from 'tailwind-variants';

export { tv };

export type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl' | '2xl' | '3xl' | '4xl';
export type Intent = 'default' | 'primary' | 'danger' | 'ghost' | 'outline';

// Square icon-button dims share the same height steps as Size.
export type IconButtonSize = Size;
// Badges only carry the two small typography steps.
export type BadgeSize = 'xs' | 'sm';
// Alert status scale - distinct from Intent (interactive) - maps to the status
// color tokens (info / success / warning / error).
export type AlertVariant = 'info' | 'success' | 'warning' | 'danger';

// Sizing / spacing / typography only - generic across Button, Input, Badge.
// No component-specific shape (radius, role colors) lives here.
export const sizes: Record<Size, string> = {
	xs: 'h-6 px-2 text-xs',
	sm: 'h-8 px-3 text-sm',
	md: 'h-10 px-4 text-base',
	lg: 'h-12 px-6 text-lg',
	xl: 'h-14 px-8 text-xl',
	'2xl': 'h-16 px-10 text-2xl',
	'3xl': 'h-20 px-12 text-3xl',
	'4xl': 'h-24 px-14 text-4xl',
};

// Background / text / border / hover per intent, built from token utilities.
export const intents: Record<Intent, string> = {
	default:
		'bg-surface-overlay text-text border-border hover:bg-surface-raised',
	primary: 'bg-primary text-on-primary border-primary hover:bg-primary-hover',
	danger: 'bg-error-500 text-on-error border-error-500 hover:bg-error-600',
	ghost: 'bg-transparent text-text border-transparent hover:bg-surface-overlay',
	outline:
		'bg-transparent text-text border-border-strong hover:bg-surface-overlay',
};
