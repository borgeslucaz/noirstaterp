"use client"

import type React from "react"
import { useEffect, useRef } from "react"
import { Building2, ChevronRight, Wallet } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import { isFrozen, splitAccounts, type RenewedAccount } from "../types"

const money = (n: number) => `$${Number(n || 0).toLocaleString("pt-BR")}`

/** Roda vertical do mouse rola a tira na horizontal; num NUI de jogo não há roda lateral. */
const useHorizontalWheel = () => {
    const ref = useRef<HTMLDivElement | null>(null)
    useEffect(() => {
        const el = ref.current
        if (!el) return
        const onWheel = (e: WheelEvent) => {
            if (e.deltaY === 0 || el.scrollWidth <= el.clientWidth) return
            e.preventDefault()
            el.scrollLeft += e.deltaY
        }
        el.addEventListener("wheel", onWheel, { passive: false })
        return () => el.removeEventListener("wheel", onWheel)
    }, [])
    return ref
}

const AccountCard: React.FC<{
    account: RenewedAccount
    selected: boolean
    personal: boolean
    onSelect: () => void
}> = ({ account, selected, personal, onSelect }) => {
    const { t } = useLocale()

    return (
        <button
            type="button"
            onClick={onSelect}
            aria-pressed={selected}
            title={`${account.name} — ${account.id}`}
            className="account-card group shrink-0"
            data-selected={selected ? "true" : undefined}
        >
            <span className="account-card__icon">
                {personal ? <Wallet size={18} /> : <Building2 size={18} />}
            </span>

            <span className="account-card__identity">
                <span className="account-card__name" title={account.name}>{account.name}</span>
                <span className="account-card__iban">
                    <span className="truncate">
                        {isFrozen(account) ? t("renewed.frozen") : account.id}
                    </span>
                </span>
            </span>

            <span className="account-card__balance">
                <span className="account-card__balance-label">{t("dashboard.balance")}</span>
                <span className="account-card__balance-value">{money(account.amount)}</span>
            </span>

            <span className="account-card__go" aria-hidden="true"><ChevronRight size={16} /></span>
        </button>
    )
}

interface AccountsProps {
    accounts: RenewedAccount[]
    selectedId: string | null
    onSelect: (id: string) => void
}

export const Accounts: React.FC<AccountsProps> = ({ accounts, selectedId, onSelect }) => {
    const { t } = useLocale()
    const personalRef = useHorizontalWheel()
    const orgRef = useHorizontalWheel()

    const selected = accounts.find((a) => a.id === selectedId) ?? accounts[0]
    const { personal, orgs } = splitAccounts(accounts)
    const total = accounts.reduce((sum, a) => sum + Number(a.amount || 0), 0)
    const cash = personal[0]?.cash

    const Strip: React.FC<{
        title: string; subtitle: string; icon: React.ReactNode; personal: boolean
        list: RenewedAccount[]; stripRef: React.RefObject<HTMLDivElement | null>
    }> = ({ title, subtitle, icon, list, stripRef, personal: isPersonalStrip }) => (
        <div>
            <div className="flex items-center gap-3 mb-4">
                <div className="p-2 rounded-lg border"
                     style={{ borderColor: "var(--noir-border-soft)", color: "var(--noir-text-muted)" }}>
                    {icon}
                </div>
                <div>
                    <h3 className="text-[15px] font-bold" style={{ color: "var(--noir-text-strong)" }}>{title}</h3>
                    <p className="text-[11px]" style={{ color: "var(--noir-text-muted)" }}>{subtitle}</p>
                </div>
            </div>
            <div className="account-strip" ref={stripRef}>
                {list.map((acc) => (
                    <AccountCard key={acc.id} account={acc} selected={acc.id === selected?.id}
                                 personal={isPersonalStrip} onSelect={() => onSelect(acc.id)} />
                ))}
            </div>
        </div>
    )

    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-3xl p-6 md:p-8"
                 style={{ background: "var(--noir-card)", border: "1px solid var(--noir-border-soft)" }}>
                <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                    <div>
                        <p className="font-medium mb-2 text-sm" style={{ color: "var(--noir-text)" }}>
                            {t("dashboard.totalBalance")}
                        </p>
                        <h2 className="text-4xl md:text-5xl font-bold tracking-tight"
                            style={{ color: "var(--noir-text-strong)" }}>
                            {money(total)}
                        </h2>
                        {selected && (
                            <p className="mt-2 text-sm" style={{ color: "var(--noir-text)" }}>
                                {t("dashboard.selectedAccountBalance")}:{" "}
                                <span className="font-semibold" style={{ color: "var(--noir-text-strong)" }}>
                                    {money(selected.amount)}
                                </span>
                            </p>
                        )}
                        {typeof cash === "number" && (
                            <p className="mt-1 text-[12px]" style={{ color: "var(--noir-text-muted)" }}>
                                {t("renewed.cashOnHand")}: <span className="font-semibold">{money(cash)}</span>
                            </p>
                        )}
                    </div>
                    {selected && (
                        <div className="px-4 py-2 rounded-lg"
                             style={{ background: "rgba(255,255,255,0.08)", border: "1px solid var(--noir-border)" }}>
                            <span className="font-medium text-[13px]" style={{ color: "var(--noir-text-strong)" }}>
                                {selected.name}
                            </span>
                        </div>
                    )}
                </div>
            </div>

            {personal.length > 0 && (
                <Strip title={t("dashboard.yourAccounts")}
                       subtitle={t("renewed.personalAccount")}
                       icon={<Wallet size={18} />} personal
                       list={personal} stripRef={personalRef} />
            )}

            {orgs.length > 0 && (
                <Strip title={t("dashboard.sharedAccounts")}
                       subtitle={t("dashboard.sharedAccountsCount", {
                           count: orgs.length, plural: orgs.length !== 1 ? "s" : "",
                       })}
                       icon={<Building2 size={18} />} personal={false}
                       list={orgs} stripRef={orgRef} />
            )}

            {accounts.length === 0 && (
                <p className="py-10 text-center text-[13px]" style={{ color: "var(--noir-text-muted)" }}>
                    {t("renewed.noAccount")}
                </p>
            )}
        </div>
    )
}
