"use client"

import type React from "react"
import {
    LayoutDashboard, CreditCard, History, Banknote, Building2, LogOut, PiggyBank,
    Users, ArrowLeftRight, Repeat, FileText, Receipt, Wallet,
} from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface SidebarProps {
    activeTab: string
    setActiveTab: (tab: string) => void
    onClose: () => void
    currentBank?: string
    currentBankType?: string
    bankManagementEnabled?: boolean
    directDebitsEnabled?: boolean
    checksEnabled?: boolean
    scheduleChecksEnabled?: boolean
    transferRequestsEnabled?: boolean
    contactsEnabled?: boolean
    savingsEnabled?: boolean
    scheduledEnabled?: boolean
    loansEnabled?: boolean
    cardsEnabled?: boolean
}

/**
 * Rail de navegação do DESIGN_v3 (§7.1), em estado aberto permanente.
 *
 * O v3 prevê recolher/expandir, mas este resource não expõe o controle: o banco
 * tem até treze destinos e rótulo visível é o que os distingue -- `Contas`,
 * `Cartões` e `Cheques` viram três ícones parecidos sem texto. Sem o botão, some
 * também a faixa de identidade com o `<` integrado, que só existe para abrigá-lo.
 */
export const Sidebar: React.FC<SidebarProps> = ({
    activeTab, setActiveTab, onClose, currentBank, currentBankType,
    bankManagementEnabled, directDebitsEnabled, checksEnabled,
    transferRequestsEnabled, contactsEnabled,
    savingsEnabled, scheduledEnabled, loansEnabled, cardsEnabled,
}) => {
    const { t } = useLocale()

    const bankTitle = currentBank && currentBank.trim() ? currentBank : t("sidebar.bankName")
    const bankSubtitle =
        currentBank && currentBank.trim()
            ? currentBankType === "state"
                ? t("dashboard.bankInfo.bankTypes.state")
                : currentBankType === "private"
                    ? t("dashboard.bankInfo.bankTypes.private")
                    : undefined
            : t("sidebar.bankSubtitle")

    const menuItems = [
        { id: "accounts", label: t("sidebar.accounts"), icon: <Wallet size={18} /> },
        ...(cardsEnabled ? [{ id: "cards", label: t("sidebar.cards"), icon: <CreditCard size={18} /> }] : []),
        { id: "transactions", label: t("sidebar.transactions"), icon: <History size={18} /> },
        ...(loansEnabled ? [{ id: "loans", label: t("sidebar.loans"), icon: <Banknote size={18} /> }] : []),
        ...(savingsEnabled ? [{ id: "savings", label: t("sidebar.savings"), icon: <PiggyBank size={18} /> }] : []),
        ...(scheduledEnabled ? [{ id: "scheduled", label: t("sidebar.scheduled"), icon: <Repeat size={18} /> }] : []),
        ...(checksEnabled ? [{ id: "checks", label: t("sidebar.checks"), icon: <FileText size={18} /> }] : []),
        ...(directDebitsEnabled ? [{ id: "directdebits", label: t("sidebar.directDebits"), icon: <Receipt size={18} /> }] : []),
        { id: "stats", label: t("sidebar.stats"), icon: <LayoutDashboard size={18} /> },
        ...(transferRequestsEnabled ? [{ id: "requests", label: t("sidebar.requests"), icon: <ArrowLeftRight size={18} /> }] : []),
        ...(contactsEnabled ? [{ id: "contacts", label: t("sidebar.contacts"), icon: <Users size={18} /> }] : []),
        ...(bankManagementEnabled ? [{ id: "banks", label: t("sidebar.banks"), icon: <Building2 size={18} /> }] : []),
    ]

    /** §7.1: setas, Home e End num tablist vertical. */
    const onKeyDown = (event: React.KeyboardEvent<HTMLDivElement>) => {
        const keys = ["ArrowDown", "ArrowUp", "Home", "End"]
        if (!keys.includes(event.key)) return
        event.preventDefault()
        const index = menuItems.findIndex((item) => item.id === activeTab)
        const last = menuItems.length - 1
        const next =
            event.key === "Home" ? 0
                : event.key === "End" ? last
                    : event.key === "ArrowDown" ? (index + 1 > last ? 0 : index + 1)
                        : (index - 1 < 0 ? last : index - 1)
        setActiveTab(menuItems[next].id)
    }

    return (
        <div className="nav-rail w-72 m-4 rounded-xl overflow-hidden">
            <div className="p-4 pb-3">
                <div className="nav-rail__brand">
                    <div
                        className="w-[34px] h-[34px] rounded-md grid place-items-center"
                        style={{ background: "rgba(0,0,0,0.22)" }}
                    >
                        <Building2 size={18} style={{ color: "var(--noir-on-accent)" }} />
                    </div>
                    <div className="min-w-0">
                        <h1
                            className="text-[15px] font-semibold leading-tight truncate"
                            style={{ color: "var(--noir-on-accent)", letterSpacing: "-0.015em" }}
                            title={bankTitle}
                        >
                            {bankTitle}
                        </h1>
                        {bankSubtitle ? (
                            <p className="text-[11px] leading-tight truncate" style={{ color: "rgba(255,255,255,0.68)" }}>
                                {bankSubtitle}
                            </p>
                        ) : null}
                    </div>
                </div>
            </div>

            <div
                role="tablist"
                aria-orientation="vertical"
                aria-label={t("sidebar.bankName")}
                onKeyDown={onKeyDown}
                className="flex-1 min-h-0 overflow-y-auto px-3 pb-3 space-y-1"
            >
                {menuItems.map((item) => {
                    const selected = activeTab === item.id
                    return (
                        <button
                            key={item.id}
                            role="tab"
                            aria-selected={selected}
                            tabIndex={selected ? 0 : -1}
                            onClick={() => setActiveTab(item.id)}
                            className="nav-rail__item"
                        >
                            <span className="shrink-0 grid place-items-center">{item.icon}</span>
                            <span className="truncate">{item.label}</span>
                        </button>
                    )
                })}
            </div>

            {/* §7.1: ação global fica separada no fim do rail. */}
            <div className="px-3 py-3" style={{ borderTop: "1px solid rgba(0,0,0,0.22)" }}>
                <button onClick={onClose} className="nav-rail__item nav-rail__danger">
                    <span className="shrink-0 grid place-items-center"><LogOut size={18} /></span>
                    <span className="truncate">{t("sidebar.close")}</span>
                </button>
            </div>
        </div>
    )
}
