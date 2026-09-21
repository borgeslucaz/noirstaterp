"use client"

import type React from "react"
import { ArrowDownLeft, ArrowUpRight, Building2, Landmark, LogOut, Send, Wallet } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import { splitAccounts, type RenewedAccount } from "../types"
import type { BankAction } from "./ActionModal"

const money = (n: number) => `$${Number(n || 0).toLocaleString("pt-BR")}`
const when = (s: number) =>
    new Date(s * 1000).toLocaleString("pt-BR", { day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" })

interface AtmProps {
    accounts: RenewedAccount[]
    selectedId: string | null
    onSelect: (id: string) => void
    onAction: (action: BankAction) => void
    onClose: () => void
}

/**
 * Tela do caixa eletrônico.
 *
 * Mesmo backend da agência -- o Renewed manda o mesmo `setVisible`, só com `atm = true`. O que
 * muda é o enquadramento: um caixa é uma máquina pequena, então aqui não há rail nem abas. Conta,
 * saldo, as três operações e os últimos lançamentos, numa janela estreita.
 *
 * Extrato completo e estatísticas ficam na agência, que é onde faz sentido sentar e olhar.
 */
export const Atm: React.FC<AtmProps> = ({ accounts, selectedId, onSelect, onAction, onClose }) => {
    const { t } = useLocale()

    const selected = accounts.find((a) => a.id === selectedId) ?? accounts[0] ?? null
    const { personal } = splitAccounts(accounts)
    const cash = personal[0]?.cash
    // Três, não quatro: é o que cabe inteiro na altura fixa. Uma quarta linha aparecia cortada
    // pela metade na borda, o que num caixa lê como tela quebrada, não como "tem mais abaixo".
    // A rolagem fica de rede de segurança para fontes maiores ou 720p.
    const recent = (selected?.transactions ?? []).slice(0, 3)

    const actions: Array<[BankAction, string, React.ReactNode]> = [
        ["deposit", t("quickActions.deposit"), <ArrowDownLeft size={18} />],
        ["withdraw", t("quickActions.withdraw"), <ArrowUpRight size={18} />],
        ["transfer", t("quickActions.transfer"), <Send size={18} />],
    ]

    return (
        <div className="fixed inset-0 grid place-items-center p-6 animate-in">
            {/* Altura FIXA. Sem isso a janela pulsava ao trocar de conta: a lista de lançamentos
                muda de tamanho (uma conta sem movimento mostra uma linha de texto, outra mostra
                quatro), e o painel acompanhava. O `min()` com `dvh` evita estourar em 720p. */}
            <div className="w-full max-w-[560px] rounded-xl overflow-hidden animate-scale-in flex flex-col"
                 style={{ height: "min(560px, calc(100dvh - 48px))",
                          background: "var(--noir-canvas-solid)", border: "1px solid var(--noir-border)",
                          boxShadow: "var(--shadow-window)" }}>

                {/* Cabeçalho: a faixa de acento é a única superfície colorida, como no rail. */}
                <div className="flex items-center justify-between px-5 py-4 shrink-0"
                     style={{ background: "linear-gradient(180deg, var(--noir-accent), var(--noir-accent-deep))" }}>
                    <div className="flex items-center gap-3">
                        <span className="grid place-items-center w-9 h-9 rounded-md"
                              style={{ background: "rgba(0,0,0,0.22)", color: "var(--noir-on-accent)" }}>
                            <Landmark size={18} />
                        </span>
                        <div>
                            <h2 className="text-[15px] font-semibold leading-tight"
                                style={{ color: "var(--noir-on-accent)", letterSpacing: "-0.015em" }}>
                                {t("renewed.atmTitle")}
                            </h2>
                            <p className="text-[11px] leading-tight" style={{ color: "rgba(255,255,255,0.68)" }}>
                                {t("renewed.atmSubtitle")}
                            </p>
                        </div>
                    </div>
                    <button onClick={onClose} aria-label={t("sidebar.close")}
                            className="grid place-items-center w-9 h-9 rounded-md transition-colors"
                            style={{ color: "rgba(255,255,255,0.82)" }}
                            onMouseEnter={(e) => { e.currentTarget.style.background = "rgba(0,0,0,0.22)" }}
                            onMouseLeave={(e) => { e.currentTarget.style.background = "transparent" }}>
                        <LogOut size={17} />
                    </button>
                </div>

                <div className="p-5 flex flex-col gap-4 flex-1 min-h-0">
                    {/* Saldo da conta selecionada */}
                    <div className="rounded-md p-4 shrink-0"
                         style={{ background: "var(--noir-card)", border: "1px solid var(--noir-border-soft)" }}>
                        <p className="text-[10px] font-semibold uppercase tracking-wider"
                           style={{ color: "var(--noir-text-faint)" }}>
                            {t("renewed.atmAccount")}
                        </p>
                        <p className="text-[13px] font-semibold mt-1 truncate"
                           style={{ color: "var(--noir-text-strong)" }}>
                            {selected?.name ?? t("renewed.noAccount")}
                        </p>
                        <p className="text-3xl font-bold tracking-tight mt-2"
                           style={{ color: "var(--noir-text-strong)" }}>
                            {money(selected?.amount ?? 0)}
                        </p>
                        {typeof cash === "number" && (
                            <p className="text-[11px] mt-1" style={{ color: "var(--noir-text-muted)" }}>
                                {t("renewed.cashOnHand")}: <span className="font-semibold">{money(cash)}</span>
                            </p>
                        )}
                    </div>

                    {/* Troca de conta: só aparece quando há mais de uma ao alcance. */}
                    {accounts.length > 1 && (
                        <div className="flex flex-wrap gap-2 shrink-0">
                            {accounts.map((acc) => {
                                const isPersonal = personal.some((p) => p.id === acc.id)
                                return (
                                    <button key={acc.id} onClick={() => onSelect(acc.id)}
                                            aria-pressed={acc.id === selected?.id}
                                            className="chip flex items-center gap-2">
                                        {isPersonal ? <Wallet size={12} /> : <Building2 size={12} />}
                                        <span className="truncate max-w-[130px]">{acc.name}</span>
                                    </button>
                                )
                            })}
                        </div>
                    )}

                    <div className="grid grid-cols-3 gap-3 shrink-0">
                        {actions.map(([id, label, icon]) => (
                            <button key={id} onClick={() => onAction(id)}
                                    className="flex flex-col items-center justify-center gap-2 py-4 rounded-md transition-colors"
                                    style={{ minHeight: 40, background: "var(--noir-card)",
                                             border: "1px solid var(--noir-border-soft)", color: "var(--noir-text)" }}
                                    onMouseEnter={(e) => {
                                        e.currentTarget.style.background = "var(--noir-card-hover)"
                                        e.currentTarget.style.color = "var(--noir-text-strong)"
                                    }}
                                    onMouseLeave={(e) => {
                                        e.currentTarget.style.background = "var(--noir-card)"
                                        e.currentTarget.style.color = "var(--noir-text)"
                                    }}>
                                {icon}
                                <span className="text-[13px] font-medium">{label}</span>
                            </button>
                        ))}
                    </div>

                    <div className="flex flex-col flex-1 min-h-0">
                        <p className="text-[10px] font-semibold uppercase tracking-wider mb-2 shrink-0"
                           style={{ color: "var(--noir-text-faint)" }}>
                            {t("renewed.atmRecent")}
                        </p>
                        {recent.length === 0 ? (
                            <p className="text-[12px] py-3" style={{ color: "var(--noir-text-muted)" }}>
                                {t("renewed.atmNoRecent")}
                            </p>
                        ) : (
                            <div className="space-y-1 overflow-y-auto pr-1">
                                {recent.map((tx) => {
                                    const income = tx.trans_type === "deposit"
                                    return (
                                        <div key={tx.trans_id} className="flex items-center gap-3 rounded-md px-3 py-2"
                                             style={{ background: "var(--noir-panel-raised)" }}>
                                            <span className="shrink-0"
                                                  style={{ color: income ? "var(--noir-success)" : "var(--noir-danger-hover)" }}>
                                                {income ? <ArrowDownLeft size={14} /> : <ArrowUpRight size={14} />}
                                            </span>
                                            <span className="text-[11px] truncate flex-1"
                                                  style={{ color: "var(--noir-text-muted)" }}>
                                                {when(tx.time)}
                                            </span>
                                            <span className="text-[12px] font-bold whitespace-nowrap"
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
            </div>
        </div>
    )
}
