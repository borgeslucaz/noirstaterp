import type { Language, Tier } from '../types/trucking'

export function money(value: number | undefined | null): string {
  const v = Math.round(value ?? 0)
  const sign = v < 0 ? '-' : ''
  return `${sign}$${Math.abs(v).toLocaleString('en-US')}`
}

export function signedMoney(value: number): string {
  if (value === 0) return money(0)
  return value > 0 ? `+${money(value)}` : `-${money(Math.abs(value))}`
}

export function clock(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds))
  const m = Math.floor(s / 60)
  const r = s % 60
  return `${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`
}

export function makeT(language: Language) {
  return (key: string, fallback?: string, ...args: (string | number)[]) => {
    let str = language[key] ?? fallback ?? key
    for (const arg of args) {
      str = str.replace('%s', String(arg))
    }
    return str
  }
}

export function tierKey(tier: Tier | null | undefined): string {
  return tier ? `tier_${tier}` : ''
}

export function companyName(
  companies: Record<string, string> | string[] | undefined,
  index: number | undefined,
  fallback = '',
): string {
  if (index === undefined || index === null) return fallback
  if (!companies) return fallback
  if (Array.isArray(companies)) return companies[index] ?? fallback
  return companies[String(index)] ?? fallback
}

export const defaultCompanies: Record<string, string> = {
  '0': 'National Transfer & Storage Co.',
  '1': 'The Grain Of Truth Company',
  '2': 'Redwood Cigarettes Company',
  '3': 'You Tool Company',
  '4': 'Premium Deluxe Motorsport',
  '5': 'Fruit Computers Company',
  '6': 'Ron Oil Company',
  '7': 'Merry Weather Security',
}
