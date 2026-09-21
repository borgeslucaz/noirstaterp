"use client"

import type React from "react"
import { useMemo, useState } from "react"
import { ArrowDownLeft, ArrowUpRight, Search } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import type { RenewedTransaction } from "../types"

const money = (n: number) => `$${Math.abs(n).toLocaleString("pt-BR")}`

/** O Renewed grava `time` em segundos; `Date` espera milissegundos. */
const when = (seconds: number) =>
    new Date(seconds * 1000).toLocaleString("pt-BR", {
        day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit",
    })

export const TransactionHistory: React.FC<{ transactions: RenewedTransaction[] }> = ({ transactions }) => {
    const { t } = useLocale()
    const [search, setSearch] = useState("")
    const [filter, setFilter] = useState<"all" | "income" | "expense">("all")

    const shown = useMemo(() => transactions.filter((tx) => {
        const isIncome = tx.trans_type === "deposit"
        if (filter === "income" && !isIncome) return false
        if (filter === "expense" && isIncome) return false
        if (!search) return true
        const haystack = `${tx.title} ${tx.message} ${tx.issuer} ${tx.receiver}`.toLowerCase()
        return haystack.includes(search.toLowerCase())
    }), [transactions, search, filter])

    const chips: Array<["all" | "income" | "expense", string]> = [
        ["all", t("transactions.all")],
        ["income", t("transactions.income")],
        ["expense", t("transactions.expenses")],
    ]

    return (
        <div className="space-y-4 animate-in">
            <div className="flex flex-wrap items-center gap-3">
                <div className="relative flex-1 min-w-[220px]">
                    <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2"
                            style={{ color: "var(--noir-text-faint)" }} />
                    <input
                        className="input-field w-full rounded-md pl-9 pr-3 text-[13px]"
                        placeholder={t("transactions.search")}
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        aria-label={t("transactions.search")}
                    />
                </div>
                <div className="flex gap-2">
                    {chips.map(([id, label]) => (
                        <button key={id} onClick={() => setFilter(id)} aria-pressed={filter === id}
                                className="chip">
                            {label}
                        </button>
                    ))}
                </div>
            </div>

            <div className="rounded-xl p-5"
                 style={{ background: "var(--noir-card)", border: "1px solid var(--noir-border-soft)" }}>
                <h3 className="text-[15px] font-semibold" style={{ color: "var(--noir-text-strong)" }}>
                    {t("transactions.history")}
                </h3>
                <p className="text-[11px] mb-4" style={{ color: "var(--noir-text-muted)" }}>
                    {t("transactions.count", { count: shown.length })}
                </p>

                {shown.length === 0 ? (
                    <p className="py-8 text-center text-[13px]" style={{ color: "var(--noir-text-muted)" }}>
                        {transactions.length === 0 ? t("transactions.noTransactions") : t("transactions.noResults")}
                    </p>
                ) : (
                    <div className="space-y-2 max-h-[52vh] overflow-y-auto pr-1">
                        {shown.map((tx) => {
                            const income = tx.trans_type === "deposit"
                            return (
                                <div key={tx.trans_id}
                                     className="flex items-center gap-3 rounded-md p-3"
                                     style={{ background: "var(--noir-panel-raised)" }}>
                                    <span className="grid place-items-center w-9 h-9 rounded-md shrink-0"
                                          style={{
                                              background: "rgba(255,255,255,0.05)",
                                              color: income ? "var(--noir-success)" : "var(--noir-danger-hover)",
                                          }}>
                                        {income ? <ArrowDownLeft size={16} /> : <ArrowUpRight size={16} />}
                                    </span>

                                    <div className="min-w-0 flex-1">
                                        <p className="text-[13px] font-semibold truncate"
                                           style={{ color: "var(--noir-text-strong)" }} title={tx.title}>
                                            {tx.title}
                                        </p>
                                        <p className="text-[11px] truncate" style={{ color: "var(--noir-text-muted)" }}>
                                            {when(tx.time)}{tx.message ? ` · ${tx.message}` : ""}
                                        </p>
                                    </div>

                                    <span className="text-[14px] font-bold whitespace-nowrap"
                                          style={{ color: income ? "var(--noir-success)" : "var(--noir-danger-hover)" }}>
                                        {income ? "+" : "−"}{money(tx.amount)}
                                    </span>
                                </div>
                            )
                        })}
                    </div>
                )}
            </div>
        </div>
    )
}
