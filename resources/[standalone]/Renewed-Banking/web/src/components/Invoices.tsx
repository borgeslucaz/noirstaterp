"use client"

import type React from "react"
import { useState } from "react"
import { AlertTriangle, Gavel, Receipt } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import type { RenewedInvoice, RenewedInvoiceSummary } from "../types"

const money = (n: number) => `$${Number(n || 0).toLocaleString("pt-BR")}`
const day = (ms: number) => new Date(ms).toLocaleDateString("pt-BR", { day: "2-digit", month: "short" })

/**
 * Botão de pagar em dois toques: o primeiro mostra o valor, o segundo paga. Evita pagar sem
 * querer e dispensa uma janela de confirmação por fatura.
 */
const PayButton: React.FC<{ invoice: RenewedInvoice; busy: boolean; onPay: (id: string) => void; compact?: boolean }> = ({
    invoice, busy, onPay, compact,
}) => {
    const { t } = useLocale()
    const [armed, setArmed] = useState(false)

    return (
        <button
            type="button"
            disabled={busy || !invoice.canPay}
            onClick={() => (armed ? onPay(invoice.id) : setArmed(true))}
            onBlur={() => setArmed(false)}
            className={`btn ${armed ? "btn-success" : "btn-secondary"} ${compact ? "px-3" : "px-4"} rounded-md text-[12px] font-semibold whitespace-nowrap`}
            style={{ minHeight: compact ? 32 : 36 }}
            aria-live="polite"
        >
            {busy ? t("invoices.paying") : armed ? t("invoices.confirm", { amount: money(invoice.amount) }) : t("invoices.pay")}
        </button>
    )
}

const InvoiceRow: React.FC<{ invoice: RenewedInvoice; busy: boolean; onPay: (id: string) => void; compact?: boolean }> = ({
    invoice, busy, onPay, compact,
}) => {
    const { t } = useLocale()
    const danger = invoice.isFine || invoice.isOverdue

    return (
        <div className={`flex items-center gap-3 rounded-md ${compact ? "px-3 py-2" : "p-3"}`}
             style={{ background: "var(--noir-panel-raised)" }}>
            <span className={`grid place-items-center ${compact ? "w-7 h-7" : "w-9 h-9"} rounded-md shrink-0`}
                  style={{ background: "rgba(255,255,255,0.05)",
                           color: danger ? "var(--noir-danger-hover)" : "var(--noir-text)" }}>
                {invoice.isFine ? <Gavel size={compact ? 14 : 16} /> : <Receipt size={compact ? 14 : 16} />}
            </span>

            <div className="min-w-0 flex-1">
                <p className={`${compact ? "text-[12px]" : "text-[13px]"} font-semibold truncate`}
                   style={{ color: "var(--noir-text-strong)" }} title={invoice.title}>
                    {invoice.title}
                </p>
                <p className="text-[11px] truncate" style={{ color: "var(--noir-text-muted)" }}
                   title={invoice.description || undefined}>
                    {invoice.isFine ? t("invoices.fine") : t("invoices.invoice")}
                    {" · "}{t("invoices.issuedBy", { issuer: invoice.issuerLabel })}
                    {invoice.dueAt ? " · " : ""}
                    {invoice.isOverdue
                        ? <span style={{ color: "var(--noir-danger-hover)", fontWeight: 600 }}>{t("invoices.overdue")}</span>
                        : invoice.dueAt ? t("invoices.due", { date: day(invoice.dueAt) }) : null}
                    {!compact && invoice.description ? ` · ${invoice.description}` : ""}
                </p>
            </div>

            <span className={`${compact ? "text-[12px]" : "text-[14px]"} font-bold whitespace-nowrap`}
                  style={{ color: "var(--noir-text-strong)" }}>
                {money(invoice.amount)}
            </span>

            <PayButton invoice={invoice} busy={busy} onPay={onPay} compact={compact} />
        </div>
    )
}

/** Aviso de que multa em aberto trava saque e transferência. */
export const FineBlockBanner: React.FC<{ amount: number }> = ({ amount }) => {
    const { t } = useLocale()
    if (amount <= 0) return null
    return (
        <div role="alert" className="flex items-start gap-3 rounded-md p-3"
             style={{ background: "rgba(213,26,26,0.12)", border: "1px solid rgba(239,41,41,0.35)" }}>
            <AlertTriangle size={16} className="shrink-0 mt-[1px]" style={{ color: "var(--noir-danger-hover)" }} />
            <p className="text-[12px]" style={{ color: "var(--noir-text-strong)" }}>
                {t("invoices.blockingBanner", { amount: money(amount) })}
            </p>
        </div>
    )
}

interface InvoicesProps {
    summary?: RenewedInvoiceSummary
    invoices: RenewedInvoice[]
    busy: boolean
    onPay: (id: string) => void
}

/** Aba Faturas da agência: tudo o que está em aberto na conta pessoal. */
export const Invoices: React.FC<InvoicesProps> = ({ summary, invoices, busy, onPay }) => {
    const { t } = useLocale()

    return (
        <div className="space-y-4 animate-in">
            <FineBlockBanner amount={summary?.blockingTotal ?? 0} />

            <div className="rounded-xl p-5"
                 style={{ background: "var(--noir-card)", border: "1px solid var(--noir-border-soft)" }}>
                <div className="flex flex-wrap items-end justify-between gap-3 mb-4">
                    <div>
                        <h3 className="text-[15px] font-semibold" style={{ color: "var(--noir-text-strong)" }}>
                            {t("invoices.title")}
                        </h3>
                        <p className="text-[11px]" style={{ color: "var(--noir-text-muted)" }}>
                            {t("invoices.subtitle")}
                        </p>
                    </div>
                    <div className="text-right">
                        <p className="text-[10px] font-semibold uppercase tracking-wider" style={{ color: "var(--noir-text-faint)" }}>
                            {t("invoices.openTotal")}
                        </p>
                        <p className="text-2xl font-bold tracking-tight" style={{ color: "var(--noir-text-strong)" }}>
                            {money(summary?.openTotal ?? 0)}
                        </p>
                        <p className="text-[11px]" style={{ color: "var(--noir-text-muted)" }}>
                            {t("invoices.openCount", { count: summary?.openCount ?? invoices.length })}
                        </p>
                    </div>
                </div>

                {invoices.length === 0 ? (
                    <p className="py-8 text-center text-[13px]" style={{ color: "var(--noir-text-muted)" }}>
                        {t("invoices.none")}
                    </p>
                ) : (
                    <div className="space-y-2 max-h-[52vh] overflow-y-auto pr-1">
                        {invoices.map((invoice) => (
                            <InvoiceRow key={invoice.id} invoice={invoice} busy={busy} onPay={onPay} />
                        ))}
                    </div>
                )}
            </div>
        </div>
    )
}

/**
 * Faixa do caixa eletrônico: o caixa é pequeno, então mostra só as multas (as que travam o
 * saque) para pagar ali mesmo, e diz onde pagar o resto.
 */
export const AtmInvoices: React.FC<InvoicesProps> = ({ summary, invoices, busy, onPay }) => {
    const { t } = useLocale()
    if (!summary || summary.openCount === 0) return null
    const fines = invoices.filter((i) => i.blocking).slice(0, 2)

    return (
        <div className="rounded-md p-3 space-y-2 shrink-0"
             style={{ background: "var(--noir-card)", border: "1px solid rgba(239,41,41,0.35)" }}>
            <p className="text-[11px] font-semibold" style={{ color: "var(--noir-danger-hover)" }}>
                {t("invoices.atmBanner", { count: summary.openCount, amount: money(summary.openTotal) })}
            </p>
            {fines.map((invoice) => (
                <InvoiceRow key={invoice.id} invoice={invoice} busy={busy} onPay={onPay} compact />
            ))}
            {summary.openCount > fines.length && (
                <p className="text-[11px]" style={{ color: "var(--noir-text-muted)" }}>{t("invoices.atmMore")}</p>
            )}
        </div>
    )
}
