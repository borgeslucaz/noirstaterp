"use client"

import type React from "react"
import { useMemo } from "react"
import { ArrowDownLeft, ArrowUpRight, Scale } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import type { RenewedTransaction } from "../types"

const money = (n: number) => `$${Math.abs(n).toLocaleString("pt-BR")}`

/**
 * Totais da conta selecionada.
 *
 * Sem biblioteca de gráfico de propósito: o Renewed guarda as transações num JSON por conta, sem
 * série temporal confiável, e um gráfico daria a impressão de precisão que o dado não tem. Três
 * números que se somam e conferem valem mais.
 */
export const Stats: React.FC<{ transactions: RenewedTransaction[]; accountName?: string }> = ({
    transactions, accountName,
}) => {
    const { t } = useLocale()

    const { income, expense } = useMemo(() => {
        let income = 0, expense = 0
        for (const tx of transactions) {
            if (tx.trans_type === "deposit") income += Number(tx.amount) || 0
            else expense += Number(tx.amount) || 0
        }
        return { income, expense }
    }, [transactions])

    const tiles = [
        { label: t("stats.totalIncome"), value: income, color: "var(--noir-success)", icon: <ArrowDownLeft size={16} /> },
        { label: t("stats.totalExpenses"), value: expense, color: "var(--noir-danger-hover)", icon: <ArrowUpRight size={16} /> },
        { label: t("stats.netFlow"), value: income - expense, color: "var(--noir-text-strong)", icon: <Scale size={16} /> },
    ]

    return (
        <div className="space-y-5 animate-in">
            <div>
                <h3 className="text-[15px] font-bold" style={{ color: "var(--noir-text-strong)" }}>
                    {t("stats.financialActivity")}
                </h3>
                {accountName && (
                    <p className="text-[11px]" style={{ color: "var(--noir-text-muted)" }}>{accountName}</p>
                )}
            </div>

            {transactions.length === 0 ? (
                <div className="rounded-xl p-10 text-center"
                     style={{ background: "var(--noir-card)", border: "1px solid var(--noir-border-soft)" }}>
                    <p className="text-[13px]" style={{ color: "var(--noir-text-muted)" }}>{t("stats.noData")}</p>
                </div>
            ) : (
                <div className="grid gap-4 sm:grid-cols-3">
                    {tiles.map((tile) => (
                        <div key={tile.label} className="rounded-xl p-5"
                             style={{ background: "var(--noir-card)", border: "1px solid var(--noir-border-soft)" }}>
                            <div className="flex items-center gap-2 mb-3" style={{ color: "var(--noir-text-muted)" }}>
                                {tile.icon}
                                <p className="text-[10px] font-semibold uppercase tracking-wider">{tile.label}</p>
                            </div>
                            <p className="text-2xl font-bold tracking-tight" style={{ color: tile.color }}>
                                {tile.value < 0 ? "−" : ""}{money(tile.value)}
                            </p>
                        </div>
                    ))}
                </div>
            )}
        </div>
    )
}
